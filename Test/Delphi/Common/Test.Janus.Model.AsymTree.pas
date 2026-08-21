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

{ @abstract(Janus Framework - test fixture: a THREE level tree whose keys are
  asymmetric at every level.)

  WHY A THIRD LEVEL EXISTS

  Test.Janus.Model.AsymKey already makes master and child impossible to
  confuse, but it stops at two levels. Two levels cannot reach the autoinc
  propagation that runs INSIDE the cascade loop: the master's own key is
  pushed down by Insert, before any cascade, and the step under test is the
  one that runs after a CHILD is inserted and pushes THAT child's fresh key
  on to ITS OWN children. With only two levels the child has no children, the
  step is a no-op, and it does not matter which class's key mapping was read.

  WHY THE NAMES ARE ALL DIFFERENT

  Every column name in the tree is unique - rkey, mkey, lkey, mparent,
  lparent. Nothing is spelled the same at two levels, so a step that looks up
  a column name against the WRONG entity's key mapping cannot resolve by
  coincidence: it either finds the name it was meant to find, or it finds
  nothing at all.

  Measured on the tree as it stood before this unit: the only three level
  model compiled by the suite was Test.Janus.Model.AutoIncTree, and there the
  mid level's association carried `root_id` - the ROOT's key name, not the
  mid's own key name (`mid_id`). That single reused spelling is what made
  the two readings indistinguishable there.

  Issue #244 has since corrected that fixture: its mid level now names its own
  `mid_id`, so the ROOT's key name is no longer reused one level down. What
  #244 did NOT change is that every association in it names the SAME column at
  both ends - `root_id` -> `root_id`, `mid_id` -> `mid_id`. A wiring that feeds
  the master's column name where the child's belongs still builds the identical
  string there. That is the confusion this unit removes, and it is why the two
  fixtures are not interchangeable: AutoIncTree is the canonical shape,
  AsymTree is the one that makes this family of defects visible.

  THE SHAPE

      atroot.rkey  --(OneToMany)-->  atmid.mparent
      atmid.mkey   --(OneToMany)-->  atleaf.lparent

  A SECOND ROOT, LINKED ONE TO ONE - issue #239

      atpair.pkey  --(OneToOne)-->   atmid.mparent
      atmid.mkey   --(OneToMany)-->  atleaf.lparent   (the same mid and leaf)

  The multiplicity of the TOP association is what picks the handler:
  CascadeActionsExecute sends OneToOne and ManyToOne to
  OneToOneCascadeActionsExecute and OneToMany / ManyToMany to
  OneToManyCascadeActionsExecute. atroot therefore only ever reaches the
  OneToMany handler. Measured before atpair existed: neither of the two model
  units Janus.Tests.RESTHorse compiles - RestHorseTest.Models and this one -
  declared a single OneToOne or ManyToOne association, so no fixture of that
  project could reach the OneToOne handler at all.

  atpair reuses atmid and atleaf verbatim rather than cloning them, so the
  level under measurement is byte for byte the same entity in both shapes and
  the key names stay spelled once each - pkey, mkey, lkey, mparent, lparent.
  atmid.mparent doubles as the foreign key of both roots; only one root type
  is ever exercised in a given test.

  atpair does NOT create its `mid` in a constructor. A test that needs the
  server's `else` branch - the one that fires when the child is absent from
  the state snapshot - has to be able to hand Modify a root whose branch is
  still nil.

  Reading the attribute: Association(AMultiplicity, AColumnsName,
  ATableNameRef, AColumnsNameRef). ColumnsName is the column on the DECLARING
  entity; ColumnsNameRef is the column on the REFERENCED table. Each level
  therefore declares its OWN primary key as ColumnsName, which is the shape a
  propagation step keyed on the child's own key can satisfy and a step keyed
  on the master's key cannot.

  CascadeAutoInc is present at both levels: without it the propagation walker
  skips the association before any key mapping is consulted.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Model.AsymTree;

interface

uses
  Classes,
  DB,
  SysUtils,
  Generics.Collections,
  MetaDbDiff.mapping.attributes,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Register;

type
  [Entity]
  [Table('atleaf', '')]
  [PrimaryKey('lkey', TAutoIncType.AutoInc,
                      TGeneratorType.SequenceInc,
                      TSortingOrder.NoSort,
                      True, 'Primary key')]
  [Sequence('atleaf')]
  TAsymTreeLeaf = class
  private
    Flkey: Integer;
    Flparent: Integer;
    Fltag: String;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('lkey', ftInteger)]
    property lkey: Integer read Flkey write Flkey;

    /// The foreign key onto atmid.mkey. Deliberately NOT called `mkey`.
    [Column('lparent', ftInteger)]
    property lparent: Integer read Flparent write Flparent;

    [Column('ltag', ftString, 20)]
    property ltag: String read Fltag write Fltag;
  end;

  [Entity]
  [Table('atmid', '')]
  [PrimaryKey('mkey', TAutoIncType.AutoInc,
                      TGeneratorType.SequenceInc,
                      TSortingOrder.NoSort,
                      True, 'Primary key')]
  [Sequence('atmid')]
  TAsymTreeMid = class
  private
    Fmkey: Integer;
    Fmparent: Integer;
    Fmtag: String;
    Fleafs: TObjectList<TAsymTreeLeaf>;
  public
    constructor Create;
    destructor Destroy; override;

    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('mkey', ftInteger)]
    property mkey: Integer read Fmkey write Fmkey;

    /// The foreign key onto atroot.rkey. Deliberately NOT called `rkey`.
    [Column('mparent', ftInteger)]
    property mparent: Integer read Fmparent write Fmparent;

    [Column('mtag', ftString, 20)]
    property mtag: String read Fmtag write Fmtag;

    /// ColumnsName is this entity's OWN key, `mkey`. A propagation step that
    /// looked the name up against the ROOT's key mapping would search for
    /// `rkey` here and find nothing.
    [Association(TMultiplicity.OneToMany, 'mkey', 'atleaf', 'lparent')]
    [CascadeActions([TCascadeAction.CascadeAutoInc,
                     TCascadeAction.CascadeInsert,
                     TCascadeAction.CascadeUpdate,
                     TCascadeAction.CascadeDelete])]
    property leafs: TObjectList<TAsymTreeLeaf> read Fleafs write Fleafs;
  end;

  [Entity]
  [Table('atroot', '')]
  [PrimaryKey('rkey', TAutoIncType.AutoInc,
                      TGeneratorType.SequenceInc,
                      TSortingOrder.NoSort,
                      True, 'Primary key')]
  [Sequence('atroot')]
  TAsymTreeRoot = class
  private
    Frkey: Integer;
    Frtag: String;
    Fmids: TObjectList<TAsymTreeMid>;
  public
    constructor Create;
    destructor Destroy; override;

    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('rkey', ftInteger)]
    property rkey: Integer read Frkey write Frkey;

    [Column('rtag', ftString, 20)]
    property rtag: String read Frtag write Frtag;

    [Association(TMultiplicity.OneToMany, 'rkey', 'atmid', 'mparent')]
    [CascadeActions([TCascadeAction.CascadeAutoInc,
                     TCascadeAction.CascadeInsert,
                     TCascadeAction.CascadeUpdate,
                     TCascadeAction.CascadeDelete])]
    property mids: TObjectList<TAsymTreeMid> read Fmids write Fmids;
  end;

  /// The OneToOne root - issue #239. Same two lower levels, a single-object
  /// association at the top, which is what routes the cascade through
  /// OneToOneCascadeActionsExecute instead of OneToManyCascadeActionsExecute.
  [Entity]
  [Table('atpair', '')]
  [PrimaryKey('pkey', TAutoIncType.AutoInc,
                      TGeneratorType.SequenceInc,
                      TSortingOrder.NoSort,
                      True, 'Primary key')]
  [Sequence('atpair')]
  TAsymTreeOneRoot = class
  private
    Fpkey: Integer;
    Fptag: String;
    Fmid: TAsymTreeMid;
  public
    destructor Destroy; override;

    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('pkey', ftInteger)]
    property pkey: Integer read Fpkey write Fpkey;

    [Column('ptag', ftString, 20)]
    property ptag: String read Fptag write Fptag;

    /// No constructor fills this in. It starts nil on purpose: the branch under
    /// test is the one that runs when the child is NOT in the state snapshot
    /// Modify took, and a snapshot taken over a nil branch is exactly that.
    [Association(TMultiplicity.OneToOne, 'pkey', 'atmid', 'mparent')]
    [CascadeActions([TCascadeAction.CascadeAutoInc,
                     TCascadeAction.CascadeInsert,
                     TCascadeAction.CascadeUpdate,
                     TCascadeAction.CascadeDelete])]
    property mid: TAsymTreeMid read Fmid write Fmid;
  end;

implementation

{ TAsymTreeMid }

constructor TAsymTreeMid.Create;
begin
  Fleafs := TObjectList<TAsymTreeLeaf>.Create;
end;

destructor TAsymTreeMid.Destroy;
begin
  Fleafs.Free;
  inherited;
end;

{ TAsymTreeRoot }

constructor TAsymTreeRoot.Create;
begin
  Fmids := TObjectList<TAsymTreeMid>.Create;
end;

destructor TAsymTreeRoot.Destroy;
begin
  Fmids.Free;
  inherited;
end;

{ TAsymTreeOneRoot }

destructor TAsymTreeOneRoot.Destroy;
begin
  Fmid.Free;
  inherited;
end;

initialization
  TRegisterClass.RegisterEntity(TAsymTreeLeaf);
  TRegisterClass.RegisterEntity(TAsymTreeMid);
  TRegisterClass.RegisterEntity(TAsymTreeRoot);
  TRegisterClass.RegisterEntity(TAsymTreeOneRoot);

end.
