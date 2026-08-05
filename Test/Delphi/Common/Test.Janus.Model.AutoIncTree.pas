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

  WHY THIS SHAPE

  TDataSetBaseAdapter<M>.SetAutoIncValueChilds recurses into the children of
  each child, so a fixture that only has master+detail proves nothing about
  grandchildren. This tree is therefore root -> mid -> leaf, and the SAME
  logical key travels the whole chain:

      aitroot.root_id  --(CascadeAutoInc)-->  aitmid.root_id
      aitmid.root_id   --(CascadeAutoInc)-->  aitleaf.root_id

  That denormalised chain is exactly the case the recursion exists for: after
  the mid rows receive the new root_id, the leaf rows must receive it too.

  TAitRoot also carries a SECOND one-to-many association, to TAitNoCascade,
  deliberately WITHOUT CascadeAutoInc. It is there so a test can prove the
  cascade filter still filters - a fix that simply updated every child would
  look green without it.
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
    Froot_id: Integer;
    Ftag: String;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('leaf_id', ftInteger)]
    property leaf_id: Integer read Fleaf_id write Fleaf_id;

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

    [Association(TMultiplicity.OneToMany, 'root_id', 'aitleaf', 'root_id')]
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
