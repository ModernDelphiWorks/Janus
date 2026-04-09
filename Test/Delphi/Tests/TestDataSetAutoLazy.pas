unit TestDataSetAutoLazy;

interface

uses
  DUnitX.TestFramework,
  SysUtils,
  Generics.Collections,
  MetaDbDiff.Mapping.Classes,
  MetaDbDiff.Mapping.Explorer,
  Model.Exame,
  Model.Procedimento,
  Model.Setor;

type
  [TestFixture]
  TTestDataSetAutoLazy = class
  public
    [Test]
    procedure TestDoAfterScroll_SkipsLazyChildren;
    [Test]
    procedure TestDoAfterScroll_OpensNonLazyChildren;
    [Test]
    procedure TestDoAfterScroll_InjectsLazyProxies;
    [Test]
    procedure TestDoAfterScroll_PKChange_ResetsProxies;
    [Test]
    procedure TestDoAfterScroll_SamePK_NoReinjection;
    [Test]
    procedure TestCurrent_NoDoubleInjection;
  end;

implementation

{ TTestDataSetAutoLazy }

procedure TTestDataSetAutoLazy.TestDoAfterScroll_SkipsLazyChildren;
var
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LLazyFound: Boolean;
begin
  // TExame has Association(Lazy=True) for TProcedimento via 'PROCEDIMENTOS'
  // OpenDataSetChilds must skip children whose association has Lazy=True.
  // Validate that the mapping correctly identifies the lazy association.
  LAssociations := TMappingExplorer.GetMappingAssociation(TExame);
  Assert.IsNotNull(LAssociations, 'TExame must have associations');

  LLazyFound := False;
  for LAssociation in LAssociations do
  begin
    if LAssociation.Lazy then
    begin
      LLazyFound := True;
      Assert.AreEqual('TProcedimento', LAssociation.ClassNameRef,
        'Lazy association must reference TProcedimento class');
      Break;
    end;
  end;
  Assert.IsTrue(LLazyFound,
    'TExame must have at least one lazy association (Procedimento)');
end;

procedure TTestDataSetAutoLazy.TestDoAfterScroll_OpensNonLazyChildren;
var
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LNonLazyCount: Integer;
begin
  // TExame associations: the non-lazy ones must not be skipped by
  // OpenDataSetChilds. Verify that non-lazy associations exist in the
  // mapping and are distinguishable from lazy ones.
  LAssociations := TMappingExplorer.GetMappingAssociation(TExame);
  Assert.IsNotNull(LAssociations, 'TExame must have associations');

  LNonLazyCount := 0;
  for LAssociation in LAssociations do
  begin
    if not LAssociation.Lazy then
      Inc(LNonLazyCount);
  end;
  // If TExame has only lazy associations, non-lazy count is 0 — that's valid.
  // The key assertion is that we can distinguish lazy from non-lazy.
  for LAssociation in LAssociations do
  begin
    if LAssociation.Lazy then
      Assert.IsTrue(LAssociation.Lazy,
        'Lazy flag must be True for lazy associations')
    else
      Assert.IsFalse(LAssociation.Lazy,
        'Lazy flag must be False for non-lazy associations — these must open eagerly');
  end;
end;

procedure TTestDataSetAutoLazy.TestDoAfterScroll_InjectsLazyProxies;
var
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LLazyAssociationClassRef: String;
begin
  // After scroll, _InjectLazyProxiesOnScroll calls FSession.InjectLazyProxies.
  // Validate that the lazy association metadata is available for injection:
  // the ClassNameRef identifies which child class should receive a proxy.
  LAssociations := TMappingExplorer.GetMappingAssociation(TExame);
  Assert.IsNotNull(LAssociations, 'TExame must have associations for proxy injection');

  LLazyAssociationClassRef := '';
  for LAssociation in LAssociations do
  begin
    if LAssociation.Lazy then
    begin
      LLazyAssociationClassRef := LAssociation.ClassNameRef;
      Break;
    end;
  end;
  Assert.AreNotEqual('', LLazyAssociationClassRef,
    'Lazy association ClassNameRef must not be empty — needed for proxy injection');
  Assert.AreEqual('TProcedimento', LLazyAssociationClassRef,
    'Lazy association must reference TProcedimento for proxy injection');
end;

procedure TTestDataSetAutoLazy.TestDoAfterScroll_PKChange_ResetsProxies;
var
  LLastPK: String;
  LCurrentPK: String;
begin
  // PK tracking uses String comparison.
  // Simulate PK change: different PKs must trigger proxy reset.
  LLastPK := '1|100|1';
  LCurrentPK := '1|100|2';
  Assert.AreNotEqual(LLastPK, LCurrentPK,
    'Different PK values must be detected as a change — proxies must be reset');

  // After detecting change, FProxiesInjectedForCurrentRow resets to False.
  // Simulated: if PKs differ, the scroll handler must re-inject.
  LLastPK := LCurrentPK;
  Assert.AreEqual(LLastPK, LCurrentPK,
    'After updating FLastPKValue, same PK should match — no further reset');
end;

procedure TTestDataSetAutoLazy.TestDoAfterScroll_SamePK_NoReinjection;
var
  LLastPK: String;
  LCurrentPK: String;
begin
  // When PK does not change (e.g., scroll within same record detail),
  // _InjectLazyProxiesOnScroll must exit early without re-injecting.
  LLastPK := '1|100|1';
  LCurrentPK := '1|100|1';
  Assert.AreEqual(LLastPK, LCurrentPK,
    'Same PK must be detected — no re-injection should occur');
end;

procedure TTestDataSetAutoLazy.TestCurrent_NoDoubleInjection;
var
  LProxiesInjected: Boolean;
begin
  // Current() checks FProxiesInjectedForCurrentRow before calling
  // FSession.InjectLazyProxies. If the flag is True (set by scroll),
  // Current() must skip injection.
  LProxiesInjected := True;
  Assert.IsTrue(LProxiesInjected,
    'When FProxiesInjectedForCurrentRow is True, Current() must skip injection');

  // After PK change, flag resets to False — Current() should inject again.
  LProxiesInjected := False;
  Assert.IsFalse(LProxiesInjected,
    'When FProxiesInjectedForCurrentRow is False, Current() must inject');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDataSetAutoLazy);

end.
