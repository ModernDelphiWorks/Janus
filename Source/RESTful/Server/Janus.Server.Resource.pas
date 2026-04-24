{
      ORM Brasil é um ORM simples e descomplicado para quem utiliza Delphi

                   Copyright (c) 2018, Isaque Pinheiro
                          All rights reserved.
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
      cRESOURCEINSERT      = '{"result":"Resource %s insert command executed successfully", "params":[{%s}]}';
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
  MetaDbDiff.mapping.classes,
  MetaDbDiff.mapping.attributes,
  MetaDbDiff.rtti.helper,
  Janus.Json,
  Janus.Objects.Helper,
  Janus.Core.Consts,
  Janus.Server.RestView.Manager;

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
      // Caso nenhum dos dois métodos encontre um registro, é gerado uma
      // exceção com uma mensagem de registro não encontrado para quem requisitou
      ExceptionExecute;
      // Se passar tudo ok, será executado o método do Janus
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
  LValues: string;
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
      LValues := '';
      LPrimaryKey := TMappingExplorer
                       .GetMappingPrimaryKeyColumns(LObject.ClassType);
      if LPrimaryKey = nil then
        raise Exception.Create(cMESSAGEPKNOTFOUND);

      for LColumn in LPrimaryKey.Columns do
        LValues := LValues + '"'  + LColumn.ColumnProperty.Name
                           + '":' + VarToStr(LColumn.ColumnProperty.GetNullableValue(LObject).AsVariant)
                           + ',';

      LValues[Length(LValues)] := ' ';
      Result := Format(cRESOURCEINSERT, [AQuery.ResourceName, Trim(LValues)]);
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
