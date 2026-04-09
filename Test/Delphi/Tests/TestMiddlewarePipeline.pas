unit TestMiddlewarePipeline;

interface

uses
  SysUtils,
  Rtti,
  Generics.Collections,
  DUnitX.TestFramework,
  Janus.Register.Middleware,
  Janus.Plugin.Interfaces,
  Janus.Before.Update.Middleware,
  Janus.After.Update.Middleware,
  Janus.Before.Delete.Middleware,
  Janus.After.Delete.Middleware,
  Janus.Events.Middleware;

type
  [TestFixture]
  TTestMiddlewarePipeline = class
  public
    [Test]
    procedure TestMiddleware_BeforeUpdate_Fires;
    [Test]
    procedure TestMiddleware_AfterUpdate_Fires;
    [Test]
    procedure TestMiddleware_BeforeDelete_Fires;
    [Test]
    procedure TestMiddleware_AfterDelete_Fires;
    [Test]
    procedure TestMiddleware_ChainOrder_Preserved;
    [Test]
    procedure TestMiddleware_ContextHasCorrectOperation;
  end;

implementation

{ TTestMiddlewarePipeline }

procedure TTestMiddlewarePipeline.TestMiddleware_BeforeUpdate_Fires;
var
  LFired: Boolean;
  LContext: IJanusHookContext;
  LEntity: TObject;
  LEvents: TContextEventList;
  LEntry: TContextEventEntry;
begin
  LFired := False;

  BeforeUpdateMiddleware.AddEvent('TMWBEFOREUPD',
    TContextEvent(procedure(const AContext: IJanusHookContext)
    begin
      LFired := True;
    end), 100);

  LEntity := TObject.Create;
  try
    LContext := TJanusHookContext.Create(onBeforeUpdate, LEntity.ClassType,
      LEntity, False);
    LEvents := TBeforeUpdateMiddleware.GetContextEvents('TMWBEFOREUPD');
    Assert.IsNotNull(LEvents);
    for LEntry in LEvents do
      LEntry.Callback(LContext);

    Assert.IsTrue(LFired);
  finally
    LEntity.Free;
  end;
end;

procedure TTestMiddlewarePipeline.TestMiddleware_AfterUpdate_Fires;
var
  LFired: Boolean;
  LContext: IJanusHookContext;
  LEntity: TObject;
  LEvents: TContextEventList;
  LEntry: TContextEventEntry;
begin
  LFired := False;

  AfterUpdateMiddleware.AddEvent('TMWAFTERUPD',
    TContextEvent(procedure(const AContext: IJanusHookContext)
    begin
      LFired := True;
    end), 100);

  LEntity := TObject.Create;
  try
    LContext := TJanusHookContext.Create(onAfterUpdate, LEntity.ClassType,
      LEntity, True);
    LEvents := TAfterUpdateMiddleware.GetContextEvents('TMWAFTERUPD');
    Assert.IsNotNull(LEvents);
    for LEntry in LEvents do
      LEntry.Callback(LContext);

    Assert.IsTrue(LFired);
  finally
    LEntity.Free;
  end;
end;

procedure TTestMiddlewarePipeline.TestMiddleware_BeforeDelete_Fires;
var
  LFired: Boolean;
  LContext: IJanusHookContext;
  LEntity: TObject;
  LEvents: TContextEventList;
  LEntry: TContextEventEntry;
begin
  LFired := False;

  BeforeDeleteMiddleware.AddEvent('TMWBEFOREDEL',
    TContextEvent(procedure(const AContext: IJanusHookContext)
    begin
      LFired := True;
    end), 100);

  LEntity := TObject.Create;
  try
    LContext := TJanusHookContext.Create(onBeforeDelete, LEntity.ClassType,
      LEntity, False);
    LEvents := TBeforeDeleteMiddleware.GetContextEvents('TMWBEFOREDEL');
    Assert.IsNotNull(LEvents);
    for LEntry in LEvents do
      LEntry.Callback(LContext);

    Assert.IsTrue(LFired);
  finally
    LEntity.Free;
  end;
end;

procedure TTestMiddlewarePipeline.TestMiddleware_AfterDelete_Fires;
var
  LFired: Boolean;
  LContext: IJanusHookContext;
  LEntity: TObject;
  LEvents: TContextEventList;
  LEntry: TContextEventEntry;
begin
  LFired := False;

  AfterDeleteMiddleware.AddEvent('TMWAFTERDEL',
    TContextEvent(procedure(const AContext: IJanusHookContext)
    begin
      LFired := True;
    end), 100);

  LEntity := TObject.Create;
  try
    LContext := TJanusHookContext.Create(onAfterDelete, LEntity.ClassType,
      LEntity, True);
    LEvents := TAfterDeleteMiddleware.GetContextEvents('TMWAFTERDEL');
    Assert.IsNotNull(LEvents);
    for LEntry in LEvents do
      LEntry.Callback(LContext);

    Assert.IsTrue(LFired);
  finally
    LEntity.Free;
  end;
end;

procedure TTestMiddlewarePipeline.TestMiddleware_ChainOrder_Preserved;
var
  LLog: TList<Integer>;
  LContext: IJanusHookContext;
  LEntity: TObject;
  LEvents: TContextEventList;
  LEntry: TContextEventEntry;
begin
  LLog := TList<Integer>.Create;
  try
    BeforeDeleteMiddleware.AddEvent('TMWCHAINORDER',
      TContextEvent(procedure(const AContext: IJanusHookContext)
      begin
        LLog.Add(200);
      end), 200);

    BeforeDeleteMiddleware.AddEvent('TMWCHAINORDER',
      TContextEvent(procedure(const AContext: IJanusHookContext)
      begin
        LLog.Add(10);
      end), 10);

    BeforeDeleteMiddleware.AddEvent('TMWCHAINORDER',
      TContextEvent(procedure(const AContext: IJanusHookContext)
      begin
        LLog.Add(100);
      end), 100);

    LEntity := TObject.Create;
    try
      LContext := TJanusHookContext.Create(onBeforeDelete, LEntity.ClassType,
        LEntity, False);
      LEvents := TBeforeDeleteMiddleware.GetContextEvents('TMWCHAINORDER');
      Assert.IsNotNull(LEvents);
      Assert.AreEqual(3, LEvents.Count);

      for LEntry in LEvents do
        LEntry.Callback(LContext);

      Assert.AreEqual(3, LLog.Count);
      // Priority order: lowest first
      Assert.AreEqual(10, LLog[0]);
      Assert.AreEqual(100, LLog[1]);
      Assert.AreEqual(200, LLog[2]);
    finally
      LEntity.Free;
    end;
  finally
    LLog.Free;
  end;
end;

procedure TTestMiddlewarePipeline.TestMiddleware_ContextHasCorrectOperation;
var
  LCapturedOps: TList<TJanusEventType>;
  LContext: IJanusHookContext;
  LEntity: TObject;
  LEvents: TContextEventList;
  LEntry: TContextEventEntry;
begin
  LCapturedOps := TList<TJanusEventType>.Create;
  try
    BeforeUpdateMiddleware.AddEvent('TMWCONTEXTOP',
      TContextEvent(procedure(const AContext: IJanusHookContext)
      begin
        LCapturedOps.Add(AContext.OperationType);
      end), 100);

    AfterDeleteMiddleware.AddEvent('TMWCONTEXTOP',
      TContextEvent(procedure(const AContext: IJanusHookContext)
      begin
        LCapturedOps.Add(AContext.OperationType);
      end), 100);

    LEntity := TObject.Create;
    try
      // BeforeUpdate context
      LContext := TJanusHookContext.Create(onBeforeUpdate, LEntity.ClassType,
        LEntity, False);
      LEvents := TBeforeUpdateMiddleware.GetContextEvents('TMWCONTEXTOP');
      if LEvents <> nil then
        for LEntry in LEvents do
          LEntry.Callback(LContext);

      // AfterDelete context
      LContext := TJanusHookContext.Create(onAfterDelete, LEntity.ClassType,
        LEntity, True);
      LEvents := TAfterDeleteMiddleware.GetContextEvents('TMWCONTEXTOP');
      if LEvents <> nil then
        for LEntry in LEvents do
          LEntry.Callback(LContext);

      Assert.AreEqual(2, LCapturedOps.Count);
      Assert.AreEqual(Ord(onBeforeUpdate), Ord(LCapturedOps[0]));
      Assert.AreEqual(Ord(onAfterDelete), Ord(LCapturedOps[1]));
    finally
      LEntity.Free;
    end;
  finally
    LCapturedOps.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestMiddlewarePipeline);

end.
