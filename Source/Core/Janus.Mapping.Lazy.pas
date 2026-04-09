{
      ORM Brasil — um ORM simples e descomplicado para quem utiliza Delphi

                   Copyright (c) 2016, Isaque Pinheiro
                          All rights reserved.

                    GNU Lesser General Public License
                      Versão 3, 29 de junho de 2007

       Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
       A todos é permitido copiar e distribuir cópias deste documento de
       licença, mas mudá-lo não é permitido.

       Esta versão da GNU Lesser General Public License incorpora
       os termos e condições da versão 3 da GNU General Public License
       Licença, complementado pelas permissões adicionais listadas no
       arquivo LICENSE na pasta principal.
}

{
  @abstract(Janus Framework.)
  @created(04 Apr 2026)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
}

unit Janus.Mapping.Lazy;

interface

uses
  DB,
  Rtti,
  SysUtils,
  Generics.Collections,
  Janus.Command.Factory,
  DataEngine.FactoryInterfaces,
  MetaDbDiff.Mapping.Classes;

type
  ELazyLoadException = class(Exception);

  ILazySessionToken = interface(IInterface)
    ['{A7F2E3D4-B5C6-4A8D-9E1F-0C2D3B4A5F6E}']
    function IsValid: Boolean;
    procedure Invalidate;
  end;

  TLazySessionToken = class(TInterfacedObject, ILazySessionToken)
  private
    FIsValid: Boolean;
  public
    constructor Create;
    function IsValid: Boolean;
    procedure Invalidate;
  end;

  ILazyProxy = interface(IInterface)
    ['{CBBB4093-AF0A-4367-AC34-018A379BDE57}']
    function Invoke: TObject;
    function IsValueCreated: Boolean;
  end;

  ILazyProxyResettable = interface(IInterface)
    ['{F8E7D6C5-B4A3-4291-80FE-1A2B3C4D5E6F}']
    procedure Reset(const ALoadFunc: TFunc<TObject>;
      const AToken: ILazySessionToken);
  end;

  TLazyProxyLoader = class(TInterfacedObject, ILazyProxy, ILazyProxyResettable)
  private
    FIsLoaded: Boolean;
    FValue: TObject;
    FRetiredValues: TObjectList<TObject>;
    FLoadFunc: TFunc<TObject>;
    FToken: ILazySessionToken;
  public
    constructor Create(const ALoadFunc: TFunc<TObject>;
      const AToken: ILazySessionToken);
    destructor Destroy; override;
    function Invoke: TObject;
    function IsValueCreated: Boolean;
    procedure Reset(const ALoadFunc: TFunc<TObject>;
      const AToken: ILazySessionToken);
  end;

  TLazyMappingExplorer = class
  strict private
    class var FInstance: TLazyMappingExplorer;
  private
    FLazyFieldsCache: TObjectDictionary<String, TObjectList<TLazyMapping>>;
    procedure _PopulateLazyFields(const AClass: TClass;
      const AList: TObjectList<TLazyMapping>);
  public
    constructor Create;
    destructor Destroy; override;
    class function GetInstance: TLazyMappingExplorer;
    class procedure ReleaseInstance;
    function GetLazyFields(const AClass: TClass): TObjectList<TLazyMapping>;
  end;

  TLazyLoadFunc = reference to function: TObject;

  TLazyBindToObjectProc = reference to procedure(const AResultSet: IDBDataSet;
    const AObject: TObject);

  TLazyLoadedObjectProc = reference to procedure(const AObject: TObject);

function LazyMappingExplorer: TLazyMappingExplorer;
function CreateLazySingleAssociationLoadFunc(const AOwnerObject: TObject;
  const AAssociation: TAssociationMapping;
  const AFactory: TDMLCommandFactoryAbstract;
  const ABindToObject: TLazyBindToObjectProc;
  const AProcessingObjects: TList<Pointer>;
  const AProcessLoadedObject: TLazyLoadedObjectProc): TLazyLoadFunc;
function CreateLazyManyAssociationLoadFunc(const AOwnerObject: TObject;
  const AAssociation: TAssociationMapping;
  const AFactory: TDMLCommandFactoryAbstract;
  const ABindToObject: TLazyBindToObjectProc;
  const AProcessingObjects: TList<Pointer>;
  const AProcessLoadedObject: TLazyLoadedObjectProc): TLazyLoadFunc;
procedure InjectLazyAssociationFactory(const AObject: TObject;
  const AAssociation: TAssociationMapping;
  const AToken: ILazySessionToken; const ALoadFunc: TLazyLoadFunc);

implementation

uses
  MetaDbDiff.RTTI.Helper,
  Janus.Objects.Helper,
  Janus.RTTI.Helper,
  Janus.Objects.Utils;

procedure ProcessLazyLoadedObject(const ALoadedObject: TObject;
  const AProcessingObjects: TList<Pointer>;
  const AProcessLoadedObject: TLazyLoadedObjectProc);
begin
  if ALoadedObject = nil then
    Exit;
  if AProcessingObjects = nil then
  begin
    if Assigned(AProcessLoadedObject) then
      AProcessLoadedObject(ALoadedObject);
    Exit;
  end;
  if AProcessingObjects.Contains(ALoadedObject) then
    Exit;

  AProcessingObjects.Add(ALoadedObject);
  try
    if Assigned(AProcessLoadedObject) then
      AProcessLoadedObject(ALoadedObject);
  finally
    AProcessingObjects.Remove(ALoadedObject);
  end;
end;

function LazyMappingExplorer: TLazyMappingExplorer;
begin
  Result := TLazyMappingExplorer.GetInstance;
end;

function CreateLazySingleAssociationLoadFunc(const AOwnerObject: TObject;
  const AAssociation: TAssociationMapping;
  const AFactory: TDMLCommandFactoryAbstract;
  const ABindToObject: TLazyBindToObjectProc;
  const AProcessingObjects: TList<Pointer>;
  const AProcessLoadedObject: TLazyLoadedObjectProc): TLazyLoadFunc;
var
  LProperty: TRttiProperty;
begin
  LProperty := AAssociation.PropertyRtti;
  Result :=
    function: TObject
    var
      LResultSet: IDBDataSet;
      LObjectValue: TObject;
      LChildClass: TClass;
    begin
      Result := nil;
      LChildClass := LProperty.PropertyType.AsInstance.MetaclassType;
      LResultSet := AFactory.GeneratorSelectOneToOne(AOwnerObject,
                                                     LChildClass,
                                                     AAssociation);
      try
        while not LResultSet.Eof do
        begin
          LObjectValue := LChildClass.Create;
          ABindToObject(LResultSet, LObjectValue);
          ProcessLazyLoadedObject(LObjectValue,
                                  AProcessingObjects,
                                  AProcessLoadedObject);
          Result := LObjectValue;
        end;
      finally
        LResultSet.Close;
      end;
    end;
end;

function CreateLazyManyAssociationLoadFunc(const AOwnerObject: TObject;
  const AAssociation: TAssociationMapping;
  const AFactory: TDMLCommandFactoryAbstract;
  const ABindToObject: TLazyBindToObjectProc;
  const AProcessingObjects: TList<Pointer>;
  const AProcessLoadedObject: TLazyLoadedObjectProc): TLazyLoadFunc;
var
  LProperty: TRttiProperty;
begin
  LProperty := AAssociation.PropertyRtti;
  Result :=
    function: TObject
    var
      LPropertyType: TRttiType;
      LObjectCreate: TObject;
      LObjectList: TObject;
      LListClass: TClass;
      LResultSet: IDBDataSet;
    begin
      LPropertyType := LProperty.PropertyType;
      LPropertyType := LProperty.GetTypeValue(LPropertyType);
      LListClass := LProperty.PropertyType.AsInstance.MetaclassType;
      LObjectList := LListClass.Create;
      LObjectList.MethodCall('Create', [True]);
      LResultSet := AFactory.GeneratorSelectOneToMany(AOwnerObject,
                                                      LPropertyType.AsInstance.MetaclassType,
                                                      AAssociation);
      try
        while not LResultSet.Eof do
        begin
          LObjectCreate := LPropertyType.AsInstance.MetaclassType.Create;
          LObjectCreate.MethodCall('Create', []);
          ABindToObject(LResultSet, LObjectCreate);
          ProcessLazyLoadedObject(LObjectCreate,
                                  AProcessingObjects,
                                  AProcessLoadedObject);
          LObjectList.MethodCall('Add', [LObjectCreate]);
        end;
      finally
        LResultSet.Close;
      end;
      Result := LObjectList;
    end;
end;

procedure InjectLazyAssociationFactory(const AObject: TObject;
  const AAssociation: TAssociationMapping;
  const AToken: ILazySessionToken; const ALoadFunc: TLazyLoadFunc);
var
  LLazyFields: TObjectList<TLazyMapping>;
  LLazyMapping: TLazyMapping;
  LLazyField: TRttiField;
  LLazyRecordType: TRttiType;
  LFLazySubField: TRttiField;
  LRecordValue: TValue;
  LRecordPtr: Pointer;
  LExistingValue: TValue;
  LExistingIntf: IInterface;
  LResettable: ILazyProxyResettable;
  LProxy: ILazyProxy;
  LRawPtr: Pointer;
  LInterfaceValue: TValue;
begin
  if (AObject = nil) or (AAssociation = nil) or not Assigned(ALoadFunc) then
    Exit;

  LLazyFields := LazyMappingExplorer.GetLazyFields(AObject.ClassType);
  if (LLazyFields = nil) or (LLazyFields.Count = 0) then
    Exit;

  for LLazyMapping in LLazyFields do
  begin
    LLazyField := LLazyMapping.FieldLazy;
    if not SameText(LLazyField.Name, 'F' + AAssociation.PropertyRtti.Name) then
      Continue;

    LLazyRecordType := LLazyField.FieldType;
    LFLazySubField := LLazyRecordType.GetField('FLazy');
    if LFLazySubField = nil then
      Continue;

    LRecordValue := LLazyField.GetValue(AObject);
    LRecordPtr := LRecordValue.GetReferenceToRawData;

    LExistingValue := LFLazySubField.GetValue(LRecordPtr);
    if not LExistingValue.IsEmpty then
    begin
      LExistingIntf := LExistingValue.AsInterface;
      if (LExistingIntf <> nil) and
         Supports(LExistingIntf, ILazyProxyResettable, LResettable) then
      begin
        LResettable.Reset(ALoadFunc, AToken);
        Break;
      end;
    end;

    LProxy := TLazyProxyLoader.Create(ALoadFunc, AToken);
    LRawPtr := Pointer(LProxy);
    TValue.Make(@LRawPtr, LFLazySubField.FieldType.Handle, LInterfaceValue);
    LFLazySubField.SetValue(LRecordPtr, LInterfaceValue);
    LLazyField.SetValue(AObject, LRecordValue);
    Break;
  end;
end;

{ TLazySessionToken }

constructor TLazySessionToken.Create;
begin
  inherited Create;
  FIsValid := True;
end;

function TLazySessionToken.IsValid: Boolean;
begin
  Result := FIsValid;
end;

procedure TLazySessionToken.Invalidate;
begin
  FIsValid := False;
end;

{ TLazyProxyLoader }

constructor TLazyProxyLoader.Create(const ALoadFunc: TFunc<TObject>;
  const AToken: ILazySessionToken);
begin
  inherited Create;
  FLoadFunc := ALoadFunc;
  FToken := AToken;
  FIsLoaded := False;
  FValue := nil;
  FRetiredValues := TObjectList<TObject>.Create(True);
end;

destructor TLazyProxyLoader.Destroy;
begin
  if FIsLoaded and (FValue <> nil) then
    FValue.Free;
  FRetiredValues.Free;
  FLoadFunc := nil;
  FToken := nil;
  inherited;
end;

function TLazyProxyLoader.Invoke: TObject;
begin
  if not FIsLoaded then
  begin
    if Assigned(FToken) and (not FToken.IsValid) then
      raise ELazyLoadException.Create(
        'Lazy load failed: the session has been destroyed. ' +
        'Ensure the session is alive before accessing lazy properties.');
    FValue := FLoadFunc();
    FIsLoaded := True;
  end;
  Result := FValue;
end;

function TLazyProxyLoader.IsValueCreated: Boolean;
begin
  Result := FIsLoaded;
end;

procedure TLazyProxyLoader.Reset(const ALoadFunc: TFunc<TObject>;
  const AToken: ILazySessionToken);
begin
  if FIsLoaded and (FValue <> nil) then
    FRetiredValues.Add(FValue);
  FLoadFunc := ALoadFunc;
  FToken := AToken;
  FIsLoaded := False;
  FValue := nil;
end;

{ TLazyMappingExplorer }

constructor TLazyMappingExplorer.Create;
begin
  FLazyFieldsCache := TObjectDictionary<String, TObjectList<TLazyMapping>>.Create([doOwnsValues]);
end;

destructor TLazyMappingExplorer.Destroy;
begin
  FLazyFieldsCache.Free;
  inherited;
end;

class function TLazyMappingExplorer.GetInstance: TLazyMappingExplorer;
begin
  if not Assigned(FInstance) then
    FInstance := TLazyMappingExplorer.Create;
  Result := FInstance;
end;

class procedure TLazyMappingExplorer.ReleaseInstance;
begin
  FreeAndNil(FInstance);
end;

function TLazyMappingExplorer.GetLazyFields(
  const AClass: TClass): TObjectList<TLazyMapping>;
begin
  if FLazyFieldsCache.ContainsKey(AClass.ClassName) then
    Exit(FLazyFieldsCache[AClass.ClassName]);

  Result := TObjectList<TLazyMapping>.Create(True);
  _PopulateLazyFields(AClass, Result);
  FLazyFieldsCache.Add(AClass.ClassName, Result);
end;

procedure TLazyMappingExplorer._PopulateLazyFields(const AClass: TClass;
  const AList: TObjectList<TLazyMapping>);
var
  LRttiType: TRttiType;
  LField: TRttiField;
begin
  LRttiType := RttiSingleton.GetRttiType(AClass);
  if LRttiType = nil then
    Exit;
  for LField in LRttiType.GetFields do
  begin
    if not LField.IsLazy then
      Continue;
    AList.Add(TLazyMapping.Create(LField));
  end;
end;

initialization

finalization
  TLazyMappingExplorer.ReleaseInstance;

end.
