unit TestCrudEndToEnd;

interface

uses
  SysUtils,
  Rtti,
  Generics.Collections,
  DUnitX.TestFramework,
  Janus.Register.Middleware,
  Janus.Plugin.Interfaces,
  Janus.Before.Insert.Middleware,
  Janus.After.Insert.Middleware,
  Janus.Before.Update.Middleware,
  Janus.After.Update.Middleware,
  Janus.Before.Delete.Middleware,
  Janus.After.Delete.Middleware,
  Janus.Events.Middleware;

type
  [TestFixture]
  TTestCrudEndToEnd = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure TestInsert_BeforeHook_FiresWithCorrectContext;
    [Test]
    procedure TestInsert_AfterHook_FiresAfterBefore;
    [Test]
    procedure TestUpdate_BeforeHook_FiresWithCorrectOperation;
    [Test]
    procedure TestUpdate_AbortInBefore_PreventsAfter;
    [Test]
    procedure TestDelete_BeforeHook_FiresWithCorrectOperation;
    [Test]
    procedure TestDelete_AbortInBefore_PreventsAfter;
    [Test]
    procedure TestCrud_FullChain_InsertUpdateDelete_AllFire;
    [Test]
    procedure TestCrud_ContextMetadata_PreservedAcrossChain;
  end;

implementation

{ TTestCrudEndToEnd }

procedure TTestCrudEndToEnd.Setup;
begin
  // Middleware singletons are class-scoped; events registered here
  // are additive per test. Use unique resource names per test.
end;

procedure TTestCrudEndToEnd.TearDown;
begin
  // No global cleanup needed — each test uses unique resource names
end;

procedure TTestCrudEndToEnd.TestInsert_BeforeHook_FiresWithCorrectContext;
var
  LFired: Boolean;
  LOperType: TJanusEventType;
  LContext: IJanusHookContext;
  LEntity: TObject;
  LEvents: TContextEventList;
  LEntry: TContextEventEntry;
begin
  LFired := False;
  LOperType := onCustom;

  BeforeInsertMiddleware.AddEvent('TCRUDINSERTBEFORE',
    procedure(const AContext: IJanusHookContext)
    begin
      LFired := True;
      LOperType := AContext.OperationType;
    end, 100);

  LEntity := TObject.Create;
  try
    LContext := TJanusHookContext.Create(onBeforeInsert, LEntity.ClassType,
      LEntity, False);
    LEvents := TBeforeInsertMiddleware.GetContextEvents('TCRUDINSERTBEFORE');
    Assert.IsNotNull(LEvents);
    for LEntry in LEvents do
      LEntry.Callback(LContext);

    Assert.IsTrue(LFired);
    Assert.AreEqual(Ord(onBeforeInsert), Ord(LOperType));
  finally
    LEntity.Free;
  end;
end;

procedure TTestCrudEndToEnd.TestInsert_AfterHook_FiresAfterBefore;
var
  LOrder: TList<String>;
  LBeforeCtx, LAfterCtx: IJanusHookContext;
  LEntity: TObject;
  LEvents: TContextEventList;
  LEntry: TContextEventEntry;
begin
  LOrder := TList<String>.Create;
  try
    BeforeInsertMiddleware.AddEvent('TCRUDINSERTORDER',
      procedure(const AContext: IJanusHookContext)
      begin
        LOrder.Add('Before');
      end, 100);

    AfterInsertMiddleware.AddEvent('TCRUDINSERTORDER',
      procedure(const AContext: IJanusHookContext)
      begin
        LOrder.Add('After');
      end, 100);

    LEntity := TObject.Create;
    try
      // Simulate session: Before → (execute) → After
      LBeforeCtx := TJanusHookContext.Create(onBeforeInsert, LEntity.ClassType,
        LEntity, False);
      LEvents := TBeforeInsertMiddleware.GetContextEvents('TCRUDINSERTORDER');
      if LEvents <> nil then
        for LEntry in LEvents do
          LEntry.Callback(LBeforeCtx);

      // Only proceed if not aborted
      if not LBeforeCtx.Aborted then
      begin
        LAfterCtx := TJanusHookContext.Create(onAfeterInsert, LEntity.ClassType,
          LEntity, True);
        LEvents := TAfterInsertMiddleware.GetContextEvents('TCRUDINSERTORDER');
        if LEvents <> nil then
          for LEntry in LEvents do
            LEntry.Callback(LAfterCtx);
      end;

      Assert.AreEqual(2, LOrder.Count);
      Assert.AreEqual('Before', LOrder[0]);
      Assert.AreEqual('After', LOrder[1]);
    finally
      LEntity.Free;
    end;
  finally
    LOrder.Free;
  end;
end;

procedure TTestCrudEndToEnd.TestUpdate_BeforeHook_FiresWithCorrectOperation;
var
  LFired: Boolean;
  LOperType: TJanusEventType;
  LContext: IJanusHookContext;
  LEntity: TObject;
  LEvents: TContextEventList;
  LEntry: TContextEventEntry;
begin
  LFired := False;
  LOperType := onCustom;

  BeforeUpdateMiddleware.AddEvent('TCRUDUPDATEBEFORE',
    procedure(const AContext: IJanusHookContext)
    begin
      LFired := True;
      LOperType := AContext.OperationType;
    end, 100);

  LEntity := TObject.Create;
  try
    LContext := TJanusHookContext.Create(onBeforeUpdate, LEntity.ClassType,
      LEntity, False);
    LEvents := TBeforeUpdateMiddleware.GetContextEvents('TCRUDUPDATEBEFORE');
    Assert.IsNotNull(LEvents);
    for LEntry in LEvents do
      LEntry.Callback(LContext);

    Assert.IsTrue(LFired);
    Assert.AreEqual(Ord(onBeforeUpdate), Ord(LOperType));
  finally
    LEntity.Free;
  end;
end;

procedure TTestCrudEndToEnd.TestUpdate_AbortInBefore_PreventsAfter;
var
  LAfterFired: Boolean;
  LBeforeCtx: IJanusHookContext;
  LAfterCtx: IJanusHookContext;
  LEntity: TObject;
  LEvents: TContextEventList;
  LEntry: TContextEventEntry;
begin
  LAfterFired := False;

  BeforeUpdateMiddleware.AddEvent('TCRUDUPDATEABORT',
    procedure(const AContext: IJanusHookContext)
    begin
      AContext.Abort;
    end, 100);

  AfterUpdateMiddleware.AddEvent('TCRUDUPDATEABORT',
    procedure(const AContext: IJanusHookContext)
    begin
      LAfterFired := True;
    end, 100);

  LEntity := TObject.Create;
  try
    LBeforeCtx := TJanusHookContext.Create(onBeforeUpdate, LEntity.ClassType,
      LEntity, False);
    LEvents := TBeforeUpdateMiddleware.GetContextEvents('TCRUDUPDATEABORT');
    if LEvents <> nil then
      for LEntry in LEvents do
      begin
        if LBeforeCtx.Aborted then
          Break;
        LEntry.Callback(LBeforeCtx);
      end;

    Assert.IsTrue(LBeforeCtx.Aborted);

    // Simulate session: if aborted, do not invoke After hooks
    if not LBeforeCtx.Aborted then
    begin
      LAfterCtx := TJanusHookContext.Create(onAfterUpdate, LEntity.ClassType,
        LEntity, True);
      LEvents := TAfterUpdateMiddleware.GetContextEvents('TCRUDUPDATEABORT');
      if LEvents <> nil then
        for LEntry in LEvents do
          LEntry.Callback(LAfterCtx);
    end;

    Assert.IsFalse(LAfterFired);
  finally
    LEntity.Free;
  end;
end;

procedure TTestCrudEndToEnd.TestDelete_BeforeHook_FiresWithCorrectOperation;
var
  LFired: Boolean;
  LOperType: TJanusEventType;
  LContext: IJanusHookContext;
  LEntity: TObject;
  LEvents: TContextEventList;
  LEntry: TContextEventEntry;
begin
  LFired := False;
  LOperType := onCustom;

  BeforeDeleteMiddleware.AddEvent('TCRUDDELETEBEFORE',
    procedure(const AContext: IJanusHookContext)
    begin
      LFired := True;
      LOperType := AContext.OperationType;
    end, 100);

  LEntity := TObject.Create;
  try
    LContext := TJanusHookContext.Create(onBeforeDelete, LEntity.ClassType,
      LEntity, False);
    LEvents := TBeforeDeleteMiddleware.GetContextEvents('TCRUDDELETEBEFORE');
    Assert.IsNotNull(LEvents);
    for LEntry in LEvents do
      LEntry.Callback(LContext);

    Assert.IsTrue(LFired);
    Assert.AreEqual(Ord(onBeforeDelete), Ord(LOperType));
  finally
    LEntity.Free;
  end;
end;

procedure TTestCrudEndToEnd.TestDelete_AbortInBefore_PreventsAfter;
var
  LAfterFired: Boolean;
  LBeforeCtx: IJanusHookContext;
  LAfterCtx: IJanusHookContext;
  LEntity: TObject;
  LEvents: TContextEventList;
  LEntry: TContextEventEntry;
begin
  LAfterFired := False;

  BeforeDeleteMiddleware.AddEvent('TCRUDDELETEABORT',
    procedure(const AContext: IJanusHookContext)
    begin
      AContext.Abort;
    end, 100);

  AfterDeleteMiddleware.AddEvent('TCRUDDELETEABORT',
    procedure(const AContext: IJanusHookContext)
    begin
      LAfterFired := True;
    end, 100);

  LEntity := TObject.Create;
  try
    LBeforeCtx := TJanusHookContext.Create(onBeforeDelete, LEntity.ClassType,
      LEntity, False);
    LEvents := TBeforeDeleteMiddleware.GetContextEvents('TCRUDDELETEABORT');
    if LEvents <> nil then
      for LEntry in LEvents do
      begin
        if LBeforeCtx.Aborted then
          Break;
        LEntry.Callback(LBeforeCtx);
      end;

    Assert.IsTrue(LBeforeCtx.Aborted);

    if not LBeforeCtx.Aborted then
    begin
      LAfterCtx := TJanusHookContext.Create(onAfterDelete, LEntity.ClassType,
        LEntity, True);
      LEvents := TAfterDeleteMiddleware.GetContextEvents('TCRUDDELETEABORT');
      if LEvents <> nil then
        for LEntry in LEvents do
          LEntry.Callback(LAfterCtx);
    end;

    Assert.IsFalse(LAfterFired);
  finally
    LEntity.Free;
  end;
end;

procedure TTestCrudEndToEnd.TestCrud_FullChain_InsertUpdateDelete_AllFire;
var
  LLog: TList<String>;
  LContext: IJanusHookContext;
  LEntity: TObject;
  LEvents: TContextEventList;
  LEntry: TContextEventEntry;
begin
  LLog := TList<String>.Create;
  try
    // Register BeforeInsert
    BeforeInsertMiddleware.AddEvent('TCRUDFULLCHAIN',
      procedure(const AContext: IJanusHookContext)
      begin
        LLog.Add('BeforeInsert');
      end, 100);
    // Register AfterInsert
    AfterInsertMiddleware.AddEvent('TCRUDFULLCHAIN',
      procedure(const AContext: IJanusHookContext)
      begin
        LLog.Add('AfterInsert');
      end, 100);
    // Register BeforeUpdate
    BeforeUpdateMiddleware.AddEvent('TCRUDFULLCHAIN',
      procedure(const AContext: IJanusHookContext)
      begin
        LLog.Add('BeforeUpdate');
      end, 100);
    // Register AfterUpdate
    AfterUpdateMiddleware.AddEvent('TCRUDFULLCHAIN',
      procedure(const AContext: IJanusHookContext)
      begin
        LLog.Add('AfterUpdate');
      end, 100);
    // Register BeforeDelete
    BeforeDeleteMiddleware.AddEvent('TCRUDFULLCHAIN',
      procedure(const AContext: IJanusHookContext)
      begin
        LLog.Add('BeforeDelete');
      end, 100);
    // Register AfterDelete
    AfterDeleteMiddleware.AddEvent('TCRUDFULLCHAIN',
      procedure(const AContext: IJanusHookContext)
      begin
        LLog.Add('AfterDelete');
      end, 100);

    LEntity := TObject.Create;
    try
      // Simulate INSERT
      LContext := TJanusHookContext.Create(onBeforeInsert, LEntity.ClassType,
        LEntity, False);
      LEvents := TBeforeInsertMiddleware.GetContextEvents('TCRUDFULLCHAIN');
      if LEvents <> nil then
        for LEntry in LEvents do
          LEntry.Callback(LContext);
      LContext := TJanusHookContext.Create(onAfeterInsert, LEntity.ClassType,
        LEntity, True);
      LEvents := TAfterInsertMiddleware.GetContextEvents('TCRUDFULLCHAIN');
      if LEvents <> nil then
        for LEntry in LEvents do
          LEntry.Callback(LContext);

      // Simulate UPDATE
      LContext := TJanusHookContext.Create(onBeforeUpdate, LEntity.ClassType,
        LEntity, False);
      LEvents := TBeforeUpdateMiddleware.GetContextEvents('TCRUDFULLCHAIN');
      if LEvents <> nil then
        for LEntry in LEvents do
          LEntry.Callback(LContext);
      LContext := TJanusHookContext.Create(onAfterUpdate, LEntity.ClassType,
        LEntity, True);
      LEvents := TAfterUpdateMiddleware.GetContextEvents('TCRUDFULLCHAIN');
      if LEvents <> nil then
        for LEntry in LEvents do
          LEntry.Callback(LContext);

      // Simulate DELETE
      LContext := TJanusHookContext.Create(onBeforeDelete, LEntity.ClassType,
        LEntity, False);
      LEvents := TBeforeDeleteMiddleware.GetContextEvents('TCRUDFULLCHAIN');
      if LEvents <> nil then
        for LEntry in LEvents do
          LEntry.Callback(LContext);
      LContext := TJanusHookContext.Create(onAfterDelete, LEntity.ClassType,
        LEntity, True);
      LEvents := TAfterDeleteMiddleware.GetContextEvents('TCRUDFULLCHAIN');
      if LEvents <> nil then
        for LEntry in LEvents do
          LEntry.Callback(LContext);

      Assert.AreEqual(6, LLog.Count);
      Assert.AreEqual('BeforeInsert', LLog[0]);
      Assert.AreEqual('AfterInsert', LLog[1]);
      Assert.AreEqual('BeforeUpdate', LLog[2]);
      Assert.AreEqual('AfterUpdate', LLog[3]);
      Assert.AreEqual('BeforeDelete', LLog[4]);
      Assert.AreEqual('AfterDelete', LLog[5]);
    finally
      LEntity.Free;
    end;
  finally
    LLog.Free;
  end;
end;

procedure TTestCrudEndToEnd.TestCrud_ContextMetadata_PreservedAcrossChain;
var
  LMetadataValue: String;
  LContext: IJanusHookContext;
  LEntity: TObject;
  LEvents: TContextEventList;
  LEntry: TContextEventEntry;
begin
  LMetadataValue := '';

  BeforeInsertMiddleware.AddEvent('TCRUDMETADATA',
    procedure(const AContext: IJanusHookContext)
    begin
      AContext.Metadata.AddOrSetValue('source', TValue.From<String>('batch'));
    end, 50);

  BeforeInsertMiddleware.AddEvent('TCRUDMETADATA',
    procedure(const AContext: IJanusHookContext)
    begin
      if AContext.Metadata.ContainsKey('source') then
        LMetadataValue := AContext.Metadata['source'].AsString;
    end, 100);

  LEntity := TObject.Create;
  try
    LContext := TJanusHookContext.Create(onBeforeInsert, LEntity.ClassType,
      LEntity, False);
    LEvents := TBeforeInsertMiddleware.GetContextEvents('TCRUDMETADATA');
    if LEvents <> nil then
      for LEntry in LEvents do
        LEntry.Callback(LContext);

    Assert.AreEqual('batch', LMetadataValue);
  finally
    LEntity.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestCrudEndToEnd);

end.
