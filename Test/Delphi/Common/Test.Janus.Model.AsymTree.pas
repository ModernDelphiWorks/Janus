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
  model compiled by the suite is Test.Janus.Model.AutoIncTree, and there the
  mid level's association carries `root_id` - the ROOT's key name, not the
  mid's own key name (`mid_id`). That single reused spelling is what makes
  the two readings indistinguishable there.

  THE SHAPE

      atroot.rkey  --(OneToMany)-->  atmid.mparent
      atmid.mkey   --(OneToMany)-->  atleaf.lparent

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

initialization
  TRegisterClass.RegisterEntity(TAsymTreeLeaf);
  TRegisterClass.RegisterEntity(TAsymTreeMid);
  TRegisterClass.RegisterEntity(TAsymTreeRoot);

end.
