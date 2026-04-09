{
      ORM Brasil — um ORM simples e descomplicado para quem utiliza Delphi

                   Copyright (c) 2016, Isaque Pinheiro
                          All rights reserved.

                    GNU Lesser General Public License
                      Versao 3, 29 de junho de 2007

       Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
       A todos e permitido copiar e distribuir copias deste documento de
       licenca, mas muda-lo nao e permitido.

       Esta versao da GNU Lesser General Public License incorpora
       os termos e condicoes da versao 3 da GNU General Public License
       Licenca, complementado pelas permissoes adicionais listadas no
       arquivo LICENSE na pasta principal.
}

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

{$INCLUDE ..\Janus.inc}

unit Janus.Register.Middleware;

interface

uses
  SysUtils,
  Rtti,
  Generics.Collections,
  Generics.Defaults;

type
  TJanusEventType = (onBeforeInsert, onAfeterInsert,
                     onBeforeUpdate, onAfterUpdate,
                     onBeforeDelete, onAfterDelete,
                     onCustom);

  TQueryScopeList = TDictionary<String, TFunc<String>>;
  TQueryScopeCallback = reference to function(const AResource: String): TQueryScopeList;
  TEvent = TProc<TObject>;
  TEventCallback = reference to function(const AResource: String): TEvent;

  // Forward declaration
  IJanusHookContext = interface;

  TContextEvent = TProc<IJanusHookContext>;

  TContextEventEntry = record
    Priority: Integer;
    Callback: TContextEvent;
  end;

  TContextEventList = TList<TContextEventEntry>;
  TContextEventCallback = reference to function(const AResource: String): TContextEventList;

  IJanusHookContext = interface
    ['{1A2B3C4D-5E6F-7A8B-9C0D-E1F2A3B4C5D6}']
    function GetOperationType: TJanusEventType;
    function GetEntityClass: TClass;
    function GetEntity: TObject;
    function GetAborted: Boolean;
    function GetMetadata: TDictionary<String, TValue>;
    procedure Abort;
    property OperationType: TJanusEventType read GetOperationType;
    property EntityClass: TClass read GetEntityClass;
    property Entity: TObject read GetEntity;
    property Aborted: Boolean read GetAborted;
    property Metadata: TDictionary<String, TValue> read GetMetadata;
  end;

  TMiddlewareQueryScope = class
  private
    FQueryScopeCallback: TQueryScopeCallback;
  public
    constructor Create(const ACallback: TQueryScopeCallback); overload;
    function ExecuteQueryScopeCallback(const AResource: String): TQueryScopeList;
  end;

  TMiddlewareEvent = class
  private
    FEventCallback: TEventCallback;
  public
    constructor Create(const ACallback: TEventCallback); overload;
    function ExecuteEventCallback(const AResource: String): TEvent;
  end;

  TMiddlewareContextEvent = class
  private
    FContextEventCallback: TContextEventCallback;
  public
    constructor Create(const ACallback: TContextEventCallback); overload;
    function ExecuteContextEventCallback(const AResource: String): TContextEventList;
  end;

  TJanusMiddlewares = class
  private
    class var FQueryScopeCallbacks: TDictionary<String, TMiddlewareQueryScope>;
    class var FEventCallbacks: TDictionary<String, TMiddlewareEvent>;
    class var FContextEventCallbacks: TDictionary<String, TMiddlewareContextEvent>;
    class var FCustomEventCallbacks: TDictionary<String, TContextEventList>;
    class var FReservedEventNames: TList<String>;
    class procedure _InitReservedNames;
    class function _IsReservedName(const AEventName: String): Boolean;
  public
    class constructor Create;
    class destructor Destroy;
    // Query Scope
    class procedure RegisterQueryScopeCallback(const ANameCallback: String;
      const ACallback: TQueryScopeCallback);
    class function ExecuteQueryScopeCallback(const AClass: TClass;
      const ANameCallback: String): TQueryScopeList;
    // Events (legacy)
    class procedure RegisterEventCallback(const ANameCallback: String;
      const ACallback: TEventCallback);
    class function ExecuteEventCallback(const AClass: TClass;
      const ANameCallback: String): TEvent;
    // Context Events (new)
    class procedure RegisterContextEventCallback(const ANameCallback: String;
      const ACallback: TContextEventCallback);
    class function ExecuteContextEventCallback(const AClass: TClass;
      const ANameCallback: String): TContextEventList;
    // Custom Events
    class procedure RegisterCustomEvent(const AEventName: String;
      const ACallback: TContextEvent; const APriority: Integer = 100);
    class procedure ExecuteCustomEvent(const AEventName: String;
      const AContext: IJanusHookContext);
  end;

implementation

{ TJanusMiddlewares }

class constructor TJanusMiddlewares.Create;
begin
  FQueryScopeCallbacks := TObjectDictionary<String, TMiddlewareQueryScope>.Create([doOwnsValues]);
  FEventCallbacks := TObjectDictionary<String, TMiddlewareEvent>.Create([doOwnsValues]);
  FContextEventCallbacks := TObjectDictionary<String, TMiddlewareContextEvent>.Create([doOwnsValues]);
  FCustomEventCallbacks := TObjectDictionary<String, TContextEventList>.Create([doOwnsValues]);
  FReservedEventNames := TList<String>.Create;
  _InitReservedNames;
end;

class destructor TJanusMiddlewares.Destroy;
begin
  FQueryScopeCallbacks.Free;
  FEventCallbacks.Free;
  FContextEventCallbacks.Free;
  FCustomEventCallbacks.Free;
  FReservedEventNames.Free;
end;

class procedure TJanusMiddlewares._InitReservedNames;
begin
  FReservedEventNames.Add(UpperCase('BeforeInsert'));
  FReservedEventNames.Add(UpperCase('AfterInsert'));
  FReservedEventNames.Add(UpperCase('BeforeUpdate'));
  FReservedEventNames.Add(UpperCase('AfterUpdate'));
  FReservedEventNames.Add(UpperCase('BeforeDelete'));
  FReservedEventNames.Add(UpperCase('AfterDelete'));
end;

class function TJanusMiddlewares._IsReservedName(const AEventName: String): Boolean;
begin
  Result := FReservedEventNames.Contains(UpperCase(AEventName));
end;

class procedure TJanusMiddlewares.RegisterEventCallback(
  const ANameCallback: String; const ACallback: TEventCallback);
begin
  FEventCallbacks.AddOrSetValue(ANameCallback, TMiddlewareEvent.Create(ACallback));
end;

class procedure TJanusMiddlewares.RegisterQueryScopeCallback(const ANameCallback: String;
  const ACallback: TQueryScopeCallback);
begin
  FQueryScopeCallbacks.AddOrSetValue(ANameCallback, TMiddlewareQueryScope.Create(ACallback));
end;

class function TJanusMiddlewares.ExecuteEventCallback(const AClass: TClass;
  const ANameCallback: String): TEvent;
begin
  Result := nil;
  if not FEventCallbacks.ContainsKey(ANameCallback) then
    Exit;
  Result := FEventCallbacks[ANameCallback].ExecuteEventCallback(UpperCase(AClass.ClassName));
end;

class function TJanusMiddlewares.ExecuteQueryScopeCallback(const AClass: TClass;
  const ANameCallback: String): TQueryScopeList;
begin
  Result := nil;
  if not FQueryScopeCallbacks.ContainsKey(ANameCallback) then
    Exit;
  Result := FQueryScopeCallbacks[ANameCallback].ExecuteQueryScopeCallback(UpperCase(AClass.ClassName));
end;

class procedure TJanusMiddlewares.RegisterContextEventCallback(
  const ANameCallback: String; const ACallback: TContextEventCallback);
begin
  FContextEventCallbacks.AddOrSetValue(ANameCallback,
    TMiddlewareContextEvent.Create(ACallback));
end;

class function TJanusMiddlewares.ExecuteContextEventCallback(const AClass: TClass;
  const ANameCallback: String): TContextEventList;
begin
  Result := nil;
  if not FContextEventCallbacks.ContainsKey(ANameCallback) then
    Exit;
  Result := FContextEventCallbacks[ANameCallback]
    .ExecuteContextEventCallback(UpperCase(AClass.ClassName));
end;

class procedure TJanusMiddlewares.RegisterCustomEvent(const AEventName: String;
  const ACallback: TContextEvent; const APriority: Integer);
var
  LList: TContextEventList;
  LEntry: TContextEventEntry;
  LIndex: Integer;
  LInserted: Boolean;
begin
  if _IsReservedName(AEventName) then
    raise Exception.CreateFmt(
      'Cannot register custom event with reserved name "%s".', [AEventName]);
  if not FCustomEventCallbacks.TryGetValue(UpperCase(AEventName), LList) then
  begin
    LList := TContextEventList.Create;
    FCustomEventCallbacks.Add(UpperCase(AEventName), LList);
  end;
  LEntry.Priority := APriority;
  LEntry.Callback := ACallback;
  LInserted := False;
  for LIndex := 0 to LList.Count - 1 do
  begin
    if APriority < LList[LIndex].Priority then
    begin
      LList.Insert(LIndex, LEntry);
      LInserted := True;
      Break;
    end;
  end;
  if not LInserted then
    LList.Add(LEntry);
end;

class procedure TJanusMiddlewares.ExecuteCustomEvent(const AEventName: String;
  const AContext: IJanusHookContext);
var
  LList: TContextEventList;
  LEntry: TContextEventEntry;
begin
  if not FCustomEventCallbacks.TryGetValue(UpperCase(AEventName), LList) then
    Exit;
  for LEntry in LList do
  begin
    if AContext.Aborted then
      Break;
    LEntry.Callback(AContext);
  end;
end;

{ TQueryScopeMiddleware }

constructor TMiddlewareQueryScope.Create(const ACallback: TQueryScopeCallback);
begin
  FQueryScopeCallback := ACallback;
end;

function TMiddlewareQueryScope.ExecuteQueryScopeCallback(const AResource: String): TQueryScopeList;
begin
  Result := FQueryScopeCallback(AResource);
end;

{ TMiddlewareEvent }

constructor TMiddlewareEvent.Create(const ACallback: TEventCallback);
begin
  FEventCallback := ACallback;
end;

function TMiddlewareEvent.ExecuteEventCallback(const AResource: String): TEvent;
begin
  Result := FEventCallback(AResource);
end;

{ TMiddlewareContextEvent }

constructor TMiddlewareContextEvent.Create(const ACallback: TContextEventCallback);
begin
  FContextEventCallback := ACallback;
end;

function TMiddlewareContextEvent.ExecuteContextEventCallback(
  const AResource: String): TContextEventList;
begin
  Result := FContextEventCallback(AResource);
end;

end.
