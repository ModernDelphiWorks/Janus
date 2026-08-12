{
  ------------------------------------------------------------------------------
  Janus
  Modern Object-Relational Mapping (ORM) framework for Delphi.

  SPDX-License-Identifier: MIT
  Copyright (c) 2016-2026 Isaque Pinheiro

  Licensed under the MIT License.
  See the LICENSE file in the project root for full license information.
  ------------------------------------------------------------------------------
}

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Test.Janus.DML.Generator.ADS;

interface

uses
  Winapi.Windows,
  SysUtils,
  DateUtils,
  DUnitX.TestFramework,
  DataEngine.FactoryInterfaces,
  MetaDbDiff.Mapping.Classes,
  MetaDbDiff.Types.Mapping,
  Janus.Command.Selecter,
  Janus.DML.Generator.ADS,
  Janus.DML.Generator.MSSQL,
  Janus.Model.Client,
  Test.Janus.Model.Moment,
  // TFakeConnection: o duble de IDBConnection ja existente para os testes de
  // gerador; reaproveitado em vez de duplicado.
  Test.Janus.DML.Generator.SQLite;

type
  // FDateFormat/FTimeFormat sao protected em TDMLGeneratorAbstract; um
  // descendente e o unico caminho legitimo para ler o que o gerador do ADS
  // realmente entrega ao FormatDateTime nos dois ramos de data de
  // TDMLGeneratorAbstract._GetPropertyValue - o de ftDateTime/ftDate e o de
  // ftTime/ftTimeStamp/ftOraTimeStamp. POR RAMO, e nao por linha: o
  // ":624/617" que estava aqui ja tinha UMA das duas ancoras podre ANTES desta
  // frente - :617 era o ramo ftLargeint, que nao chama FormatDateTime nenhum -
  // e a outra apodreceu quando a issue #326 inseriu 97 linhas naquela unit.
  TADSGeneratorProbe = class(TDMLGeneratorADS)
  public
    function DateFormat: String;
    function TimeFormat: String;
  end;

  [TestFixture]
  TTestDMLGeneratorADS = class
  private
    FGenerator: TADSGeneratorProbe;
    // 15/03/2027 14:07:53 -- dia e mes distinguiveis, para que uma troca
    // dd<->MM apareca na assercao de igualdade exata.
    function SampleMoment: TDateTime;
    // Monta na mao a associacao TMoment -> Tclient sobre a coluna pedida. Feito
    // na mao de proposito: nenhuma entidade mapeada da casa associa por coluna
    // de data/hora, e registrar uma so para isso mexeria no explorer global.
    function AssociationOn(const AOwnerColumn: String): TAssociationMapping;
    // Devolve o conteudo da PRIMEIRA literal entre aspas simples do SQL, que e
    // exatamente o que _GetPropertyValue produziu e o QuotedStr embrulhou.
    function FirstQuotedLiteral(const ASQL: String): String;
    // Roda AProc com um FormatSettings global hostil e SEMPRE restaura o
    // original. Nao restaurar aqui envenena a suite inteira.
    procedure WithHostileLocale(const AProc: TProc);
    // Roda AProc com o LOCALE DE THREAD trocado por um cujo DateSeparator e '.'
    // (de-DE, $0407) e SEMPRE restaura. Diferente de WithHostileLocale: aqui a
    // variavel global FormatSettings continua intacta, so o locale do SO muda.
    procedure WithHostileThreadLocale(const AProc: TProc);
    // SQL de associacao gerado por um dialeto a partir de TMoment.
    function GenerateWhereFor(const ADriver: TDriverName;
      const AOwnerColumn: String): String;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure TestDateFormat_ProducesAnsiDateLiteral;
    [Test]
    procedure TestDateFormat_DoesNotDependOnClientDateSeparator;
    [Test]
    procedure TestTimeFormat_ProducesTimeOfDay;
    [Test]
    procedure TestGeneratedSql_AdsDateLiteralReachesTheWhere;
    [Test]
    procedure TestGeneratedSql_TimeLiteralIsStableUnderHostileTimeSeparator;
    [Test]
    procedure TestGeneratedSql_SlashDateMaskIsStableUnderHostileDateSeparator;
    [Test]
    procedure TestGeneratedSql_DefaultLocaleOutputIsUnchanged;
    [Test]
    procedure TestGeneratedSql_DateLiteralIgnoresTheOperatingSystemLocale;
  end;

implementation

{ TADSGeneratorProbe }

function TADSGeneratorProbe.DateFormat: String;
begin
  Result := FDateFormat;
end;

function TADSGeneratorProbe.TimeFormat: String;
begin
  Result := FTimeFormat;
end;

{ TTestDMLGeneratorADS }

function TTestDMLGeneratorADS.SampleMoment: TDateTime;
begin
  Result := EncodeDateTime(2027, 3, 15, 14, 7, 53, 0);
end;

procedure TTestDMLGeneratorADS.Setup;
begin
  FGenerator := TADSGeneratorProbe.Create;
end;

procedure TTestDMLGeneratorADS.TearDown;
begin
  FGenerator.Free;
end;

function TTestDMLGeneratorADS.AssociationOn(
  const AOwnerColumn: String): TAssociationMapping;
begin
  Result := TAssociationMapping.Create(TMultiplicity.OneToOne,
                                       [AOwnerColumn], ['client_id'],
                                       'Tclient', nil, False, []);
end;

function TTestDMLGeneratorADS.FirstQuotedLiteral(const ASQL: String): String;
var
  LOpen: Integer;
  LClose: Integer;
begin
  LOpen := Pos('''', ASQL);
  Assert.IsTrue(LOpen > 0,
    'O SQL gerado deveria trazer a literal entre aspas simples: ' + ASQL);
  LClose := Pos('''', ASQL, LOpen + 1);
  Assert.IsTrue(LClose > LOpen,
    'A literal do SQL gerado ficou sem a aspa de fechamento: ' + ASQL);
  Result := Copy(ASQL, LOpen + 1, LClose - LOpen - 1);
end;

procedure TTestDMLGeneratorADS.WithHostileLocale(const AProc: TProc);
var
  LSaved: TFormatSettings;
begin
  LSaved := FormatSettings;
  try
    FormatSettings.DateSeparator := '.';
    FormatSettings.TimeSeparator := '-';
    AProc();
  finally
    FormatSettings := LSaved;
  end;
end;

procedure TTestDMLGeneratorADS.WithHostileThreadLocale(const AProc: TProc);
const
  // de-DE: DateSeparator '.', TimeSeparator ':'
  CGermanLCID = $0407;
var
  LSaved: LCID;
begin
  LSaved := GetThreadLocale;
  try
    Assert.IsTrue(SetThreadLocale(CGermanLCID),
      'Nao foi possivel trocar o locale de thread para de-DE; sem isso este ' +
      'teste passaria por acidente');
    // Guarda contra falso verde: so vale medir se a troca REALMENTE mudou o
    // que TFormatSettings.Create le.
    Assert.AreEqual('.', String(TFormatSettings.Create.DateSeparator),
      'O locale de thread nao surtiu efeito; o teste nao mediria nada');
    AProc();
  finally
    SetThreadLocale(LSaved);
  end;
end;

function TTestDMLGeneratorADS.GenerateWhereFor(const ADriver: TDriverName;
  const AOwnerColumn: String): String;
var
  LOwner: TMoment;
  LConnection: IDBConnection;
  LAssociation: TAssociationMapping;
  LSelecter: TCommandSelecter;
begin
  LOwner := TMoment.Create;
  try
    LOwner.moment_id := 1;
    LOwner.moment_date := SampleMoment;
    LOwner.moment_time := SampleMoment;
    LConnection := TFakeConnection.Create(ADriver);
    LAssociation := AssociationOn(AOwnerColumn);
    try
      LSelecter := TCommandSelecter.Create(LConnection, ADriver, LOwner);
      try
        Result := LSelecter.GenerateSelectOneToOne(LOwner, Tclient,
                                                   LAssociation);
      finally
        LSelecter.Free;
      end;
    finally
      LAssociation.Free;
    end;
  finally
    LOwner.Free;
  end;
end;

procedure TTestDMLGeneratorADS.TestDateFormat_ProducesAnsiDateLiteral;
begin
  // Este e literalmente o valor que o ramo ftDateTime/ftDate de
  // TDMLGeneratorAbstract._GetPropertyValue embute, entre
  // aspas simples, em todo WHERE gerado para o dialeto Advantage.
  // A mascara anterior 'DD/MM/CCYY' entregava aqui (medido)
  // '15/03/15/03/2027 14:07:5327', porque 'CC' nao e especificador do
  // FormatDateTime -- 'C' e data curta + hora longa, e o 'YY' final ainda
  // colava o ano de dois digitos.
  Assert.AreEqual('2027-03-15',
    FormatDateTime(FGenerator.DateFormat, SampleMoment),
    'A literal de data do ADS deve ser o formato ANSI ccyy-mm-dd');
end;

procedure TTestDMLGeneratorADS.TestDateFormat_DoesNotDependOnClientDateSeparator;
var
  LSettings: TFormatSettings;
begin
  // O FormatDateTime troca '/' pelo DateSeparator e ':' pelo TimeSeparator; o
  // '-' e literal. Uma mascara com '/' produziria separador diferente sob outro
  // locale; a ANSI nao. Medido aqui com um DateSeparator hostil.
  LSettings := TFormatSettings.Create;
  LSettings.DateSeparator := '.';
  Assert.AreEqual('2027-03-15',
    FormatDateTime(FGenerator.DateFormat, SampleMoment, LSettings),
    'O formato ANSI nao pode variar com o DateSeparator do cliente');
end;

procedure TTestDMLGeneratorADS.TestTimeFormat_ProducesTimeOfDay;
begin
  // 'MM' logo apos 'HH' e minuto, nao mes -- medido, e por isso o FTimeFormat
  // 'HH:MM:SS' (o mesmo nos 13 geradores) NAO tem o defeito da data.
  Assert.AreEqual('14:07:53',
    FormatDateTime(FGenerator.TimeFormat, SampleMoment),
    'A literal de hora do ADS deve trazer hora:minuto:segundo');
end;

procedure TTestDMLGeneratorADS.TestGeneratedSql_AdsDateLiteralReachesTheWhere;
begin
  // Caminho de producao de verdade: GenerateSelectOneToOne -> GetValue ->
  // _GetPropertyValue, ramo ftDateTime/ftDate. Prova que a mascara
  // corrigida do ADS chega mesmo ao SQL, e nao so ao FormatDateTime do teste.
  Assert.AreEqual('2027-03-15',
    FirstQuotedLiteral(GenerateWhereFor(dnADS, 'moment_date')),
    'O WHERE do ADS deve trazer a data no formato ANSI');
end;

procedure TTestDMLGeneratorADS.TestGeneratedSql_TimeLiteralIsStableUnderHostileTimeSeparator;
begin
  // Mesmo caminho, ramo da hora (ftTime/ftTimeStamp/ftOraTimeStamp de
  // TDMLGeneratorAbstract._GetPropertyValue). A mascara
  // 'HH:MM:SS' -- identica nos treze geradores -- TEM ':', entao com a
  // sobrecarga que le o FormatSettings global uma maquina com TimeSeparator
  // '-' emitia (medido) '14-07-53'. Morre se a chamada voltar a ler o global.
  WithHostileLocale(
    procedure
    begin
      Assert.AreEqual('14:07:53',
        FirstQuotedLiteral(GenerateWhereFor(dnADS, 'moment_time')),
        'A literal de hora no SQL gerado nao pode seguir o locale da maquina');
    end);
end;

procedure TTestDMLGeneratorADS.TestGeneratedSql_SlashDateMaskIsStableUnderHostileDateSeparator;
begin
  // A mascara ANSI do ADS nao tem '/', entao ela sozinha nao consegue provar o
  // ramo da DATA. O MSSQL usa 'dd/MM/yyyy'; com a sobrecarga global e
  // DateSeparator '.' o servidor recebia (medido) '15.03.2027'. Este teste esta
  // aqui porque o conserto vive na base TDMLGeneratorAbstract, e portanto vale
  // para os treze dialetos, nao so para o ADS.
  // MSSQL de proposito, e nao Firebird: Janus.Command.Selecter.pas:70 troca o
  // gerador de dnFirebird/dnFirebird3 por dnSQLite, entao um teste "Firebird"
  // aqui mediria a mascara do SQLite (medido).
  WithHostileLocale(
    procedure
    begin
      Assert.AreEqual('15/03/2027',
        FirstQuotedLiteral(GenerateWhereFor(dnMSSQL, 'moment_date')),
        'A literal de data de um dialeto com mascara "/" nao pode seguir o locale');
    end);
end;

procedure TTestDMLGeneratorADS.TestGeneratedSql_DefaultLocaleOutputIsUnchanged;
begin
  // O conserto tem de ser invisivel no caso normal: com o FormatSettings da
  // maquina intacto, a saida e a mesma de antes, nos tres ramos medidos.
  Assert.AreEqual('2027-03-15',
    FirstQuotedLiteral(GenerateWhereFor(dnADS, 'moment_date')),
    'A data do ADS nao pode mudar numa maquina de locale padrao');
  Assert.AreEqual('15/03/2027',
    FirstQuotedLiteral(GenerateWhereFor(dnMSSQL, 'moment_date')),
    'A data do MSSQL nao pode mudar numa maquina de locale padrao');
  Assert.AreEqual('14:07:53',
    FirstQuotedLiteral(GenerateWhereFor(dnADS, 'moment_time')),
    'A hora nao pode mudar numa maquina de locale padrao');
end;

procedure TTestDMLGeneratorADS.TestGeneratedSql_DateLiteralIgnoresTheOperatingSystemLocale;
begin
  // Os dois testes de locale hostil acima fixam apenas "nao le a variavel
  // global FormatSettings" -- e por isso trocar TFormatSettings.Invariant por
  // TFormatSettings.Create sobrevive a eles: o .Create nao le a global, le o
  // locale do SO. Aqui o locale de THREAD e trocado antes de o gerador ser
  // construido (e o construtor que captura FFormatSettings), com a global
  // intacta. Medido: sob de-DE, 'dd/MM/yyyy' rende '15.03.2027' com
  // TFormatSettings.Create e '15/03/2027' com TFormatSettings.Invariant.
  WithHostileThreadLocale(
    procedure
    begin
      Assert.AreEqual('15/03/2027',
        FirstQuotedLiteral(GenerateWhereFor(dnMSSQL, 'moment_date')),
        'A literal de data nao pode seguir o locale do sistema operacional');
    end);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDMLGeneratorADS);

end.
