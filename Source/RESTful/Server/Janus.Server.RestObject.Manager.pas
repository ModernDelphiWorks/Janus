{
      ORM Brasil � um ORM simples e descomplicado para quem utiliza Delphi

                   Copyright (c) 2016, Isaque Pinheiro
                          All rights reserved.
}

{ 
  @abstract(REST Componentes)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Janus.Server.RestObject.Manager;

interface

uses
  DB,
  Rtti,
  Types,
  Classes,
  SysUtils,
  Variants,
  Generics.Collections,
  /// Janus
  Janus.Command.Executor.Abstract,
  Janus.Command.Factory,
  Janus.Mapping.Lazy,
  DataEngine.FactoryInterfaces,
  MetaDbDiff.mapping.popular,
  MetaDbDiff.mapping.explorer,
  MetaDbDiff.types.mapping,
  MetaDbDiff.mapping.classes;

type
  TRESTObjectManager = class
  private
    FOwner: TObject;
    FObjectInternal: TObject;
    FLazyToken: ILazySessionToken;
    FProcessingObjects: TList<Pointer>;
    procedure FillAssociation(const AObject: TObject);
    procedure FillAssociationLazy(const AOwner, AObject: TObject);
    procedure _InjectLazyFactory(const AObject: TObject;
      const AAssociation: TAssociationMapping);
  protected
    FConnection: IDBConnection;
    FFetchingRecords: Boolean;
    // F�brica de comandos a serem executados
    FDMLCommandFactory: TDMLCommandFactoryAbstract;
    // Controle de pagina��o vindo do banco de dados
    FPageSize: Integer;
    procedure ExecuteOneToOne(AObject: TObject; AProperty: TRttiProperty;
      AAssociation: TAssociationMapping);
    procedure ExecuteOneToMany(AObject: TObject; AProperty: TRttiProperty;
      AAssociation: TAssociationMapping);
    function FindSQLInternal(const ASQL: String): TObjectList<TObject>;
    function SelectInternalWhere(const AWhere: String;
      const AOrderBy: String): String;
  public
    constructor Create(const AOwner: TObject; const AConnection: IDBConnection;
      const AClassType: TClass; const APageSize: Integer);
    destructor Destroy; override;
    // Procedures
    procedure InsertInternal(const AObject: TObject);
    procedure UpdateInternal(const AObject: TObject; const AModifiedFields: TDictionary<String, String>);
    procedure DeleteInternal(const AObject: TObject);
    procedure LoadLazy(const AOwner, AObject: TObject);
    procedure InjectLazyFactories(const AObject: TObject);
    procedure NextPacketList(const AObjectList: TObjectList<TObject>;
      const APageSize, APageNext: Integer); overload;
    procedure NextPacketList(const AObjectList: TObjectList<TObject>;
      const AWhere, AOrderBy: String; const APageSize, APageNext: Integer); overload;
    function NextPacketList: TObjectList<TObject>; overload;
    function NextPacketList(const APageSize, APageNext: Integer): TObjectList<TObject>; overload;
    function NextPacketList(const AWhere, AOrderBy: String;
      const APageSize, APageNext: Integer): TObjectList<TObject>; overload;
    // Functions
    function GetDMLCommand: String;
    function ExistSequence: Boolean;
    // DataSet
    function SelectInternalAll: IDBDataSet;
    function SelectInternalID(const AID: TValue): IDBDataSet;
    function SelectInternal(const ASQL: String): IDBDataSet;
    function NextPacket: IDBDataSet; overload;
    function NextPacket(const APageSize, APageNext: Integer): IDBDataSet; overload;
    function NextPacket(const AWhere, AOrderBy: String;
      const APageSize, APageNext: Integer): IDBDataSet; overload;
    // ObjectSet
    function Find: TObjectList<TObject>; overload;
    function Find(const AID: TValue): TObject; overload;
    function FindWhere(const AWhere: String; const AOrderBy: String): TObjectList<TObject>;
    function FindOne(const AWhere: String): TObject;
    //
    property FetchingRecords: Boolean read FFetchingRecords write FFetchingRecords;
  end;

implementation

uses
  Janus.Bind,
  Janus.Objects.Helper,
  Janus.RTTI.Helper,
  Janus.Server.RestObjectSet.Session;

{ TRESTObjectManager<M> }

constructor TRESTObjectManager.Create(const AOwner: TObject; const AConnection: IDBConnection;
  const AClassType: TClass; const APageSize: Integer);
begin
  FOwner := AOwner;
  FPageSize := APageSize;
  if not (AOwner is TRESTObjectSetSession) then
    raise Exception
            .Create('O Object Manager n�o deve ser inst�nciada diretamente, use as classes TRESTObjectSetSession');
  FConnection := AConnection;
  FObjectInternal := AClassType.Create;
  // Fabrica de comandos SQL
  FDMLCommandFactory := TDMLCommandFactory.Create(FObjectInternal,
                                                  AConnection,
                                                  AConnection.GetDriver);
  FLazyToken := TLazySessionToken.Create;
  FProcessingObjects := TList<Pointer>.Create;
end;

destructor TRESTObjectManager.Destroy;
begin
  FLazyToken.Invalidate;
  FProcessingObjects.Free;
  FDMLCommandFactory.Free;
  FObjectInternal.Free;
  inherited;
end;

procedure TRESTObjectManager.DeleteInternal(const AObject: TObject);
begin
  FDMLCommandFactory.GeneratorDelete(AObject);
end;

function TRESTObjectManager.SelectInternalAll: IDBDataSet;
begin
  Result := FDMLCommandFactory.GeneratorSelectAll(FObjectInternal.ClassType, FPageSize);
end;

function TRESTObjectManager.SelectInternalID(const AID: TValue): IDBDataSet;
begin
  Result := FDMLCommandFactory.GeneratorSelectID(FObjectInternal.ClassType, AID);
end;

function TRESTObjectManager.SelectInternalWhere(const AWhere: String;
  const AOrderBy: String): String;
begin
  Result := FDMLCommandFactory
              .GeneratorSelectWhere(FObjectInternal.ClassType, AWhere, AOrderBy, FPageSize);
end;

procedure TRESTObjectManager.FillAssociation(const AObject: TObject);
var
  LAssociationList: TAssociationMappingList;
  LAssociation: TAssociationMapping;
begin
  // Se o driver selecionado for do tipo de banco NoSQL,
  // o atributo Association deve ser ignorado.
  if FConnection.GetDriver = dnMongoDB then
    Exit;

  LAssociationList := TMappingExplorer.GetMappingAssociation(AObject.ClassType);
  if LAssociationList = nil then
    Exit;

  for LAssociation in LAssociationList do
  begin
     if LAssociation.Lazy then
     begin
       _InjectLazyFactory(AObject, LAssociation);
       Continue;
     end;
     if LAssociation.Multiplicity in [TMultiplicity.OneToOne, TMultiplicity.ManyToOne] then
        ExecuteOneToOne(AObject, LAssociation.PropertyRtti, LAssociation)
     else
     if LAssociation.Multiplicity in [TMultiplicity.OneToMany, TMultiplicity.ManyToMany] then
        ExecuteOneToMany(AObject, LAssociation.PropertyRtti, LAssociation);
  end;
end;

procedure TRESTObjectManager.FillAssociationLazy(const AOwner, AObject: TObject);
var
  LAssociationList: TAssociationMappingList;
  LAssociation: TAssociationMapping;
begin
  // Se o driver selecionado for do tipo de banco NoSQL,
  // o atributo Association deve ser ignorado.
  if FConnection.GetDriver = dnMongoDB then
    Exit;

  LAssociationList := TMappingExplorer.GetMappingAssociation(AOwner.ClassType);
  if LAssociationList = nil then
    Exit;

  for LAssociation in LAssociationList do
  begin
     if not LAssociation.Lazy then
       Continue;

     if Pos(LAssociation.ClassNameRef, AObject.ClassName) = 0 then
       Continue;

     if LAssociation.Multiplicity in [TMultiplicity.OneToOne, TMultiplicity.ManyToOne] then
        ExecuteOneToOne(AOwner, LAssociation.PropertyRtti, LAssociation)
     else
     if LAssociation.Multiplicity in [TMultiplicity.OneToMany, TMultiplicity.ManyToMany] then
        ExecuteOneToMany(AOwner, LAssociation.PropertyRtti, LAssociation);
  end;
end;

procedure TRESTObjectManager.ExecuteOneToOne(AObject: TObject; AProperty: TRttiProperty;
  AAssociation: TAssociationMapping);
var
  LResultSet: IDBDataSet;
  LObjectValue: TObject;
begin
  LResultSet := FDMLCommandFactory
                  .GeneratorSelectOneToOne(AObject,
                                           AProperty.PropertyType.AsInstance.MetaclassType,
                                           AAssociation);
  try
    while not LResultSet.Eof do
    begin
      LObjectValue := AProperty.GetNullableValue(AObject).AsObject;
      // Preenche o objeto com os dados do ResultSet
      TBind.Instance.SetFieldToProperty(LResultSet, LObjectValue);
      // Alimenta registros das associa��es existentes 1:1 ou 1:N
      FillAssociation(LObjectValue);
    end;
  finally
    LResultSet.Close;
  end;
end;

procedure TRESTObjectManager.ExecuteOneToMany(AObject: TObject;
  AProperty: TRttiProperty; AAssociation: TAssociationMapping);
var
  LPropertyType: TRttiType;
  LObjectCreate: TObject;
  LObjectList: TObject;
  LResultSet: IDBDataSet;
begin
  LPropertyType := AProperty.PropertyType;
  LPropertyType := AProperty.GetTypeValue(LPropertyType);
  LResultSet := FDMLCommandFactory
                  .GeneratorSelectOneToMany(AObject,
                                            LPropertyType.AsInstance.MetaclassType,
                                            AAssociation);
  try
    while not LResultSet.Eof do
    begin
      // Instancia o objeto do tipo definido na lista
      LObjectCreate := LPropertyType.AsInstance.MetaclassType.Create;
      LObjectCreate.MethodCall('Create', []);
      // Popula o objeto com os dados do ResultSet
      TBind.Instance.SetFieldToProperty(LResultSet, LObjectCreate);
      // Alimenta registros das associa��es existentes 1:1 ou 1:N
      FillAssociation(LObjectCreate);
      // Adiciona o objeto a lista
      LObjectList := AProperty.GetNullableValue(AObject).AsObject;
      if LObjectList <> nil then
        LObjectList.MethodCall('Add', [LObjectCreate]);
    end;
  finally
    LResultSet.Close;
  end;
end;

function TRESTObjectManager.ExistSequence: Boolean;
begin
  Result := FDMLCommandFactory.ExistSequence;
end;

function TRESTObjectManager.GetDMLCommand: String;
begin
  Result := FDMLCommandFactory.GetDMLCommand;
end;

function TRESTObjectManager.NextPacket: IDBDataSet;
begin
  Result := FDMLCommandFactory.GeneratorNextPacket;
  if Result.FetchingAll then
    FFetchingRecords := True;
end;

function TRESTObjectManager.NextPacket(const APageSize, APageNext: Integer): IDBDataSet;
begin
  Result := FDMLCommandFactory
              .GeneratorNextPacket(FObjectInternal.ClassType, APageSize, APageNext);
  if Result.FetchingAll then
    FFetchingRecords := True;
end;

function TRESTObjectManager.NextPacketList: TObjectList<TObject>;
var
 LResultSet: IDBDataSet;
 LObjectList: TObjectList<TObject>;
 LObject: TObject;
begin
  LObjectList := TObjectList<TObject>.Create;
  LObjectList.TrimExcess;
  LResultSet := NextPacket;
  try
    while not LResultSet.Eof do
    begin
      LObject := FObjectInternal.ClassType.Create;
      LObject.MethodCall('Create', []);
      LObjectList.Add(LObject);
      TBind.Instance.SetFieldToProperty(LResultSet, LObjectList.Last);
      // Alimenta registros das associa��es existentes 1:1 ou 1:N
      FillAssociation(LObjectList.Last);
    end;
    Result := LObjectList;
  finally
    LResultSet.Close;
  end;
end;

function TRESTObjectManager.NextPacket(const AWhere, AOrderBy: String;
  const APageSize, APageNext: Integer): IDBDataSet;
begin
  Result := FDMLCommandFactory
              .GeneratorNextPacket(FObjectInternal.ClassType,
                                   AWhere,
                                   AOrderBy,
                                   APageSize,
                                   APageNext);
  if Result.FetchingAll then
    FFetchingRecords := True;
end;

function TRESTObjectManager.NextPacketList(const AWhere, AOrderBy: String;
  const APageSize, APageNext: Integer): TObjectList<TObject>;
var
 LResultSet: IDBDataSet;
 LObjectList: TObjectList<TObject>;
 LObject: TObject;
begin
  LObjectList := TObjectList<TObject>.Create;
  LObjectList.TrimExcess;
  LResultSet := NextPacket(AWhere, AOrderBy, APageSize, APageNext);
  try
    while not LResultSet.Eof do
    begin
      LObject := FObjectInternal.ClassType.Create;
      LObject.MethodCall('Create', []);
      LObjectList.Add(LObject);
      TBind.Instance.SetFieldToProperty(LResultSet, LObjectList.Last);
      // Alimenta registros das associa��es existentes 1:1 ou 1:N
      FillAssociation(LObjectList.Last);
    end;
    Result := LObjectList;
  finally
    LResultSet.Close;
  end;
end;

procedure TRESTObjectManager.NextPacketList(const AObjectList: TObjectList<TObject>;
  const AWhere, AOrderBy: String; const APageSize, APageNext: Integer);
var
 LResultSet: IDBDataSet;
 LObject: TObject;
begin
  LResultSet := NextPacket(AWhere, AOrderBy, APageSize, APageNext);
  try
    while not LResultSet.Eof do
    begin
      LObject := FObjectInternal.ClassType.Create;
      LObject.MethodCall('Create', []);
      AObjectList.Add(LObject);
      TBind.Instance.SetFieldToProperty(LResultSet, AObjectList.Last);
      // Alimenta registros das associa��es existentes 1:1 ou 1:N
      FillAssociation(AObjectList.Last);
    end;
  finally
    LResultSet.Close;
  end;
end;

procedure TRESTObjectManager.NextPacketList(const AObjectList: TObjectList<TObject>;
  const APageSize, APageNext: Integer);
var
 LResultSet: IDBDataSet;
 LObject: TObject;
begin
  LResultSet := NextPacket(APageSize, APageNext);
  try
    while not LResultSet.Eof do
    begin
      LObject := FObjectInternal.ClassType.Create;
      LObject.MethodCall('Create', []);
      AObjectList.Add(LObject);
      TBind.Instance.SetFieldToProperty(LResultSet, AObjectList.Last);
      // Alimenta registros das associa��es existentes 1:1 ou 1:N
      FillAssociation(AObjectList.Last);
    end;
  finally
    LResultSet.Close;
  end;
end;

function TRESTObjectManager.NextPacketList(const APageSize, APageNext: Integer): TObjectList<TObject>;
var
  LResultSet: IDBDataSet;
  LObjectList: TObjectList<TObject>;
  LObject: TObject;
begin
  LObjectList := TObjectList<TObject>.Create;
  LObjectList.TrimExcess;
  LResultSet := NextPacket(APageSize, APageNext);
  try
    while not LResultSet.Eof do
    begin
      LObject := FObjectInternal.ClassType.Create;
      LObject.MethodCall('Create', []);
      LObjectList.Add(LObject);
      TBind.Instance.SetFieldToProperty(LResultSet, LObjectList.Last);
      // Alimenta registros das associa��es existentes 1:1 ou 1:N
      FillAssociation(LObjectList.Last);
    end;
    Result := LObjectList;
  finally
    LResultSet.Close;
  end;
end;

function TRESTObjectManager.SelectInternal(const ASQL: String): IDBDataSet;
begin
  Result := FDMLCommandFactory.GeneratorSelect(ASQL, FPageSize);
end;

procedure TRESTObjectManager.UpdateInternal(const AObject: TObject;
  const AModifiedFields: TDictionary<String, String>);
begin
  FDMLCommandFactory.GeneratorUpdate(AObject, AModifiedFields);
end;

procedure TRESTObjectManager.InsertInternal(const AObject: TObject);
begin
  FDMLCommandFactory.GeneratorInsert(AObject);
end;

procedure TRESTObjectManager.LoadLazy(const AOwner, AObject: TObject);
begin
  FillAssociationLazy(AOwner, AObject);
end;

procedure TRESTObjectManager._InjectLazyFactory(const AObject: TObject;
  const AAssociation: TAssociationMapping);
var
  LLoadFunc: TLazyLoadFunc;
begin
  if AAssociation.Multiplicity in [TMultiplicity.OneToOne,
                                   TMultiplicity.ManyToOne] then
    LLoadFunc := CreateLazySingleAssociationLoadFunc(
      AObject,
      AAssociation,
      FDMLCommandFactory,
      procedure(const AResultSet: IDBDataSet; const ALoadedObject: TObject)
      begin
        Bind.SetFieldToProperty(AResultSet, ALoadedObject);
      end,
      FProcessingObjects,
      procedure(const ALoadedObject: TObject)
      begin
        FillAssociation(ALoadedObject);
        InjectLazyFactories(ALoadedObject);
      end)
  else
    LLoadFunc := CreateLazyManyAssociationLoadFunc(
      AObject,
      AAssociation,
      FDMLCommandFactory,
      procedure(const AResultSet: IDBDataSet; const ALoadedObject: TObject)
      begin
        Bind.SetFieldToProperty(AResultSet, ALoadedObject);
      end,
      FProcessingObjects,
      procedure(const ALoadedObject: TObject)
      begin
        FillAssociation(ALoadedObject);
        InjectLazyFactories(ALoadedObject);
      end);

  InjectLazyAssociationFactory(AObject, AAssociation, FLazyToken, LLoadFunc);
end;

procedure TRESTObjectManager.InjectLazyFactories(const AObject: TObject);
var
  LAssociationList: TAssociationMappingList;
  LAssociation: TAssociationMapping;
begin
  if FConnection.GetDriver = dnMongoDB then
    Exit;
  if AObject = nil then
    Exit;
  LAssociationList := TMappingExplorer.GetMappingAssociation(AObject.ClassType);
  if LAssociationList = nil then
    Exit;
  for LAssociation in LAssociationList do
  begin
    if not LAssociation.Lazy then
      Continue;
    _InjectLazyFactory(AObject, LAssociation);
  end;
end;

function TRESTObjectManager.FindSQLInternal(const ASQL: String): TObjectList<TObject>;
var
 LResultSet: IDBDataSet;
 LObject: TObject;
begin
  Result := TObjectList<TObject>.Create;
  Result.TrimExcess;
  if ASQL = '' then
    LResultSet := SelectInternalAll
  else
    LResultSet := SelectInternal(ASQL);
  try
    while not LResultSet.Eof do
    begin
      LObject := FObjectInternal.ClassType.Create;
      LObject.MethodCall('Create', []);
      TBind.Instance.SetFieldToProperty(LResultSet, Result.Items[Result.Add(LObject)]);
      // Alimenta registros das associa��es existentes 1:1 ou 1:N
      FillAssociation(Result.Items[Result.Count -1]);
    end;
  finally
    LResultSet.Close;
  end;
end;

function TRESTObjectManager.Find: TObjectList<TObject>;
begin
  Result := FindSQLInternal('');
end;

function TRESTObjectManager.Find(const AID: TValue): TObject;
var
  LResultSet: IDBDataSet;
begin
  LResultSet := SelectInternalID(AID);
  try
    if LResultSet.RecordCount = 1 then
    begin
      Result := FObjectInternal.ClassType.Create;
      Result.MethodCall('Create', []);
      TBind.Instance.SetFieldToProperty(LResultSet, Result);
      // Alimenta registros das associa��es existentes 1:1 ou 1:N
      FillAssociation(Result);
    end
    else
      Result := nil;
  finally
    LResultSet.Close;
  end;
end;

function TRESTObjectManager.FindOne(const AWhere: String): TObject;
var
 LResultSet: IDBDataSet;
 LObject: TObject;
begin
  LResultSet := SelectInternal(SelectInternalWhere(AWhere, ''));
  try
    if LResultSet.RecordCount > 0 then
    begin
      LObject := FObjectInternal.ClassType.Create;
      LObject.MethodCall('Create', []);
      TBind.Instance.SetFieldToProperty(LResultSet, LObject);
      // Alimenta registros das associa��es existentes 1:1 ou 1:N
      FillAssociation(LObject);
      Result := LObject;
    end
    else
      Result := nil;
  finally
    LResultSet.Close;
  end;
end;

function TRESTObjectManager.FindWhere(const AWhere: String;
  const AOrderBy: String): TObjectList<TObject>;
begin
  Result := FindSQLInternal(SelectInternalWhere(AWhere, AOrderBy));
end;

end.

