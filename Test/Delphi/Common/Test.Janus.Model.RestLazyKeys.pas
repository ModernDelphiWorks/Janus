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

{ @abstract(Janus Framework - test fixture: the two association shapes the
  REST lazy filter had no model for. Issue #251.)

  WHY THIS UNIT EXISTS

  Test.Janus.Model.AsymKey answers one question very well - which END of the
  association is which - because mkey and cparent are spelled differently. What
  it cannot answer is anything about the VALUE, because mkey is an Integer, and
  an Integer is the one type that reaches a $filter correctly whether or not
  the code that built it thought about types at all.

  Two gaps followed from that, both measured as surviving mutations before this
  unit existed:

    * a String foreign key. Unquoted, `scparent eq AB C` is a syntax error on
      any strict server and `scparent = ABC` is a comparison against an unknown
      COLUMN - wrong, silently. GUID and alphanumeric codes are first-class
      keys in this framework: TGeneratorType carries Guid32Inc, Guid36Inc and
      Guid38Inc.
    * a COMPOSITE association. With one column, the separator between terms is
      never written, so ' AND ' could have been ' OR ' and nothing would have
      noticed.

  TStrMaster covers the first and also the null-value guard, because a String
  key can be left empty in a way an Integer key cannot. TCompMaster covers the
  second, and its two columns are deliberately of DIFFERENT TYPES so one
  assertion pins the separator and the quoting of the text half at once.

  BOTH ENDS ARE STILL SPELLED DIFFERENTLY - smkey -> scparent, cmk1/cmk2 ->
  cck1/cck2 - so these models never lose the property AsymKey was built for.
}

unit Test.Janus.Model.RestLazyKeys;

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
  [Table('strchild', '')]
  [PrimaryKey('sckey', TAutoIncType.NotInc,
                       TGeneratorType.NoneInc,
                       TSortingOrder.NoSort,
                       True, 'Primary key')]
  TStrChild = class
  private
    Fsckey: Integer;
    Fscparent: String;
    Fsctag: String;
  public
    [Column('sckey', ftInteger)]
    property sckey: Integer read Fsckey write Fsckey;

    /// The foreign key, and it is a STRING. Deliberately not called `smkey`.
    [Column('scparent', ftString, 20)]
    property scparent: String read Fscparent write Fscparent;

    [Column('sctag', ftString, 20)]
    property sctag: String read Fsctag write Fsctag;
  end;

  [Entity]
  [Table('strmaster', '')]
  [PrimaryKey('smkey', TAutoIncType.NotInc,
                       TGeneratorType.NoneInc,
                       TSortingOrder.NoSort,
                       True, 'Primary key')]
  TStrMaster = class
  private
    Fsmkey: String;
    Fsmtag: String;
    Fchilds: TObjectList<TStrChild>;
  public
    constructor Create;
    destructor Destroy; override;

    /// A String primary key - a GUID or an alphanumeric code, which this
    /// framework generates on purpose (TGeneratorType.Guid36Inc and friends).
    [Column('smkey', ftString, 20)]
    property smkey: String read Fsmkey write Fsmkey;

    [Column('smtag', ftString, 20)]
    property smtag: String read Fsmtag write Fsmtag;

    [Association(TMultiplicity.OneToMany, 'smkey', 'strchild', 'scparent')]
    [CascadeActions([TCascadeAction.CascadeInsert,
                     TCascadeAction.CascadeUpdate,
                     TCascadeAction.CascadeDelete])]
    property childs: TObjectList<TStrChild> read Fchilds write Fchilds;
  end;

  [Entity]
  [Table('compchild', '')]
  [PrimaryKey('cckey', TAutoIncType.NotInc,
                       TGeneratorType.NoneInc,
                       TSortingOrder.NoSort,
                       True, 'Primary key')]
  TCompChild = class
  private
    Fcckey: Integer;
    Fcck1: Integer;
    Fcck2: String;
  public
    [Column('cckey', ftInteger)]
    property cckey: Integer read Fcckey write Fcckey;

    /// The two halves of the composite foreign key, of DIFFERENT types.
    [Column('cck1', ftInteger)]
    property cck1: Integer read Fcck1 write Fcck1;

    [Column('cck2', ftString, 20)]
    property cck2: String read Fcck2 write Fcck2;
  end;

  [Entity]
  [Table('compmaster', '')]
  [PrimaryKey('cmkey', TAutoIncType.NotInc,
                       TGeneratorType.NoneInc,
                       TSortingOrder.NoSort,
                       True, 'Primary key')]
  TCompMaster = class
  private
    Fcmkey: Integer;
    Fcmk1: Integer;
    Fcmk2: String;
    Fchilds: TObjectList<TCompChild>;
  public
    constructor Create;
    destructor Destroy; override;

    [Column('cmkey', ftInteger)]
    property cmkey: Integer read Fcmkey write Fcmkey;

    [Column('cmk1', ftInteger)]
    property cmk1: Integer read Fcmk1 write Fcmk1;

    [Column('cmk2', ftString, 20)]
    property cmk2: String read Fcmk2 write Fcmk2;

    /// Two columns on each side, and the two sides spelled differently.
    [Association(TMultiplicity.OneToMany, 'cmk1;cmk2', 'compchild',
                 'cck1;cck2')]
    [CascadeActions([TCascadeAction.CascadeInsert,
                     TCascadeAction.CascadeUpdate,
                     TCascadeAction.CascadeDelete])]
    property childs: TObjectList<TCompChild> read Fchilds write Fchilds;
  end;

implementation

{ TStrMaster }

constructor TStrMaster.Create;
begin
  Fchilds := TObjectList<TStrChild>.Create;
end;

destructor TStrMaster.Destroy;
begin
  Fchilds.Free;
  inherited;
end;

{ TCompMaster }

constructor TCompMaster.Create;
begin
  Fchilds := TObjectList<TCompChild>.Create;
end;

destructor TCompMaster.Destroy;
begin
  Fchilds.Free;
  inherited;
end;

initialization
  TRegisterClass.RegisterEntity(TStrChild);
  TRegisterClass.RegisterEntity(TStrMaster);
  TRegisterClass.RegisterEntity(TCompChild);
  TRegisterClass.RegisterEntity(TCompMaster);

end.
