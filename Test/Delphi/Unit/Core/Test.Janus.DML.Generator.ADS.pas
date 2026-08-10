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
  SysUtils,
  DateUtils,
  DUnitX.TestFramework,
  Janus.DML.Generator.ADS;

type
  // FDateFormat/FTimeFormat sao protected em TDMLGeneratorAbstract; um
  // descendente e o unico caminho legitimo para ler o que o gerador do ADS
  // realmente entrega ao FormatDateTime em Janus.DML.Generator.pas:519/522.
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

procedure TTestDMLGeneratorADS.TestDateFormat_ProducesAnsiDateLiteral;
begin
  // Este e literalmente o valor que Janus.DML.Generator.pas:519 embute, entre
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
  // '-' e literal. Como a producao (Janus.DML.Generator.pas:519) chama a
  // sobrecarga SEM TFormatSettings, ela usa o FormatSettings global da maquina.
  // Uma mascara com '/' produziria separador diferente sob outro locale; a
  // ANSI nao. Medido aqui com um DateSeparator hostil.
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

initialization
  TDUnitX.RegisterTestFixture(TTestDMLGeneratorADS);

end.
