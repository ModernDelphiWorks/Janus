unit TestPluginRegistry;

interface

uses
  SysUtils,
  Rtti,
  Generics.Collections,
  DUnitX.TestFramework,
  Janus.Register.Middleware,
  Janus.Plugin.Interfaces,
  Janus.Plugin.Registry;

type
  TMockPlugin = class(TInterfacedObject, IJanusPlugin)
  private
    FPluginInfo: IJanusPluginInfo;
    FEnabled: Boolean;
    FInitCalled: Boolean;
    FFinalizeCalled: Boolean;
  public
    constructor Create(const APluginId, APluginName, AVersion: String);
    procedure Init;
    procedure Finalize;
    function GetPluginInfo: IJanusPluginInfo;
    function GetEnabled: Boolean;
    procedure SetEnabled(const AValue: Boolean);
    property Enabled: Boolean read GetEnabled write SetEnabled;
    property InitCalled: Boolean read FInitCalled;
    property FinalizeCalled: Boolean read FFinalizeCalled;
  end;

  [TestFixture]
  TTestPluginRegistry = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure TestPluginRegisterAndRetrieve;
    [Test]
    procedure TestPluginEnableDisable;
    [Test]
    procedure TestHookContextCarriesOperation;
    [Test]
    procedure TestHookContextCarriesEntity;
    [Test]
    procedure TestBeforeHookAbort;
    [Test]
    procedure TestAfterHookAbortRaises;
    [Test]
    procedure TestHookPriorityOrder;
    [Test]
    procedure TestCustomEventRegistration;
    [Test]
    procedure TestLegacyMiddlewareStillWorks;
    [Test]
    procedure TestDisabledPluginSkipped;
  end;

implementation

uses
  Janus.Before.Insert.Middleware,
  Janus.Events.Middleware;

{ TMockPlugin }

constructor TMockPlugin.Create(const APluginId, APluginName, AVersion: String);
begin
  FPluginInfo := TJanusPluginInfo.Create(APluginId, APluginName, AVersion);
  FEnabled := True;
  FInitCalled := False;
  FFinalizeCalled := False;
end;

procedure TMockPlugin.Init;
begin
  FInitCalled := True;
end;

procedure TMockPlugin.Finalize;
begin
  FFinalizeCalled := True;
end;

function TMockPlugin.GetPluginInfo: IJanusPluginInfo;
begin
  Result := FPluginInfo;
end;

function TMockPlugin.GetEnabled: Boolean;
begin
  Result := FEnabled;
end;

procedure TMockPlugin.SetEnabled(const AValue: Boolean);
begin
  FEnabled := AValue;
end;

{ TTestPluginRegistry }

procedure TTestPluginRegistry.Setup;
begin
  TPluginRegistry.Clear;
end;

procedure TTestPluginRegistry.TearDown;
begin
  TPluginRegistry.Clear;
end;

procedure TTestPluginRegistry.TestPluginRegisterAndRetrieve;
var
  LPlugin: IJanusPlugin;
  LRetrieved: IJanusPlugin;
begin
  LPlugin := TMockPlugin.Create('test.plugin.1', 'Test Plugin', '1.0.0');
  TPluginRegistry.Register(LPlugin);
  LRetrieved := TPluginRegistry.GetPlugin('test.plugin.1');
  Assert.IsNotNull(LRetrieved);
  Assert.AreEqual('test.plugin.1', LRetrieved.GetPluginInfo.PluginId);
  Assert.AreEqual('Test Plugin', LRetrieved.GetPluginInfo.PluginName);
  Assert.IsTrue((LPlugin as TMockPlugin).InitCalled);
end;

procedure TTestPluginRegistry.TestPluginEnableDisable;
var
  LPlugin: IJanusPlugin;
  LEnabled: TArray<IJanusPlugin>;
begin
  LPlugin := TMockPlugin.Create('test.plugin.2', 'Test Plugin 2', '1.0.0');
  TPluginRegistry.Register(LPlugin);

  LEnabled := TPluginRegistry.GetEnabled;
  Assert.AreEqual(1, Length(LEnabled));

  TPluginRegistry.Disable('test.plugin.2');
  Assert.IsFalse(LPlugin.Enabled);

  LEnabled := TPluginRegistry.GetEnabled;
  Assert.AreEqual(0, Length(LEnabled));

  TPluginRegistry.Enable('test.plugin.2');
  Assert.IsTrue(LPlugin.Enabled);

  LEnabled := TPluginRegistry.GetEnabled;
  Assert.AreEqual(1, Length(LEnabled));
end;

procedure TTestPluginRegistry.TestHookContextCarriesOperation;
var
  LContext: IJanusHookContext;
begin
  LContext := TJanusHookContext.Create(onBeforeInsert, TObject, nil, False);
  Assert.AreEqual(Ord(onBeforeInsert), Ord(LContext.OperationType));

  LContext := TJanusHookContext.Create(onBeforeUpdate, TObject, nil, False);
  Assert.AreEqual(Ord(onBeforeUpdate), Ord(LContext.OperationType));

  LContext := TJanusHookContext.Create(onBeforeDelete, TObject, nil, False);
  Assert.AreEqual(Ord(onBeforeDelete), Ord(LContext.OperationType));
end;

procedure TTestPluginRegistry.TestHookContextCarriesEntity;
var
  LEntity: TObject;
  LContext: IJanusHookContext;
begin
  LEntity := TObject.Create;
  try
    LContext := TJanusHookContext.Create(onBeforeInsert, LEntity.ClassType,
      LEntity, False);
    Assert.AreEqual(TObject, LContext.EntityClass);
    Assert.AreSame(LEntity, LContext.Entity);
    Assert.IsNotNull(LContext.Metadata);
  finally
    LEntity.Free;
  end;
end;

procedure TTestPluginRegistry.TestBeforeHookAbort;
var
  LContext: IJanusHookContext;
begin
  LContext := TJanusHookContext.Create(onBeforeInsert, TObject, nil, False);
  Assert.IsFalse(LContext.Aborted);
  LContext.Abort;
  Assert.IsTrue(LContext.Aborted);
end;

procedure TTestPluginRegistry.TestAfterHookAbortRaises;
var
  LContext: IJanusHookContext;
begin
  LContext := TJanusHookContext.Create(onAfeterInsert, TObject, nil, True);
  Assert.WillRaise(
    procedure
    begin
      LContext.Abort;
    end,
    EJanusPluginException);
end;

procedure TTestPluginRegistry.TestHookPriorityOrder;
var
  LLog: TList<Integer>;
  LContext: IJanusHookContext;
  LEntry: TContextEventEntry;
  LEvents: TContextEventList;
begin
  LLog := TList<Integer>.Create;
  try
    BeforeInsertMiddleware.AddEvent('TPRIORITYTEST',
      procedure(const AContext: IJanusHookContext)
      begin
        LLog.Add(100);
      end, 100);

    BeforeInsertMiddleware.AddEvent('TPRIORITYTEST',
      procedure(const AContext: IJanusHookContext)
      begin
        LLog.Add(50);
      end, 50);

    BeforeInsertMiddleware.AddEvent('TPRIORITYTEST',
      procedure(const AContext: IJanusHookContext)
      begin
        LLog.Add(200);
      end, 200);

    LEvents := TBeforeInsertMiddleware.GetContextEvents('TPRIORITYTEST');
    Assert.IsNotNull(LEvents);
    Assert.AreEqual(3, LEvents.Count);

    LContext := TJanusHookContext.Create(onBeforeInsert, TObject, nil, False);
    for LEntry in LEvents do
    begin
      if LContext.Aborted then
        Break;
      LEntry.Callback(LContext);
    end;

    Assert.AreEqual(3, LLog.Count);
    Assert.AreEqual(50, LLog[0]);
    Assert.AreEqual(100, LLog[1]);
    Assert.AreEqual(200, LLog[2]);
  finally
    LLog.Free;
  end;
end;

procedure TTestPluginRegistry.TestCustomEventRegistration;
var
  LCalled: Boolean;
  LContext: IJanusHookContext;
begin
  LCalled := False;
  TJanusMiddlewares.RegisterCustomEvent('OnBeforeValidate',
    procedure(const AContext: IJanusHookContext)
    begin
      LCalled := True;
    end);

  LContext := TJanusHookContext.Create(onCustom, TObject, nil, False);
  TJanusMiddlewares.ExecuteCustomEvent('OnBeforeValidate', LContext);
  Assert.IsTrue(LCalled);

  Assert.WillRaise(
    procedure
    begin
      TJanusMiddlewares.RegisterCustomEvent('BeforeInsert',
        procedure(const AContext: IJanusHookContext) begin end);
    end,
    Exception);
end;

procedure TTestPluginRegistry.TestLegacyMiddlewareStillWorks;
var
  LCalled: Boolean;
  LEvent: TEvent;
begin
  LCalled := False;
  BeforeInsertMiddleware.AddEvent('TLEGACYTEST',
    procedure(AObject: TObject)
    begin
      LCalled := True;
    end);

  LEvent := TBeforeInsertMiddleware.GetEvent('TLEGACYTEST');
  Assert.IsNotNull(TObject(@LEvent));
  LEvent(nil);
  Assert.IsTrue(LCalled);
end;

procedure TTestPluginRegistry.TestDisabledPluginSkipped;
var
  LPlugin: IJanusPlugin;
  LAll: TArray<IJanusPlugin>;
  LEnabled: TArray<IJanusPlugin>;
begin
  LPlugin := TMockPlugin.Create('test.disabled', 'Disabled Plugin', '1.0.0');
  TPluginRegistry.Register(LPlugin);
  TPluginRegistry.Disable('test.disabled');

  LAll := TPluginRegistry.GetAll;
  Assert.AreEqual(1, Length(LAll));

  LEnabled := TPluginRegistry.GetEnabled;
  Assert.AreEqual(0, Length(LEnabled));

  Assert.IsFalse(LPlugin.Enabled);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestPluginRegistry);

end.
