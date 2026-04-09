unit TestLazyProxy;

interface

uses
  DUnitX.TestFramework,
  Rtti,
  SysUtils,
  Generics.Collections,
  Janus.Types.Lazy,
  Janus.Mapping.Lazy,
  MetaDbDiff.Mapping.Classes,
  MetaDbDiff.Mapping.Explorer,
  Model.Exame,
  Model.Procedimento;

type
  [TestFixture]
  TTestLazyProxy = class
  public
    [Test]
    procedure TestProxyLoader_InvokeReturnsObject;
    [Test]
    procedure TestProxyLoader_IsValueCreated;
    [Test]
    procedure TestProxyLoader_CachesResult;
    [Test]
    procedure TestLazyProxy_InvalidSession;
    [Test]
    procedure TestLazyProxy_RecursiveFill;
    [Test]
    procedure TestLazyProxy_SkipReinjection;
    [Test]
    procedure TestInjectLazyAssociationFactory_ReusesExistingProxy;
  end;

implementation

{ TTestLazyProxy }

procedure TTestLazyProxy.TestProxyLoader_InvokeReturnsObject;
var
  LProxy: ILazyProxy;
  LToken: ILazySessionToken;
  LResult: TObject;
begin
  LToken := TLazySessionToken.Create;
  LProxy := TLazyProxyLoader.Create(
    function: TObject
    begin
      Result := TProcedimento.Create;
    end, LToken);
  LResult := LProxy.Invoke;
  Assert.IsNotNull(LResult, 'Proxy Invoke must return a non-nil object');
  Assert.IsTrue(LResult is TProcedimento, 'Returned object must be TProcedimento');
end;

procedure TTestLazyProxy.TestProxyLoader_IsValueCreated;
var
  LProxy: ILazyProxy;
  LToken: ILazySessionToken;
begin
  LToken := TLazySessionToken.Create;
  LProxy := TLazyProxyLoader.Create(
    function: TObject
    begin
      Result := TProcedimento.Create;
    end, LToken);
  Assert.IsFalse(LProxy.IsValueCreated, 'IsValueCreated must be False before Invoke');
  LProxy.Invoke;
  Assert.IsTrue(LProxy.IsValueCreated, 'IsValueCreated must be True after Invoke');
end;

procedure TTestLazyProxy.TestProxyLoader_CachesResult;
var
  LProxy: ILazyProxy;
  LToken: ILazySessionToken;
  LCallCount: Integer;
  LResult1, LResult2: TObject;
begin
  LCallCount := 0;
  LToken := TLazySessionToken.Create;
  LProxy := TLazyProxyLoader.Create(
    function: TObject
    begin
      Inc(LCallCount);
      Result := TProcedimento.Create;
    end, LToken);
  LResult1 := LProxy.Invoke;
  LResult2 := LProxy.Invoke;
  Assert.AreEqual(1, LCallCount, 'Factory must be called only once (cached result)');
  Assert.AreSame(LResult1, LResult2, 'Subsequent calls must return same instance');
end;

procedure TTestLazyProxy.TestLazyProxy_InvalidSession;
var
  LProxy: ILazyProxy;
  LToken: ILazySessionToken;
begin
  LToken := TLazySessionToken.Create;
  LProxy := TLazyProxyLoader.Create(
    function: TObject
    begin
      Result := TProcedimento.Create;
    end, LToken);
  // Invalidate the token (simulates session destruction)
  LToken.Invalidate;
  Assert.WillRaise(
    procedure
    begin
      LProxy.Invoke;
    end,
    ELazyLoadException,
    'Invoke on invalid session must raise ELazyLoadException');
end;

procedure TTestLazyProxy.TestLazyProxy_RecursiveFill;
var
  LProxy: ILazyProxy;
  LToken: ILazySessionToken;
  LChild: TObject;
  LFillCalled: Boolean;
begin
  LToken := TLazySessionToken.Create;
  LFillCalled := False;
  LProxy := TLazyProxyLoader.Create(
    function: TObject
    begin
      Result := TExame.Create;
      LFillCalled := True;
    end, LToken);
  LChild := LProxy.Invoke;
  Assert.IsNotNull(LChild, 'Child object must be created via proxy');
  Assert.IsTrue(LChild is TExame, 'Child must be TExame');
  Assert.IsTrue(LFillCalled, 'Load function must have executed (sub-associations would be filled)');
end;

procedure TTestLazyProxy.TestLazyProxy_SkipReinjection;
var
  LProxy: ILazyProxy;
  LResettable: ILazyProxyResettable;
  LToken: ILazySessionToken;
  LCallCount: Integer;
  LResult1, LResult2: TObject;
begin
  LCallCount := 0;
  LToken := TLazySessionToken.Create;
  LProxy := TLazyProxyLoader.Create(
    function: TObject
    begin
      Inc(LCallCount);
      Result := TProcedimento.Create;
    end, LToken);
  // First invoke
  LResult1 := LProxy.Invoke;
  Assert.AreEqual(1, LCallCount, 'First invoke must call factory once');
  Assert.IsTrue(LProxy.IsValueCreated, 'Value must be created after first invoke');
  // Reset the proxy (simulates re-injection on scroll)
  Assert.IsTrue(Supports(LProxy, ILazyProxyResettable, LResettable),
    'Proxy must support ILazyProxyResettable');
  LResettable.Reset(
    function: TObject
    begin
      Inc(LCallCount);
      Result := TExame.Create;
    end, LToken);
  Assert.IsFalse(LProxy.IsValueCreated, 'After Reset, IsValueCreated must be False');
  // Second invoke after Reset
  LResult2 := LProxy.Invoke;
  Assert.AreEqual(2, LCallCount, 'After Reset, new load function must be called');
  Assert.IsTrue(LResult2 is TExame, 'After Reset, new type must be returned');
end;

procedure TTestLazyProxy.TestInjectLazyAssociationFactory_ReusesExistingProxy;
var
  LExame: TExame;
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LFirstCallCount: Integer;
  LSecondCallCount: Integer;
  LToken: ILazySessionToken;
begin
  LExame := TExame.Create;
  try
    LAssociations := TMappingExplorer.GetMappingAssociation(TExame);
    Assert.IsNotNull(LAssociations, 'TExame must expose lazy associations for injection');

    LAssociation := nil;
    for LAssociation in LAssociations do
    begin
      if LAssociation.Lazy then
        Break;
    end;
    Assert.IsNotNull(LAssociation, 'A lazy association must exist for the shared injector helper');

    LFirstCallCount := 0;
    LSecondCallCount := 0;
    LToken := TLazySessionToken.Create;

    InjectLazyAssociationFactory(
      LExame,
      LAssociation,
      LToken,
      function: TObject
      begin
        Inc(LFirstCallCount);
        Result := TProcedimento.Create;
      end);

    InjectLazyAssociationFactory(
      LExame,
      LAssociation,
      LToken,
      function: TObject
      begin
        Inc(LSecondCallCount);
        Result := TProcedimento.Create;
      end);

    Assert.AreEqual(0, LFirstCallCount,
      'Injection must stay deferred before the first property access');
    Assert.AreEqual(0, LSecondCallCount,
      'Resetting the existing proxy must also stay deferred before access');

    Assert.IsNotNull(LExame.Procedimento,
      'The injected helper must keep the lazy property accessible on demand');
    Assert.AreEqual(0, LFirstCallCount,
      'The first proxy load func must be replaced by Reset before invocation');
    Assert.AreEqual(1, LSecondCallCount,
      'The shared helper must reuse the existing proxy and invoke only the latest load func');
  finally
    LExame.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestLazyProxy);

end.
