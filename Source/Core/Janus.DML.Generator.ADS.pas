{
  ------------------------------------------------------------------------------
  Janus ORM
  State-of-the-art Object-Relational Mapping (ORM) framework for Delphi.

  SPDX-License-Identifier: MIT
  Copyright (c) 2025-2026 Isaque Pinheiro

  Licensed under the MIT License.
  See the LICENSE file in the project root for full license information.
  ------------------------------------------------------------------------------
}

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
}

unit Janus.DML.Generator.ADS;

interface

uses
  Classes,
  SysUtils,
  StrUtils,
  Variants,
  Rtti,
  Janus.DML.Generator,
  MetaDbDiff.Mapping.Classes,
  MetaDbDiff.Mapping.Explorer,
  DataEngine.FactoryInterfaces,
  Janus.Driver.Register,
  Janus.DML.Interfaces,
  Janus.DML.Commands,
  Janus.DML.Cache,
  FluentSQL,
  FluentSQL.Interfaces;

type
  // Classe de banco de dados ADS
  TDMLGeneratorADS = class(TDMLGeneratorAbstract)
  protected
    /// <summary> Issue #355. dbnADS EXISTS in TFluentSQLDriver and has NO
    ///  implementation: there is no FluentSQL.Serialize.ADS / Select.ADS unit
    ///  and no _Register call for it, so FluentSQL.Register.pas raises
    ///  EFluentSQLDriverNotRegistered the moment a statement is serialized.
    ///  Measured: naming dbnADS here turns GeneratorInsert, GeneratorUpdate,
    ///  GeneratorDelete and _BuildSelectSQL into that exception, all four.
    ///
    ///  So this answers dbnMSSQL - not because T-SQL is what an Advantage
    ///  server speaks, but because it is what this generator has been emitting
    ///  since the field existed, and because it is the one registered
    ///  serializer that leaves the ':pN' markers alone. The day FluentSQL
    ///  registers dbnADS this line is the single place to change. </summary>
    class function SerializationDialect: TFluentSQLDriver; override;
    /// Ver TDMLGeneratorAbstract.GuidLiteral: abstract de proposito,
    /// para que um dialeto novo nao herde em silencio o literal de outro.
    function GuidLiteral(const AGuid: TGUID): String; override;
  public
    constructor Create; override;
    destructor Destroy; override;
    function GeneratorSelectAll(AClass: TClass;
      APageSize: Integer; AID: TValue): String; override;
    function GeneratorSelectWhere(AClass: TClass; AWhere: String;
      AOrderBy: String; APageSize: Integer): String; override;
    function GeneratorAutoIncCurrentValue(AObject: TObject;
      AAutoInc: TDMLCommandAutoInc): Int64; override;
    function GeneratorAutoIncNextValue(AObject: TObject;
      AAutoInc: TDMLCommandAutoInc): Int64; override;
  end;

implementation

{ TDMLGeneratorADS }

class function TDMLGeneratorADS.SerializationDialect: TFluentSQLDriver;
begin
  Result := dbnMSSQL;
end;

constructor TDMLGeneratorADS.Create;
begin
  inherited;
  // 'CC' nao e especificador do FormatDateTime do Delphi. O 'C' da RTL e data
  // curta + hora longa, e a RTL consome os 'c' consecutivos numa unica
  // expansao, entao 'DD/MM/CCYY' com 15/03/2027 14:07:53 produzia (medido)
  // '15/03/15/03/2027 14:07:5327' -- toda literal de data gerada para o
  // dialeto ADS saia malformada.
  // De onde saiu esse 'CCYY' e DESCONHECIDO. Nao e mascara da RTL, e tambem
  // nao e mascara do Advantage: a referencia da ACE API para AdsSetDateFormat
  // diz que o formato "must contain two or more occurrences of the letters D,
  // M, and Y respectively (e.g. "MMDDYYYY")", com default "MM/DD/YYYY" -- o
  // alfabeto e D/M/Y, nunca C. Nao ha etiologia comprovada aqui.
  // 'yyyy-MM-dd' e o formato ANSI (ccyy-mm-dd, prosa do Developer's Guide para
  // o layout da literal) que o Advantage aceita independentemente do formato
  // de data configurado no cliente por AdsSetDateFormat / TAdsSettings.
  // DateFormat.
  FDateFormat := 'yyyy-MM-dd';
  FTimeFormat := 'HH:MM:SS';
end;

destructor TDMLGeneratorADS.Destroy;
begin
  inherited;
end;

function TDMLGeneratorADS.GeneratorSelectAll(AClass: TClass;
  APageSize: Integer; AID: TValue): String;
const
  SELECT_CLAUSE = 'SELECT ';
var
  LSQL: IFluentSQL;
  LTable: TTableMapping;
  LKey: string;
  LPos: Integer;
begin
  LKey := AClass.ClassName + '-SELECT';
  if APageSize > -1 then
    LKey := LKey + '-PAGINATE';
  if not FQueryCache.TryGetValue(LKey, Result) then
  begin
    LSQL := _BuildSelectSQL(AClass, AID);
    Result := LSQL.AsString;
    if APageSize > -1 then
    begin
      LPos := Pos(SELECT_CLAUSE, UpperCase(Result));
      if LPos > 0 then
        Insert('FIRST %s SKIP %s ', Result, LPos + Length(SELECT_CLAUSE));
    end;
    FQueryCache.AddOrSetValue(LKey, Result);
  end;
  LTable := TMappingExplorer.GetMappingTable(AClass);
  // Where
  Result := Result + GetGeneratorWhere(AClass, LTable.Name, AID);
  // OrderBy
  Result := Result + GetGeneratorOrderBy(AClass, LTable.Name, AID);
end;

function TDMLGeneratorADS.GeneratorSelectWhere(AClass: TClass;
  AWhere: String; AOrderBy: String; APageSize: Integer): String;
const
  SELECT_CLAUSE = 'SELECT ';
var
  LSQL: IFluentSQL;
  LScopeWhere: String;
  LScopeOrderBy: String;
  LKey: string;
  LPos: Integer;
begin
  LKey := AClass.ClassName + '-SELECT';
  if APageSize > -1 then
    LKey := LKey + '-PAGINATE';
  if not FQueryCache.TryGetValue(LKey, Result) then
  begin
    LSQL := _BuildSelectSQL(AClass, '-1');
    Result := LSQL.AsString;
    if APageSize > -1 then
    begin
      LPos := Pos(SELECT_CLAUSE, UpperCase(Result));
      if LPos > 0 then
        Insert('FIRST %s SKIP %s ', Result, LPos + Length(SELECT_CLAUSE));
    end;
    FQueryCache.AddOrSetValue(LKey, Result);
  end;
  // Scope Where
  LScopeWhere := GetGeneratorQueryScopeWhere(AClass);
  if LScopeWhere <> '' then
    Result := Result + ' WHERE ' + LScopeWhere;
  if Length(AWhere) > 0 then
  begin
    Result := Result + IfThen(LScopeWhere = '', ' WHERE ', ' AND ');
    Result := Result + AWhere;
  end;
  // Scope OrderBy
  LScopeOrderBy := GetGeneratorQueryScopeOrderBy(AClass);
  if LScopeOrderBy <> '' then
    Result := Result + ' ORDER BY ' + LScopeOrderBy;
  if Length(AOrderBy) > 0 then
  begin
    Result := Result + IfThen(LScopeOrderBy = '', ' ORDER BY ', ', ');
    Result := Result + AOrderBy;
  end;
end;

function TDMLGeneratorADS.GeneratorAutoIncCurrentValue(AObject: TObject;
  AAutoInc: TDMLCommandAutoInc): Int64;
begin
  Result := ExecuteSequence(Format('SELECT GEN_ID(%s, 0) FROM RDB$DATABASE;',
                                   [AAutoInc.Sequence.Name]));
end;

function TDMLGeneratorADS.GeneratorAutoIncNextValue(AObject: TObject;
  AAutoInc: TDMLCommandAutoInc): Int64;
begin
  Result := ExecuteSequence(Format('SELECT GEN_ID(%s, %s) FROM RDB$DATABASE;',
                                   [AAutoInc.Sequence.Name,
                           IntToStr(AAutoInc.Sequence.Increment)]));
end;

/// <summary> NAO MEDIDO CONTRA DOCUMENTACAO OFICIAL. O Advantage Database
///  Server nao serve mais documentacao: devzone.advantagedatabase.com faz 301
///  para community.sap.com em toda URL de webhelp. Snippets de busca afirmam
///  que o ADS 11+ tem tipo GUID de 16 bytes e funcao NewID(), mas nenhuma
///  pagina oficial abriu e isso NAO fica registrado como fato. ARMADILHA: a doc
///  de `newid` que esta' no ar em help.sap.com e' do SAP ASE, produto
///  DIFERENTE, e nao serve de citacao para o ADS. A doc do ADS hoje so' existe
///  como CHM local (Advantage 12.0\Help\advantage.chm).
///  Nao ha' arquivo de metadata para ADS em Source/Drivers.
///  Fica a forma canonica, conservadora e marcada: hoje este dialeto devolve
///  '1 = 0' em silencio e qualquer literal ja e' melhora. </summary>
function TDMLGeneratorADS.GuidLiteral(const AGuid: TGUID): String;
begin
  Result := CanonicalGuidLiteral(AGuid);
end;

initialization
  TDriverRegister.RegisterDriver(dnADS,
    function: IDMLGeneratorCommand
    begin
      Result := TDMLGeneratorADS.Create;
    end);

end.