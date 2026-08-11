{
  ------------------------------------------------------------------------------
  Janus
  Modern Object-Relational Mapping (ORM) framework for Delphi.

  SPDX-License-Identifier: MIT
  Copyright (c) 2016-2026 Isaque Pinheiro

  Licensed under the MIT License.
  See the LICENSE file in the project root for full license information.
  ------------------------------------------------------------------------------
}

{ @abstract(Janus Framework - reading .Current with a single-object association
  left nil must leave it nil, not fall over.)

  WHAT IS UNDER TEST - issue #296

  TDataSetBaseAdapter<M>._ExecuteOneToOne, the branch FillMastersClass picks for
  a OneToOne or a ManyToOne association. It read the property's current value
  and handed whatever came back to Bind.SetFieldToProperty, which opens with
  TMappingExplorer.GetMappingColumn(AObject.ClassType). On a nil reference that
  ClassType dereferences address zero, so a read of .Current raised
  EAccessViolation - not an exception a consumer's try..except can name, and
  raised on the READ path, which ApplyInserter takes on its own.

  THE GUARD THAT WAS ALREADY THERE DID NOT COVER IT. `if not LValue.IsObject
  then Exit` is about the KIND of the TValue, not its content: TValue.IsObject
  answers True for a nil class reference. IsObjectIsTrueForANilClassReference
  measures that instead of quoting it, because the whole defect rests on it and
  a reader who assumes the opposite would call the repair redundant.

  WHAT THAT PREMISE DOES NOT SAY IS THAT THE OLD GUARD EARNS ITS PLACE. It
  measures only that the guard CANNOT catch a nil. Whether it catches anything
  else is not measured here and is not measured anywhere: deleting it outright
  leaves this project at 567 found, 0 failures, 0 errors - a number measured on
  issue #296's branch and NOT re-run since, so it is the total this project had
  BEFORE issue #307 added twelve clauses and took it to 579. It is pre-existing
  and it is left alone, uncovered - said plainly so the premise below is not
  read as a defence of it.

  A NIL THERE IS A STATE THE REPOSITORY ITSELF SHIPS. TAsymTreeOneRoot.mid is
  declared [Association(TMultiplicity.OneToOne, ...)] and no constructor fills
  it in - its own model header says "It starts nil on purpose". A consumer that
  declares a single-object association and does not construct it in the
  constructor, which is the Delphi default, is in exactly that state.

  THE DECISION, AND WHOSE IT IS

  Three behaviours were on the table and the owner picked one: EXIT IN SILENCE,
  leaving the property nil in the graph. The consumer gets back what it had -
  no data in, no data out. Raising a named exception was refused because the
  shipped model hands that nil over deliberately; instantiating the object was
  refused because it changes OWNERSHIP - nothing in the walk would be
  responsible for freeing it.

  SO "IT DID NOT RAISE" IS NOT WHAT THESE CLAUSES ASSERT. That is the weakest
  assertion available and it goes green for a repair that quietly abandons the
  whole walk. Every clause here asserts the GRAPH: one string carrying the
  root's own bound column AND the state of the association, so "the property
  stayed nil" and "the rest still arrived" cannot be told apart from one
  another by accident. The nil clauses read `P2(<nil>)` - the P2 is the second
  root row, which pins that the read bound the row the cursor was ON.

  THE THREE FAMILIES ARE MEASURED, NOT INFERRED

  _ExecuteOneToOne is declared once, on the shared base TDataSetBaseAdapter<M>,
  and it is not virtual - so one repair reaching all three families is a
  reasonable expectation. It is only that until measured: on issue #276 the
  three families diverged and on #295 they converged, so the house rule is that
  this is asked and not assumed. FDMemTable, ClientDataSet and the REST
  FDMemTable each get their own clause.

  MANYTOONE CARRIES ITS OWN LABEL HERE

  Janus.DataSet.Events said, over TPendingChildsAction, "OneToOne and ManyToOne
  both route to that branch ... no test carries the ManyToOne label". The
  sentence entered at commit 6741bbe, with issue #276, and this change is what
  narrowed it - so the words above are the text AS IT STOOD, not what is there
  now. FillMastersClass really does test both in one `in [...]` set, so the
  claim was readable off the source - but readable is not measured, and
  TAsymTreeManyRoot below is the first entity in the suite to declare
  TMultiplicity.ManyToOne. It reuses atmid and atleaf verbatim, the same way
  atpair does, so the only thing that differs from the OneToOne clauses is the
  multiplicity token.

  WHAT WOULD KILL EACH CLAUSE - the mutations that were run are recorded in the
  commit that installs them, not here, so this header does not go stale when the
  next reader runs a different one.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`. }

unit Test.Janus.OneToOne.NilAssociation;

interface

uses
  DB,
  Classes,
  SysUtils,
  Rtti,
  DBClient,
  Generics.Collections,
  DUnitX.TestFramework,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Param,
  FireDAC.Stan.Error,
  FireDAC.DatS,
  FireDAC.Phys.Intf,
  FireDAC.DApt.Intf,
  FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,
  DataEngine.FactoryInterfaces,
  MetaDbDiff.Mapping.Attributes,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Register,
  Janus.DataSet.Base.Adapter,
  Janus.DataSet.FDMemTable,
  Janus.DataSet.ClientDataSet,
  Janus.RestDataSet.FDMemTable,
  Janus.RestFactory.Interfaces,
  /// For TAsymTreeOneRoot / TAsymTreeMid / TAsymTreeLeaf - the OneToOne top
  /// level the repository already ships, and the two levels under it.
  Test.Janus.Model.AsymTree,
  /// For TRowsConnection, the IDBConnection double that hands out an empty
  /// cursor instead of nil.
  Test.Janus.Cursor.Double,
  /// For TInertRestConnection, the IRESTConnection double.
  Test.Janus.MasterDetail.Link;

type
  /// <summary> The FIRST entity in the suite to carry TMultiplicity.ManyToOne -
  ///  issue #296. Everything else about it is TAsymTreeOneRoot: it hangs off
  ///  the SAME atmid rows through the same `mparent` foreign key, and it leaves
  ///  its single-object association nil for the same reason - no constructor
  ///  fills it in.
  ///
  ///  IT EXISTS HERE AND NOT IN Test.Janus.Model.AsymTree because that unit is
  ///  compiled by Janus.Tests.RESTHorse as well, and a new registered entity
  ///  reaching a project that has no use for it is a change nobody asked
  ///  for. </summary>
  [Entity]
  [Table('atmto', '')]
  [PrimaryKey('qkey', TAutoIncType.AutoInc,
                      TGeneratorType.SequenceInc,
                      TSortingOrder.NoSort,
                      True, 'Primary key')]
  [Sequence('atmto')]
  TAsymTreeManyRoot = class
  private
    Fqkey: Integer;
    Fqtag: String;
    Fmid: TAsymTreeMid;
  public
    destructor Destroy; override;

    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('qkey', ftInteger)]
    property qkey: Integer read Fqkey write Fqkey;

    [Column('qtag', ftString, 20)]
    property qtag: String read Fqtag write Fqtag;

    /// Nil on delivery, exactly like TAsymTreeOneRoot.mid. The token that
    /// differs from every other association in the suite is the FIRST one.
    [Association(TMultiplicity.ManyToOne, 'qkey', 'atmid', 'mparent')]
    [CascadeActions([TCascadeAction.CascadeAutoInc,
                     TCascadeAction.CascadeInsert,
                     TCascadeAction.CascadeUpdate,
                     TCascadeAction.CascadeDelete])]
    property mid: TAsymTreeMid read Fmid write Fmid;
  end;

  [TestFixture]
  TTestOneToOneNilAssociation = class
  private
    FConn: IDBConnection;
    FRest: IRESTConnection;
    /// FDMemTable family.
    FMemRootTable: TFDMemTable;
    FMemMidTable: TFDMemTable;
    FMemLeafTable: TFDMemTable;
    FMemRoot: TFDMemTableAdapter<TAsymTreeOneRoot>;
    FMemMid: TFDMemTableAdapter<TAsymTreeMid>;
    FMemLeaf: TFDMemTableAdapter<TAsymTreeLeaf>;
    /// ClientDataSet family.
    FCdsRootTable: TClientDataSet;
    FCdsMidTable: TClientDataSet;
    FCdsLeafTable: TClientDataSet;
    FCdsRoot: TClientDataSetAdapter<TAsymTreeOneRoot>;
    FCdsMid: TClientDataSetAdapter<TAsymTreeMid>;
    FCdsLeaf: TClientDataSetAdapter<TAsymTreeLeaf>;
    /// REST family.
    FRestRootTable: TFDMemTable;
    FRestMidTable: TFDMemTable;
    FRestLeafTable: TFDMemTable;
    FRestRoot: TRESTFDMemTableAdapter<TAsymTreeOneRoot>;
    FRestMid: TRESTFDMemTableAdapter<TAsymTreeMid>;
    FRestLeaf: TRESTFDMemTableAdapter<TAsymTreeLeaf>;
    /// The ManyToOne top level, FDMemTable family.
    FMtoRootTable: TFDMemTable;
    FMtoMidTable: TFDMemTable;
    FMtoLeafTable: TFDMemTable;
    FMtoRoot: TFDMemTableAdapter<TAsymTreeManyRoot>;
    FMtoMid: TFDMemTableAdapter<TAsymTreeMid>;
    FMtoLeaf: TFDMemTableAdapter<TAsymTreeLeaf>;
    procedure BuildMemTree;
    procedure BuildCdsTree;
    procedure BuildRestTree;
    procedure BuildMtoTree;
    procedure SeedTwoRootsOneMidOneLeaf(const ARoot, AMid, ALeaf: TDataSet;
      const ARootTagColumn: String);
    function OneRootGraph(const ARoot: TAsymTreeOneRoot): String;
    function ManyRootGraph(const ARoot: TAsymTreeManyRoot): String;
    function MidGraph(const AMid: TAsymTreeMid): String;
    function LeafRows(const ADataSet: TDataSet): String;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // -----------------------------------------------------------------------
    // The premises the whole issue rests on
    // -----------------------------------------------------------------------

    /// The reason the guard that was already in _ExecuteOneToOne does not
    /// catch this. TValue.IsObject is about the KIND of the value, and a nil
    /// class reference is still of object kind. Measured on the RTTI itself,
    /// through the same TRttiProperty.GetValue the walk uses, because the
    /// repair is only necessary if this is true.
    [Test]
    procedure Premise_IsObjectIsTrueForANilClassReference;
    /// And the model really does deliver the association nil. Read off the
    /// adapter's own entity, which is what .Current returns.
    [Test]
    procedure Premise_TheShippedModelDeliversTheAssociationNil;

    // -----------------------------------------------------------------------
    // The three families
    // -----------------------------------------------------------------------

    /// FDMemTable. Two root rows so the bound tag says WHICH row was read, one
    /// middle row and one leaf row so the walk that the nil short-circuits
    /// would have had something to do at both levels.
    [Test]
    procedure Mem_ReadingCurrentWithTheAssociationNil_LeavesItNilAndBindsTheRest;
    /// ClientDataSet - a different TDataSet descendant behind the same base
    /// adapter.
    [Test]
    procedure Cds_ReadingCurrentWithTheAssociationNil_LeavesItNilAndBindsTheRest;
    /// REST. TRESTDataSetAdapter<M> overrides OpenDataSetChilds with an empty
    /// body and reaches _ExecuteOneToOne through the same FillMastersClass, so
    /// it is the family least likely to differ - which is not a reason to
    /// leave it unasked.
    [Test]
    procedure Rest_ReadingCurrentWithTheAssociationNil_LeavesItNilAndBindsTheRest;

    // -----------------------------------------------------------------------
    // What the silence must NOT cost
    // -----------------------------------------------------------------------

    /// The other side of the repair, and the clause that dies if the new exit
    /// is phrased too widely. With the association ASSIGNED the walk has to
    /// run exactly as before: the middle object populated from the middle row
    /// AND its own leaf list built from the level below. A guard that exits on
    /// anything but nil reddens this and nothing else.
    [Test]
    procedure WithTheAssociationAssigned_TheWalkStillBuildsTheWholeBranch;
    /// The nil hand-off happens TWICE in that method - once into
    /// Bind.SetFieldToProperty and once into the recursion that walks the next
    /// level down - and only the first one raises. This clause is about the
    /// second: the grandchild rows the operator typed are still there,
    /// untouched, after the read that found the nil.
    [Test]
    procedure TheNilRead_LeavesTheGrandchildRowsWhereTheyWere;

    // -----------------------------------------------------------------------
    // The other multiplicity that routes through the same branch
    // -----------------------------------------------------------------------

    /// The ManyToOne label, carried by a test for the first time. Same
    /// property, same nil, same branch - the multiplicity token is the only
    /// difference from the FDMemTable clause above.
    [Test]
    procedure ManyToOne_ReadingCurrentWithTheAssociationNil_LeavesItNilAndBindsTheRest;
    /// And the same sibling guard on the ManyToOne route: assigned, it still
    /// builds the branch.
    [Test]
    procedure ManyToOne_WithTheAssociationAssigned_TheWalkStillBuildsTheWholeBranch;
  end;

implementation

const
  cROOTTAG    = 'ptag';
  cMANYTAG    = 'qtag';
  cMIDTAG     = 'mtag';
  cMIDKEY     = 'mkey';
  cMIDPARENT  = 'mparent';
  cLEAFTAG    = 'ltag';
  cLEAFPARENT = 'lparent';

  cROOT1      = 'P1';
  cROOT2      = 'P2';
  cMID1       = 'AM1';
  cLEAF1      = 'AL1';
  /// The middle row's own key, and the value the leaf row names as its parent.
  /// A number no other column in the tree carries, so a leaf that arrived
  /// under the wrong parent cannot read as if it had arrived under the right
  /// one.
  cMIDOWNKEY  = 311;
  /// What a nil association renders as. Spelled, not empty, so an assertion
  /// cannot pass on a signature that simply stopped being built.
  cNILBRANCH  = '<nil>';
  cNOROW      = '<no row>';
  /// A walk over a dataset that never advances is an infinite loop, not a slow
  /// one. Nothing here seeds more than three rows.
  cWALKCEIL   = 64;

type
  /// Saved BeforeScroll/AfterScroll pair, so a fixture helper can walk a
  /// dataset without TDataSetAdapter<M>.DoAfterScroll re-opening its children -
  /// which would empty the very rows the walk is there to count.
  TScrollMute = record
    Before: TDataSetNotifyEvent;
    After: TDataSetNotifyEvent;
  end;

function MuteScroll(const ADataSet: TDataSet): TScrollMute;
begin
  Result.Before := ADataSet.BeforeScroll;
  Result.After := ADataSet.AfterScroll;
  ADataSet.BeforeScroll := nil;
  ADataSet.AfterScroll := nil;
end;

procedure UnmuteScroll(const ADataSet: TDataSet; const AMute: TScrollMute);
begin
  ADataSet.BeforeScroll := AMute.Before;
  ADataSet.AfterScroll := AMute.After;
end;

{ TAsymTreeManyRoot }

destructor TAsymTreeManyRoot.Destroy;
begin
  Fmid.Free;
  inherited;
end;

{ TTestOneToOneNilAssociation }

procedure TTestOneToOneNilAssociation.Setup;
begin
  // Zero rows on purpose. Nothing here reads the store; every row under test
  // is one an operator typed into the grid and has not saved, which is the
  // state the issue is about.
  FConn := TRowsConnection.Create(dnSQLite, 0,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add(cMIDKEY, ftInteger);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName(cMIDKEY).AsInteger := AIndex;
    end,
    'onetoone-nil');
  FRest := TInertRestConnection.Create;
end;

procedure TTestOneToOneNilAssociation.TearDown;
begin
  FreeAndNil(FMemLeaf);
  FreeAndNil(FMemMid);
  FreeAndNil(FMemRoot);
  FreeAndNil(FMemLeafTable);
  FreeAndNil(FMemMidTable);
  FreeAndNil(FMemRootTable);
  FreeAndNil(FCdsLeaf);
  FreeAndNil(FCdsMid);
  FreeAndNil(FCdsRoot);
  FreeAndNil(FCdsLeafTable);
  FreeAndNil(FCdsMidTable);
  FreeAndNil(FCdsRootTable);
  FreeAndNil(FRestLeaf);
  FreeAndNil(FRestMid);
  FreeAndNil(FRestRoot);
  FreeAndNil(FRestLeafTable);
  FreeAndNil(FRestMidTable);
  FreeAndNil(FRestRootTable);
  FreeAndNil(FMtoLeaf);
  FreeAndNil(FMtoMid);
  FreeAndNil(FMtoRoot);
  FreeAndNil(FMtoLeafTable);
  FreeAndNil(FMtoMidTable);
  FreeAndNil(FMtoRootTable);
  FRest := nil;
  FConn := nil;
end;

procedure TTestOneToOneNilAssociation.BuildMemTree;
begin
  FMemRootTable := TFDMemTable.Create(nil);
  FMemRoot := TFDMemTableAdapter<TAsymTreeOneRoot>.Create(FConn, FMemRootTable,
                -1, nil);
  FMemMidTable := TFDMemTable.Create(nil);
  FMemMid := TFDMemTableAdapter<TAsymTreeMid>.Create(FConn, FMemMidTable, -1,
               FMemRoot);
  FMemLeafTable := TFDMemTable.Create(nil);
  FMemLeaf := TFDMemTableAdapter<TAsymTreeLeaf>.Create(FConn, FMemLeafTable, -1,
                FMemMid);
end;

procedure TTestOneToOneNilAssociation.BuildCdsTree;
begin
  FCdsRootTable := TClientDataSet.Create(nil);
  FCdsRoot := TClientDataSetAdapter<TAsymTreeOneRoot>.Create(FConn,
                FCdsRootTable, -1, nil);
  FCdsMidTable := TClientDataSet.Create(nil);
  FCdsMid := TClientDataSetAdapter<TAsymTreeMid>.Create(FConn, FCdsMidTable, -1,
               FCdsRoot);
  FCdsLeafTable := TClientDataSet.Create(nil);
  FCdsLeaf := TClientDataSetAdapter<TAsymTreeLeaf>.Create(FConn, FCdsLeafTable,
                -1, FCdsMid);
end;

procedure TTestOneToOneNilAssociation.BuildRestTree;
begin
  FRestRootTable := TFDMemTable.Create(nil);
  FRestRoot := TRESTFDMemTableAdapter<TAsymTreeOneRoot>.Create(FRest,
                 FRestRootTable, -1, nil);
  FRestMidTable := TFDMemTable.Create(nil);
  FRestMid := TRESTFDMemTableAdapter<TAsymTreeMid>.Create(FRest, FRestMidTable,
                -1, FRestRoot);
  FRestLeafTable := TFDMemTable.Create(nil);
  FRestLeaf := TRESTFDMemTableAdapter<TAsymTreeLeaf>.Create(FRest,
                 FRestLeafTable, -1, FRestMid);
end;

procedure TTestOneToOneNilAssociation.BuildMtoTree;
begin
  FMtoRootTable := TFDMemTable.Create(nil);
  FMtoRoot := TFDMemTableAdapter<TAsymTreeManyRoot>.Create(FConn,
                FMtoRootTable, -1, nil);
  FMtoMidTable := TFDMemTable.Create(nil);
  FMtoMid := TFDMemTableAdapter<TAsymTreeMid>.Create(FConn, FMtoMidTable, -1,
               FMtoRoot);
  FMtoLeafTable := TFDMemTable.Create(nil);
  FMtoLeaf := TFDMemTableAdapter<TAsymTreeLeaf>.Create(FConn, FMtoLeafTable, -1,
                FMtoMid);
end;

/// TWO root rows, ONE middle row, ONE leaf row.
///
/// The second root row is not decoration: every assertion here reads the
/// root's own bound column, and with a single row that column would come out
/// right whether the read bound the current row or the first one. Two Appends
/// leave the cursor on the SECOND, so `P2` in a signature is the statement
/// that .Current bound the row the cursor was on.
///
/// `mparent` and `lparent` are typed by hand. The framework fetches a master's
/// values into a new child row only when that row has children of its own, so
/// the leaf - the last level - is never given anything, and a leaf whose
/// parent column stayed at its default cannot say which middle row it belongs
/// to.
procedure TTestOneToOneNilAssociation.SeedTwoRootsOneMidOneLeaf(
  const ARoot, AMid, ALeaf: TDataSet; const ARootTagColumn: String);
begin
  ARoot.Append;
  ARoot.FieldByName(ARootTagColumn).AsString := cROOT1;
  ARoot.Post;
  ARoot.Append;
  ARoot.FieldByName(ARootTagColumn).AsString := cROOT2;
  ARoot.Post;

  AMid.Append;
  AMid.FieldByName(cMIDTAG).AsString := cMID1;
  AMid.FieldByName(cMIDKEY).AsInteger := cMIDOWNKEY;
  if AMid.FieldByName(cMIDPARENT).IsNull then
    AMid.FieldByName(cMIDPARENT).AsInteger := 0;
  AMid.Post;

  ALeaf.Append;
  ALeaf.FieldByName(cLEAFTAG).AsString := cLEAF1;
  ALeaf.FieldByName(cLEAFPARENT).AsInteger := cMIDOWNKEY;
  ALeaf.Post;
end;

/// The middle object rendered: its tag, its own key, and its leaf list. Used
/// inside both root signatures so the two multiplicities are read through the
/// same renderer and a difference between them cannot come from the rendering.
function TTestOneToOneNilAssociation.MidGraph(const AMid: TAsymTreeMid): String;
var
  LLeaf: TAsymTreeLeaf;
begin
  if AMid = nil then
    Exit(cNILBRANCH);
  Result := AMid.mtag + '/' + IntToStr(AMid.mkey) + '[';
  for LLeaf in AMid.leafs do
    Result := Result + LLeaf.ltag + '/' + IntToStr(LLeaf.lparent) + ';';
  Result := Result + ']';
end;

function TTestOneToOneNilAssociation.OneRootGraph(
  const ARoot: TAsymTreeOneRoot): String;
begin
  Result := ARoot.ptag + '(' + MidGraph(ARoot.mid) + ')';
end;

function TTestOneToOneNilAssociation.ManyRootGraph(
  const ARoot: TAsymTreeManyRoot): String;
begin
  Result := ARoot.qtag + '(' + MidGraph(ARoot.mid) + ')';
end;

/// Every row of the grandchild dataset, tag and parent, walked with the scroll
/// events muted so counting the rows cannot be what destroys them.
function TTestOneToOneNilAssociation.LeafRows(const ADataSet: TDataSet): String;
var
  LMute: TScrollMute;
  LRows: Integer;
begin
  LMute := MuteScroll(ADataSet);
  try
    Result := '';
    LRows := 0;
    ADataSet.First;
    while (not ADataSet.Eof) and (LRows < cWALKCEIL) do
    begin
      Result := Result + ADataSet.FieldByName(cLEAFTAG).AsString + '/' +
                ADataSet.FieldByName(cLEAFPARENT).AsString + ';';
      Inc(LRows);
      ADataSet.Next;
    end;
    if Result = '' then
      Result := cNOROW;
  finally
    UnmuteScroll(ADataSet, LMute);
  end;
end;

procedure TTestOneToOneNilAssociation.Premise_IsObjectIsTrueForANilClassReference;
var
  LContext: TRttiContext;
  LProperty: TRttiProperty;
  LRoot: TAsymTreeOneRoot;
  LValue: TValue;
begin
  LContext := TRttiContext.Create;
  LRoot := TAsymTreeOneRoot.Create;
  try
    LProperty := LContext.GetType(TAsymTreeOneRoot).GetProperty('mid');
    Assert.IsNotNull(LProperty, 'premise: the property the walk reads exists');

    LValue := LProperty.GetValue(LRoot);

    Assert.IsTrue(LValue.IsObject,
      'IsObject is the guard _ExecuteOneToOne already had, and it answers ' +
      'TRUE over a nil reference - it classifies the TYPE, not the content. ' +
      'If this line ever goes red the repair below is redundant and should ' +
      'be removed rather than left as noise');
    Assert.IsTrue(LValue.AsObject = nil,
      'and what it let through really is nil - which is the pointer that ' +
      'reached AObject.ClassType inside Bind.SetFieldToProperty');
  finally
    LRoot.Free;
    LContext.Free;
  end;
end;

procedure TTestOneToOneNilAssociation.Premise_TheShippedModelDeliversTheAssociationNil;
var
  LRoot: TAsymTreeOneRoot;
begin
  BuildMemTree;

  // Safe on an empty root dataset whatever the state of the repair: .Current
  // returns FCurrentInternal on its RecordCount = 0 exit and walks nothing.
  LRoot := FMemRoot.Current;

  Assert.IsNotNull(LRoot, 'premise: the adapter hands back its entity');
  Assert.IsTrue(LRoot.mid = nil,
    'the entity the adapter carries arrives with its OneToOne association ' +
    'nil, and no constructor fills it in - the model header says so in as ' +
    'many words. A model changed to construct it would take the defect out ' +
    'of reach without repairing anything');
end;

procedure TTestOneToOneNilAssociation.Mem_ReadingCurrentWithTheAssociationNil_LeavesItNilAndBindsTheRest;
var
  LRoot: TAsymTreeOneRoot;
begin
  BuildMemTree;
  SeedTwoRootsOneMidOneLeaf(FMemRootTable, FMemMidTable, FMemLeafTable,
    cROOTTAG);

  LRoot := FMemRoot.Current;

  Assert.AreEqual(cROOT2 + '(' + cNILBRANCH + ')', OneRootGraph(LRoot), False,
    'the association was nil and it stays nil - the consumer gets back ' +
    'exactly the branch it had. And the rest of the graph still arrived: the ' +
    'root''s own column carries the SECOND row, the one the cursor was on. ' +
    'Before the repair this line was never reached - the read raised ' +
    'EAccessViolation inside Bind.SetFieldToProperty');
end;

procedure TTestOneToOneNilAssociation.Cds_ReadingCurrentWithTheAssociationNil_LeavesItNilAndBindsTheRest;
var
  LRoot: TAsymTreeOneRoot;
begin
  BuildCdsTree;
  SeedTwoRootsOneMidOneLeaf(FCdsRootTable, FCdsMidTable, FCdsLeafTable,
    cROOTTAG);

  LRoot := FCdsRoot.Current;

  Assert.AreEqual(cROOT2 + '(' + cNILBRANCH + ')', OneRootGraph(LRoot), False,
    'the ClientDataSet family answers the same. The walk lives on the shared ' +
    'base and is not virtual, so one repair reaching all three is expected - ' +
    'expected is not measured, and on issue #276 the three families did NOT ' +
    'answer alike');
end;

procedure TTestOneToOneNilAssociation.Rest_ReadingCurrentWithTheAssociationNil_LeavesItNilAndBindsTheRest;
var
  LRoot: TAsymTreeOneRoot;
begin
  BuildRestTree;
  SeedTwoRootsOneMidOneLeaf(FRestRootTable, FRestMidTable, FRestLeafTable,
    cROOTTAG);

  LRoot := FRestRoot.Current;

  Assert.AreEqual(cROOT2 + '(' + cNILBRANCH + ')', OneRootGraph(LRoot), False,
    'and so does the REST family, which reaches _ExecuteOneToOne through the ' +
    'same FillMastersClass even though its OpenDataSetChilds has an empty body');
end;

procedure TTestOneToOneNilAssociation.WithTheAssociationAssigned_TheWalkStillBuildsTheWholeBranch;
var
  LRoot: TAsymTreeOneRoot;
begin
  BuildMemTree;
  // Assigned while the root dataset is still empty, which is the only moment
  // .Current is reachable without the walk. The adapter owns the entity and
  // TAsymTreeOneRoot.Destroy frees this branch, so nothing here leaks.
  FMemRoot.Current.mid := TAsymTreeMid.Create;
  SeedTwoRootsOneMidOneLeaf(FMemRootTable, FMemMidTable, FMemLeafTable,
    cROOTTAG);

  LRoot := FMemRoot.Current;

  Assert.AreEqual(
    cROOT2 + '(' + cMID1 + '/' + IntToStr(cMIDOWNKEY) + '[' +
    cLEAF1 + '/' + IntToStr(cMIDOWNKEY) + ';])',
    OneRootGraph(LRoot), False,
    'with the association ASSIGNED the walk has to run exactly as before, ' +
    'both levels of it. This is the clause a repair phrased too widely - one ' +
    'that leaves the branch on anything, not only on nil - turns red, and it ' +
    'is the only one that does');
end;

procedure TTestOneToOneNilAssociation.TheNilRead_LeavesTheGrandchildRowsWhereTheyWere;
begin
  BuildMemTree;
  SeedTwoRootsOneMidOneLeaf(FMemRootTable, FMemMidTable, FMemLeafTable,
    cROOTTAG);

  Assert.AreEqual(cLEAF1 + '/' + IntToStr(cMIDOWNKEY) + ';',
    LeafRows(FMemLeafTable), False,
    'premise: the grandchild line is on screen before anything is read');

  FMemRoot.Current;

  Assert.AreEqual(cLEAF1 + '/' + IntToStr(cMIDOWNKEY) + ';',
    LeafRows(FMemLeafTable), False,
    'the nil is handed on TWICE in that method and only the first hand-off ' +
    'raises: the second passes it to FillMastersClass one level down. ' +
    'Leaving the walk before either of them has to cost the grandchild rows ' +
    'nothing - the same rows issue #276 was about');
end;

procedure TTestOneToOneNilAssociation.ManyToOne_ReadingCurrentWithTheAssociationNil_LeavesItNilAndBindsTheRest;
var
  LRoot: TAsymTreeManyRoot;
begin
  BuildMtoTree;
  SeedTwoRootsOneMidOneLeaf(FMtoRootTable, FMtoMidTable, FMtoLeafTable,
    cMANYTAG);

  LRoot := FMtoRoot.Current;

  Assert.AreEqual(cROOT2 + '(' + cNILBRANCH + ')', ManyRootGraph(LRoot), False,
    'FillMastersClass routes ManyToOne to _ExecuteOneToOne in the same ' +
    '`in [...]` set as OneToOne. Janus.DataSet.Events said so from commit ' +
    '6741bbe on, and said in the same breath that no test carried the label - ' +
    'a claim read off the source is not a measurement of it');
end;

procedure TTestOneToOneNilAssociation.ManyToOne_WithTheAssociationAssigned_TheWalkStillBuildsTheWholeBranch;
var
  LRoot: TAsymTreeManyRoot;
begin
  BuildMtoTree;
  FMtoRoot.Current.mid := TAsymTreeMid.Create;
  SeedTwoRootsOneMidOneLeaf(FMtoRootTable, FMtoMidTable, FMtoLeafTable,
    cMANYTAG);

  LRoot := FMtoRoot.Current;

  Assert.AreEqual(
    cROOT2 + '(' + cMID1 + '/' + IntToStr(cMIDOWNKEY) + '[' +
    cLEAF1 + '/' + IntToStr(cMIDOWNKEY) + ';])',
    ManyRootGraph(LRoot), False,
    'and the ManyToOne route still builds the whole branch when there is one ' +
    'to build. Without this the ManyToOne clause above would go green for a ' +
    'repair that stopped walking that multiplicity altogether');
end;

initialization
  // In `initialization` and not in a [Setup]: the mapping is read when the
  // first adapter over the entity is constructed, and a registration made
  // inside the fixture arrives after that.
  TRegisterClass.RegisterEntity(TAsymTreeManyRoot);
  TDUnitX.RegisterTestFixture(TTestOneToOneNilAssociation);

end.
