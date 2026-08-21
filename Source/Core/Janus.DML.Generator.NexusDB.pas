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

unit Janus.DML.Generator.NexusDB;

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
  // Classe de banco de dados NexusDB
  TDMLGeneratorNexusDB = class(TDMLGeneratorAbstract)
  protected
    /// <summary> Issue #355. dbnNexusDB is in the enum and unimplemented -
    ///  same measurement as the ADS sibling. Answers dbnMSSQL, which is what
    ///  this generator was already emitting through the enum's zero value, now
    ///  said out loud. </summary>
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
    function GeneratorPageNext(const ACommandSelect: String;
      APageSize, APageNext: Integer): String; override;
  end;

implementation

{ TDMLGeneratorNexusDB }

class function TDMLGeneratorNexusDB.SerializationDialect: TFluentSQLDriver;
begin
  Result := dbnMSSQL;
end;

constructor TDMLGeneratorNexusDB.Create;
begin
  inherited;
  FDateFormat := 'yyyy-mm-dd';
  FTimeFormat := 'HH:MM:SS';
end;

destructor TDMLGeneratorNexusDB.Destroy;
begin
  inherited;
end;

function TDMLGeneratorNexusDB.GeneratorSelectAll(AClass: TClass;
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
        Insert('TOP %s, %s ', Result, LPos + Length(SELECT_CLAUSE));
    end;
    FQueryCache.AddOrSetValue(LKey, Result);
  end;
  LTable := TMappingExplorer.GetMappingTable(AClass);
  // Where
  Result := Result + GetGeneratorWhere(AClass, LTable.Name, AID);
  // OrderBy
  Result := Result + GetGeneratorOrderBy(AClass, LTable.Name, AID);
end;

function TDMLGeneratorNexusDB.GeneratorSelectWhere(AClass: TClass;
  AWhere, AOrderBy: String; APageSize: Integer): String;
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
        Insert('TOP %s, %s ', Result, LPos + Length(SELECT_CLAUSE));
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
  // Scope Where
  LScopeOrderBy := GetGeneratorQueryScopeOrderBy(AClass);
  if LScopeOrderBy <> '' then
    Result := Result + ' ORDER BY ' + LScopeOrderBy;
  if Length(AOrderBy) > 0 then
  begin
    Result := Result + IfThen(LScopeOrderBy = '', ' ORDER BY ', ', ');
    Result := Result + AOrderBy;
  end;
end;

function TDMLGeneratorNexusDB.GeneratorPageNext(const ACommandSelect: String;
  APageSize, APageNext: Integer): String;
begin
  if APageNext = 0 then
    APageNext := 1;
  if APageSize > 0 then
    Result := Format(ACommandSelect, [IntToStr(APageSize), IntToStr(APageNext)])
  else
    Result := ACommandSelect;
end;

function TDMLGeneratorNexusDB.GeneratorAutoIncCurrentValue(AObject: TObject;
  AAutoInc: TDMLCommandAutoInc): Int64;
begin
  Result := ExecuteSequence(Format('SELECT MAX(%s) FROM %s',
                                   [AAutoInc.PrimaryKey.Columns.Items[0],
                                    AAutoInc.Sequence.TableName]));
end;

function TDMLGeneratorNexusDB.GeneratorAutoIncNextValue(AObject: TObject;
  AAutoInc: TDMLCommandAutoInc): Int64;
begin
  Result := GeneratorAutoIncCurrentValue(AObject, AAutoInc)
          + AAutoInc.Sequence.Increment;
end;

/// <summary> NAO MEDIDO CONTRA DOCUMENTACAO OFICIAL. nexusdb.com responde HTTP
///  403 a fetch programatico em todo caminho, inclusive sqldatatypes.htm,
///  valueexpressions.htm e o wiki de GUIDs. As paginas existem e estao
///  indexadas; um navegador as alcancaria. Ha' espelho verbatim em terceiro,
///  deliberadamente NAO usado por nao ser fonte oficial.
///  Nao ha' sequer arquivo de metadata para NexusDB em Source/Drivers, entao
///  nem o DDL desta casa diz o que a coluna vira.
///  Fica a forma canonica, conservadora e marcada: hoje este dialeto devolve
///  '1 = 0' em silencio e qualquer literal ja e' melhora. Sem excecao - trocar
///  um silencio por um crash em quem hoje ao menos nao estoura seria piorar
///  antes de medir. </summary>
function TDMLGeneratorNexusDB.GuidLiteral(const AGuid: TGUID): String;
begin
  Result := CanonicalGuidLiteral(AGuid);
end;

initialization
  TDriverRegister.RegisterDriver(dnNexusDB,
    function: IDMLGeneratorCommand
    begin
      Result := TDMLGeneratorNexusDB.Create;
    end);

end.