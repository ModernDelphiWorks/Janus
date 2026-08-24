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

{ @abstract(Janus Framework - test fixture: the three routes that materialise a
  child whose OWN CONSTRUCTOR builds something, so that the one route which
  does not run that constructor can be told apart from the two that do.)

  WHY THIS MODEL HAD TO BE WRITTEN

  Measured before it existed, by writing the owner and child class names to a
  file from inside CreateLazySingleAssociationLoadFunc and running the whole
  Janus.Tests.Units suite: the lazy single-object load ran THREE times in 715
  tests, always TExame -> TProcedimento, and always from
  Test.Janus.Cursor.Advance.LazySingleAssociation_ThreeRows_Terminates, which
  calls the load function DIRECTLY. No public route reached it, and
  TProcedimento.Create is EMPTY, so there was nothing for a skipped constructor
  to lose. That is why the defect could be alive and the suite green.

  THE SHAPE - one child row, three roots, all keyed 1

      lzlazy.zkey  --(OneToOne,  Lazy)--> lzchild.cparent   THE ROUTE UNDER TEST
      lzmany.ykey  --(OneToMany, Lazy)--> lzchild.cparent   CONTROL - lazy works
      lzeager.ekey --(OneToMany      )--> lzchild.cparent   CONTROL - data is fine
      lzchild.ckey --(OneToMany      )--> lzgrand.gparent

  TLazyCtorChild.Create builds Fgrands. Reached through either CONTROL the list
  arrives built, because both of those routes call MethodCall('Create', []) on
  the instance after allocating it through a class reference. Reached through
  the route under test it does not, because that route stops at the allocation.

  WHY THE EAGER 1:1 ROUTE IS NOT ONE OF THE CONTROLS

  It has the SAME defect, and its repair is issue #369, on its own branch. On
  develop it would be red beside the clause under test and would isolate
  nothing. It is named here so the next reader does not mistake its absence for
  an oversight.

  WHY EVERY COLUMN NAME IS SPELLED ONCE

  Same discipline as Test.Janus.Model.AsymTree: gkey, gparent, ckey, cparent,
  zkey, ykey, ekey. A step that resolved a column name against the wrong
  entity's mapping cannot succeed by coincidence here.

  WHY THE LAZY ROOT IS PROBED BEHAVIOURALLY AND NOT BY A FLAG

  WHAT DOES NOT COMPILE, and that part stands. A probe written DIRECTLY on the
  Lazy<> member DOES NOT COMPILE: ILazy<T> descends from TFunc<T>, so it is a
  METHOD REFERENCE and the compiler AUTO-INVOKES it on any member access.
  `LLazy.IsValueCreated` is read as `LLazy().IsValueCreated` and looked up on
  the CHILD class - measured, "E2003 Undeclared identifier: 'IsValueCreated'",
  and the independent review of this branch reproduced it with an E2015
  alongside. Casting the VARIABLE through Pointer() to dodge the
  auto-invocation is worse and not better: the auto-invocation happens INSIDE
  the cast too, so what reaches IInterface is the loaded OBJECT and the first
  AddRef walks that object's VMT.

  WHAT AN EARLIER VERSION OF THIS HEADER GOT WRONG, kept here because the
  mistake is instructive. It concluded from the paragraph above that asking the
  proxy whether it had fired was not available AT ALL - and then, one sentence
  later, named the route that works. FALSE, and measured false. The flag IS
  reachable, by the framework's OWN idiom: read the Lazy<> FIELD by RTTI,
  GetReferenceToRawData, GetField('FLazy'), AsInterface, Supports(...,
  ILazyProxy, ...), then ILazyProxy.IsValueCreated - the very sequence
  Janus.Mapping.Lazy.InjectLazyAssociationFactory already performs to find an
  existing proxy, and ILazyProxy is a plain interface, which is why every
  IsValueCreated call in this repository goes through it and none through
  ILazy<T>. Measured in the independent review of this branch, on this fixture:
  beforeTouch=False, afterTouch=True, suite green. A second form measured
  green too - Supports(IInterface(Pointer(@Fchild)^), ILazyProxy, ...) answered
  SUPPORTS-OK with IsValueCreated=False and no AV. What separates it from the
  AV above is that it takes the ADDRESS of the record field, so there is no
  member access on the method reference and nothing is auto-invoked.

  WHY THE BEHAVIOURAL PREMISE STAYS ANYWAY. Not because the flag is out of
  reach - it is not - but because the flag is WEAKER evidence. IsValueCreated
  is a boolean about the proxy; what has to be pinned here is WHEN THE SELECT
  RAN. The fixture decides that by editing the child row AFTER the root is
  loaded and BEFORE the property is touched: a lazy route reads the edit, an
  eager one cannot, and Lazy<T>.CreateDefaultValue - the fallback when no proxy
  was injected - produces a blank instance that carries neither value. One
  True/False cannot tell those three apart; the edit can.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Model.LazyCtor;

interface

uses
  Classes,
  DB,
  SysUtils,
  Generics.Collections,
  Janus.Types.Lazy,
  MetaDbDiff.mapping.attributes,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Register;

type
  [Entity]
  [Table('lzgrand', '')]
  [PrimaryKey('gkey', TAutoIncType.AutoInc,
                      TGeneratorType.SequenceInc,
                      TSortingOrder.NoSort,
                      True, 'Primary key')]
  [Sequence('lzgrand')]
  TLazyCtorGrand = class
  private
    Fgkey: Integer;
    Fgparent: Integer;
    Fgtag: String;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('gkey', ftInteger)]
    property gkey: Integer read Fgkey write Fgkey;

    /// The foreign key onto lzchild.ckey. Deliberately NOT called `ckey`.
    [Column('gparent', ftInteger)]
    property gparent: Integer read Fgparent write Fgparent;

    [Column('gtag', ftString, 20)]
    property gtag: String read Fgtag write Fgtag;
  end;

  /// THE CHILD WHOSE CONSTRUCTOR BUILDS SOMETHING. Everything this fixture
  /// measures is whether `Fgrands` exists after a load, and if it does,
  /// whether the rows underneath it survived.
  [Entity]
  [Table('lzchild', '')]
  [PrimaryKey('ckey', TAutoIncType.AutoInc,
                      TGeneratorType.SequenceInc,
                      TSortingOrder.NoSort,
                      True, 'Primary key')]
  [Sequence('lzchild')]
  TLazyCtorChild = class
  private
    Fckey: Integer;
    Fcparent: Integer;
    Fctag: String;
    Fgrands: TObjectList<TLazyCtorGrand>;
  public
    constructor Create;
    destructor Destroy; override;

    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('ckey', ftInteger)]
    property ckey: Integer read Fckey write Fckey;

    /// The foreign key of ALL THREE roots at once. Only one root type is ever
    /// exercised in a given clause, so the three routes read the same row.
    [Column('cparent', ftInteger)]
    property cparent: Integer read Fcparent write Fcparent;

    [Column('ctag', ftString, 20)]
    property ctag: String read Fctag write Fctag;

    [Association(TMultiplicity.OneToMany, 'ckey', 'lzgrand', 'gparent')]
    [CascadeActions([TCascadeAction.CascadeAutoInc,
                     TCascadeAction.CascadeInsert,
                     TCascadeAction.CascadeUpdate,
                     TCascadeAction.CascadeDelete])]
    property grands: TObjectList<TLazyCtorGrand> read Fgrands write Fgrands;
  end;

  /// THE ROUTE UNDER TEST: a LAZY single-object association.
  ///
  /// No destructor frees the child. TLazyProxyLoader.Destroy already does,
  /// and the proxy is released when this object's Lazy<> record field goes.
  [Entity]
  [Table('lzlazy', '')]
  [PrimaryKey('zkey', TAutoIncType.AutoInc,
                      TGeneratorType.SequenceInc,
                      TSortingOrder.NoSort,
                      True, 'Primary key')]
  [Sequence('lzlazy')]
  TLazyCtorLazyRoot = class
  private
    Fzkey: Integer;
    Fztag: String;
    Fchild: Lazy<TLazyCtorChild>;
    function Getchild: TLazyCtorChild;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('zkey', ftInteger)]
    property zkey: Integer read Fzkey write Fzkey;

    [Column('ztag', ftString, 20)]
    property ztag: String read Fztag write Fztag;

    [Association(TMultiplicity.OneToOne, 'zkey', 'lzchild', 'cparent', True)]
    property child: TLazyCtorChild read Getchild;
  end;

  /// CONTROL. The LAZY collection route. Same lazy machinery, same child
  /// class, same row - and it has always called MethodCall('Create', []).
  /// Green on both sides of the repair is what says the cause is the
  /// SINGLE-OBJECT variant and not laziness itself.
  [Entity]
  [Table('lzmany', '')]
  [PrimaryKey('ykey', TAutoIncType.AutoInc,
                      TGeneratorType.SequenceInc,
                      TSortingOrder.NoSort,
                      True, 'Primary key')]
  [Sequence('lzmany')]
  TLazyCtorManyRoot = class
  private
    Fykey: Integer;
    Fytag: String;
    Fkids: Lazy<TObjectList<TLazyCtorChild>>;
    function Getkids: TObjectList<TLazyCtorChild>;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('ykey', ftInteger)]
    property ykey: Integer read Fykey write Fykey;

    [Column('ytag', ftString, 20)]
    property ytag: String read Fytag write Fytag;

    [Association(TMultiplicity.OneToMany, 'ykey', 'lzchild', 'cparent', True)]
    property kids: TObjectList<TLazyCtorChild> read Getkids;
  end;

  /// CONTROL. The EAGER collection route. Proves the schema, the rows and the
  /// links are sound, so a nil list on the route under test is a loss and not
  /// a load that never happened.
  [Entity]
  [Table('lzeager', '')]
  [PrimaryKey('ekey', TAutoIncType.AutoInc,
                      TGeneratorType.SequenceInc,
                      TSortingOrder.NoSort,
                      True, 'Primary key')]
  [Sequence('lzeager')]
  TLazyCtorEagerRoot = class
  private
    Fekey: Integer;
    Fetag: String;
    Fkids: TObjectList<TLazyCtorChild>;
  public
    constructor Create;
    destructor Destroy; override;

    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('ekey', ftInteger)]
    property ekey: Integer read Fekey write Fekey;

    [Column('etag', ftString, 20)]
    property etag: String read Fetag write Fetag;

    [Association(TMultiplicity.OneToMany, 'ekey', 'lzchild', 'cparent')]
    property kids: TObjectList<TLazyCtorChild> read Fkids write Fkids;
  end;

implementation

{ TLazyCtorChild }

constructor TLazyCtorChild.Create;
begin
  Fgrands := TObjectList<TLazyCtorGrand>.Create;
end;

destructor TLazyCtorChild.Destroy;
begin
  Fgrands.Free;
  inherited;
end;

{ TLazyCtorLazyRoot }

function TLazyCtorLazyRoot.Getchild: TLazyCtorChild;
begin
  Result := Fchild.Value;
end;

{ TLazyCtorManyRoot }

function TLazyCtorManyRoot.Getkids: TObjectList<TLazyCtorChild>;
begin
  Result := Fkids.Value;
end;

{ TLazyCtorEagerRoot }

constructor TLazyCtorEagerRoot.Create;
begin
  Fkids := TObjectList<TLazyCtorChild>.Create;
end;

destructor TLazyCtorEagerRoot.Destroy;
begin
  Fkids.Free;
  inherited;
end;

initialization
  TRegisterClass.RegisterEntity(TLazyCtorGrand);
  TRegisterClass.RegisterEntity(TLazyCtorChild);
  TRegisterClass.RegisterEntity(TLazyCtorLazyRoot);
  TRegisterClass.RegisterEntity(TLazyCtorManyRoot);
  TRegisterClass.RegisterEntity(TLazyCtorEagerRoot);

end.
