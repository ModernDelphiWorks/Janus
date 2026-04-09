unit TestPluginIntegration;

interface

uses
  SysUtils,
  Rtti,
  Generics.Collections,
  DUnitX.TestFramework,
  Janus.Register.Middleware,
  Janus.Plugin.Interfaces,
  Janus.Plugin.Registry,
  Janus.Before.Insert.Middleware,
  Janus.Before.Update.Middleware,
  Janus.Before.Delete.Middleware,
  Janus.Events.Middleware;

type
  TAbortingPlugin = class(TInterfacedObject, IJanusPlugin)
  private
    FPluginInfo: IJanusPluginInfo;
    FEnabled: Boolean;
    FAbortOperation: TJanusEventType;
  public
    constructor Create(const APluginId, APluginName, AVersion: String;
      const AAbortOperation: TJanusEventType);
    procedure Init;
    procedure Finalize;
    function GetPluginInfo: IJanusPluginInfo;
    function GetEnabled: Boolean;
    procedure SetEnabled(const AValue: Boolean);
    property Enabled: Boolean read GetEnabled write SetEnabled;
    property AbortOperation: TJanusEventType read FAbortOperation;
  end;

  [TestFixture]
  TTestPluginIntegration = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure TestPlugin_AbortInsert_PreventsExecution;
    [Test]
    procedure TestPlugin_AbortUpdate_PreventsExecution;
    [Test]
    procedure TestPlugin_AbortDelete_PreventsExecution;
    [Test]
    procedure TestPlugin_PriorityOrder_AbortStopsLater;
    [Test]
    procedure TestPlugin_CustomEvent_WithEntityContext;
    [Test]
    procedure TestPlugin_DisabledAtRuntime_NotInvoked;
  end;

implementation

{ TAbortingPlugin }

constructor TAbortingPlugin.Create(const APluginId, APluginName, AVersion: String;
  const AAbortOperation: TJanusEventType);
begin
  FPluginInfo := TJanusPluginInfo.Create(APluginId, APluginName, AVersion);
  FEnabled := True;
  FAbortOperation := AAbortOperation;
end;

procedure TAbortingPlugin.Init;
begin
end;

procedure TAbortingPlugin.Finalize;
begin
end;

function TAbortingPlugin.GetPluginInfo: IJanusPluginInfo;
begin
  Result := FPluginInfo;
end;

function TAbortingPlugin.GetEnabled: Boolean;
begin
  Result := FEnabled;
end;

procedure TAbortingPlugin.SetEnabled(const AValue: Boolean);
begin
  FEnabled := AValue;
end;

{ TTestPluginIntegration }

procedure TTestPluginIntegration.Setup;
begin
  TPluginRegistry.Clear;
end;

procedure TTestPluginIntegration.TearDown;
begin
  TPluginRegistry.Clear;
end;

procedure TTestPluginIntegration.TestPlugin_AbortInsert_PreventsExecution;
var
  LInsertExecuted: Boolean;
  LContext: IJanusHookContext;
  LEntity: TObject;
  LEvents: TContextEventList;
  LEntry: TContextEventEntry;
begin
  LInsertExecuted := False;

  // Register a plugin that aborts insert
  BeforeInsertMiddleware.AddEvent('TPLUGINABORTINSERT',
    procedure(const AContext: IJanusHookContext)
    begin
      AContext.Abort;
    end, 50);

  // Register a callback that simulates the insert execution
  BeforeInsertMiddleware.AddEvent('TPLUGINABORTINSERT',
    procedure(const AContext: IJanusHookContext)
    begin
      LInsertExecuted := True;
    end, 100);

  LEntity := TObject.Create;
  try
    LContext := TJanusHookContext.Create(onBeforeInsert, LEntity.ClassType,
      LEntity, False);
    LEvents := TBeforeInsertMiddleware.GetContextEvents('TPLUGINABORTINSERT');
    Assert.IsNotNull(LEvents);
    for LEntry in LEvents do
    begin
      if LContext.Aborted then
        Break;
      LEntry.Callback(LContext);
    end;

    Assert.IsTrue(LContext.Aborted);
    Assert.IsFalse(LInsertExecuted);
  finally
    LEntity.Free;
  end;
end;

procedure TTestPluginIntegration.TestPlugin_AbortUpdate_PreventsExecution;
var
  LUpdateExecuted: Boolean;
  LContext: IJanusHookContext;
  LEntity: TObject;
  LEvents: TContextEventList;
  LEntry: TContextEventEntry;
begin
  LUpdateExecuted := False;

  BeforeUpdateMiddleware.AddEvent('TPLUGINABORTUPDATE',
    procedure(const AContext: IJanusHookContext)
    begin
      AContext.Abort;
    end, 50);

  BeforeUpdateMiddleware.AddEvent('TPLUGINABORTUPDATE',
    procedure(const AContext: IJanusHookContext)
    begin
      LUpdateExecuted := True;
    end, 100);

  LEntity := TObject.Create;
  try
    LContext := TJanusHookContext.Create(onBeforeUpdate, LEntity.ClassType,
      LEntity, False);
    LEvents := TBeforeUpdateMiddleware.GetContextEvents('TPLUGINABORTUPDATE');
    Assert.IsNotNull(LEvents);
    for LEntry in LEvents do
    begin
      if LContext.Aborted then
        Break;
      LEntry.Callback(LContext);
    end;

    Assert.IsTrue(LContext.Aborted);
    Assert.IsFalse(LUpdateExecuted);
  finally
    LEntity.Free;
  end;
end;

procedure TTestPluginIntegration.TestPlugin_AbortDelete_PreventsExecution;
var
  LDeleteExecuted: Boolean;
  LContext: IJanusHookContext;
  LEntity: TObject;
  LEvents: TContextEventList;
  LEntry: TContextEventEntry;
begin
  LDeleteExecuted := False;

  BeforeDeleteMiddleware.AddEvent('TPLUGINABORTDELETE',
    procedure(const AContext: IJanusHookContext)
    begin
      AContext.Abort;
    end, 50);

  BeforeDeleteMiddleware.AddEvent('TPLUGINABORTDELETE',
    procedure(const AContext: IJanusHookContext)
    begin
      LDeleteExecuted := True;
    end, 100);

  LEntity := TObject.Create;
  try
    LContext := TJanusHookContext.Create(onBeforeDelete, LEntity.ClassType,
      LEntity, False);
    LEvents := TBeforeDeleteMiddleware.GetContextEvents('TPLUGINABORTDELETE');
    Assert.IsNotNull(LEvents);
    for LEntry in LEvents do
    begin
      if LContext.Aborted then
        Break;
      LEntry.Callback(LContext);
    end;

    Assert.IsTrue(LContext.Aborted);
    Assert.IsFalse(LDeleteExecuted);
  finally
    LEntity.Free;
  end;
end;

procedure TTestPluginIntegration.TestPlugin_PriorityOrder_AbortStopsLater;
var
  LLog: TList<Integer>;
  LContext: IJanusHookContext;
  LEntity: TObject;
  LEvents: TContextEventList;
  LEntry: TContextEventEntry;
begin
  LLog := TList<Integer>.Create;
  try
    // Priority 10 — runs first
    BeforeInsertMiddleware.AddEvent('TPLUGINPRIORITY',
      procedure(const AContext: IJanusHookContext)
      begin
        LLog.Add(10);
      end, 10);

    // Priority 50 — runs second and aborts
    BeforeInsertMiddleware.AddEvent('TPLUGINPRIORITY',
      procedure(const AContext: IJanusHookContext)
      begin
        LLog.Add(50);
        AContext.Abort;
      end, 50);

    // Priority 200 — should NOT run (aborted)
    BeforeInsertMiddleware.AddEvent('TPLUGINPRIORITY',
      procedure(const AContext: IJanusHookContext)
      begin
        LLog.Add(200);
      end, 200);

    LEntity := TObject.Create;
    try
      LContext := TJanusHookContext.Create(onBeforeInsert, LEntity.ClassType,
        LEntity, False);
      LEvents := TBeforeInsertMiddleware.GetContextEvents('TPLUGINPRIORITY');
      Assert.IsNotNull(LEvents);
      for LEntry in LEvents do
      begin
        if LContext.Aborted then
          Break;
        LEntry.Callback(LContext);
      end;

      Assert.AreEqual(2, LLog.Count);
      Assert.AreEqual(10, LLog[0]);
      Assert.AreEqual(50, LLog[1]);
      Assert.IsTrue(LContext.Aborted);
    finally
      LEntity.Free;
    end;
  finally
    LLog.Free;
  end;
end;

procedure TTestPluginIntegration.TestPlugin_CustomEvent_WithEntityContext;
var
  LCapturedClass: TClass;
  LCapturedEntity: TObject;
  LContext: IJanusHookContext;
  LEntity: TObject;
begin
  LCapturedClass := nil;
  LCapturedEntity := nil;

  TJanusMiddlewares.RegisterCustomEvent('OnPreValidateIntegration',
    procedure(const AContext: IJanusHookContext)
    begin
      LCapturedClass := AContext.EntityClass;
      LCapturedEntity := AContext.Entity;
    end, 100);

  LEntity := TObject.Create;
  try
    LContext := TJanusHookContext.Create(onCustom, LEntity.ClassType,
      LEntity, False);
    TJanusMiddlewares.ExecuteCustomEvent('OnPreValidateIntegration', LContext);

    Assert.AreEqual(TObject, LCapturedClass);
    Assert.AreSame(LEntity, LCapturedEntity);
  finally
    LEntity.Free;
  end;
end;

procedure TTestPluginIntegration.TestPlugin_DisabledAtRuntime_NotInvoked;
var
  LPlugin: IJanusPlugin;
  LEnabled: TArray<IJanusPlugin>;
begin
  LPlugin := TAbortingPlugin.Create('integ.disabled', 'Disabled Plugin',
    '1.0.0', onBeforeInsert);
  TPluginRegistry.Register(LPlugin);

  LEnabled := TPluginRegistry.GetEnabled;
  Assert.AreEqual(1, Length(LEnabled));

  // Disable at runtime
  TPluginRegistry.Disable('integ.disabled');
  LEnabled := TPluginRegistry.GetEnabled;
  Assert.AreEqual(0, Length(LEnabled));
  Assert.IsFalse(LPlugin.Enabled);

  // Re-enable and verify
  TPluginRegistry.Enable('integ.disabled');
  LEnabled := TPluginRegistry.GetEnabled;
  Assert.AreEqual(1, Length(LEnabled));
  Assert.IsTrue(LPlugin.Enabled);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestPluginIntegration);

end.
