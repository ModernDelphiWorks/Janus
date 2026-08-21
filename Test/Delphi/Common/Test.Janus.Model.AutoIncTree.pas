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

{ @abstract(Janus Framework - test fixture: a THREE level CascadeAutoInc tree.)

  WHICH FIXTURE PLAYS WHICH PART

  This unit is the CANONICAL shape: every association names the same column on
  both ends, which is how associations in this repository are overwhelmingly
  written - Test.Janus.Model.AsymKey records the measurement, eight of eight in
  the models Janus.Tests.Units compiled when it was written.

  Test.Janus.Model.AsymTree is the OTHER one, and it is not a spare copy: it
  spells every column name exactly ONCE across three levels, which is what makes
  a step that resolves a name against the wrong entity's mapping fail visibly
  instead of resolving by coincidence. Three defects in this series hid behind
  matching names. So the choice between the two is deliberate: this one for the
  ordinary shape, AsymTree whenever the measurement has to tell two readings
  apart.

  WHY THIS SHAPE

  TDataSetBaseAdapter<M>.SetAutoIncValueChilds recurses into the children of
  each child, so a fixture that only has master+detail proves nothing about
  grandchildren. This tree is therefore root -> mid -> leaf, and EACH LEVEL
  PROPAGATES ITS OWN KEY:

      aitroot.root_id  --(CascadeAutoInc)-->  aitmid.root_id
      aitmid.mid_id    --(CascadeAutoInc)-->  aitleaf.mid_id

  Reading the attribute: Association(AMultiplicity, AColumnsName, ATableNameRef,
  AColumnsNameRef). ColumnsName is the column on the DECLARING entity;
  ColumnsNameRef is the column on the REFERENCED table. Each level therefore
  declares its OWN primary key as ColumnsName.

  WHAT `root_id` IS DOING ON THE LEAF - issue #244

  Until #244 the mid level's association named `root_id` at BOTH ends, so the
  key that travelled the whole chain was the ROOT's. That modelled a propagation
  the framework does not offer: CascadeAutoInc carries the IMMEDIATE parent's
  freshly generated key to that parent's children, and no ancestor's key is
  propagated. TObjectSetBaseAdapter<M>.SetAutoIncValueOneToMany is where that is
  concrete - it looks the parent's OWN primary key property up against the
  association's ColumnsName, so a mid level offering `root_id` while its key is
  `mid_id` resolves nothing and writes nothing, silently.

  The column stays on the leaf, and NO association names it. That turns the
  leftover into a negative control: with the tree wired as above, a leaf's
  `root_id` must come out of a cascade exactly as it went in.

  Both halves are earned by a mutation of THIS unit, each reddening exactly one
  test and a different one:

    - replacing `mid_id` with `root_id` on the mid association reddens
      Test.Janus.AutoInc.Childs.Linked_EveryGrandchildRowReceivesTheNewKey on
      the clause that says the leaves receive the mid's key, and
      Test.Janus.AutoInc.Childs.ObjectSet_EveryGrandchildObjectReceivesTheMidKey
      on the same clause in the other family;

    - ADDING `root_id` alongside `mid_id` leaves those green and reddens the
      DataSet clause that says the leaves' own `root_id` was left alone. The
      ObjectSet family stays green under that one, and the difference is the
      point: there the propagated column is looked up FROM the parent's key
      mapping, so a second column the parent's key does not name is never
      reached.

  TAitRoot also carries a SECOND one-to-many association, to TAitNoCascade,
  deliberately WITHOUT CascadeAutoInc. It is there so a test can prove the
  cascade filter still filters - a fix that simply updated every child would
  look green without it.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Model.AutoIncTree;

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
  [Table('aitleaf', '')]
  [PrimaryKey('leaf_id', TAutoIncType.AutoInc,
                         TGeneratorType.SequenceInc,
                         TSortingOrder.NoSort,
                         True, 'Primary key')]
  [Sequence('aitleaf')]
  TAitLeaf = class
  private
    Fleaf_id: Integer;
    Fmid_id: Integer;
    Froot_id: Integer;
    Ftag: String;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('leaf_id', ftInteger)]
    property leaf_id: Integer read Fleaf_id write Fleaf_id;

    /// The foreign key onto aitmid.mid_id - the key the leaf's own parent
    /// generates. Spelled the same at both ends, which is this fixture's part;
    /// AsymTree is where the two ends are spelled differently.
    [Column('mid_id', ftInteger)]
    property mid_id: Integer read Fmid_id write Fmid_id;

    /// DENORMALISED and DELIBERATELY UNLINKED - see the header. No association
    /// names this column, so no cascade may write it. It is the negative
    /// control for ancestor propagation, not a foreign key.
    [Restrictions([TRestriction.NotNull])]
    [Column('root_id', ftInteger)]
    property root_id: Integer read Froot_id write Froot_id;

    [Column('tag', ftString, 20)]
    property tag: String read Ftag write Ftag;
  end;

  [Entity]
  [Table('aitmid', '')]
  [PrimaryKey('mid_id', TAutoIncType.AutoInc,
                        TGeneratorType.SequenceInc,
                        TSortingOrder.NoSort,
                        True, 'Primary key')]
  [Sequence('aitmid')]
  TAitMid = class
  private
    Fmid_id: Integer;
    Froot_id: Integer;
    Ftag: String;
    Fleafs: TObjectList<TAitLeaf>;
  public
    constructor Create;
    destructor Destroy; override;

    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('mid_id', ftInteger)]
    property mid_id: Integer read Fmid_id write Fmid_id;

    [Restrictions([TRestriction.NotNull])]
    [Column('root_id', ftInteger)]
    property root_id: Integer read Froot_id write Froot_id;

    [Column('tag', ftString, 20)]
    property tag: String read Ftag write Ftag;

    /// ColumnsName is this entity's OWN key, `mid_id`. Naming `root_id` here -
    /// which is what this fixture did before #244 - asks for the GRANDPARENT's
    /// key to reach the leaf, and that is not what CascadeAutoInc offers.
    [Association(TMultiplicity.OneToMany, 'mid_id', 'aitleaf', 'mid_id')]
    [CascadeActions([TCascadeAction.CascadeAutoInc,
                     TCascadeAction.CascadeInsert,
                     TCascadeAction.CascadeUpdate,
                     TCascadeAction.CascadeDelete])]
    property leafs: TObjectList<TAitLeaf> read Fleafs write Fleafs;
  end;

  [Entity]
  [Table('aitnocascade', '')]
  [PrimaryKey('other_id', TAutoIncType.AutoInc,
                          TGeneratorType.SequenceInc,
                          TSortingOrder.NoSort,
                          True, 'Primary key')]
  [Sequence('aitnocascade')]
  TAitNoCascade = class
  private
    Fother_id: Integer;
    Froot_id: Integer;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('other_id', ftInteger)]
    property other_id: Integer read Fother_id write Fother_id;

    [Restrictions([TRestriction.NotNull])]
    [Column('root_id', ftInteger)]
    property root_id: Integer read Froot_id write Froot_id;
  end;

  [Entity]
  [Table('aitroot', '')]
  [PrimaryKey('root_id', TAutoIncType.AutoInc,
                         TGeneratorType.SequenceInc,
                         TSortingOrder.NoSort,
                         True, 'Primary key')]
  [Sequence('aitroot')]
  TAitRoot = class
  private
    Froot_id: Integer;
    Ftag: String;
    Fmids: TObjectList<TAitMid>;
    Fothers: TObjectList<TAitNoCascade>;
  public
    constructor Create;
    destructor Destroy; override;

    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('root_id', ftInteger)]
    property root_id: Integer read Froot_id write Froot_id;

    [Column('tag', ftString, 20)]
    property tag: String read Ftag write Ftag;

    /// ColumnsName is this entity's OWN key, `root_id`.
    [Association(TMultiplicity.OneToMany, 'root_id', 'aitmid', 'root_id')]
    [CascadeActions([TCascadeAction.CascadeAutoInc,
                     TCascadeAction.CascadeInsert,
                     TCascadeAction.CascadeUpdate,
                     TCascadeAction.CascadeDelete])]
    property mids: TObjectList<TAitMid> read Fmids write Fmids;

    /// Same shape as `mids`, but WITHOUT CascadeAutoInc on purpose.
    [Association(TMultiplicity.OneToMany, 'root_id', 'aitnocascade', 'root_id')]
    [CascadeActions([TCascadeAction.CascadeInsert,
                     TCascadeAction.CascadeUpdate])]
    property others: TObjectList<TAitNoCascade> read Fothers write Fothers;
  end;

implementation

{ TAitMid }

constructor TAitMid.Create;
begin
  Fleafs := TObjectList<TAitLeaf>.Create;
end;

destructor TAitMid.Destroy;
begin
  Fleafs.Free;
  inherited;
end;

{ TAitRoot }

constructor TAitRoot.Create;
begin
  Fmids := TObjectList<TAitMid>.Create;
  Fothers := TObjectList<TAitNoCascade>.Create;
end;

destructor TAitRoot.Destroy;
begin
  Fothers.Free;
  Fmids.Free;
  inherited;
end;

initialization
  TRegisterClass.RegisterEntity(TAitLeaf);
  TRegisterClass.RegisterEntity(TAitMid);
  TRegisterClass.RegisterEntity(TAitNoCascade);
  TRegisterClass.RegisterEntity(TAitRoot);

end.
