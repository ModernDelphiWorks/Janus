unit TestObjectSetLazyProxy;

interface

uses
  DUnitX.TestFramework,
  SysUtils,
  Janus.Types.Lazy,
  Janus.Mapping.Lazy,
  MetaDbDiff.Mapping.Classes,
  MetaDbDiff.Mapping.Explorer,
  Model.Exame,
  Model.Procedimento;

type
  /// <summary>
  ///   R18.2 smoke expansion for ObjectSet lazy-loading baseline.
  ///   Uses the same fixture models from Examples/Delphi/Data/Object Lazy.
  /// </summary>
  [TestFixture]
  TTestObjectSetLazyProxy = class
  public
    [Test]
    procedure TestObjectSetMapping_HasLazyAssociation;
    [Test]
    procedure TestObjectSetProxy_DeferredLoad;
    [Test]
    procedure TestObjectSetProxy_InvalidSessionRaises;
    [Test]
    procedure TestObjectSetProxy_ResetAllowsReinjection;
  end;

implementation

{ TTestObjectSetLazyProxy }

procedure TTestObjectSetLazyProxy.TestObjectSetMapping_HasLazyAssociation;
var
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LHasLazy: Boolean;
begin
  LAssociations := TMappingExplorer.GetMappingAssociation(TExame);
  Assert.IsNotNull(LAssociations, 'TExame must expose associations for ObjectSet lazy loading');

  LHasLazy := False;
  for LAssociation in LAssociations do
  begin
    if LAssociation.Lazy then
    begin
      LHasLazy := True;
      Break;
    end;
  end;

  Assert.IsTrue(LHasLazy,
    'ObjectSet smoke baseline requires at least one lazy association in TExame');
end;

procedure TTestObjectSetLazyProxy.TestObjectSetProxy_DeferredLoad;
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
    'ObjectSet proxy must stay deferred before the first Invoke');
end;

procedure TTestObjectSetLazyProxy.TestObjectSetProxy_InvalidSessionRaises;
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
    'ObjectSet proxy must raise ELazyLoadException after token invalidation');
end;

procedure TTestObjectSetLazyProxy.TestObjectSetProxy_ResetAllowsReinjection;
var
  LToken: ILazySessionToken;
  LProxy: ILazyProxy;
  LResettable: ILazyProxyResettable;
  LCallCount: Integer;
  LFirstResult: TObject;
  LSecondResult: TObject;
begin
  LCallCount := 0;
  LToken := TLazySessionToken.Create;
  LProxy := TLazyProxyLoader.Create(
    function: TObject
    begin
      Inc(LCallCount);
      Result := TProcedimento.Create;
    end, LToken);

  LFirstResult := LProxy.Invoke;
  Assert.AreEqual(1, LCallCount, 'First invoke must execute factory exactly once');

  Assert.IsTrue(Supports(LProxy, ILazyProxyResettable, LResettable),
    'ObjectSet proxy must support ILazyProxyResettable for row re-injection');

  LResettable.Reset(
    function: TObject
    begin
      Inc(LCallCount);
      Result := TProcedimento.Create;
    end, LToken);

  Assert.IsFalse(LProxy.IsValueCreated,
    'After Reset, ObjectSet proxy must be marked as not loaded');

  LSecondResult := LProxy.Invoke;
  Assert.AreEqual(2, LCallCount, 'Invoke after Reset must run the new factory');
  Assert.AreNotSame(LFirstResult, LSecondResult,
    'Invoke after Reset must return a new object instance');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestObjectSetLazyProxy);

end.
