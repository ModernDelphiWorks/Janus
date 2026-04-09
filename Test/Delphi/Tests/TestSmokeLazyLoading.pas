unit TestSmokeLazyLoading;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  Generics.Collections,
  Janus.Types.Lazy,
  Janus.Mapping.Lazy,
  MetaDbDiff.Mapping.Classes,
  MetaDbDiff.Mapping.Explorer,
  MetaDbDiff.Types.Mapping,
  Model.Exame,
  Model.Procedimento,
  Model.Setor;

type
  /// <summary>
  ///   S1 — Baseline smoke tests for explicit lazy loading.
  ///   Validates that the lazy infrastructure is in place before the transparent
  ///   proxy is active. These tests must pass without any database connection.
  /// </summary>
  [TestFixture]
  TTestSmokeLazyLoading = class
  public
    /// Verify that TExame has a lazy association in its mapping.
    [Test]
    procedure TestLazyAssociationExists_Exame;
    /// Verify that the only smoke model with no lazy fields (TSetor) reports zero.
    [Test]
    procedure TestLazyAssociationAbsent_Setor;
    /// A freshly created TLazySessionToken must report IsValid = True.
    [Test]
    procedure TestSessionToken_StartsValid;
    /// After Invalidate, the token must report IsValid = False.
    [Test]
    procedure TestSessionToken_InvalidatedAfterInvalidate;
    /// A TLazyProxyLoader created with a valid token must not be loaded yet.
    [Test]
    procedure TestProxy_NotLoadedBeforeInvoke;
    /// TLazyProxyLoader.Invoke must return the object produced by the factory.
    [Test]
    procedure TestProxy_ExplicitInvokeReturnsObject;
    /// TLazyProxyLoader.Invoke with an invalidated token must raise ELazyLoadException.
    [Test]
    procedure TestProxy_InvalidatedTokenRaisesError;
    /// TLazyMappingExplorer returns the same list instance on two consecutive calls
    /// (cache hit), confirming RTTI is not re-extracted on every access.
    [Test]
    procedure TestMappingExplorer_CacheHit_Exame;
    /// The Lazy<T> record default (no factory injected) must create a non-nil
    /// default instance of T when T is a class — backward-compat guarantee.
    [Test]
    procedure TestLazyRecord_DefaultCreatesInstance;
    /// Reset on TLazyProxyResettable must allow a second load via a different factory.
    [Test]
    procedure TestProxy_ResetAllowsReload;
  end;

implementation

{ TTestSmokeLazyLoading }

procedure TTestSmokeLazyLoading.TestLazyAssociationExists_Exame;
var
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LFound: Boolean;
begin
  LAssociations := TMappingExplorer.GetMappingAssociation(TExame);
  Assert.IsNotNull(LAssociations, 'TExame must have at least one association');

  LFound := False;
  for LAssociation in LAssociations do
  begin
    if LAssociation.Lazy then
    begin
      LFound := True;
      Break;
    end;
  end;
  Assert.IsTrue(LFound,
    'TExame must have at least one lazy association (baseline for transparent proxy)');
end;

procedure TTestSmokeLazyLoading.TestLazyAssociationAbsent_Setor;
var
  LFields: TObjectList<TLazyMapping>;
begin
  LFields := LazyMappingExplorer.GetLazyFields(TSetor);
  Assert.IsNotNull(LFields, 'GetLazyFields must never return nil');
  Assert.AreEqual(0, LFields.Count,
    'TSetor must have 0 lazy fields — smoke baseline for association-free entities');
end;

procedure TTestSmokeLazyLoading.TestSessionToken_StartsValid;
var
  LToken: ILazySessionToken;
begin
  LToken := TLazySessionToken.Create;
  Assert.IsTrue(LToken.IsValid,
    'A new TLazySessionToken must be valid immediately after creation');
end;

procedure TTestSmokeLazyLoading.TestSessionToken_InvalidatedAfterInvalidate;
var
  LToken: ILazySessionToken;
begin
  LToken := TLazySessionToken.Create;
  LToken.Invalidate;
  Assert.IsFalse(LToken.IsValid,
    'After Invalidate, IsValid must return False');
end;

procedure TTestSmokeLazyLoading.TestProxy_NotLoadedBeforeInvoke;
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
    'IsValueCreated must be False before the first Invoke call');
end;

procedure TTestSmokeLazyLoading.TestProxy_ExplicitInvokeReturnsObject;
var
  LToken: ILazySessionToken;
  LProxy: ILazyProxy;
  LResult: TObject;
begin
  LToken := TLazySessionToken.Create;
  LProxy := TLazyProxyLoader.Create(
    function: TObject
    begin
      Result := TProcedimento.Create;
    end, LToken);
  LResult := LProxy.Invoke;
  Assert.IsNotNull(LResult,
    'Invoke must return a non-nil object (explicit load path — backward compat)');
  Assert.IsTrue(LResult is TProcedimento,
    'Returned object must be of the expected type');
end;

procedure TTestSmokeLazyLoading.TestProxy_InvalidatedTokenRaisesError;
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
    'Invoke after session invalidation must raise ELazyLoadException');
end;

procedure TTestSmokeLazyLoading.TestMappingExplorer_CacheHit_Exame;
var
  LFields1: TObjectList<TLazyMapping>;
  LFields2: TObjectList<TLazyMapping>;
begin
  LFields1 := LazyMappingExplorer.GetLazyFields(TExame);
  LFields2 := LazyMappingExplorer.GetLazyFields(TExame);
  Assert.AreSame(TObject(LFields1), TObject(LFields2),
    'Two successive calls must return the same cached list instance (no RTTI re-extraction)');
end;

procedure TTestSmokeLazyLoading.TestLazyRecord_DefaultCreatesInstance;
var
  LExame: TExame;
  LProc: TProcedimento;
begin
  LExame := TExame.Create;
  try
    // Access the Procedimento property without injecting a factory.
    // Lazy<T>.GetValue falls back to CreateDefaultValue which invokes the
    // default constructor — the backward-compatible "no proxy" path.
    LProc := LExame.Procedimento;
    Assert.IsNotNull(LProc,
      'Lazy<T>.Value without a proxy must still create a default instance');
  finally
    LExame.Free;
  end;
end;

procedure TTestSmokeLazyLoading.TestProxy_ResetAllowsReload;
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
  Assert.AreEqual(1, LCallCount, 'Factory called once before Reset');

  Assert.IsTrue(Supports(LProxy, ILazyProxyResettable, LResettable),
    'TLazyProxyLoader must support ILazyProxyResettable for explicit reset path');

  LResettable.Reset(
    function: TObject
    begin
      Inc(LCallCount);
      Result := TProcedimento.Create;
    end, LToken);

  Assert.IsFalse(LProxy.IsValueCreated, 'IsValueCreated must be False after Reset');
  LResult2 := LProxy.Invoke;
  Assert.AreEqual(2, LCallCount, 'New factory must be invoked after Reset');
  Assert.AreNotSame(LResult1, LResult2, 'Reset must yield a new object instance');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestSmokeLazyLoading);

end.
