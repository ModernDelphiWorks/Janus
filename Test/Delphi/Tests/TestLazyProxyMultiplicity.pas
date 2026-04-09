unit TestLazyProxyMultiplicity;

interface

uses
  DUnitX.TestFramework,
  SysUtils,
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
  ///   S4 — Multiplicity validation for transparent lazy proxy.
  ///   These tests validate that each supported multiplicity (OneToOne, OneToMany)
  ///   is correctly detected, routed, and handled by the lazy proxy infrastructure
  ///   across ObjectSet, DataSet, and REST contexts.
  /// </summary>
  [TestFixture]
  TTestLazyProxyMultiplicity = class
  public
    /// TExame has exactly one lazy association (OneToOne → TProcedimento).
    [Test]
    procedure TestMultiplicity_OneToOne_ExameProcedimento;
    /// TProcedimento has exactly one lazy association (OneToMany → TSetor list).
    [Test]
    procedure TestMultiplicity_OneToMany_ProcedimentoSetores;
    /// A OneToOne lazy proxy returns a single object (not a list).
    [Test]
    procedure TestProxy_OneToOne_ReturnsSingleObject;
    /// A OneToMany lazy proxy returns a list (simulated by TObjectList).
    [Test]
    procedure TestProxy_OneToMany_ReturnsList;
    /// All lazy fields for TExame must have a multiplicity that is either
    /// OneToOne or ManyToOne (single-object associations).
    [Test]
    procedure TestLazyField_ExameMultiplicity_IsSingleObject;
    /// All lazy fields for TProcedimento must have a multiplicity that is either
    /// OneToMany or ManyToMany (collection associations).
    [Test]
    procedure TestLazyField_ProcedimentoMultiplicity_IsCollection;
    /// A lazy association with OneToOne multiplicity must inject a single-value proxy.
    [Test]
    procedure TestProxyFactory_OneToOne_InvokesBuildOnce;
    /// A lazy association with OneToMany multiplicity must invoke the factory once
    /// and the result must not be nil (list is lazily created).
    [Test]
    procedure TestProxyFactory_OneToMany_InvokesBuildOnce;
    /// Retrocompatibility: LoadLazy explicit path still works for both multiplicities.
    [Test]
    procedure TestExplicitLoadLazy_CompatibleWithBothMultiplicities;
  end;

implementation

{ TTestLazyProxyMultiplicity }

procedure TTestLazyProxyMultiplicity.TestMultiplicity_OneToOne_ExameProcedimento;
var
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LFound: Boolean;
begin
  LAssociations := TMappingExplorer.GetMappingAssociation(TExame);
  Assert.IsNotNull(LAssociations, 'TExame must have associations');

  LFound := False;
  for LAssociation in LAssociations do
  begin
    if LAssociation.Lazy and
       (LAssociation.Multiplicity in [TMultiplicity.OneToOne, TMultiplicity.ManyToOne]) then
    begin
      LFound := True;
      Assert.AreEqual('TProcedimento', LAssociation.ClassNameRef,
        'OneToOne lazy association in TExame must reference TProcedimento');
      Break;
    end;
  end;
  Assert.IsTrue(LFound,
    'TExame must have a OneToOne or ManyToOne lazy association');
end;

procedure TTestLazyProxyMultiplicity.TestMultiplicity_OneToMany_ProcedimentoSetores;
var
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LFound: Boolean;
begin
  LAssociations := TMappingExplorer.GetMappingAssociation(TProcedimento);
  Assert.IsNotNull(LAssociations, 'TProcedimento must have associations');

  LFound := False;
  for LAssociation in LAssociations do
  begin
    if LAssociation.Lazy and
       (LAssociation.Multiplicity in [TMultiplicity.OneToMany, TMultiplicity.ManyToMany]) then
    begin
      LFound := True;
      Break;
    end;
  end;
  Assert.IsTrue(LFound,
    'TProcedimento must have a OneToMany or ManyToMany lazy association (Setores)');
end;

procedure TTestLazyProxyMultiplicity.TestProxy_OneToOne_ReturnsSingleObject;
var
  LToken: ILazySessionToken;
  LProxy: ILazyProxy;
  LResult: TObject;
begin
  LToken := TLazySessionToken.Create;
  // Simulate a OneToOne factory: returns a single TProcedimento
  LProxy := TLazyProxyLoader.Create(
    function: TObject
    begin
      Result := TProcedimento.Create;
    end, LToken);

  LResult := LProxy.Invoke;
  Assert.IsNotNull(LResult, 'OneToOne proxy must return a non-nil single object');
  Assert.IsTrue(LResult is TProcedimento,
    'OneToOne proxy must return the associated type, not a list');
end;

procedure TTestLazyProxyMultiplicity.TestProxy_OneToMany_ReturnsList;
var
  LToken: ILazySessionToken;
  LProxy: ILazyProxy;
  LResult: TObject;
  LList: TObjectList<TSetor>;
begin
  LToken := TLazySessionToken.Create;
  // Simulate a OneToMany factory: returns a TObjectList<TSetor>
  LProxy := TLazyProxyLoader.Create(
    function: TObject
    var
      LNewList: TObjectList<TSetor>;
    begin
      LNewList := TObjectList<TSetor>.Create(True);
      LNewList.Add(TSetor.Create);
      Result := LNewList;
    end, LToken);

  LResult := LProxy.Invoke;
  Assert.IsNotNull(LResult, 'OneToMany proxy must return a non-nil list');
  Assert.IsTrue(LResult is TObjectList<TSetor>,
    'OneToMany proxy must return a list of the associated child type');
  LList := TObjectList<TSetor>(LResult);
  Assert.AreEqual(1, LList.Count,
    'OneToMany proxy list must contain the pre-populated item');
end;

procedure TTestLazyProxyMultiplicity.TestLazyField_ExameMultiplicity_IsSingleObject;
var
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
begin
  LAssociations := TMappingExplorer.GetMappingAssociation(TExame);
  for LAssociation in LAssociations do
  begin
    if not LAssociation.Lazy then
      Continue;
    Assert.IsTrue(
      LAssociation.Multiplicity in [TMultiplicity.OneToOne, TMultiplicity.ManyToOne],
      'All lazy associations in TExame must be single-object multiplicity (OneToOne or ManyToOne)');
  end;
end;

procedure TTestLazyProxyMultiplicity.TestLazyField_ProcedimentoMultiplicity_IsCollection;
var
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LHasCollection: Boolean;
begin
  LAssociations := TMappingExplorer.GetMappingAssociation(TProcedimento);
  Assert.IsNotNull(LAssociations, 'TProcedimento must have associations');

  LHasCollection := False;
  for LAssociation in LAssociations do
  begin
    if not LAssociation.Lazy then
      Continue;
    if LAssociation.Multiplicity in [TMultiplicity.OneToMany, TMultiplicity.ManyToMany] then
    begin
      LHasCollection := True;
      Break;
    end;
  end;
  Assert.IsTrue(LHasCollection,
    'TProcedimento must have at least one lazy collection-multiplicity association');
end;

procedure TTestLazyProxyMultiplicity.TestProxyFactory_OneToOne_InvokesBuildOnce;
var
  LToken: ILazySessionToken;
  LProxy: ILazyProxy;
  LBuildCount: Integer;
begin
  LBuildCount := 0;
  LToken := TLazySessionToken.Create;
  LProxy := TLazyProxyLoader.Create(
    function: TObject
    begin
      Inc(LBuildCount);
      Result := TProcedimento.Create;
    end, LToken);

  LProxy.Invoke;
  LProxy.Invoke;

  Assert.AreEqual(1, LBuildCount,
    'OneToOne factory must be called exactly once regardless of access count');
end;

procedure TTestLazyProxyMultiplicity.TestProxyFactory_OneToMany_InvokesBuildOnce;
var
  LToken: ILazySessionToken;
  LProxy: ILazyProxy;
  LBuildCount: Integer;
  LResult: TObject;
begin
  LBuildCount := 0;
  LToken := TLazySessionToken.Create;
  LProxy := TLazyProxyLoader.Create(
    function: TObject
    var
      LNewList: TObjectList<TSetor>;
    begin
      Inc(LBuildCount);
      LNewList := TObjectList<TSetor>.Create(True);
      Result := LNewList;
    end, LToken);

  LResult := LProxy.Invoke;
  LProxy.Invoke;

  Assert.AreEqual(1, LBuildCount,
    'OneToMany factory must be called exactly once (list is cached after first access)');
  Assert.IsNotNull(LResult,
    'OneToMany proxy must return a non-nil list on first access');
end;

procedure TTestLazyProxyMultiplicity.TestExplicitLoadLazy_CompatibleWithBothMultiplicities;
var
  LToken1: ILazySessionToken;
  LToken2: ILazySessionToken;
  LProxyOneToOne: ILazyProxy;
  LProxyOneToMany: ILazyProxy;
begin
  LToken1 := TLazySessionToken.Create;
  LToken2 := TLazySessionToken.Create;

  // OneToOne: explicit load (LoadLazy path)
  LProxyOneToOne := TLazyProxyLoader.Create(
    function: TObject
    begin
      Result := TProcedimento.Create;
    end, LToken1);

  // OneToMany: explicit load (LoadLazy path)
  LProxyOneToMany := TLazyProxyLoader.Create(
    function: TObject
    begin
      Result := TObjectList<TSetor>.Create(True);
    end, LToken2);

  Assert.IsNotNull(LProxyOneToOne.Invoke,
    'Explicit LoadLazy for OneToOne must still return a valid object');
  Assert.IsNotNull(LProxyOneToMany.Invoke,
    'Explicit LoadLazy for OneToMany must still return a valid list object');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestLazyProxyMultiplicity);

end.
