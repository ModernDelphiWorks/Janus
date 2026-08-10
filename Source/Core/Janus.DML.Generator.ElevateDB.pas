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

unit Janus.DML.Generator.ElevateDB;

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
  // Classe de banco de dados ElevateDB
  TDMLGeneratorElevateDB = class(TDMLGeneratorAbstract)
  protected
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

{ TDMLGeneratorElevateDB }

constructor TDMLGeneratorElevateDB.Create;
begin
  inherited;
  FDateFormat := 'yyyy-mm-dd';
  FTimeFormat := 'HH:MM:SS';
end;

destructor TDMLGeneratorElevateDB.Destroy;
begin
  inherited;
end;

function TDMLGeneratorElevateDB.GeneratorSelectAll(AClass: TClass;
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

function TDMLGeneratorElevateDB.GeneratorSelectWhere(AClass: TClass;
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

function TDMLGeneratorElevateDB.GeneratorPageNext(const ACommandSelect: String;
  APageSize, APageNext: Integer): String;
begin
  if APageNext = 0 then
    APageNext := 1;
  if APageSize > 0 then
    Result := Format(ACommandSelect, [IntToStr(APageSize), IntToStr(APageNext)])
  else
    Result := ACommandSelect;
end;

function TDMLGeneratorElevateDB.GeneratorAutoIncCurrentValue(AObject: TObject;
  AAutoInc: TDMLCommandAutoInc): Int64;
begin
  Result := ExecuteSequence(Format('SELECT MAX(%s) FROM %s',
                                   [AAutoInc.PrimaryKey.Columns.Items[0],
                                    AAutoInc.Sequence.TableName]));
end;

function TDMLGeneratorElevateDB.GeneratorAutoIncNextValue(AObject: TObject;
  AAutoInc: TDMLCommandAutoInc): Int64;
begin
  Result := GeneratorAutoIncCurrentValue(AObject, AAutoInc)
          + AAutoInc.Sequence.Increment;
end;

/// <summary> O ElevateDB TEM tipo `GUID`, e a doc oficial o define assim,
///  verbatim: "A string value that has an exact length of 38 characters. A GUID
///  value is treated the same as a VARCHAR value."
///  (https://www.elevatesoft.com/manual?action=viewtopic&id=edb2sql&topic=String_Types),
///  e CURRENT_GUID() "returns a new GUID value as a 38-character string"
///  (https://www.elevatesoft.com/manual?action=viewtopic&id=edb2sql&topic=current_guid).
///  38 caracteres so' cabe na forma {8-4-4-4-12}, que e' a que este metodo
///  emite, e "tratado como VARCHAR" significa literal de string aspado.
///  NAO MEDIDO: a doc nao diz nada sobre chaves, hifens, caixa dos hex nem
///  case-sensitivity da comparacao - a pagina de CAST tambem e' silente
///  (https://www.elevatesoft.com/manual?action=viewtopic&id=edb2sql&topic=CAST).
///  A forma de 38 e' inferencia a partir do comprimento documentado, nao um
///  fato documentado. </summary>
function TDMLGeneratorElevateDB.GuidLiteral(const AGuid: TGUID): String;
begin
  Result := CanonicalGuidLiteral(AGuid);
end;

initialization
  TDriverRegister.RegisterDriver(dnElevateDB,
    function: IDMLGeneratorCommand
    begin
      Result := TDMLGeneratorElevateDB.Create;
    end);

end.

