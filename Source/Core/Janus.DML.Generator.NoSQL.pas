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

unit Janus.DML.Generator.NoSQL;

interface

uses
  DB,
  Rtti,
  Classes,
  SysUtils,
  Variants,
  StrUtils,
  Generics.Collections,
  Janus.DML.Generator,
  Janus.Json,
  Janus.DML.Commands,
  Janus.Objects.Helper,
  MetaDbDiff.Rtti.Helper,
  MetaDbDiff.Mapping.Classes;

type
  TDMLGeneratorNoSQL = class(TDMLGeneratorAbstract)
  protected
    /// Ver TDMLGeneratorAbstract.GuidLiteral: abstract de proposito,
    /// para que um dialeto novo nao herde em silencio o literal de outro.
    function GuidLiteral(const AGuid: TGUID): String; override;
    function GetCriteriaSelectNoSQL(const AClass: TClass;
      const AID: TValue): String;
    function GetGeneratorSelectNoSQL(const ACriteria: String): String;
    function ExecuteSequence(const ASQL: String): Int64; override;
  public
    constructor Create; override;
    destructor Destroy; override;
    function GeneratorSelectAll(AClass: TClass; APageSize: Integer;
      AID: TVAlue): String; override;
    function GeneratorSelectWhere(AClass: TClass; AWhere: String;
      AOrderBy: String; APageSize: Integer): String; override;
    function GenerateSelectOneToOne(AOwner: TObject; AClass: TClass;
      AAssociation: TAssociationMapping): String; override;
    function GenerateSelectOneToOneMany(AOwner: TObject; AClass: TClass;
      AAssociation: TAssociationMapping): String; override;
    function GeneratorUpdate(AObject: TObject; AParams: TParams;
      AModifiedFields: TDictionary<String, String>): String; override;
    function GeneratorInsert(AObject: TObject): String; override;
    function GeneratorDelete(AObject: TObject; AParams: TParams): String; override;
    function GeneratorAutoIncCurrentValue(AObject: TObject;
      AAutoInc: TDMLCommandAutoInc): Int64; override;
    function GeneratorAutoIncNextValue(AObject: TObject;
      AAutoInc: TDMLCommandAutoInc): Int64; override;
  end;

implementation

uses
  MetaDbDiff.mapping.explorer,
  MetaDbDiff.mapping.attributes;

{ TDMLGeneratorNoSQL }

constructor TDMLGeneratorNoSQL.Create;
begin
  inherited;
end;

destructor TDMLGeneratorNoSQL.Destroy;
begin
  inherited;
end;

function TDMLGeneratorNoSQL.ExecuteSequence(const ASQL: String): Int64;
begin
  Result := 0;
end;

function TDMLGeneratorNoSQL.GenerateSelectOneToOne(AOwner: TObject;
  AClass: TClass; AAssociation: TAssociationMapping): String;
begin
  Result := '';
end;

function TDMLGeneratorNoSQL.GenerateSelectOneToOneMany(AOwner: TObject;
  AClass: TClass; AAssociation: TAssociationMapping): String;
begin
  Result := '';
end;

function TDMLGeneratorNoSQL.GeneratorInsert(AObject: TObject): String;
var
  LTable: TTableMapping;
  LCriteria: TStringBuilder;
begin
  Result := '';
  LTable := TMappingExplorer.GetMappingTable(AObject.ClassType);
  LCriteria := TStringBuilder.Create;
  try
    LCriteria
      .Append('command=insert& ')
        .Append('collection=' + LTable.Name + '& ')
          .Append('json=')
            .Append(TJanusJson.ObjectToJsonString(AObject));
    Result := LCriteria.ToString;
  finally
    LCriteria.Free;
  end;
end;

function TDMLGeneratorNoSQL.GeneratorUpdate(AObject: TObject; AParams: TParams;
  AModifiedFields: TDictionary<String, String>): String;
var
  LTable: TTableMapping;
  LCriteria: TStringBuilder;
  LFor: Integer;
begin
  Result := '';
  LTable := TMappingExplorer.GetMappingTable(AObject.ClassType);
  LCriteria := TStringBuilder.Create;
  try
    LCriteria
      .Append('command=update& ')
        .Append('collection=' + LTable.Name)
          .Append('& ')
            .Append('filter={');
    for LFor := 0 to AParams.Count -1 do
    begin
      LCriteria
        .Append(AnsiQuotedStr(AParams.Items[LFor].Name, '"'))
          .Append(': ')
            .Append(VarToStr(AParams.Items[LFor].Value));
      if LFor < AParams.Count -1 then
        LCriteria.Append('& ');
    end;
    LCriteria
      .Append('}')
        .Append('& ')
          .Append('json=')
            .Append('{"$set":')
              .Append(TJanusJson.ObjectToJsonString(AObject))
                .Append('}');
    Result := LCriteria.ToString;
  finally
    LCriteria.Free;
  end;
end;

function TDMLGeneratorNoSQL.GeneratorDelete(AObject: TObject;
  AParams: TParams): String;
var
  LTable: TTableMapping;
  LCriteria: TStringBuilder;
  LFor: Integer;
begin
  Result := '';
  LTable := TMappingExplorer.GetMappingTable(AObject.ClassType);
  LCriteria := TStringBuilder.Create;
  try
    LCriteria
      .Append('command=delete&')
        .Append('collection=' + LTable.Name + '&')
          .Append('json={');
    for LFor := 0 to AParams.Count -1 do
    begin
      LCriteria
        .Append(AnsiQuotedStr(AParams.Items[LFor].Name, '"'))
          .Append(':')
            .Append(VarToStr(AParams.Items[LFor].Value))
              .Append('&');
    end;
    LCriteria
      .Append('}')
        .Replace('& }', '}');
    Result := LCriteria.ToString;
  finally
    LCriteria.Free;
  end;
end;

function TDMLGeneratorNoSQL.GeneratorSelectAll(AClass: TClass;
  APageSize: Integer; AID: TValue): String;
begin
  Result := GetCriteriaSelectNoSQL(AClass, AID);
  if APageSize > -1 then
     Result := GetGeneratorSelectNoSQL(Result);
end;

function TDMLGeneratorNoSQL.GeneratorSelectWhere(AClass: TClass; AWhere,
  AOrderBy: String; APageSize: Integer): String;
var
  LTable: TTableMapping;
  LCriteria: TStringBuilder;
begin
  LTable := TMappingExplorer.GetMappingTable(AClass);
  LCriteria := TStringBuilder.Create;
  try
    LCriteria
      .Append('command=find& ')
        .Append('collection=' + LTable.Name + '& ')
          .Append('filter=' + AWhere + '& ')
            .Append('sort=' + AOrderBy);
    Result := LCriteria.ToString;
  finally
    LCriteria.Free;
  end;
end;

function TDMLGeneratorNoSQL.GeneratorAutoIncCurrentValue(AObject: TObject;
  AAutoInc: TDMLCommandAutoInc): Int64;
begin
  Result := 0;
end;

function TDMLGeneratorNoSQL.GeneratorAutoIncNextValue(AObject: TObject;
  AAutoInc: TDMLCommandAutoInc): Int64;
begin
  Result := 0;
end;

function TDMLGeneratorNoSQL.GetCriteriaSelectNoSQL(const AClass: TClass;
  const AID: TValue): String;
var
  LTable: TTableMapping;
  LPrimaryKey: TPrimaryKeyMapping;
  LCriteria: TStringBuilder;
  LOrderBy: TOrderByMapping;
  LOrderByList: TStringList;
  LFor: Integer;
  LOrder: Integer;
begin
  // Collection
  LTable := TMappingExplorer.GetMappingTable(AClass);
  LCriteria := TStringBuilder.Create;
  try
    LCriteria
      .Append('command=find& ')
        .Append('collection=' + LTable.Name);
    // PrimaryKey
    if AID.ToString <> '-1' then
    begin
      LPrimaryKey := TMappingExplorer.GetMappingPrimaryKey(AClass);
      if LPrimaryKey <> nil then
      begin
        LCriteria.Append('& filter={');
        if AID.Kind = tkInteger then
          LCriteria.Append('"' + LPrimaryKey.Columns[0] + '":' + AID.ToString)
        else
          LCriteria.Append('"' + LPrimaryKey.Columns[0] + '":"' + AID.ToString + '"');
        LCriteria.Append('}');
      end;
    end;
    // Order By
    LOrderBy := TMappingExplorer.GetMappingOrderBy(AClass);
    if LOrderBy <> nil then
    begin
      LOrderByList := TStringList.Create;
      try
        LOrderByList.Duplicates := dupError;
        ExtractStrings([',', ';'], [' '], PChar(LOrderBy.ColumnsName), LOrderByList);
        LCriteria.Append('& sort={');
        for LFor := 0 to LOrderByList.Count -1 do
        begin
          LOrderByList[LFor] := UpperCase(LOrderByList[LFor]);
          if Pos('DESC', LOrderByList[LFor]) > 0 then
            LOrder := -1
          else
            LOrder := 1;

          LOrderByList[LFor] := ReplaceStr(LOrderByList[LFor], 'ASC', '');
          LOrderByList[LFor] := ReplaceStr(LOrderByList[LFor], 'DESC', '');
          LOrderByList[LFor] := Trim(LOrderByList[LFor]);
          LCriteria.Append('"' + LOrderByList[LFor] + '": ' + IntToStr(LOrder));  // Asc = 1, Desc = -1
          if LFor < LOrderByList.Count -1 then
            LCriteria.Append(',');
        end;
        LCriteria.Append('}');
      finally
        LOrderByList.Free;
      end;
    end;
    Result := LCriteria.ToString;
  finally
    LCriteria.Free;
  end;
end;

function TDMLGeneratorNoSQL.GetGeneratorSelectNoSQL(const ACriteria: String): String;
begin
  Result := ACriteria + '& limit=%s& skip=%s';
end;

/// <summary> INALCANCAVEL NESTA FAMILIA, e concreto so' porque a classe precisa
///  ser instanciavel. TDMLGeneratorNoSQL sobrescreve GenerateSelectOneToOne e
///  GenerateSelectOneToOneMany para devolver '' (:87-97 desta unidade), entao
///  _GetPropertyValue - e com ele o ramo ftGuid - nunca e' chamado por este
///  caminho. TDMLGeneratorMongoDB herda as duas sobrescritas e por isso NAO
///  redeclara este metodo: dar-lhe um literal SQL seria inventar comportamento
///  que nao roda. O UUID do MongoDB nem literal SQL e': e' binData subtipo 4,
///  construido por UUID("36 com hifen") ou BinData(4,"base64")
///  (https://www.mongodb.com/docs/manual/reference/bson-types/), e o que o
///  driver grava depende de UuidRepresentation. </summary>
function TDMLGeneratorNoSQL.GuidLiteral(const AGuid: TGUID): String;
begin
  Result := CanonicalGuidLiteral(AGuid);
end;

end.
