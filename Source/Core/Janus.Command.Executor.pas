{
      ORM Brasil � um ORM simples e descomplicado para quem utiliza Delphi

                   Copyright (c) 2016, Isaque Pinheiro
                          All rights reserved.

                    GNU Lesser General Public License
                      Vers�o 3, 29 de junho de 2007

       Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
       A todos � permitido copiar e distribuir c�pias deste documento de
       licen�a, mas mud�-lo n�o � permitido.

       Esta vers�o da GNU Lesser General Public License incorpora
       os termos e condi��es da vers�o 3 da GNU General Public License
       Licen�a, complementado pelas permiss�es adicionais listadas no
       arquivo LICENSE na pasta principal.
}

{
  @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Janus.Command.Executor;

interface

uses
  DB,
  Rtti,
  Classes,
  SysUtils,
  Variants,
  Generics.Collections,
  /// Janus
  Janus.Command.Factory,
  Janus.Command.Executor.Abstract,
  Janus.Mapping.Lazy,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Classes,
  MetaDbDiff.Mapping.Popular,
  DataEngine.FactoryInterfaces,
  MetaDbDiff.Mapping.Explorer;

type
  TSQLCommandExecutor<M: class, constructor> = class sealed(TSQLCommandExecutorAbstract<M>)
  private
    FOwner: TObject;
    FObjectInternal: M;
    FLazyToken: ILazySessionToken;
    FProcessingObjects: TList<Pointer>;
    procedure _InjectLazyFactory(const AObject: TObject;
      const AAssociation: TAssociationMapping);
  protected
    FConnection: IDBConnection;
    FPageSize: Integer;
    FDMLCommandFactory: TDMLCommandFactoryAbstract;
    procedure ExecuteOneToOne(AObject: TObject; AProperty: TRttiProperty;
      AAssociation: TAssociationMapping); override;
    procedure ExecuteOneToMany(AObject: TObject; AProperty: TRttiProperty;
      AAssociation: TAssociationMapping); override;
    function FindSQLInternal(const ASQL: String): IDBDataSet; override;
  public
    constructor Create(const AOwner: TObject; const AConnection: IDBConnection;
      const APageSize: Integer); override;
    destructor Destroy; override;
    // Procedures
    procedure InsertInternal(const AObject: M); override;
    procedure UpdateInternal(const AObject: TObject;
      const AModifiedFields: TDictionary<String, String>); override;
    procedure DeleteInternal(const AObject: M); override;
    procedure LoadLazy(const AOwner, AObject: TObject); override;
    procedure NextPacketList(const AObjectList: TObjectList<M>;
      const APageSize, APageNext: Integer); overload; override;
    procedure NextPacketList(const AObjectList: TObjectList<M>;
      const AWhere, AOrderBy: String;
      const APageSize, APageNext: Integer); overload; override;
    procedure FillAssociation(const AObject: M); override;
    procedure FillAssociationLazy(const AOwner, AObject: TObject); override;
    procedure InjectLazyFactories(const AObject: TObject); override;
    function NextPacketList: IDBDataSet; overload; override;
    function NextPacketList(const APageSize,
      APageNext: Integer): IDBDataSet; overload; override;
    function NextPacketList(const AWhere, AOrderBy: String;
      const APageSize, APageNext: Integer): IDBDataSet; overload; override;
    // Functions
    function GetDMLCommand: String; override;
    function ExistSequence: Boolean; override;
    // DataSet
    function SelectInternalWhere(const AWhere: String;
      const AOrderBy: String): String; override;
    function SelectInternalAll: IDBDataSet; override;
    function SelectInternalID(const AID: TValue): IDBDataSet; override;
    function SelectInternal(const ASQL: String): IDBDataSet; override;
    function SelectInternalAssociation(const AObject: TObject): String; override;
    function NextPacket: IDBDataSet; overload; override;
    function NextPacket(const APageSize,
      APageNext: Integer): IDBDataSet; overload; override;
    function NextPacket(const AWhere, AOrderBy: String;
      const APageSize, APageNext: Integer): IDBDataSet; overload; override;
    // ObjectSet
    function Find: IDBDataSet; overload; override;
    function Find(const AID: TValue): M; overload; override;
    function FindWhere(const AWhere: String;
      const AOrderBy: String): IDBDataSet; override;
  end;

implementation

uses
  Janus.Bind,
  Janus.Session.Abstract,
  Janus.Objects.Helper,
  Janus.RTTI.Helper;

{ TObjectManager<M> }

constructor TSQLCommandExecutor<M>.Create(const AOwner: TObject;
  const AConnection: IDBConnection; const APageSize: Integer);
begin
  inherited;
  FOwner := AOwner;
  FPageSize := APageSize;
  if not (AOwner is TSessionAbstract<M>) then
    raise Exception
            .Create('O Object Manager n�o deve ser inst�nciada diretamente, use as classes TSessionObject<M> ou TSessionDataSet<M>');
  FConnection := AConnection;

  FObjectInternal := M.Create;
  FDMLCommandFactory := TDMLCommandFactory.Create(FObjectInternal,
                                                  AConnection,
                                                  AConnection.GetDriver);
  FLazyToken := TLazySessionToken.Create;
  FProcessingObjects := TList<Pointer>.Create;
end;

destructor TSQLCommandExecutor<M>.Destroy;
begin
  FLazyToken.Invalidate;
  FProcessingObjects.Free;
  FDMLCommandFactory.Free;
  FObjectInternal.Free;
  inherited;
end;

procedure TSQLCommandExecutor<M>.DeleteInternal(const AObject: M);
begin
  FDMLCommandFactory.GeneratorDelete(AObject);
end;

function TSQLCommandExecutor<M>.SelectInternalAll: IDBDataSet;
begin
  Result := FDMLCommandFactory.GeneratorSelectAll(M, FPageSize);
end;

function TSQLCommandExecutor<M>.SelectInternalAssociation(
  const AObject: TObject): String;
var
  LAssociationList: TAssociationMappingList;
  LAssociation: TAssociationMapping;
begin
  // Result deve sempre iniciar vazio
  Result := '';
  LAssociationList := TMappingExplorer.GetMappingAssociation(AObject.ClassType);
  if LAssociationList = nil then
    Exit;
  for LAssociation in LAssociationList do
  begin
     if LAssociation.ClassNameRef <> FObjectInternal.ClassName then
       Continue;
     if LAssociation.Lazy then
       Continue;
     if LAssociation.Multiplicity in [TMultiplicity.OneToOne,
                                      TMultiplicity.ManyToOne] then
        Result := FDMLCommandFactory
                    .GeneratorSelectAssociation(AObject,
                                                FObjectInternal.ClassType,
                                                LAssociation)
     else
     if LAssociation.Multiplicity in [TMultiplicity.OneToMany,
                                      TMultiplicity.ManyToMany] then
        Result := FDMLCommandFactory
                    .GeneratorSelectAssociation(AObject,
                                                FObjectInternal.ClassType,
                                                LAssociation)
  end;
end;

function TSQLCommandExecutor<M>.SelectInternalID(const AID: TValue): IDBDataSet;
begin
  Result := FDMLCommandFactory.GeneratorSelectID(M, AID);
end;

function TSQLCommandExecutor<M>.SelectInternalWhere(const AWhere: String;
  const AOrderBy: String): String;
begin
  Result := FDMLCommandFactory.GeneratorSelectWhere(M,
                                                    AWhere,
                                                    AOrderBy,
                                                    FPageSize);
end;

procedure TSQLCommandExecutor<M>.FillAssociation(const AObject: M);
var
  LAssociationList: TAssociationMappingList;
  LAssociation: TAssociationMapping;
begin
  // Em bancos NoSQL o atributo Association deve ser ignorado.
  if FConnection.GetDriver = TDBEngineDriver.dnMongoDB then
    Exit;
  if Assigned(AObject) then
  begin
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
       if LAssociation.Multiplicity in [TMultiplicity.OneToOne,
                                        TMultiplicity.ManyToOne] then
          ExecuteOneToOne(AObject, LAssociation.PropertyRtti, LAssociation)
       else
       if LAssociation.Multiplicity in [TMultiplicity.OneToMany,
                                        TMultiplicity.ManyToMany] then
          ExecuteOneToMany(AObject, LAssociation.PropertyRtti, LAssociation);
    end;
  end;
end;

procedure TSQLCommandExecutor<M>.FillAssociationLazy(const AOwner, AObject: TObject);
var
  LAssociationList: TAssociationMappingList;
  LAssociation: TAssociationMapping;
begin
  // Em bancos NoSQL o atributo Association deve ser ignorado.
  if FConnection.GetDriver = TDBEngineDriver.dnMongoDB then
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
    if LAssociation.Multiplicity in [TMultiplicity.OneToOne,
                                     TMultiplicity.ManyToOne] then
      ExecuteOneToOne(AOwner, LAssociation.PropertyRtti, LAssociation)
    else
    if LAssociation.Multiplicity in [TMultiplicity.OneToMany,
                                     TMultiplicity.ManyToMany] then
      ExecuteOneToMany(AOwner, LAssociation.PropertyRtti, LAssociation);
  end;
end;

procedure TSQLCommandExecutor<M>._InjectLazyFactory(const AObject: TObject;
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

procedure TSQLCommandExecutor<M>.InjectLazyFactories(const AObject: TObject);
var
  LAssociationList: TAssociationMappingList;
  LAssociation: TAssociationMapping;
begin
  if FConnection.GetDriver = TDBEngineDriver.dnMongoDB then
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

procedure TSQLCommandExecutor<M>.ExecuteOneToOne(AObject: TObject;
  AProperty: TRttiProperty; AAssociation: TAssociationMapping);
var
  LResultSet: IDBDataSet;
  LObjectValue: TObject;
begin
  LResultSet := FDMLCommandFactory
                  .GeneratorSelectOneToOne(AObject,
                                           AProperty.PropertyType
                                                    .AsInstance.MetaclassType,
                                           AAssociation);
  try
    while not LResultSet.Eof do
    begin
      LObjectValue := AProperty.GetNullableValue(AObject).AsObject;
      if LObjectValue = nil then
      begin
        LObjectValue := AProperty.PropertyType
                                 .AsInstance
                                 .MetaclassType.Create;
        AProperty.SetValue(AObject, TValue.from<TObject>(LObjectValue));
      end;
      // Preenche o objeto com os dados do ResultSet
      Bind.SetFieldToProperty(LResultSet, LObjectValue);
      // Alimenta registros das associa��es existentes 1:1 ou 1:N
      FillAssociation(LObjectValue);
    end;
  finally
    LResultSet.Close;
  end;
end;

procedure TSQLCommandExecutor<M>.ExecuteOneToMany(AObject: TObject;
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
                                            LPropertyType.AsInstance
                                                         .MetaclassType,
                                            AAssociation);
  try
    while not LResultSet.Eof do
    begin
      // Instancia o objeto do tipo definido na lista
      LObjectCreate := LPropertyType.AsInstance.MetaclassType.Create;
      LObjectCreate.MethodCall('Create', []);
      // Popula o objeto com os dados do ResultSet
      Bind.SetFieldToProperty(LResultSet, LObjectCreate);
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

function TSQLCommandExecutor<M>.ExistSequence: Boolean;
begin
  Result := FDMLCommandFactory.ExistSequence;
end;

function TSQLCommandExecutor<M>.GetDMLCommand: String;
begin
  Result := FDMLCommandFactory.GetDMLCommand;
end;

function TSQLCommandExecutor<M>.NextPacket: IDBDataSet;
begin
  Result := FDMLCommandFactory.GeneratorNextPacket;
end;

function TSQLCommandExecutor<M>.NextPacket(const APageSize,
  APageNext: Integer): IDBDataSet;
begin
  Result := FDMLCommandFactory.GeneratorNextPacket(TClass(M),
                                                   APageSize,
                                                   APageNext);
end;

function TSQLCommandExecutor<M>.NextPacketList: IDBDataSet;
begin
  Result := NextPacket;
end;

function TSQLCommandExecutor<M>.NextPacket(const AWhere, AOrderBy: String;
  const APageSize, APageNext: Integer): IDBDataSet;
begin
  Result := FDMLCommandFactory
              .GeneratorNextPacket(TClass(M),
                                   AWhere,
                                   AOrderBy,
                                   APageSize,
                                   APageNext);
end;

function TSQLCommandExecutor<M>.NextPacketList(const AWhere, AOrderBy: String;
  const APageSize, APageNext: Integer): IDBDataSet;
begin
  Result := NextPacket(AWhere, AOrderBy, APageSize, APageNext);
end;

procedure TSQLCommandExecutor<M>.NextPacketList(const AObjectList: TObjectList<M>;
  const AWhere, AOrderBy: String; const APageSize, APageNext: Integer);
var
 LResultSet: IDBDataSet;
begin
  LResultSet := NextPacket(AWhere, AOrderBy, APageSize, APageNext);
  try
    while not LResultSet.Eof do
    begin
      AObjectList.Add(M.Create);
      Bind.SetFieldToProperty(LResultSet, TObject(AObjectList.Last));
      // Alimenta registros das associa��es existentes 1:1 ou 1:N
      FillAssociation(AObjectList.Last);
    end;
  finally
    // Essa tag � controlada pela session, mas como esse m�todo fornece
    // dados para a session, tiver que muda-la aqui.
    if LResultSet.RecordCount = 0 then
      TSessionAbstract<M>(FOwner).FetchingRecords := True;

    LResultSet.Close;
  end;
end;

procedure TSQLCommandExecutor<M>.NextPacketList(const AObjectList: TObjectList<M>;
  const APageSize, APageNext: Integer);
var
 LResultSet: IDBDataSet;
begin
  LResultSet := NextPacket(APageSize, APageNext);
  try
    while not LResultSet.Eof do
    begin
      AObjectList.Add(M.Create);
      Bind.SetFieldToProperty(LResultSet, TObject(AObjectList.Last));
      // Alimenta registros das associa��es existentes 1:1 ou 1:N
      FillAssociation(AObjectList.Last);
    end;
  finally
    // Essa tag � controlada pela session, mas como esse m�todo fornece
    // dados para a session, tiver que muda-la aqui.
    if LResultSet.RecordCount = 0 then
      TSessionAbstract<M>(FOwner).FetchingRecords := True;

    LResultSet.Close;
  end;
end;

function TSQLCommandExecutor<M>.NextPacketList(const APageSize,
  APageNext: Integer): IDBDataSet;
begin
  Result := NextPacket(APageSize, APageNext);
end;

function TSQLCommandExecutor<M>.SelectInternal(const ASQL: String): IDBDataSet;
begin
  Result := FDMLCommandFactory.GeneratorSelect(ASQL, FPageSize);
end;

procedure TSQLCommandExecutor<M>.UpdateInternal(const AObject: TObject;
  const AModifiedFields: TDictionary<String, String>);
begin
  FDMLCommandFactory.GeneratorUpdate(AObject, AModifiedFields);
end;

procedure TSQLCommandExecutor<M>.InsertInternal(const AObject: M);
begin
  FDMLCommandFactory.GeneratorInsert(AObject);
end;

procedure TSQLCommandExecutor<M>.LoadLazy(const AOwner, AObject: TObject);
begin
  FillAssociationLazy(AOwner, AObject);
end;

function TSQLCommandExecutor<M>.FindSQLInternal(const ASQL: String): IDBDataSet;
begin
  if ASQL = '' then
    Result := SelectInternalAll
  else
    Result := SelectInternal(ASQL);
end;

function TSQLCommandExecutor<M>.Find: IDBDataSet;
begin
  Result := FindSQLInternal('');
end;

function TSQLCommandExecutor<M>.Find(const AID: TValue): M;
var
 LResultSet: IDBDataSet;
begin
  LResultSet := SelectInternalID(AID);
  try
    if LResultSet.RecordCount = 1 then
    begin
      Result := M.Create;
      Bind.SetFieldToProperty(LResultSet, TObject(Result));
      // Alimenta registros das associa��es existentes 1:1 ou 1:N
      FillAssociation(Result);
    end
    else
      Result := nil;
  finally
    LResultSet.Close;
  end;
end;

function TSQLCommandExecutor<M>.FindWhere(const AWhere: String;
  const AOrderBy: String): IDBDataSet;
begin
  Result := FindSQLInternal(SelectInternalWhere(AWhere, AOrderBy));
end;

end.

