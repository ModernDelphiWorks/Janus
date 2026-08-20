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

{ @abstract(Janus Framework - test fixture models: a GENERATED primary key whose
  property is a Nullable. Issue #317.)

  WHY THESE EXIST

  The #301 repair reads the key the server generated out of the insert answer
  and writes it onto the inserted object. It writes only ORDINAL and textual
  properties; a key declared `Nullable<...>` fell through untouched. The author
  of #301 wrote a `tkRecord` arm for it and then REMOVED it, under a rule that
  is still in force - the reader must not be able to raise - and with an
  enumeration that was true where it was measured: nothing under `Test\Delphi`
  had a Nullable key, so the arm could not be held honest by any clause.

  THE ENUMERATION HAS SINCE MOVED, AND THE MOVE IS RECORDED HERE RATHER THAN
  ASSUMED. Re-run at 7e5e51d over every `[PrimaryKey]` under `Test\` resolved to
  its `[Column]` declaration, `Test\Delphi` now carries TWO Nullable keys -
  `Test.Janus.Model.KeyTypes.TKeyTypeNullable` and
  `Test.Janus.Model.KeyTypeDecoy.TKeyTypeDecoy`, both `Nullable<String>`, both
  added by #311. So the sentence "none has a Nullable key" is FALSE at this
  commit. It is still true that neither of them can hold the client reader
  honest: both are `TAutoIncType.NotInc` with NO `[Sequence]`, so
  `TSessionRestFul<M>.ExistSequence` answers False and
  `TRESTObjectSetAdapter<M>.Insert` never enters the block that reads the answer
  at all. They are also linked only into `Janus.Tests.RESTHorse`.

  A NULLABLE KEY *AND* A `[Sequence]` TOGETHER is the shape that was missing,
  and it is what every entity below carries.

  THE SHAPE IS THE ONE THE REPOSITORY SHIPS AS AN EXAMPLE

  `Examples\Delphi\Data\Varios Niveis de Dados` declares all eight of its models
  this way. `TNkRoot` below reproduces `Orion.Model.Contato.Tcontato` pair for
  pair - `[Column('...', ftInteger)]` over `property ...: Nullable<Integer>` -
  because a Nullable property over an INTEGER column is the combination the
  consumer is taught, and it is the one a reader that dispatches on the COLUMN
  type rather than on the PROPERTY type gets wrong.

  ONE ROOT PER ELEMENT TYPE, ON PURPOSE

  The reader dispatches per element type, so one entity carrying several
  Nullable columns would exercise one arm and no more: only the primary key is
  named by the insert answer. Four roots therefore:

    TNkRoot   Nullable<Integer>  - the Examples shape, and the only one with a
                                   cascading child, so the ORDER of the read
                                   against the cascade is measured here
    TNlRoot   Nullable<Int64>    - the 64-bit arm
    TNsRoot   Nullable<String>   - a TEXTUAL key that IS generated, which is the
                                   shape issue #317 asks about by name and which
                                   exists nowhere else in this repository:
                                   `TKeyTypeGuid` is generated but its property
                                   is a bare String, and the two Nullable keys
                                   named above are not generated
    TNdRoot   Nullable<Double>   - the NEGATIVE CONTROL. Its element type is
                                   outside the three the reader writes, so it
                                   must come out of an insert still holding the
                                   placeholder. Without it "the reader handles
                                   Nullable" would be indistinguishable from
                                   "the reader handles every Nullable", and the
                                   scope of the repair would rest on a comment.
                                   A fractional key is not invented for the
                                   occasion - `Examples\Delphi\Data\Quatro
                                   Niveis de Dados\Model.Setor` declares a
                                   Double primary key today.

  THE CHILD'S FOREIGN KEY IS A NULLABLE TOO

  `TNkChild.nk_id` is `Nullable<Integer>`, matching its parent. The cascade
  copies the parent's key property onto it as a raw TValue
  (`TObjectSetBaseAdapter<M>.SetAutoIncValueOneToMany`), so the two ends have to
  agree in type for anything to arrive - and a root left on the placeholder
  hands the placeholder down, which is the half of the defect a consumer sees
  as a foreign key pointing at a row nobody has.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Model.NullableKey;

interface

uses
  Classes,
  DB,
  SysUtils,
  Generics.Collections,
  Janus.Types.Nullable,
  MetaDbDiff.mapping.attributes,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Register;

type
  [Entity]
  [Table('nkchild', '')]
  [PrimaryKey('child_id', TAutoIncType.AutoInc,
                          TGeneratorType.SequenceInc,
                          TSortingOrder.NoSort,
                          True, 'Primary key')]
  [Sequence('nkchild')]
  TNkChild = class
  private
    Fchild_id: Nullable<Integer>;
    Fnk_id: Nullable<Integer>;
    Ftag: String;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('child_id', ftInteger)]
    property child_id: Nullable<Integer> read Fchild_id write Fchild_id;

    /// The foreign key onto nkroot.nk_id, declared with the SAME Nullable the
    /// parent's key carries. The cascade copies a raw TValue across, so a
    /// mismatch here would write nothing at all and the fixture would be
    /// measuring the wrong thing.
    [Column('nk_id', ftInteger)]
    property nk_id: Nullable<Integer> read Fnk_id write Fnk_id;

    [Column('tag', ftString, 20)]
    property tag: String read Ftag write Ftag;
  end;

  [Entity]
  [Table('nkroot', '')]
  [PrimaryKey('nk_id', TAutoIncType.AutoInc,
                       TGeneratorType.SequenceInc,
                       TSortingOrder.NoSort,
                       True, 'Primary key')]
  [Sequence('nkroot')]
  TNkRoot = class
  private
    Fnk_id: Nullable<Integer>;
    Ftag: String;
    Fchilds: TObjectList<TNkChild>;
  public
    constructor Create;
    destructor Destroy; override;

    /// `Orion.Model.Contato.Tcontato` declares its key exactly like this:
    /// an INTEGER column carrying a NULLABLE property. Reproduced pair for
    /// pair, because the disagreement between the two is the thing.
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('nk_id', ftInteger)]
    property nk_id: Nullable<Integer> read Fnk_id write Fnk_id;

    [Column('tag', ftString, 20)]
    property tag: String read Ftag write Ftag;

    [Association(TMultiplicity.OneToMany, 'nk_id', 'nkchild', 'nk_id')]
    [CascadeActions([TCascadeAction.CascadeAutoInc,
                     TCascadeAction.CascadeInsert,
                     TCascadeAction.CascadeUpdate,
                     TCascadeAction.CascadeDelete])]
    property childs: TObjectList<TNkChild> read Fchilds write Fchilds;
  end;

  [Entity]
  [Table('nlroot', '')]
  [PrimaryKey('nl_id', TAutoIncType.AutoInc,
                       TGeneratorType.SequenceInc,
                       TSortingOrder.NoSort,
                       True, 'Primary key')]
  [Sequence('nlroot')]
  TNlRoot = class
  private
    Fnl_id: Nullable<Int64>;
    Ftag: String;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('nl_id', ftLargeint)]
    property nl_id: Nullable<Int64> read Fnl_id write Fnl_id;

    [Column('tag', ftString, 20)]
    property tag: String read Ftag write Ftag;
  end;

  [Entity]
  [Table('nsroot', '')]
  [PrimaryKey('ns_id', TAutoIncType.AutoInc,
                       TGeneratorType.SequenceInc,
                       TSortingOrder.NoSort,
                       True, 'Primary key')]
  [Sequence('nsroot')]
  TNsRoot = class
  private
    Fns_id: Nullable<String>;
    Ftag: String;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('ns_id', ftString, 20)]
    property ns_id: Nullable<String> read Fns_id write Fns_id;

    [Column('tag', ftString, 20)]
    property tag: String read Ftag write Ftag;
  end;

  /// A BARE String key, generated, and otherwise identical to TNsRoot. It is
  /// the POSITIVE CONTROL for a neighbouring defect this branch measured and
  /// did NOT repair: in the DataSet family a GENERATED key gets
  /// `DefaultExpression := '-1'` written onto its TField unconditionally -
  /// TBind.SetInternalInitFieldDefsObjectClass does it for every column of an
  /// AutoIncrement primary key without looking at the column's type - and a
  /// TFDMemTable evaluating that on a string field raises
  /// `[FireDAC][Stan][Eval]-104. Type mismatch in expression` on the APPEND,
  /// before any answer is read. This entity exists so the finding can be shown
  /// to be about a TEXTUAL GENERATED KEY and not about Nullable: it fails the
  /// same way with no Nullable anywhere in it.
  [Entity]
  [Table('nbroot', '')]
  [PrimaryKey('nb_id', TAutoIncType.AutoInc,
                       TGeneratorType.SequenceInc,
                       TSortingOrder.NoSort,
                       True, 'Primary key')]
  [Sequence('nbroot')]
  TNbRoot = class
  private
    Fnb_id: String;
    Ftag: String;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('nb_id', ftString, 20)]
    property nb_id: String read Fnb_id write Fnb_id;

    [Column('tag', ftString, 20)]
    property tag: String read Ftag write Ftag;
  end;

  /// THE NEGATIVE CONTROL - see the header. A Nullable whose element type the
  /// reader does not write, so an insert must leave it exactly as it was.
  [Entity]
  [Table('ndroot', '')]
  [PrimaryKey('nd_id', TAutoIncType.AutoInc,
                       TGeneratorType.SequenceInc,
                       TSortingOrder.NoSort,
                       True, 'Primary key')]
  [Sequence('ndroot')]
  TNdRoot = class
  private
    Fnd_id: Nullable<Double>;
    Ftag: String;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('nd_id', ftFloat)]
    property nd_id: Nullable<Double> read Fnd_id write Fnd_id;

    [Column('tag', ftString, 20)]
    property tag: String read Ftag write Ftag;
  end;

implementation

{ TNkRoot }

constructor TNkRoot.Create;
begin
  Fchilds := TObjectList<TNkChild>.Create;
end;

destructor TNkRoot.Destroy;
begin
  Fchilds.Free;
  inherited;
end;

initialization
  TRegisterClass.RegisterEntity(TNkChild);
  TRegisterClass.RegisterEntity(TNkRoot);
  TRegisterClass.RegisterEntity(TNlRoot);
  TRegisterClass.RegisterEntity(TNsRoot);
  TRegisterClass.RegisterEntity(TNbRoot);
  TRegisterClass.RegisterEntity(TNdRoot);

end.
