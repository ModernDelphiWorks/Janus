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

{ @abstract(Janus Framework - test fixture: a CascadeAutoInc tree whose key is
  NOT autoinc.)

  WHY THIS MODEL EXISTS - issue #262

  The #262 guard refuses to propagate a key column that still reads -1, because
  on an AUTOINC primary key -1 is the placeholder
  TBind.SetInternalInitFieldDefsObjectClass writes as DefaultExpression: the row
  has no key yet. On a key declared TAutoIncType.NotInc that reasoning does not
  hold - no placeholder is ever written there, and -1 is an ordinary value a
  consumer may have typed. Refusing it would be a silent regression on a shape
  no other model in this repository has.

  So this model is the one entity family in the test tree whose primary key is
  NotInc, and it exists to hold TDataSetBaseAdapter<M>._AutoIncKeyIsGenerated to
  its narrower reading. Removing the `if not LPrimaryKey.AutoIncrement` clause
  from that method reddens
  Test.Janus.AutoInc.UngeneratedKey.NotIncKey_MinusOneIsAnOrdinaryKeyAndIsStill
  Propagated and nothing else - measured.

  ONE LEVEL OF CASCADE IS ENOUGH HERE. The recursion is not the question; the
  question is whether -1 in the PARENT's key column is read as "no key". Depth
  is measured on Test.Janus.Model.AutoIncTree, which is the autoinc shape.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Model.NotIncKey;

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
  [Table('nikchild', '')]
  [PrimaryKey('child_id', TAutoIncType.NotInc,
                          TGeneratorType.NoneInc,
                          TSortingOrder.NoSort,
                          True, 'Primary key')]
  TNikChild = class
  private
    Fchild_id: Integer;
    Fnik_id: Integer;
    Ftag: String;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('child_id', ftInteger)]
    property child_id: Integer read Fchild_id write Fchild_id;

    [Column('nik_id', ftInteger)]
    property nik_id: Integer read Fnik_id write Fnik_id;

    [Column('tag', ftString, 20)]
    property tag: String read Ftag write Ftag;
  end;

  [Entity]
  [Table('nikroot', '')]
  /// NOT autoinc, and that is the whole point of the model. No placeholder is
  /// ever written into this column, so a -1 found here was typed by whoever
  /// owns the row.
  [PrimaryKey('nik_id', TAutoIncType.NotInc,
                        TGeneratorType.NoneInc,
                        TSortingOrder.NoSort,
                        True, 'Primary key')]
  TNikRoot = class
  private
    Fnik_id: Integer;
    Ftag: String;
    Fchilds: TObjectList<TNikChild>;
  public
    constructor Create;
    destructor Destroy; override;

    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('nik_id', ftInteger)]
    property nik_id: Integer read Fnik_id write Fnik_id;

    [Column('tag', ftString, 20)]
    property tag: String read Ftag write Ftag;

    [Association(TMultiplicity.OneToMany, 'nik_id', 'nikchild', 'nik_id')]
    [CascadeActions([TCascadeAction.CascadeAutoInc,
                     TCascadeAction.CascadeInsert,
                     TCascadeAction.CascadeUpdate,
                     TCascadeAction.CascadeDelete])]
    property childs: TObjectList<TNikChild> read Fchilds write Fchilds;
  end;

implementation

{ TNikRoot }

constructor TNikRoot.Create;
begin
  Fchilds := TObjectList<TNikChild>.Create;
end;

destructor TNikRoot.Destroy;
begin
  Fchilds.Free;
  inherited;
end;

initialization
  TRegisterClass.RegisterEntity(TNikChild);
  TRegisterClass.RegisterEntity(TNikRoot);

end.
