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

{
  @abstract(REST Componentes)
  @created(20 Jun 2018)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

{$INCLUDE ..\..\Janus.inc}
//{$DEFINE TRIAL}

unit Janus.Server.Resource;

interface

uses
  Classes,
  SysUtils,
  Variants,
  Rtti,
  Generics.Collections,
  // Janus
  MetaDbDiff.mapping.repository,
  MetaDbDiff.mapping.explorer,
  MetaDbDiff.mapping.popular,
  MetaDbDiff.mapping.register,
  Janus.Server.RestQuery.Parse,
  Janus.Server.RestObjectSet,
  DataEngine.FactoryInterfaces;

type
  TAppResourceBase = class
  private
    FConnection: IDBConnection;
    const
      cRESOURCENOTFOUND    = '{"exception":"Resource T%s not found!"}';
      cRESOURCENOTREGISTER = '{"exception":"Resource [%s] not registered on the server!"}';
      cRESOURCEPERMITION   = '{"exception":"Resource [%s] without access permission by the [NotServerUse] attribute!"}';
      cRESOURCEREADONLY    = '{"exception":"Resource %s is read-only (RESTReadOnly)"}';
      cRESOURCEVERBNOTALLOWED = '{"exception":"HTTP %s not allowed for %s"}';
      cEXCEPTIONJSON       = '{"exception":"There was an error in trying to convert JSON into the class [%s]!"}';
      cRESOURCEDELETE      = '{"result":"Resource %s delete command executed successfully"}';
      /// The %s is now a whole serialised JSON OBJECT, braces included - it
      /// used to be the inside of a pair list, with the braces written here.
      /// The document on the wire is unchanged.
      cRESOURCEINSERT      = '{"result":"Resource %s insert command executed successfully", "params":[%s]}';
      cRESOURCEUPDATE      = '{"result":"Resource %s update command executed successfully"}';
    function ResolverFindToSkip(const AObjectSet: TRESTObjectSet;
      const AQuery: TRESTQueryParse): string;
    function ResolverFindFilter(const AObjectSet: TRESTObjectSet;
      const AQuery: TRESTQueryParse): string;
    function ResolverFindID(const AObjectSet: TRESTObjectSet;
      const AQuery: TRESTQueryParse): string;
    function ResolverFindAll(const AObjectSet: TRESTObjectSet;
      const AQuery: TRESTQueryParse): string;
  protected
    FResultCount: Integer;
    function ParseInsert(const AQuery: TRESTQueryParse; const AValue: string): string;
    function ParseUpdate(const AQuery: TRESTQueryParse; const AValue: string): string;
  public
    constructor Create(const AConnection: IDBConnection); overload; virtual;
    destructor Destroy; override;
    function ParseFind(const AQuery: TRESTQueryParse): string;
    function ParseDelete(const AQuery: TRESTQueryParse): string;
    function select(const AResource: string): string; overload; virtual;
    function insert(const AResource: string; const AValue: string): string; overload; virtual;
    function update(const AResource: string; const AValue: string): string; overload; virtual;
    function delete(const AResource: string): string; overload; virtual;
    function ResultCount: Integer;
  end;

implementation

uses
  JSON,
  MetaDbDiff.mapping.classes,
  MetaDbDiff.mapping.attributes,
  MetaDbDiff.rtti.helper,
  Janus.Json,
  Janus.Objects.Helper,
  Janus.Core.Consts,
  Janus.Server.RestView.Manager;

/// <summary> The JSON VALUE of one primary key column, BUILT rather than
///  pasted into a string.
///
///  What it replaces emitted the value raw, straight out of VarToStr, next to
///  a hand-quoted name. That is valid JSON only while the value happens to
///  look like a JSON number, which is to say only for an integer key. A
///  textual key came out as a bare token, a generated GUID came out with
///  braces and hyphens, a date came out with slashes, and a fractional key
///  came out with whatever the AMBIENT decimal separator is - a comma on a
///  pt-BR machine. None of those is JSON, and the client discards a document
///  it cannot parse through a bare Exit, silently.
///
///  WHY THIS DISPATCHES ON THE VARIANT AND NOT ON TColumnMapping.FieldType.
///  The argument is about SELECTING a branch, and about nothing else. A
///  FieldType table is a list of enum labels, and a label in the wrong bucket
///  cannot be caught by anything short of one entity per label - drop
///  ftLargeint from the numeric bucket and a 64-bit key silently starts
///  arriving quoted, with the whole suite green. The Variant has FOUR states
///  reachable from a mapped property and the fixture has a clause for each:
///  null, ordinal, float, everything else.
///
///  That says nothing whatsoever about the CONVERSION performed once a branch
///  has been selected, and the first version of this repair learned the
///  difference the hard way: it selected the number branch correctly for an
///  unsigned 64-bit key and then handed the caller the negative
///  reinterpretation of it. Selection and conversion are two surfaces, and
///  each needs its own clause - see BigIntegerKey_MustNotBeNarrowed and
///  UnsignedKeyAboveHighInt64_MustNotFlipSign.
///
///  The one Variant state that has NO clause is varEmpty, and it is guarded
///  above alongside Null. Enumerated rather than assumed: MetaDbDiff's
///  TRttiPropertyHelper.GetNullableValue leaves an EMPTY TValue by exactly
///  three routes - a nil instance, a Nullable-shaped record with no FHasValue
///  field, and one with FHasValue set but no FValue field. The first cannot
///  happen here, because the caller has just dereferenced that object. The
///  other two need a record whose type NAME begins with 'Nullable<' - the
///  check is by name - but whose layout is not Janus's, which no entity in
///  this repository declares. The guard stays because removing it is NOT
///  response-neutral: without it an empty Variant would leave as "" rather
///  than null, and an empty string is something a client writes into a field.
///
///
///  Booleans are deliberately NOT mapped onto a JSON boolean: VarIsOrdinal is
///  true for varBoolean, so the guard below excludes it and a boolean key
///  leaves as the quoted string VarToStr already produced. That is valid JSON
///  and it is what the previous behaviour meant to say; turning it into a JSON
///  literal would be a contract change no clause here measures.
///
///  varDate is excluded from the float branch by VarIsFloat itself, which
///  covers only varSingle, varDouble and varCurrency. A date key therefore
///  reaches the string branch and keeps rendering exactly as it did - what
///  changes is only that it is now QUOTED. Whether that rendering should be
///  ISO-8601 instead of the ambient FormatSettings is a question about what a
///  consumer receives, and it is not this repair's to answer. </summary>
function _PrimaryKeyValueToJson(const AColumn: TColumnMapping;
  const AObject: TObject): TJSONValue;
var
  LValue: Variant;
begin
  LValue := AColumn.ColumnProperty.GetNullableValue(AObject).AsVariant;
  if VarIsNull(LValue) or VarIsEmpty(LValue) then
    Exit(TJSONNull.Create);
  if VarIsOrdinal(LValue) and (VarType(LValue) <> varBoolean) then
    Exit(TJSONNumber.Create(VarToStr(LValue)));
  if VarIsFloat(LValue) then
    Exit(TJSONNumber.Create(Double(VarAsType(LValue, varDouble))));
  Result := TJSONString.Create(VarToStr(LValue));
end;

{ TAppResourceBase }

constructor TAppResourceBase.Create(const AConnection: IDBConnection);
begin
  FResultCount := 0;
  FConnection := AConnection;
end;

function TAppResourceBase.delete(const AResource: string): string;
begin
  Result := AResource;
end;

destructor TAppResourceBase.Destroy;
begin

  inherited;
end;

function TAppResourceBase.insert(const AResource, AValue: string): string;
var
  LQuery: TRESTQueryParse;
begin
  LQuery := TRESTQueryParse.Create;
  try
    LQuery.ParseQuery(AResource);
    // Parse da Query passada na URI
    if LQuery.ResourceName = '' then
      raise Exception.CreateFmt(cRESOURCENOTFOUND, [AResource]);
    Result := ParseInsert(LQuery, AValue)
  finally
    LQuery.Free;
  end;
end;

function TAppResourceBase.update(const AResource, AValue: string): string;
var
  LQuery: TRESTQueryParse;
begin
  LQuery := TRESTQueryParse.Create;
  try
    // Parse da Query passada na URI
    LQuery.ParseQuery(AResource);
    if LQuery.ResourceName = '' then
      raise Exception.CreateFmt(cRESOURCENOTFOUND, [AResource]);
    Result := ParseUpdate(LQuery, AValue)
  finally
    LQuery.Free;
  end;
end;

function TAppResourceBase.ParseDelete(const AQuery: TRESTQueryParse): string;
var
  LObject: TObject;
  LClassType: TClass;
  LObjectSet: TRESTObjectSet;
  LAllowVerbs: TRESTAllowVerbCache;

  procedure ExceptionExecute;
  begin
    if LObject = nil then
      raise Exception.Create('{"result":"No records found to delete, with the filter entered!"}');
  end;

  procedure FilterExecuteFind;
  begin
    if Length(AQuery.Filter) > 0  then
      LObject := LObjectSet.FindOne(AQuery.Filter);
  end;

  procedure IDExecuteFind;
  begin
    if LObject <> nil then
      Exit;
    if AQuery.ID.IsEmpty then
      raise Exception.Create('{"exception":"The delete method needs the ID parameter!"}');
    LObject := LObjectSet.Find(AQuery.ID.ToString);
  end;

begin
  Result := '';
  LObject := nil;
  LClassType := TMappingExplorer.GetRepositoryMapping.FindEntityByName(AQuery.ResourceName);
  if LClassType = nil then
    Exit;

  if TMappingExplorer.GetRESTReadOnly(LClassType) then
    raise Exception.CreateFmt(cRESOURCEREADONLY, [AQuery.ResourceName]);

  if TMappingExplorer.GetMappingView(LClassType) <> nil then
    raise Exception.CreateFmt(cRESOURCEREADONLY, [AQuery.ResourceName]);

  LAllowVerbs := TMappingExplorer.GetRESTAllowVerbs(LClassType);
  if LAllowVerbs.HasAllowList then
    if not (rvDELETE in LAllowVerbs.AllowedVerbs) then
      raise Exception.CreateFmt(cRESOURCEVERBNOTALLOWED, ['DELETE', AQuery.ResourceName]);

  try
    LObjectSet := TRESTObjectSet.Create(FConnection, LClassType);
    try
      // Busca o registro pelo filtro
      FilterExecuteFind;
      // Busca o registro pelo ID
      IDExecuteFind;
      // Caso nenhum dos dois metodos encontre um registro, sera gerado uma
      // excecao com uma mensagem de registro nao encontrado para quem requisitou
      ExceptionExecute;
      // Se passar tudo ok, sera executado o metodo do Janus
      LObjectSet.Delete(LObject);
      Result := Format(cRESOURCEDELETE, [AQuery.ResourceName]);
    finally
      if LObject <> nil then
        LObject.Free;
      LObjectSet.Free;
    end;
  except
    on E: Exception do
    begin
      raise Exception.Create(E.Message);
    end;
  end;
end;

function TAppResourceBase.ParseFind(const AQuery: TRESTQueryParse): string;
var
  LClassType: TClass;
  LObjectSet: TRESTObjectSet;
  LNotSeverUse: Boolean;
  LAllowVerbs: TRESTAllowVerbCache;
begin
  LClassType := TMappingExplorer.GetRepositoryMapping
                                .FindEntityByName(AQuery.ResourceName);
  if LClassType = nil then
    raise Exception.CreateFmt(cRESOURCENOTREGISTER, [AQuery.ResourceName]);

  // Verifica se foi negado acesso a classe, pelo atributo NotServerUse
  LNotSeverUse := TMappingExplorer.GetNotServerUse(LClassType);
  if LNotSeverUse then
    raise Exception.CreateFmt(cRESOURCEPERMITION, [AQuery.ResourceName]);

  LAllowVerbs := TMappingExplorer.GetRESTAllowVerbs(LClassType);
  if LAllowVerbs.HasAllowList then
    if not TMappingExplorer.GetRESTReadOnly(LClassType) then
      if not (rvGET in LAllowVerbs.AllowedVerbs) then
        raise Exception.CreateFmt(cRESOURCEVERBNOTALLOWED, ['GET', AQuery.ResourceName]);

  if TMappingExplorer.GetMappingView(LClassType) <> nil then
    TRESTViewManager.EnsureViewLazy(LClassType, FConnection);

  LObjectSet := TRESTObjectSet.Create(FConnection, LClassType);
  try
    if AQuery.Top > 0 then
      Result := ResolverFindToSkip(LObjectSet, AQuery)
    else
    if Length(AQuery.Filter) > 0  then
      Result := ResolverFindFilter(LObjectSet, AQuery)
    else
    if not AQuery.ID.IsEmpty then
      Result := ResolverFindID(LObjectSet, AQuery)
    else
      Result := ResolverFindAll(LObjectSet, AQuery);
  finally
    LObjectSet.Free;
  end;
end;

function TAppResourceBase.ParseInsert(const AQuery: TRESTQueryParse;
  const AValue: string): string;
var
  LPrimaryKey: TPrimaryKeyColumnsMapping;
  LColumn: TColumnMapping;
  LObject: TObject;
  LClassType: TClass;
  LObjectSet: TRESTObjectSet;
  LParams: TJSONObject;
  LAllowVerbs: TRESTAllowVerbCache;
begin
  LClassType := TMappingExplorer.GetRepositoryMapping
                                .FindEntityByName(AQuery.ResourceName);
  if LClassType = nil then
    raise Exception.CreateFmt(cRESOURCENOTREGISTER, [AQuery.ResourceName]);

  if TMappingExplorer.GetRESTReadOnly(LClassType) then
    raise Exception.CreateFmt(cRESOURCEREADONLY, [AQuery.ResourceName]);

  if TMappingExplorer.GetMappingView(LClassType) <> nil then
    raise Exception.CreateFmt(cRESOURCEREADONLY, [AQuery.ResourceName]);

  LAllowVerbs := TMappingExplorer.GetRESTAllowVerbs(LClassType);
  if LAllowVerbs.HasAllowList then
    if not (rvPOST in LAllowVerbs.AllowedVerbs) then
      raise Exception.CreateFmt(cRESOURCEVERBNOTALLOWED, ['POST', AQuery.ResourceName]);

  try
    LObjectSet := TRESTObjectSet.Create(FConnection, LClassType);
    LObject := LClassType.Create;
    LObject.MethodCall('Create', []);

    TJanusJson.JsonToObject(AValue, LObject);
    if LObject = nil then
      Exit;

    try
      LObjectSet.Insert(LObject);
      LPrimaryKey := TMappingExplorer
                       .GetMappingPrimaryKeyColumns(LObject.ClassType);
      if LPrimaryKey = nil then
        raise Exception.Create(cMESSAGEPKNOTFOUND);

      /// The pairs are ADDED to a TJSONObject and serialised by it. Escaping a
      /// quote or a backslash inside the value, and rendering a number with
      /// the decimal separator JSON requires rather than the one the machine's
      /// locale requires, are then the serialiser's job and not this loop's.
      LParams := TJSONObject.Create;
      try
        for LColumn in LPrimaryKey.Columns do
          LParams.AddPair(LColumn.ColumnProperty.Name,
                          _PrimaryKeyValueToJson(LColumn, LObject));
        /// ToJSON and NOT ToString: both run TJSONAncestor.ToChars, so both
        /// escape the quote and the backslash, but ToString passes no options
        /// while ToJSON passes EncodeBelow32 and EncodeAbove127. A control
        /// character raw inside a JSON string is illegal, so ToString is the
        /// one that can still emit a document nobody can parse.
        /// An empty column list now yields {} instead of indexing LValues[0].
        Result := Format(cRESOURCEINSERT, [AQuery.ResourceName,
                                           LParams.ToJSON]);
      finally
        LParams.Free;
      end;
    finally
      LObject.Free;
      LObjectSet.Free;
    end;
  except
    on E: Exception do
    begin
      raise Exception.Create(E.Message);
    end;
  end;
end;

function TAppResourceBase.ParseUpdate(const AQuery: TRESTQueryParse;
  const AValue: string): string;
var
  LObjectOld: TObject;
  LObjectNew: TObject;
  LClassType: TClass;
  LObjectSet: TRESTObjectSet;
  LPrimaryKey: TPrimaryKeyColumnsMapping;
  LColumn: TColumnMapping;
  LWhere: string;
  LAllowVerbs: TRESTAllowVerbCache;
begin
  LClassType := TMappingExplorer.GetRepositoryMapping
                                .FindEntityByName(AQuery.ResourceName);
  if LClassType = nil then
    Exit;

  if TMappingExplorer.GetRESTReadOnly(LClassType) then
    raise Exception.CreateFmt(cRESOURCEREADONLY, [AQuery.ResourceName]);

  if TMappingExplorer.GetMappingView(LClassType) <> nil then
    raise Exception.CreateFmt(cRESOURCEREADONLY, [AQuery.ResourceName]);

  LAllowVerbs := TMappingExplorer.GetRESTAllowVerbs(LClassType);
  if LAllowVerbs.HasAllowList then
    if not (rvPUT in LAllowVerbs.AllowedVerbs) then
      raise Exception.CreateFmt(cRESOURCEVERBNOTALLOWED, ['PUT', AQuery.ResourceName]);
  try
    LObjectSet := TRESTObjectSet.Create(FConnection, LClassType);
    LObjectNew := LClassType.Create;
    LObjectNew.MethodCall('Create', []);

    TJanusJson.JsonToObject(AValue, LObjectNew);
    if LObjectNew = nil then
      raise Exception.CreateFmt(cEXCEPTIONJSON, [AQuery.ResourceName]);

    try
      LWhere := '';
      LPrimaryKey := TMappingExplorer.GetMappingPrimaryKeyColumns(LObjectNew.ClassType);
      if LPrimaryKey = nil then
        raise Exception.Create(cMESSAGEPKNOTFOUND);

      for LColumn in LPrimaryKey.Columns do
        LWhere := LWhere + '(' + LObjectNew.GetTable.Name
                         + '.' + LColumn.ColumnName
                         + '=' + VarToStr(LColumn.ColumnProperty
                                                 .GetNullableValue(LObjectNew).AsVariant) + ') AND ';
      LWhere := Copy(LWhere, 1, Length(LWhere) -5);
      LObjectOld := LObjectSet.FindOne(LWhere);
      if LObjectOld = nil then
        Exit;

      try
        LObjectSet.Modify(LObjectOld);
        LObjectSet.Update(LObjectNew);
        Result := Format(cRESOURCEUPDATE, [AQuery.ResourceName]);
      finally
        LObjectOld.Free;
      end;
    finally
      LObjectNew.MethodCall('Destroy', []);
      LObjectSet.Free;
    end;
  except
    on E: Exception do
    begin
      raise Exception.Create(E.Message);
    end;
  end;
end;

function TAppResourceBase.ResolverFindAll(const AObjectSet: TRESTObjectSet;
  const AQuery: TRESTQueryParse): string;
var
  LObjectList: TObjectList<TObject>;
begin
  FResultCount := 0;
  LObjectList := AObjectSet.Find;
  try
    Result := TJanusJson.ObjectListToJsonString(LObjectList);
    if AQuery.Count then
      FResultCount := LObjectList.Count;
  finally
    LObjectList.Clear;
    LObjectList.Free;
  end;
end;

function TAppResourceBase.ResolverFindFilter(const AObjectSet: TRESTObjectSet;
  const AQuery: TRESTQueryParse): string;
var
  LObjectList: TObjectList<TObject>;
begin
  FResultCount := 0;
  LObjectList := AObjectSet.FindWhere(AQuery.Filter, AQuery.OrderBy);
  try
    Result := TJanusJson.ObjectListToJsonString(LObjectList);
    if AQuery.Count then
      FResultCount := LObjectList.Count;
  finally
    LObjectList.Clear;
    LObjectList.Free;
  end;
end;

function TAppResourceBase.ResolverFindID(const AObjectSet: TRESTObjectSet;
  const AQuery: TRESTQueryParse): string;
var
  LObject: TObject;
begin
  FResultCount := 0;
  LObject := AObjectSet.Find(AQuery.ID.ToString);
  try
    Result := TJanusJson.ObjectToJsonString(LObject);
    if AQuery.Count then
      FResultCount := 1;
  finally
    LObject.Free;
  end;
end;

function TAppResourceBase.ResolverFindToSkip(const AObjectSet: TRESTObjectSet;
  const AQuery: TRESTQueryParse): string;
var
  LObjectList: TObjectList<TObject>;
begin
  FResultCount := 0;
  LObjectList := AObjectSet.NextPacket(AQuery.Filter,
                                       AQuery.OrderBy,
                                       AQuery.Top,
                                       AQuery.Skip);
  try
    Result := TJanusJson.ObjectListToJsonString(LObjectList);
    if AQuery.Count then
      FResultCount := LObjectList.Count;
  finally
    LObjectList.Clear;
    LObjectList.Free;
  end;
end;

function TAppResourceBase.ResultCount: Integer;
begin
  Result := FResultCount;
end;

function TAppResourceBase.select(const AResource: string): string;
begin
  Result := AResource;
end;

end.
