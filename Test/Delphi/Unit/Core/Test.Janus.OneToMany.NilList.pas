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

{ @abstract(Janus Framework - reading .Current with a list association left nil
  must leave it nil, not fall over.)

  WHAT IS UNDER TEST - issue #307

  TDataSetBaseAdapter<M>._ExecuteOneToMany, the branch FillMastersClass picks
  for a OneToMany or a ManyToMany association. For every child row that
  survives the foreign-key filter it read the owner's list property and called
  `Add` on whatever came back. On a list no constructor created that is a nil
  TObject, MethodCall reaches its ClassType, and the read of .Current raised
  EAccessViolation - not an exception a consumer's try..except can name, and
  raised on the READ path, which ApplyInserter takes on its own.

  THIS IS THE SIBLING OF #296 AND NOT THE SAME DEFECT. #296 repaired
  _ExecuteOneToOne, the single-object branch, and its own source comment records
  that the two were measured in ONE build at two DIFFERENT module offsets. The
  guard #296 installed is on HEAD while this fixture was first run, and every
  clause below raised anyway: that is the measurement, not the argument.

  THE OFFSETS THEMSELVES ARE NOT REPRODUCIBLE and this fixture deliberately does
  not turn one into an assertion. The run behind these clauses printed 7FB9B9
  for this site and 89F831 for the sibling; an independent reviewer, on the same
  commit in his own worktree, got 7FB9A1 and 89F819 - each exactly 0x18 lower. A
  module offset moves with the build environment and no anchor rescues it. WHAT
  IS STABLE IS THE DIFFERENCE: 0xA3E78 in both builds, byte for byte, which is
  what makes "two sites" a measurement rather than a coincidence.

  WHERE THE TWO DIFFER IN SHAPE, AND WHY THE GUARD IS NOT IN THE SAME PLACE

  The single-object branch can answer before it does anything: it reads the
  property once, at the top, and leaves. This one cannot. The list is read for
  a child ROW, and which rows there are is only known by walking the child
  cursor with the #295 foreign-key filter applied - so the exit sits inside the
  walk, at the first row that would have been added. It is placed BEFORE the
  child object is constructed on purpose: one line later and the exit would
  leak the object it had just created, since the list is the only thing that
  would have owned it. `Exit` from there still runs the three enclosing
  `finally` blocks, so the block-read mode goes back to zero, the bookmark is
  restored and freed, the #276 suppression is decremented and the two TField
  lists are freed. TheNilRead_LeavesTheGrandchildRowsWhereTheyWere is what
  holds the second of those.

  THE DECISION, AND WHOSE IT IS

  Three behaviours were on the table - exit in silence leaving the list nil,
  instantiate the list, or raise a named exception - ALL THREE WERE BUILT AND
  RUN, and the OWNER PICKED THE FIRST. These clauses assert a decision, not a
  survivor: the other two work, and the numbers are in the commit that installs
  this fixture.

  WHAT CLOSED IT is that the house already answers this exact question the same
  way one layer down. `if LObjectList = nil then Exit` appears FIVE times in
  Source\ - enumerated, not sampled - and two of them read a list property off
  an entity through RTTI, which is this question. TBind.SetFieldToPropertyClass
  is the identical one: same GetNullableValue(...).AsObject, same MethodCall on
  what comes back, same bare `Exit`. Its sibling in the same unit runs the
  opposite direction and answers the same way. Both are already in the first
  commit that carries the file. The other three answer a DIFFERENT question -
  a fetch that returned no list at all - with the same answer, and are counted
  so the precedent is not overstated. Any other answer here would put TWO
  answers to one question inside one framework, and would break symmetry with
  #296, this branch's sibling.

  INSTANTIATING WAS REFUSED ON A MEASUREMENT, not a preference. It passes
  everything except the four clauses that assert `<nil>`, and it hands the
  consumer a FULL list out of a property the entity never filled. The list it
  builds carries OwnsObjects=True - read back off the object the walk created -
  so it owns the child objects too, and nothing in the walk frees the list or
  its contents. That is a silent leak traded for an Access Violation that at
  least announces itself. Raising was refused because it needs a new exception
  class exported from a SHIPPED unit and answers the opposite way from #296.

  SO "IT DID NOT RAISE" IS NOT WHAT THESE CLAUSES ASSERT. That is the weakest
  assertion available and it goes green for a repair that quietly abandons the
  whole walk. Every clause asserts the GRAPH: the owner's own bound column, the
  state of the list, and - where there is one - the whole branch under it. And
  a nil list and an EMPTY list render differently on purpose, `<nil>` against
  `[]`: those two strings are exactly what separates the decision taken from
  the decision refused, and an assertion that could not tell them apart would
  not be measuring the decision at all.

  THE THREE FAMILIES ARE MEASURED, NOT INFERRED

  _ExecuteOneToMany is declared once, on the shared base TDataSetBaseAdapter<M>,
  and it is not virtual - so one repair reaching all three families is a
  reasonable expectation. It is only that until measured: on issue #276 the
  three families diverged and on #295 they converged, so the house rule is that
  this is asked and not assumed. FDMemTable, ClientDataSet and the REST
  FDMemTable each get their own clause.

  MANYTOMANY CARRIES ITS OWN LABEL HERE

  FillMastersClass routes OneToMany and ManyToMany to this branch in one
  `in [...]` set. Before this unit NOT ONE `[Association(...)]` ANYWHERE IN THE
  REPOSITORY carried TMultiplicity.ManyToMany - enumerated, not sampled: every
  other occurrence of the token is a routing test of the form `in [OneToMany,
  ManyToMany]` in Source\ or in a test, a prose comment, a docs page, or the
  integer legend of the DLL project. So the second half of that set was reached
  by nothing at all. TAsymTreeM2MRoot below is the first entity in the
  repository to declare it, and it is TAsymTreeNilListRoot with one token
  changed.

  WHAT THE REPOSITORY ITSELF SHIPS

  No model here delivers a nil list, and that is measured rather than quoted:
  Premise_TheModelsOfTheSuiteBuildTheirListEitherWay walks the two rescues the
  repository actually uses - a constructor that creates it (TAsymTreeRoot) and
  a Lazy<> declaration that materialises it on first read (TProcedimento, whose
  own constructor is empty). So this defect has no net in the suite, which is
  why #296 could add the equivalent guard here and see nothing go red. What a
  CONSUMER ships is the other question, and the Delphi default for a field
  nobody assigns is nil.

  WHAT WOULD KILL EACH CLAUSE - the mutations that were run are recorded in the
  commit that installs them, not here, so this header does not go stale when the
  next reader runs a different one.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`. }

unit Test.Janus.OneToMany.NilList;

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
  /// For TRttiPropertyHelper.GetNullableValue - the very call
  /// _ExecuteOneToMany makes to read the list off the owner.
  MetaDbDiff.RTTI.Helper,
  Janus.DataSet.Base.Adapter,
  Janus.DataSet.FDMemTable,
  Janus.DataSet.ClientDataSet,
  Janus.RestDataSet.FDMemTable,
  Janus.RestFactory.Interfaces,
  /// For TAsymTreeMid / TAsymTreeLeaf - the two levels under the roots
  /// declared here - and for TAsymTreeRoot, which is the constructor rescue
  /// the premise clause reads.
  Test.Janus.Model.AsymTree,
  /// For TProcedimento, the Lazy<> rescue. It is an EXAMPLE model, linked by
  /// this project already, and its constructor is empty.
  Model.Procedimento,
  /// For TRowsConnection, the IDBConnection double that hands out an empty
  /// cursor instead of nil.
  Test.Janus.Cursor.Double,
  /// For TInertRestConnection, the IRESTConnection double.
  Test.Janus.MasterDetail.Link;

type
  /// <summary> A OneToMany owner whose list NO CONSTRUCTOR CREATES - issue
  ///  #307. It has no constructor at all, which is what leaves `mids` at the
  ///  Delphi default for an unassigned object field: nil.
  ///
  ///  IT HANGS OFF THE SAME atmid ROWS as TAsymTreeRoot, through the same
  ///  `mparent` foreign key, so the level under measurement is byte for byte
  ///  the same entity and a difference between the two roots cannot come from
  ///  the level below.
  ///
  ///  IT EXISTS HERE AND NOT IN Test.Janus.Model.AsymTree because that unit is
  ///  compiled by Janus.Tests.RESTHorse as well, and a new registered entity
  ///  reaching a project that has no use for it is a change nobody asked for.
  ///  Same reasoning TAsymTreeManyRoot was declared under on #296. </summary>
  [Entity]
  [Table('atnml', '')]
  [PrimaryKey('nkey', TAutoIncType.AutoInc,
                      TGeneratorType.SequenceInc,
                      TSortingOrder.NoSort,
                      True, 'Primary key')]
  [Sequence('atnml')]
  TAsymTreeNilListRoot = class
  private
    Fnkey: Integer;
    Fntag: String;
    Fmids: TObjectList<TAsymTreeMid>;
  public
    destructor Destroy; override;

    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('nkey', ftInteger)]
    property nkey: Integer read Fnkey write Fnkey;

    [Column('ntag', ftString, 20)]
    property ntag: String read Fntag write Fntag;

    /// Nil on delivery. There is no constructor above to fill it in, which is
    /// the whole premise - and it is the DEFAULT a consumer gets by writing
    /// nothing, not a state anyone has to opt into.
    [Association(TMultiplicity.OneToMany, 'nkey', 'atmid', 'mparent')]
    [CascadeActions([TCascadeAction.CascadeAutoInc,
                     TCascadeAction.CascadeInsert,
                     TCascadeAction.CascadeUpdate,
                     TCascadeAction.CascadeDelete])]
    property mids: TObjectList<TAsymTreeMid> read Fmids write Fmids;
  end;

  /// <summary> The FIRST entity in the REPOSITORY to carry
  ///  TMultiplicity.ManyToMany - issue #307. FillMastersClass routes it to
  ///  _ExecuteOneToMany in the same `in [...]` set as OneToMany, and until this
  ///  declaration nothing anywhere reached that half of the set. Everything
  ///  else about it is TAsymTreeNilListRoot with one token changed. </summary>
  [Entity]
  [Table('atm2m', '')]
  [PrimaryKey('zkey', TAutoIncType.AutoInc,
                      TGeneratorType.SequenceInc,
                      TSortingOrder.NoSort,
                      True, 'Primary key')]
  [Sequence('atm2m')]
  TAsymTreeM2MRoot = class
  private
    Fzkey: Integer;
    Fztag: String;
    Fmids: TObjectList<TAsymTreeMid>;
  public
    destructor Destroy; override;

    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('zkey', ftInteger)]
    property zkey: Integer read Fzkey write Fzkey;

    [Column('ztag', ftString, 20)]
    property ztag: String read Fztag write Fztag;

    [Association(TMultiplicity.ManyToMany, 'zkey', 'atmid', 'mparent')]
    [CascadeActions([TCascadeAction.CascadeAutoInc,
                     TCascadeAction.CascadeInsert,
                     TCascadeAction.CascadeUpdate,
                     TCascadeAction.CascadeDelete])]
    property mids: TObjectList<TAsymTreeMid> read Fmids write Fmids;
  end;

  [TestFixture]
  TTestOneToManyNilList = class
  private
    FConn: IDBConnection;
    FRest: IRESTConnection;
    /// FDMemTable family.
    FMemRootTable: TFDMemTable;
    FMemMidTable: TFDMemTable;
    FMemLeafTable: TFDMemTable;
    FMemRoot: TFDMemTableAdapter<TAsymTreeNilListRoot>;
    FMemMid: TFDMemTableAdapter<TAsymTreeMid>;
    FMemLeaf: TFDMemTableAdapter<TAsymTreeLeaf>;
    /// ClientDataSet family.
    FCdsRootTable: TClientDataSet;
    FCdsMidTable: TClientDataSet;
    FCdsLeafTable: TClientDataSet;
    FCdsRoot: TClientDataSetAdapter<TAsymTreeNilListRoot>;
    FCdsMid: TClientDataSetAdapter<TAsymTreeMid>;
    FCdsLeaf: TClientDataSetAdapter<TAsymTreeLeaf>;
    /// REST family.
    FRestRootTable: TFDMemTable;
    FRestMidTable: TFDMemTable;
    FRestLeafTable: TFDMemTable;
    FRestRoot: TRESTFDMemTableAdapter<TAsymTreeNilListRoot>;
    FRestMid: TRESTFDMemTableAdapter<TAsymTreeMid>;
    FRestLeaf: TRESTFDMemTableAdapter<TAsymTreeLeaf>;
    /// The ManyToMany owner, FDMemTable family.
    FM2mRootTable: TFDMemTable;
    FM2mMidTable: TFDMemTable;
    FM2mLeafTable: TFDMemTable;
    FM2mRoot: TFDMemTableAdapter<TAsymTreeM2MRoot>;
    FM2mMid: TFDMemTableAdapter<TAsymTreeMid>;
    FM2mLeaf: TFDMemTableAdapter<TAsymTreeLeaf>;
    procedure BuildMemTree;
    procedure BuildCdsTree;
    procedure BuildRestTree;
    procedure BuildM2mTree;
    procedure SeedTwoRootsOneMidOneLeaf(const ARoot, AMid, ALeaf: TDataSet;
      const ARootKeyColumn, ARootTagColumn: String;
      const ASecondMid: Boolean = False);
    function MidsGraph(const AMids: TObjectList<TAsymTreeMid>): String;
    function NilListRootGraph(const ARoot: TAsymTreeNilListRoot): String;
    function M2mRootGraph(const ARoot: TAsymTreeM2MRoot): String;
    function LeafRows(const ADataSet: TDataSet): String;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // -----------------------------------------------------------------------
    // The premises the whole issue rests on
    // -----------------------------------------------------------------------

    /// The state under test really is what a declaration without a constructor
    /// delivers. Read off the adapter's own entity, which is what .Current
    /// hands back.
    [Test]
    procedure Premise_AListPropertyNoConstructorFillsArrivesNil;
    /// And it reaches the walk as a nil TObject through the very call the walk
    /// makes - TRttiProperty.GetNullableValue(...).AsObject - so the repair is
    /// answering the pointer the defect was about and not a different one.
    [Test]
    procedure Premise_TheWalksOwnReadOfThatPropertyAnswersANilObject;
    /// The two rescues the repository actually uses, so "no model here ships a
    /// nil list" is measured and not asserted from reading. One constructor
    /// that creates the list, one Lazy<> declaration behind an EMPTY
    /// constructor that materialises it on first read.
    [Test]
    procedure Premise_TheModelsOfTheSuiteBuildTheirListEitherWay;

    // -----------------------------------------------------------------------
    // The three families
    // -----------------------------------------------------------------------

    /// FDMemTable. Two owner rows so the bound tag says WHICH row was read,
    /// one middle row keyed to the second of them, and one leaf row under the
    /// middle one - so the walk the nil short-circuits would have had
    /// something to do at both levels.
    [Test]
    procedure Mem_ReadingCurrentWithTheListNil_LeavesItNilAndBindsTheRest;
    /// ClientDataSet - a different TDataSet descendant behind the same base
    /// adapter.
    [Test]
    procedure Cds_ReadingCurrentWithTheListNil_LeavesItNilAndBindsTheRest;
    /// REST. TRESTDataSetAdapter<M> overrides OpenDataSetChilds with an empty
    /// body and reaches _ExecuteOneToMany through the same FillMastersClass,
    /// so it is the family least likely to differ - which is not a reason to
    /// leave it unasked.
    [Test]
    procedure Rest_ReadingCurrentWithTheListNil_LeavesItNilAndBindsTheRest;

    // -----------------------------------------------------------------------
    // What the silence must NOT cost
    // -----------------------------------------------------------------------

    /// The other side of the repair, and the clause that dies if the new exit
    /// is phrased too widely. With the list ASSIGNED the walk has to run
    /// exactly as before: the middle object built from the middle row, added
    /// to the list, AND its own leaf list built from the level below.
    [Test]
    procedure WithTheListAssigned_TheWalkStillBuildsTheWholeBranch;
    /// An assigned list must still be FILTERED by the association's foreign
    /// key - the #295 contract. Two owner rows, one middle row under each: the
    /// second owner gets its own middle row and not both. Without this the
    /// clause above would go green for an exit moved above the filter.
    [Test]
    procedure WithTheListAssigned_TheOwnerStillGetsOnlyItsOwnChildRows;
    /// The grandchild rows the operator typed are still there, untouched,
    /// after the read that found the nil - the same rows issue #276 was about.
    /// The exit sits INSIDE the walk, so it runs with a bookmark taken and the
    /// suppression raised, and both have to be given back.
    [Test]
    procedure TheNilRead_LeavesTheGrandchildRowsWhereTheyWere;
    /// And the child cursor is where it was. The exit is inside the block that
    /// takes the bookmark; leaving without restoring it parks the child
    /// dataset on a row the operator was not on.
    [Test]
    procedure TheNilRead_LeavesTheChildCursorWhereItWas;

    // -----------------------------------------------------------------------
    // The other multiplicity that routes through the same branch
    // -----------------------------------------------------------------------

    /// The ManyToMany label, carried by an entity for the first time in this
    /// repository.
    [Test]
    procedure ManyToMany_ReadingCurrentWithTheListNil_LeavesItNilAndBindsTheRest;
    /// And the same sibling guard on the ManyToMany route: assigned, it still
    /// builds the branch. Without this the ManyToMany clause above would go
    /// green for a repair that stopped walking that multiplicity altogether.
    [Test]
    procedure ManyToMany_WithTheListAssigned_TheWalkStillBuildsTheWholeBranch;
  end;

implementation

const
  cROOTKEY    = 'nkey';
  cROOTTAG    = 'ntag';
  cM2MKEY     = 'zkey';
  cM2MTAG     = 'ztag';
  cMIDTAG     = 'mtag';
  cMIDKEY     = 'mkey';
  cMIDPARENT  = 'mparent';
  cLEAFTAG    = 'ltag';
  cLEAFPARENT = 'lparent';

  cROOT1      = 'P1';
  cROOT2      = 'P2';
  cMID1       = 'AM1';
  cMID2       = 'AM2';
  cLEAF1      = 'AL1';
  /// The two owner keys. Different numbers, and neither of them is a value any
  /// other column in the tree carries, so a middle row that arrived under the
  /// wrong owner cannot read as if it had arrived under the right one.
  cROOTKEY1   = 101;
  cROOTKEY2   = 202;
  /// The middle row's own key, and the value the leaf row names as its parent.
  cMIDOWNKEY  = 311;
  cMIDOWNKEY2 = 312;
  /// What a nil list renders as. NOT the same string as an empty list: those
  /// two are the decision taken and the decision refused, and an assertion
  /// that could not tell them apart would not be measuring the decision.
  cNILLIST    = '<nil>';
  cEMPTYLIST  = '[]';
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

{ TAsymTreeNilListRoot }

destructor TAsymTreeNilListRoot.Destroy;
begin
  /// Free on nil is a no-op, so this destructor is correct for the shape the
  /// entity ships in AND for the shape a fixture hands it after assigning the
  /// list by hand.
  Fmids.Free;
  inherited;
end;

{ TAsymTreeM2MRoot }

destructor TAsymTreeM2MRoot.Destroy;
begin
  Fmids.Free;
  inherited;
end;

{ TTestOneToManyNilList }

procedure TTestOneToManyNilList.Setup;
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
    'onetomany-nil');
  FRest := TInertRestConnection.Create;
end;

procedure TTestOneToManyNilList.TearDown;
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
  FreeAndNil(FM2mLeaf);
  FreeAndNil(FM2mMid);
  FreeAndNil(FM2mRoot);
  FreeAndNil(FM2mLeafTable);
  FreeAndNil(FM2mMidTable);
  FreeAndNil(FM2mRootTable);
  FRest := nil;
  FConn := nil;
end;

procedure TTestOneToManyNilList.BuildMemTree;
begin
  FMemRootTable := TFDMemTable.Create(nil);
  FMemRoot := TFDMemTableAdapter<TAsymTreeNilListRoot>.Create(FConn,
                FMemRootTable, -1, nil);
  FMemMidTable := TFDMemTable.Create(nil);
  FMemMid := TFDMemTableAdapter<TAsymTreeMid>.Create(FConn, FMemMidTable, -1,
               FMemRoot);
  FMemLeafTable := TFDMemTable.Create(nil);
  FMemLeaf := TFDMemTableAdapter<TAsymTreeLeaf>.Create(FConn, FMemLeafTable, -1,
                FMemMid);
end;

procedure TTestOneToManyNilList.BuildCdsTree;
begin
  FCdsRootTable := TClientDataSet.Create(nil);
  FCdsRoot := TClientDataSetAdapter<TAsymTreeNilListRoot>.Create(FConn,
                FCdsRootTable, -1, nil);
  FCdsMidTable := TClientDataSet.Create(nil);
  FCdsMid := TClientDataSetAdapter<TAsymTreeMid>.Create(FConn, FCdsMidTable, -1,
               FCdsRoot);
  FCdsLeafTable := TClientDataSet.Create(nil);
  FCdsLeaf := TClientDataSetAdapter<TAsymTreeLeaf>.Create(FConn, FCdsLeafTable,
                -1, FCdsMid);
end;

procedure TTestOneToManyNilList.BuildRestTree;
begin
  FRestRootTable := TFDMemTable.Create(nil);
  FRestRoot := TRESTFDMemTableAdapter<TAsymTreeNilListRoot>.Create(FRest,
                 FRestRootTable, -1, nil);
  FRestMidTable := TFDMemTable.Create(nil);
  FRestMid := TRESTFDMemTableAdapter<TAsymTreeMid>.Create(FRest, FRestMidTable,
                -1, FRestRoot);
  FRestLeafTable := TFDMemTable.Create(nil);
  FRestLeaf := TRESTFDMemTableAdapter<TAsymTreeLeaf>.Create(FRest,
                 FRestLeafTable, -1, FRestMid);
end;

procedure TTestOneToManyNilList.BuildM2mTree;
begin
  FM2mRootTable := TFDMemTable.Create(nil);
  FM2mRoot := TFDMemTableAdapter<TAsymTreeM2MRoot>.Create(FConn, FM2mRootTable,
                -1, nil);
  FM2mMidTable := TFDMemTable.Create(nil);
  FM2mMid := TFDMemTableAdapter<TAsymTreeMid>.Create(FConn, FM2mMidTable, -1,
               FM2mRoot);
  FM2mLeafTable := TFDMemTable.Create(nil);
  FM2mLeaf := TFDMemTableAdapter<TAsymTreeLeaf>.Create(FConn, FM2mLeafTable, -1,
                FM2mMid);
end;

/// TWO owner rows, ONE middle row, ONE leaf row.
///
/// The second owner row is not decoration, and here it does TWO jobs. Every
/// assertion reads the owner's own bound column, and with a single row that
/// column would come out right whether the read bound the current row or the
/// first one; two Appends leave the cursor on the SECOND, so `P2` in a
/// signature is the statement that .Current bound the row the cursor was on.
/// And with two owner rows the #295 foreign-key filter is ARMED -
/// _ForeignKeyFieldPairs returns an empty list, and admits everything, when
/// the master holds a single row. So the middle row has to name its owner, and
/// it names the second one.
///
/// The owner keys are typed by hand for the same reason: the framework fetches
/// a master's values into a new child row, but the owner's own key is the
/// AutoInc placeholder until something generates it, and two rows that carry
/// the same placeholder are not two parents.
///
/// ASecondMid adds a middle row under the FIRST owner, which arms the same
/// filter one level down as well.
///
/// THE LEAF ROW IS APPENDED LAST AND THAT ORDER IS LOAD-BEARING, measured the
/// hard way: with the leaf typed before the second middle row, the Append on
/// the middle dataset fires its own AfterScroll, TDataSetAdapter<M> re-opens
/// the leaf dataset, and the leaf row is gone before the read under test ever
/// happens - the exact behaviour issue #276 is about, here as a fixture
/// hazard rather than as the thing under test. The first run of this unit had
/// the two the other way round and WithTheListAssigned_TheOwnerStillGets...
/// came back `AM1/311{}`: the middle object was right and its leaf list was
/// empty, because there was no leaf row left in the dataset to find.
procedure TTestOneToManyNilList.SeedTwoRootsOneMidOneLeaf(
  const ARoot, AMid, ALeaf: TDataSet;
  const ARootKeyColumn, ARootTagColumn: String;
  const ASecondMid: Boolean);
begin
  ARoot.Append;
  ARoot.FieldByName(ARootKeyColumn).AsInteger := cROOTKEY1;
  ARoot.FieldByName(ARootTagColumn).AsString := cROOT1;
  ARoot.Post;
  ARoot.Append;
  ARoot.FieldByName(ARootKeyColumn).AsInteger := cROOTKEY2;
  ARoot.FieldByName(ARootTagColumn).AsString := cROOT2;
  ARoot.Post;

  AMid.Append;
  AMid.FieldByName(cMIDTAG).AsString := cMID1;
  AMid.FieldByName(cMIDKEY).AsInteger := cMIDOWNKEY;
  AMid.FieldByName(cMIDPARENT).AsInteger := cROOTKEY2;
  AMid.Post;

  if ASecondMid then
  begin
    AMid.Append;
    AMid.FieldByName(cMIDTAG).AsString := cMID2;
    AMid.FieldByName(cMIDKEY).AsInteger := cMIDOWNKEY2;
    AMid.FieldByName(cMIDPARENT).AsInteger := cROOTKEY1;
    AMid.Post;
  end;

  ALeaf.Append;
  ALeaf.FieldByName(cLEAFTAG).AsString := cLEAF1;
  ALeaf.FieldByName(cLEAFPARENT).AsInteger := cMIDOWNKEY;
  ALeaf.Post;
end;

/// The list rendered, and the three states it can be in are three different
/// strings: nil, empty, and populated. Used inside both owner signatures so
/// the two multiplicities are read through the same renderer and a difference
/// between them cannot come from the rendering.
function TTestOneToManyNilList.MidsGraph(
  const AMids: TObjectList<TAsymTreeMid>): String;
var
  LMid: TAsymTreeMid;
  LLeaf: TAsymTreeLeaf;
begin
  if AMids = nil then
    Exit(cNILLIST);
  if AMids.Count = 0 then
    Exit(cEMPTYLIST);
  Result := '[';
  for LMid in AMids do
  begin
    Result := Result + LMid.mtag + '/' + IntToStr(LMid.mkey) + '{';
    for LLeaf in LMid.leafs do
      Result := Result + LLeaf.ltag + '/' + IntToStr(LLeaf.lparent) + ';';
    Result := Result + '};';
  end;
  Result := Result + ']';
end;

function TTestOneToManyNilList.NilListRootGraph(
  const ARoot: TAsymTreeNilListRoot): String;
begin
  Result := ARoot.ntag + '(' + MidsGraph(ARoot.mids) + ')';
end;

function TTestOneToManyNilList.M2mRootGraph(
  const ARoot: TAsymTreeM2MRoot): String;
begin
  Result := ARoot.ztag + '(' + MidsGraph(ARoot.mids) + ')';
end;

/// Every row of the grandchild dataset, tag and parent, walked with the scroll
/// events muted so counting the rows cannot be what destroys them.
function TTestOneToManyNilList.LeafRows(const ADataSet: TDataSet): String;
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

procedure TTestOneToManyNilList.Premise_AListPropertyNoConstructorFillsArrivesNil;
var
  LRoot: TAsymTreeNilListRoot;
begin
  BuildMemTree;

  // Safe on an empty owner dataset whatever the state of the repair: .Current
  // returns FCurrentInternal on its RecordCount = 0 exit and walks nothing.
  LRoot := FMemRoot.Current;

  Assert.IsNotNull(LRoot, 'premise: the adapter hands back its entity');
  Assert.IsTrue(LRoot.mids = nil,
    'the entity the adapter carries arrives with its OneToMany list nil, ' +
    'because nothing constructs it - the entity has no constructor at all. ' +
    'An entity changed to build the list would take the defect out of reach ' +
    'without repairing anything');
end;

procedure TTestOneToManyNilList.Premise_TheWalksOwnReadOfThatPropertyAnswersANilObject;
var
  LContext: TRttiContext;
  LProperty: TRttiProperty;
  LRoot: TAsymTreeNilListRoot;
  LValue: TValue;
begin
  LContext := TRttiContext.Create;
  LRoot := TAsymTreeNilListRoot.Create;
  try
    LProperty := LContext.GetType(TAsymTreeNilListRoot).GetProperty('mids');
    Assert.IsNotNull(LProperty, 'premise: the property the walk reads exists');

    LValue := LProperty.GetNullableValue(LRoot);

    Assert.IsTrue(LValue.AsObject = nil,
      'the walk reads the list through TRttiProperty.GetNullableValue and ' +
      'takes .AsObject off it, and over this entity that answer is a nil ' +
      'TObject. That nil is the pointer MethodCall(''Add'', ...) dereferenced');
  finally
    LRoot.Free;
    LContext.Free;
  end;
end;

procedure TTestOneToManyNilList.Premise_TheModelsOfTheSuiteBuildTheirListEitherWay;
var
  LCtorRescued: TAsymTreeRoot;
  LLazyRescued: TProcedimento;
begin
  // The constructor rescue: the SAME two lower levels as the entity under
  // test, under an owner that does build its list.
  LCtorRescued := TAsymTreeRoot.Create;
  try
    Assert.IsNotNull(LCtorRescued.mids,
      'the shipped OneToMany owner of this model builds its list in its own ' +
      'constructor, which is why nothing in the suite drove the defect - ' +
      'issue #296 measured that from the other side, by adding the guard here ' +
      'and seeing nothing go red');
  finally
    LCtorRescued.Free;
  end;

  // The Lazy rescue, and the reason "every model builds it in its
  // CONSTRUCTOR" is too narrow a sentence: this one's constructor is empty.
  LLazyRescued := TProcedimento.Create;
  try
    Assert.IsNotNull(LLazyRescued.SetoresList,
      'a Lazy<TObjectList<T>> association materialises an empty owning list ' +
      'on first read, through Lazy<T>.GetValue and CreateDefaultValue, so it ' +
      'is never nil when the walk reads it - and its owner''s constructor is ' +
      'EMPTY. Lazy<> already answers this defect in practice; a plain ' +
      'TObjectList<T> field does not');
  finally
    LLazyRescued.Free;
  end;
end;

procedure TTestOneToManyNilList.Mem_ReadingCurrentWithTheListNil_LeavesItNilAndBindsTheRest;
var
  LRoot: TAsymTreeNilListRoot;
begin
  BuildMemTree;
  SeedTwoRootsOneMidOneLeaf(FMemRootTable, FMemMidTable, FMemLeafTable,
    cROOTKEY, cROOTTAG);

  LRoot := FMemRoot.Current;

  Assert.AreEqual(cROOT2 + '(' + cNILLIST + ')', NilListRootGraph(LRoot), False,
    'the list was nil and it stays nil - the consumer gets back exactly the ' +
    'branch it had, and NOT an empty list, which would be a different ' +
    'decision. And the rest of the graph still arrived: the owner''s own ' +
    'column carries the SECOND row, the one the cursor was on. Before the ' +
    'repair this line was never reached - the read raised EAccessViolation ' +
    'inside MethodCall(''Add'', ...)');
end;

procedure TTestOneToManyNilList.Cds_ReadingCurrentWithTheListNil_LeavesItNilAndBindsTheRest;
var
  LRoot: TAsymTreeNilListRoot;
begin
  BuildCdsTree;
  SeedTwoRootsOneMidOneLeaf(FCdsRootTable, FCdsMidTable, FCdsLeafTable,
    cROOTKEY, cROOTTAG);

  LRoot := FCdsRoot.Current;

  Assert.AreEqual(cROOT2 + '(' + cNILLIST + ')', NilListRootGraph(LRoot), False,
    'the ClientDataSet family answers the same. The walk lives on the shared ' +
    'base and is not virtual, so one repair reaching all three is expected - ' +
    'expected is not measured, and on issue #276 the three families did NOT ' +
    'answer alike');
end;

procedure TTestOneToManyNilList.Rest_ReadingCurrentWithTheListNil_LeavesItNilAndBindsTheRest;
var
  LRoot: TAsymTreeNilListRoot;
begin
  BuildRestTree;
  SeedTwoRootsOneMidOneLeaf(FRestRootTable, FRestMidTable, FRestLeafTable,
    cROOTKEY, cROOTTAG);

  LRoot := FRestRoot.Current;

  Assert.AreEqual(cROOT2 + '(' + cNILLIST + ')', NilListRootGraph(LRoot), False,
    'and so does the REST family, which reaches _ExecuteOneToMany through the ' +
    'same FillMastersClass even though its OpenDataSetChilds has an empty body');
end;

procedure TTestOneToManyNilList.WithTheListAssigned_TheWalkStillBuildsTheWholeBranch;
var
  LRoot: TAsymTreeNilListRoot;
begin
  BuildMemTree;
  // Assigned while the owner dataset is still empty, which is the only moment
  // .Current is reachable without the walk. The adapter owns the entity and
  // TAsymTreeNilListRoot.Destroy frees this list, so nothing here leaks.
  FMemRoot.Current.mids := TObjectList<TAsymTreeMid>.Create;
  SeedTwoRootsOneMidOneLeaf(FMemRootTable, FMemMidTable, FMemLeafTable,
    cROOTKEY, cROOTTAG);

  LRoot := FMemRoot.Current;

  Assert.AreEqual(
    cROOT2 + '([' + cMID1 + '/' + IntToStr(cMIDOWNKEY) + '{' +
    cLEAF1 + '/' + IntToStr(cMIDOWNKEY) + ';};])',
    NilListRootGraph(LRoot), False,
    'with the list ASSIGNED the walk has to run exactly as before, both ' +
    'levels of it. This is the clause a repair phrased too widely - one that ' +
    'leaves the walk on anything, not only on nil - turns red');
end;

procedure TTestOneToManyNilList.WithTheListAssigned_TheOwnerStillGetsOnlyItsOwnChildRows;
var
  LRoot: TAsymTreeNilListRoot;
begin
  BuildMemTree;
  // The SECOND middle row hangs off the FIRST owner. The cursor is on the
  // second owner, so that row must not appear in what comes back.
  FMemRoot.Current.mids := TObjectList<TAsymTreeMid>.Create;
  SeedTwoRootsOneMidOneLeaf(FMemRootTable, FMemMidTable, FMemLeafTable,
    cROOTKEY, cROOTTAG, True);

  LRoot := FMemRoot.Current;

  Assert.AreEqual(
    cROOT2 + '([' + cMID1 + '/' + IntToStr(cMIDOWNKEY) + '{' +
    cLEAF1 + '/' + IntToStr(cMIDOWNKEY) + ';};])',
    NilListRootGraph(LRoot), False,
    'the #295 foreign-key filter is still doing its job under the new exit: ' +
    'the owner gets the middle row that names IT and not the one that names ' +
    'its sibling. A guard hoisted above the walk would still pass the clause ' +
    'before this one and would not obviously fail here either - what this ' +
    'clause pins is that the filter was not the thing that got skipped');
end;

procedure TTestOneToManyNilList.TheNilRead_LeavesTheGrandchildRowsWhereTheyWere;
begin
  BuildMemTree;
  SeedTwoRootsOneMidOneLeaf(FMemRootTable, FMemMidTable, FMemLeafTable,
    cROOTKEY, cROOTTAG);

  Assert.AreEqual(cLEAF1 + '/' + IntToStr(cMIDOWNKEY) + ';',
    LeafRows(FMemLeafTable), False,
    'premise: the grandchild line is on screen before anything is read');

  FMemRoot.Current;

  Assert.AreEqual(cLEAF1 + '/' + IntToStr(cMIDOWNKEY) + ';',
    LeafRows(FMemLeafTable), False,
    'the exit sits INSIDE the walk - after the bookmark is taken and the ' +
    '#276 suppression raised - so leaving through it must cost the ' +
    'grandchild rows nothing. An exit written outside those try..finally ' +
    'blocks leaves the suppression raised and the child dataset in block-read ' +
    'mode, and the next scroll destroys these rows');
end;

procedure TTestOneToManyNilList.TheNilRead_LeavesTheChildCursorWhereItWas;
var
  LMute: TScrollMute;
  LBefore: String;
begin
  // A second middle row, so "where the cursor was" is a statement with more
  // than one possible answer. The Appends leave it on the second.
  BuildMemTree;
  SeedTwoRootsOneMidOneLeaf(FMemRootTable, FMemMidTable, FMemLeafTable,
    cROOTKEY, cROOTTAG, True);

  LMute := MuteScroll(FMemMidTable);
  try
    LBefore := FMemMidTable.FieldByName(cMIDTAG).AsString;
  finally
    UnmuteScroll(FMemMidTable, LMute);
  end;
  Assert.AreEqual(cMID2, LBefore, False,
    'premise: the child cursor is on the second middle row, not the first');

  FMemRoot.Current;

  LMute := MuteScroll(FMemMidTable);
  try
    Assert.AreEqual(cMID2, FMemMidTable.FieldByName(cMIDTAG).AsString, False,
      'the exit runs with a bookmark taken and block-read mode raised, and ' +
      'the enclosing finally has to give both back. An Exit written before ' +
      'the try, or a repair that returns from inside the block without one, ' +
      'parks the child dataset on its FIRST row - which is what the operator ' +
      'sees in the grid');
  finally
    UnmuteScroll(FMemMidTable, LMute);
  end;
end;

procedure TTestOneToManyNilList.ManyToMany_ReadingCurrentWithTheListNil_LeavesItNilAndBindsTheRest;
var
  LRoot: TAsymTreeM2MRoot;
begin
  BuildM2mTree;
  SeedTwoRootsOneMidOneLeaf(FM2mRootTable, FM2mMidTable, FM2mLeafTable,
    cM2MKEY, cM2MTAG);

  LRoot := FM2mRoot.Current;

  Assert.AreEqual(cROOT2 + '(' + cNILLIST + ')', M2mRootGraph(LRoot), False,
    'FillMastersClass routes ManyToMany to _ExecuteOneToMany in the same ' +
    '`in [...]` set as OneToMany. Until this entity existed NOTHING in the ' +
    'repository declared that multiplicity, so the second half of that set ' +
    'was reached by nothing at all - readable off the source is not measured');
end;

procedure TTestOneToManyNilList.ManyToMany_WithTheListAssigned_TheWalkStillBuildsTheWholeBranch;
var
  LRoot: TAsymTreeM2MRoot;
begin
  BuildM2mTree;
  FM2mRoot.Current.mids := TObjectList<TAsymTreeMid>.Create;
  SeedTwoRootsOneMidOneLeaf(FM2mRootTable, FM2mMidTable, FM2mLeafTable,
    cM2MKEY, cM2MTAG);

  LRoot := FM2mRoot.Current;

  Assert.AreEqual(
    cROOT2 + '([' + cMID1 + '/' + IntToStr(cMIDOWNKEY) + '{' +
    cLEAF1 + '/' + IntToStr(cMIDOWNKEY) + ';};])',
    M2mRootGraph(LRoot), False,
    'and the ManyToMany route still builds the whole branch when there is one ' +
    'to build. Without this the ManyToMany clause above would go green for a ' +
    'repair that stopped walking that multiplicity altogether');
end;

initialization
  // In `initialization` and not in a [Setup]: the mapping is read when the
  // first adapter over the entity is constructed, and a registration made
  // inside the fixture arrives after that.
  TRegisterClass.RegisterEntity(TAsymTreeNilListRoot);
  TRegisterClass.RegisterEntity(TAsymTreeM2MRoot);
  TDUnitX.RegisterTestFixture(TTestOneToManyNilList);

end.
