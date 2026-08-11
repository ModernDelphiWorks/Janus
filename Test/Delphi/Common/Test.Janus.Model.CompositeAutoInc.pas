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

{ @abstract(Janus Framework - test fixture: a REST root whose AUTOINC primary
  key is COMPOSITE, over a cascading child. Issue #300.)

  WHY IT EXISTS

  Test.Janus.Model.AutoIncTree already carries an AutoInc root over a cascading
  child, and every REST test of the insert path drives it. What it cannot ask is
  the only question #300 leaves open after the parser is repaired: the gate the
  re-read of issue #297 stands behind,
  TRESTDataSetAdapter<M>._RowKeyIsUngenerated, reads the row's OWN primary key
  column BY COLUMN and answers True the moment ONE of them still carries the
  AutoInc placeholder. With a single-column key there is nothing to be partial
  about - the answer either arrives or it does not. With a COMPOSITE key there
  is, and before #300 the client always ended up in exactly that state: one
  column stamped, the others on the placeholder.

  So this pair exists to make the interaction measurable, not to add coverage of
  the mapping. TCkRoot's key is `ck1;ck2`, both AutoInc, and TCkChild hangs off
  BOTH columns with its own AutoInc key of its own - which is what makes
  _GraphBelowIsStale answer True and gives the gate something to gate.

  The child key is spelled `cc_id` and the association columns `ck1;ck2` are
  spelled the same on both sides ON PURPOSE here: the asymmetry AsymKey exists
  for is not what is under test, and the cascade must really carry both columns.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Model.CompositeAutoInc;

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
  [Table('ckchild', '')]
  [PrimaryKey('cc_id', TAutoIncType.AutoInc,
                       TGeneratorType.SequenceInc,
                       TSortingOrder.NoSort,
                       True, 'Primary key')]
  [Sequence('ckchild')]
  TCkChild = class
  private
    Fcc_id: Integer;
    Fck1: Integer;
    Fck2: Integer;
    Ftag: String;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('cc_id', ftInteger)]
    property cc_id: Integer read Fcc_id write Fcc_id;

    [Restrictions([TRestriction.NotNull])]
    [Column('ck1', ftInteger)]
    property ck1: Integer read Fck1 write Fck1;

    [Restrictions([TRestriction.NotNull])]
    [Column('ck2', ftInteger)]
    property ck2: Integer read Fck2 write Fck2;

    [Column('tag', ftString, 20)]
    property tag: String read Ftag write Ftag;
  end;

  [Entity]
  [Table('ckroot', '')]
  [PrimaryKey('ck1;ck2', TAutoIncType.AutoInc,
                         TGeneratorType.SequenceInc,
                         TSortingOrder.NoSort,
                         True, 'Composite primary key')]
  [Sequence('ckroot')]
  TCkRoot = class
  private
    Fck1: Integer;
    Fck2: Integer;
    Ftag: String;
    Fchilds: TObjectList<TCkChild>;
  public
    constructor Create;
    destructor Destroy; override;

    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('ck1', ftInteger)]
    property ck1: Integer read Fck1 write Fck1;

    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('ck2', ftInteger)]
    property ck2: Integer read Fck2 write Fck2;

    [Column('tag', ftString, 20)]
    property tag: String read Ftag write Ftag;

    [Association(TMultiplicity.OneToMany, 'ck1;ck2', 'ckchild', 'ck1;ck2')]
    [CascadeActions([TCascadeAction.CascadeAutoInc,
                     TCascadeAction.CascadeInsert,
                     TCascadeAction.CascadeUpdate,
                     TCascadeAction.CascadeDelete])]
    property childs: TObjectList<TCkChild> read Fchilds write Fchilds;
  end;

implementation

{ TCkRoot }

constructor TCkRoot.Create;
begin
  Fchilds := TObjectList<TCkChild>.Create;
end;

destructor TCkRoot.Destroy;
begin
  Fchilds.Free;
  inherited;
end;

initialization
  TRegisterClass.RegisterEntity(TCkChild);
  TRegisterClass.RegisterEntity(TCkRoot);

end.
