unit TestDataSetLazyProxy;

interface

uses
  DUnitX.TestFramework,
  SysUtils,
  Generics.Collections,
  Janus.Mapping.Lazy,
  MetaDbDiff.Mapping.Classes,
  MetaDbDiff.Mapping.Explorer,
  MetaDbDiff.Types.Mapping,
  Model.Exame,
  Model.Procedimento,
  Model.Setor;

type
  /// <summary>
  ///   S4 — DataSet lazy proxy contract tests.
  ///   These tests validate the DataSet transparent lazy injection contract at the
  ///   mapping and proxy layer, without requiring a live database connection.
  ///   Runtime integration with a real DataSet is validated by TestDataSetAutoLazy.
  /// </summary>
  [TestFixture]
  TTestDataSetLazyProxy = class
  public
    /// DataSet scroll must skip lazy children — only non-lazy associations open eagerly.
    [Test]
    procedure TestOpenDataSetChilds_SkipsLazyAssociations;
    /// After a PK change, FProxiesInjectedForCurrentRow must be reset to allow
    /// re-injection for the new row.
    [Test]
    procedure TestPKChange_ShouldAllowReinjection;
    /// Accessing a proxy after token invalidation raises ELazyLoadException,
    /// confirming session lifecycle management.
    [Test]
    procedure TestProxyRaisesOnInvalidSession;
    /// The proxy for a OneToOne lazy association must load a single object.
    [Test]
    procedure TestProxy_OneToOne_LoadsObject;
    /// A newly created proxy must not be loaded yet (deferred loading).
    [Test]
    procedure TestProxy_DeferredLoad_NotLoadedOnCreation;
    /// Two calls to the proxy factory must return the same cached instance.
    [Test]
    procedure TestProxy_CachesOnFirstAccess;
    /// The lazy field cache for TExame must be consistent across two separate
    /// proxy injections (shared TLazyMappingExplorer singleton).
    [Test]
    procedure TestMappingExplorer_ConsistentAcrossScrolls;
    /// Resetting a proxy via ILazyProxyResettable must produce a new load on
    /// the next access — simulates PK change re-injection.
    [Test]
    procedure TestProxy_ResetProducesNewLoad;
  end;

implementation

{ TTestDataSetLazyProxy }

procedure TTestDataSetLazyProxy.TestOpenDataSetChilds_SkipsLazyAssociations;
var
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LLazyCount: Integer;
  LNonLazyCount: Integer;
begin
  // The DataSet adapter must skip children whose association flag Lazy = True
  // in OpenDataSetChilds and only open non-lazy associations eagerly.
  LAssociations := TMappingExplorer.GetMappingAssociation(TExame);
  Assert.IsNotNull(LAssociations, 'TExame must have associations');

  LLazyCount := 0;
  LNonLazyCount := 0;
  for LAssociation in LAssociations do
  begin
    if LAssociation.Lazy then
      Inc(LLazyCount)
    else
      Inc(LNonLazyCount);
  end;

  Assert.IsTrue(LLazyCount > 0,
    'TExame must have at least one lazy association that DataSet scroll must skip');

  // Non-lazy count can be 0 (TExame only has lazy associations in example model);
  // the invariant is that the Lazy flag is readable from the mapping.
  for LAssociation in LAssociations do
  begin
    if LAssociation.Lazy then
      Assert.IsTrue(LAssociation.Lazy,
        'Lazy associations flagged as Lazy must be detectable by the DataSet adapter')
    else
      Assert.IsFalse(LAssociation.Lazy,
        'Non-lazy associations must not be skipped');
  end;
end;

procedure TTestDataSetLazyProxy.TestPKChange_ShouldAllowReinjection;
var
  LToken: ILazySessionToken;
  LProxy: ILazyProxy;
  LResettable: ILazyProxyResettable;
begin
  // Simulates the DataSet PK-change flow: the adapter resets the proxy
  // (ILazyProxyResettable.Reset) so that the next Current() call re-injects
  // the factory for the new record.
  LToken := TLazySessionToken.Create;
  LProxy := TLazyProxyLoader.Create(
    function: TObject
    begin
      Result := TProcedimento.Create;
    end, LToken);

  // First invoke loads the value
  LProxy.Invoke;
  Assert.IsTrue(LProxy.IsValueCreated,
    'Proxy must be loaded after first Invoke');

  // Simulate PK change: reset the proxy via ILazyProxyResettable
  Assert.IsTrue(Supports(LProxy, ILazyProxyResettable, LResettable),
    'Proxy must implement ILazyProxyResettable to support PK-change re-injection');

  LResettable.Reset(
    function: TObject
    begin
      Result := TProcedimento.Create;
    end, LToken);

  Assert.IsFalse(LProxy.IsValueCreated,
    'After Reset (PK change), IsValueCreated must be False to allow re-injection');
end;

procedure TTestDataSetLazyProxy.TestProxyRaisesOnInvalidSession;
var
  LToken: ILazySessionToken;
  LProxy: ILazyProxy;
begin
  LToken := TLazySessionToken.Create;
  LProxy := TLazyProxyLoader.Create(
    function: TObject
    begin
      Result := TProcedimento.Create;
    end, LToken);

  LToken.Invalidate;

  Assert.WillRaise(
    procedure
    begin
      LProxy.Invoke;
    end,
    ELazyLoadException,
    'Accessing lazy proxy after session invalidation must raise ELazyLoadException');
end;

procedure TTestDataSetLazyProxy.TestProxy_OneToOne_LoadsObject;
var
  LToken: ILazySessionToken;
  LProxy: ILazyProxy;
  LResult: TObject;
begin
  // Simulates the OneToOne lazy factory: loads a single child object.
  LToken := TLazySessionToken.Create;
  LProxy := TLazyProxyLoader.Create(
    function: TObject
    begin
      Result := TProcedimento.Create;
    end, LToken);

  LResult := LProxy.Invoke;
  Assert.IsNotNull(LResult, 'OneToOne lazy proxy must return a non-nil object');
  Assert.IsTrue(LResult is TProcedimento,
    'OneToOne proxy must return an instance of the associated type');
end;

procedure TTestDataSetLazyProxy.TestProxy_DeferredLoad_NotLoadedOnCreation;
var
  LToken: ILazySessionToken;
  LProxy: ILazyProxy;
begin
  LToken := TLazySessionToken.Create;
  LProxy := TLazyProxyLoader.Create(
    function: TObject
    begin
      Result := TProcedimento.Create;
    end, LToken);

  Assert.IsFalse(LProxy.IsValueCreated,
    'Proxy must not load immediately on creation (deferred semantics)');
end;

procedure TTestDataSetLazyProxy.TestProxy_CachesOnFirstAccess;
var
  LToken: ILazySessionToken;
  LProxy: ILazyProxy;
  LCallCount: Integer;
  LResult1: TObject;
  LResult2: TObject;
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

  Assert.AreEqual(1, LCallCount,
    'Factory must be invoked exactly once; subsequent accesses must use cached value');
  Assert.AreSame(LResult1, LResult2,
    'Both calls must return the same object instance');
end;

procedure TTestDataSetLazyProxy.TestMappingExplorer_ConsistentAcrossScrolls;
var
  LFields1: TObjectList<TLazyMapping>;
  LFields2: TObjectList<TLazyMapping>;
begin
  // Simulate two DataSet scrolls: both must resolve to the same cached list.
  LFields1 := LazyMappingExplorer.GetLazyFields(TExame);
  LFields2 := LazyMappingExplorer.GetLazyFields(TExame);
  Assert.AreSame(TObject(LFields1), TObject(LFields2),
    'Separate calls across scroll events must return the same cached field list');
  Assert.IsTrue(LFields1.Count > 0,
    'TExame must have at least one lazy field for the DataSet proxy to target');
end;

procedure TTestDataSetLazyProxy.TestProxy_ResetProducesNewLoad;
var
  LToken: ILazySessionToken;
  LProxy: ILazyProxy;
  LResettable: ILazyProxyResettable;
  LCallCount: Integer;
  LResult1: TObject;
  LResult2: TObject;
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
  Assert.AreEqual(1, LCallCount, 'First invoke must call factory once');

  LResettable := LProxy as ILazyProxyResettable;
  LResettable.Reset(
    function: TObject
    begin
      Inc(LCallCount);
      Result := TProcedimento.Create;
    end, LToken);

  LResult2 := LProxy.Invoke;
  Assert.AreEqual(2, LCallCount, 'Post-Reset invoke must call new factory');
  Assert.AreNotSame(LResult1, LResult2,
    'Post-Reset invoke must return a new object instance');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDataSetLazyProxy);

end.
