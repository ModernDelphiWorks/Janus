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
  SyncObjs,
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
    class var FInstanceLock: TCriticalSection;
    FLazyFieldsCache: TObjectDictionary<String, TObjectList<TLazyMapping>>;
    FCacheLock: TCriticalSection;
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
          // O MethodCall NAO E REDUNDANTE. LChildClass e um TClass, e Create
          // sobre uma REFERENCIA DE CLASSE liga ESTATICAMENTE a TObject.Create:
          // a linha acima aloca e zera a instancia, e o corpo do construtor da
          // classe filha NAO roda. A causa e a ligacao estatica, nao despacho
          // virtual - um construtor virtual alcancado assim falha igual. O
          // relato canonico do mecanismo, com a medicao das oito formas por
          // tras dele, esta em TObjectHelper.MethodCall - ancorado por SIMBOLO.
          //
          // O IRMAO DESTA FUNCAO, LOGO ABAIXO NESTA MESMA UNIT,
          // CreateLazyManyAssociationLoadFunc, sempre teve esta chamada. Doze
          // linhas de distancia, e a diferenca decidia se o dado sobrevivia.
          //
          // MEDIDO, mesmo modelo, mesmas linhas, mudando so a rota: um
          // TLazyCtorChild - cujo construtor monta Fgrands - materializado por
          // esta funcao chegava com grands nil, e as duas netas eram
          // descartadas; pelas rotas de colecao, lazy e eager, chegava com
          // grands.Count = 2. A perda e SILENCIOSA por construcao:
          // TSQLCommandExecutor<M>.ExecuteOneToMany anexa cada neta sob
          // `if LObjectList <> nil`, entao a lista nil faz aquela guarda jogar
          // fora cada linha sem excecao e sem log - e os objetos recem-criados
          // nao sao nem adicionados nem liberados.
          //
          // POR QUE A SUITE FICAVA VERDE COM O DEFEITO VIVO. Medido com uma
          // sonda nesta linha, sobre a Janus.Tests.Units inteira em 8f5864f:
          // o sitio executava TRES vezes em 715 testes, sempre
          // TExame -> TProcedimento, sempre vindo de
          // Test.Janus.Cursor.Advance.LazySingleAssociation_ThreeRows_Terminates,
          // que chama esta funcao DIRETAMENTE. NENHUMA rota publica chegava
          // aqui, e TProcedimento.Create e VAZIO - nao havia o que um construtor
          // pulado perdesse. A mesma sonda sobre a Janus.Tests.RESTfulDriver nao
          // produziu uma linha: 283 testes, sitio nunca alcancado. Quem cobre
          // isso agora e Test.Janus.ObjectSet.LazyOneToOneChildCtor, o primeiro
          // teste do repositorio a alcancar esta funcao pela API publica.
          //
          // O RISCO DESTA CHAMADA, dito como CONDICAO e nao como contagem.
          // GetMethod('Create') devolve o PRIMEIRO construtor declarado, nao uma
          // sobrecarga casada com os argumentos - o aviso esta escrito por
          // extenso no irmao logo abaixo. A chamada e segura enquanto o alvo
          // declarar no maximo um construtor sem parametros; nao declarando
          // nenhum, GetMethod cai em TObject.Create, inofensivo. Um alvo que
          // passe a declarar dois construtores, com o de parametros primeiro,
          // quebra aqui. E a armadilha especifica descrita no irmao NAO morde
          // nesta linha: mesmo que o alvo fosse um TObjectList<T>, o construtor
          // que GetMethod devolve para ele e o de ZERO argumentos, que e
          // exatamente o numero de argumentos passados aqui.
          LObjectValue.MethodCall('Create', []);
          ABindToObject(LResultSet, LObjectValue);
          ProcessLazyLoadedObject(LObjectValue,
                                  AProcessingObjects,
                                  AProcessLoadedObject);
          Result := LObjectValue;
          // Avanca o cursor: sem isso o laco nunca atinge Eof e recria o mesmo
          // objeto infinitamente (loop infinito / OOM).
          LResultSet.Next;
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
      LListType: TRttiType;
      LListCtor: TRttiMethod;
      LResultSet: IDBDataSet;
    begin
      LPropertyType := LProperty.PropertyType;
      LPropertyType := LProperty.GetTypeValue(LPropertyType);
      // A lista NAO pode ser instanciada com TClass.Create seguido de
      // MethodCall('Create', [True]). TClass.Create resolve para o TObject
      // .Create, que nao e virtual, e o MethodCall invoca o construtor que
      // GetMethod('Create') devolve - num TObjectList<T> esse e o de ZERO
      // argumentos (medido: os quatro construtores proprios da classe saem em
      // GetMethods na ordem declarada, e o primeiro e o sem parametros).
      // Passar um argumento para ele levanta 'Parameter count mismatch' antes
      // de o cursor ser tocado, o que matava o caminho lazy OneToMany inteiro.
      // Invocar o construtor sobre a METACLASSE constroi de verdade, e o
      // numero de argumentos passa a seguir o construtor que o RTTI devolveu.
      //
      // A GUARDA ABAIXO NAO E A DE Lazy<T>.CreateDefaultValue, E E DE
      // PROPOSITO. O irmao, em Janus.Types.Lazy, exige tambem LRttiType
      // .IsList; aqui o IsList foi OMITIDO. TRttiTypeHelper.IsList
      // (MetaDbDiff.RTTI.Helper.pas:799-808) e um teste de SUBSTRING no NOME
      // da classe: devolve True quando o nome contem 'TObjectList<' ou
      // 'TList<'. Isso NAO e o mesmo que "e uma lista da RTL" - e False para o
      // descendente cujo nome nao casa a substring, mas e TRUE para um
      // descendente batizado TMyTList<T> ou TBaseTObjectList<T>, porque o
      // proprio batismo carrega a substring. MEDIDO em Studio 37 sobre sete
      // formatos, com os tipos declarados numa UNIT de verdade - num .dpr o
      // FindType falha para todos e falsearia a ultima coluna:
      //
      //   nome                      IsList param [True] []    GetTypeValue
      //   TObjectList<T> .......... True   0     erro   OK    resolve
      //   TList<T> ................ True   0     erro   OK    resolve
      //   descendente sem ctor .... False  0     erro   OK    nil
      //   desc. Create(String) .... False  1     erro   erro  nil
      //   desc. Create(Boolean) ... False  1     OK     erro  nil
      //   TMyTList<T> ............. True   1     OK     erro  nil
      //   TBaseTObjectList<T> ..... True   1     OK     erro  nil
      //
      // Somar 'and IsList' NAO consertaria o descendente de Create(String) -
      // esse ja falha ALTO hoje, com EInvalidCast -, so trocaria uma excecao
      // alta por outra; e QUEBRARIA o descendente de Create(Boolean), que hoje
      // constroi certo e passaria a levantar 'Parameter count mismatch'. E as
      // duas ultimas linhas da tabela dao a razao de fundo: TMyTList<T> tem A
      // MESMA FORMA do descendente de Create(Boolean) - descendente, ctor
      // proprio de um booleano, [True] constroi certo -, e com o IsList somado
      // os dois receberiam tratamento OPOSTO, um [True] e outro [], decidido
      // unicamente pelo NOME da classe. Guarda que muda de valor por
      // RENOMEACAO nao e guarda. E por isso que o IsList fica FORA.
      //
      // O RAMO [True] NAO ESTA COBERTO PELA SUITE, e ainda nao da para
      // cobri-lo: os tres formatos que o executam sao TODOS descendentes, e
      // todo descendente morre duas linhas abaixo, em LPropertyType.AsInstance,
      // porque GetTypeValue devolve nil para nome que nao case com o strip
      // textual - coluna medida acima (upstream ModernDelphiWorks/MetaDbDiff
      // #18). MEDIDO em 6f67607: matar o ramo e invocar sempre [] deixa a
      // suite 501/501 verde - uma execucao daquele commit, quando essa era
      // toda a Janus.Tests.Units. A suite cresceu desde entao; leia o
      // numero como o tamanho daquela execucao e nao como o baseline de
      // hoje, e re-rode a mutacao em vez de escala-lo. Ele fica como defesa
      // para o dia em que aquele upstream for consertado e o descendente
      // virar caminho vivo.
      LListType := RttiSingleton.GetRttiType(
                     LProperty.PropertyType.AsInstance.MetaclassType);
      LListCtor := LListType.GetMethod('Create');
      if LListCtor = nil then
        raise ELazyLoadException.CreateFmt(
          'Lazy load failed: no "Create" constructor was found for the list ' +
          'type "%s" of property "%s".', [LListType.ToString, LProperty.Name]);
      if Length(LListCtor.GetParameters) = 1 then
        LObjectList := LListCtor.Invoke(LListType.AsInstance.MetaclassType,
                                        [True]).AsObject
      else
        LObjectList := LListCtor.Invoke(LListType.AsInstance.MetaclassType,
                                        []).AsObject;
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
          // Avanca o cursor: sem isso o laco nunca atinge Eof e adiciona a mesma
          // linha infinitamente (loop infinito / OOM).
          LResultSet.Next;
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
        LResettable.Reset(TFunc<TObject>(ALoadFunc), AToken);
        Break;
      end;
    end;

    LProxy := TLazyProxyLoader.Create(TFunc<TObject>(ALoadFunc), AToken);
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
  FCacheLock := TCriticalSection.Create;
end;

destructor TLazyMappingExplorer.Destroy;
begin
  FCacheLock.Free;
  FLazyFieldsCache.Free;
  inherited;
end;

class function TLazyMappingExplorer.GetInstance: TLazyMappingExplorer;
begin
  if not Assigned(FInstance) then
  begin
    FInstanceLock.Enter;
    try
      if not Assigned(FInstance) then
        FInstance := TLazyMappingExplorer.Create;
    finally
      FInstanceLock.Leave;
    end;
  end;
  Result := FInstance;
end;

class procedure TLazyMappingExplorer.ReleaseInstance;
begin
  FreeAndNil(FInstance);
end;

function TLazyMappingExplorer.GetLazyFields(
  const AClass: TClass): TObjectList<TLazyMapping>;
var
  LKey: String;
begin
  { Serialize the ContainsKey/populate/Add sequence: concurrent misses would
    otherwise both populate and both Add the same key (EListError) and/or leak
    the loser's list. Populate happens under the lock (cold path only, once per
    class); once warm every caller reads the already-materialized list, and
    reading an immutable, fully-populated TObjectList concurrently is safe. }
  LKey := AClass.ClassName;
  FCacheLock.Enter;
  try
    if not FLazyFieldsCache.TryGetValue(LKey, Result) then
    begin
      Result := TObjectList<TLazyMapping>.Create(True);
      _PopulateLazyFields(AClass, Result);
      FLazyFieldsCache.Add(LKey, Result);
    end;
  finally
    FCacheLock.Leave;
  end;
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
  TLazyMappingExplorer.FInstanceLock := TCriticalSection.Create;

finalization
  TLazyMappingExplorer.ReleaseInstance;
  TLazyMappingExplorer.FInstanceLock.Free;

end.
