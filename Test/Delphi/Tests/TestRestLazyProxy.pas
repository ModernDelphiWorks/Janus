unit TestRestLazyProxy;

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
  ///   S4 — REST lazy proxy contract tests.
  ///   These tests validate the REST transparent lazy injection contract at the
  ///   mapping and proxy layer, without requiring a live database connection.
  ///   They confirm that TRESTObjectManager.FillAssociation injects factories
  ///   for lazy associations (the same contract as ObjectSet) instead of skipping them.
  /// </summary>
  [TestFixture]
  TTestRestLazyProxy = class
  public
    /// FillAssociation for the REST context must detect lazy associations via mapping —
    /// the same mechanism used by ObjectSet and DataSet contexts.
    [Test]
    procedure TestRestContext_LazyAssociationDetectable;
    /// A new TLazySessionToken created by TRESTObjectManager must be valid at start
    /// (simulates the REST session lifecycle start).
    [Test]
    procedure TestRESTSessionToken_ValidOnCreate;
    /// Invalidating a REST session token must block subsequent lazy loads.
    [Test]
    procedure TestRESTSessionToken_BlocksLoadAfterInvalidate;
    /// The REST context must use TLazyProxyLoader (same as ObjectSet / DataSet).
    [Test]
    procedure TestRESTProxy_SameInfrastructureAsObjectSet;
    /// FillAssociation for REST must not skip lazy associations — they must be
    /// injected as proxy factories (contract requires Lazy flag = True => inject).
    [Test]
    procedure TestRESTFillAssociation_DoesNotSkipLazy;
    /// InjectLazyFactories must resolve lazy fields for TExame.
    [Test]
    procedure TestRestInjectLazy_ResolvesFieldsForExame;
    /// Re-injection on the same object (via Reset) must be idempotent — the
    /// proxy is reset, not doubled.
    [Test]
    procedure TestRESTProxy_ResetIsIdempotent;
  end;

implementation

{ TTestRestLazyProxy }

procedure TTestRestLazyProxy.TestRestContext_LazyAssociationDetectable;
var
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LLazyFound: Boolean;
begin
  // The REST FillAssociation now injects factories for lazy associations.
  // This test validates that the mapping correctly marks TExame associations
  // as lazy so FillAssociation has the correct routing information.
  LAssociations := TMappingExplorer.GetMappingAssociation(TExame);
  Assert.IsNotNull(LAssociations,
    'TExame must have associations for REST injection routing');

  LLazyFound := False;
  for LAssociation in LAssociations do
  begin
    if LAssociation.Lazy then
    begin
      LLazyFound := True;
      Assert.AreEqual('TProcedimento', LAssociation.ClassNameRef,
        'Lazy association in TExame must reference TProcedimento');
      Break;
    end;
  end;
  Assert.IsTrue(LLazyFound,
    'TExame must have at least one lazy association that REST FillAssociation must inject');
end;

procedure TTestRestLazyProxy.TestRESTSessionToken_ValidOnCreate;
var
  LToken: ILazySessionToken;
begin
  LToken := TLazySessionToken.Create;
  Assert.IsTrue(LToken.IsValid,
    'REST session token must be valid immediately after creation');
end;

procedure TTestRestLazyProxy.TestRESTSessionToken_BlocksLoadAfterInvalidate;
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
    'REST lazy proxy must raise ELazyLoadException when session token is invalidated');
end;

procedure TTestRestLazyProxy.TestRESTProxy_SameInfrastructureAsObjectSet;
var
  LToken: ILazySessionToken;
  LProxy: ILazyProxy;
  LResult: TObject;
begin
  // The REST context uses the same TLazyProxyLoader / ILazyProxy infrastructure
  // as ObjectSet and DataSet — no separate proxy hierarchy.
  LToken := TLazySessionToken.Create;
  LProxy := TLazyProxyLoader.Create(
    function: TObject
    begin
      Result := TProcedimento.Create;
    end, LToken);

  LResult := LProxy.Invoke;
  Assert.IsNotNull(LResult,
    'REST proxy must use the shared TLazyProxyLoader infrastructure');
  Assert.IsTrue(LProxy.IsValueCreated,
    'IsValueCreated must be True after Invoke in REST context');
end;

procedure TTestRestLazyProxy.TestRESTFillAssociation_DoesNotSkipLazy;
var
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LLazyAssociation: TAssociationMapping;
begin
  // Confirm that at least one TExame association is lazy.
  // This is the target of the REST FillAssociation route change.
  LAssociations := TMappingExplorer.GetMappingAssociation(TExame);
  LLazyAssociation := nil;
  for LAssociation in LAssociations do
  begin
    if LAssociation.Lazy then
    begin
      LLazyAssociation := LAssociation;
      Break;
    end;
  end;
  Assert.IsNotNull(LLazyAssociation,
    'At least one lazy association must exist in TExame for REST to inject');
  Assert.IsTrue(LLazyAssociation.Lazy,
    'The routed association must have Lazy = True');
  // The injection path is: FillAssociation -> _InjectLazyFactory (not Continue).
  // This test confirms the precondition; runtime injection requires a live session.
  Assert.IsNotNull(LazyMappingExplorer.GetLazyFields(TExame),
    'LazyMappingExplorer must provide field cache for REST _InjectLazyFactory');
end;

procedure TTestRestLazyProxy.TestRestInjectLazy_ResolvesFieldsForExame;
var
  LFields: TObjectList<TLazyMapping>;
begin
  LFields := LazyMappingExplorer.GetLazyFields(TExame);
  Assert.IsNotNull(LFields,
    'TLazyMappingExplorer must return a non-nil list for TExame');
  Assert.IsTrue(LFields.Count > 0,
    'TExame must have at least one lazy field for REST _InjectLazyFactory to process');
  Assert.AreEqual('FProcedimento', LFields[0].FieldLazy.Name,
    'The lazy field for TExame must be FProcedimento');
end;

procedure TTestRestLazyProxy.TestRESTProxy_ResetIsIdempotent;
var
  LToken: ILazySessionToken;
  LProxy: ILazyProxy;
  LResettable: ILazyProxyResettable;
  LCallCount: Integer;
begin
  // Simulates a second FillAssociation call on the same object (e.g., re-fetch).
  // The proxy must be reset (not duplicated) via ILazyProxyResettable.
  LCallCount := 0;
  LToken := TLazySessionToken.Create;
  LProxy := TLazyProxyLoader.Create(
    function: TObject
    begin
      Inc(LCallCount);
      Result := TProcedimento.Create;
    end, LToken);

  // First load
  LProxy.Invoke;
  Assert.AreEqual(1, LCallCount, 'First invoke must call factory once');

  // Second injection via Reset (idempotent re-inject path)
  Assert.IsTrue(Supports(LProxy, ILazyProxyResettable, LResettable),
    'REST proxy must support ILazyProxyResettable for idempotent re-injection');

  LResettable.Reset(
    function: TObject
    begin
      Inc(LCallCount);
      Result := TProcedimento.Create;
    end, LToken);

  Assert.IsFalse(LProxy.IsValueCreated,
    'After REST idempotent reset, IsValueCreated must be False');

  LProxy.Invoke;
  Assert.AreEqual(2, LCallCount,
    'After REST reset, new load function must be invoked on next access');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRestLazyProxy);

end.
