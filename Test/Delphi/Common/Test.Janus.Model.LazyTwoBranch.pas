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

{ @abstract(Janus Framework - test fixture: ONE owner carrying TWO lazy
  OneToMany branches, to two DIFFERENT child classes.)

  WHY TWO BRANCHES AND NOT ONE

  The entry point under test, LoadLazy(AOwner, AObject), does not take the
  association it should load. It takes a sample of the CHILD, and the manager
  picks the association whose ClassNameRef matches that sample's class name.
  With a single lazy branch every possible pick is the right one, so a fixture
  with one branch cannot tell "loaded the branch it was asked for" apart from
  "loaded whatever it found first". Two branches, two child classes, and the
  second branch has to stay empty.

  WHY THE TWO CLASS NAMES ARE NOT PREFIXES OF EACH OTHER

  The pick is `Pos(ClassNameRef, AObject.ClassName)` - a SUBSTRING search, not
  an equality. `TLazyBranchAlfa` and `TLazyBranchBeta` share their first
  eleven characters and neither one is contained in the other, so a sample of
  one class cannot select the other by coincidence. Sibling models in this
  suite already measured how much a shared spelling hides (#210 turned on a
  descendant name that CARRIED the substring).

  WHY THE OWNER'S KEY AND THE CHILD'S FOREIGN KEY ARE SPELLED DIFFERENTLY

  rkey -> aowner, rkey -> bowner. A WHERE built from the wrong end of the
  association mapping produces a column that does not exist here, instead of
  the same string by accident. Same reasoning as Test.Janus.Model.AsymTree.

  WHY THE CHILDREN CARRY [OrderBy]

  TDMLGeneratorAbstract.GenerateSelectOneToOneMany appends ORDER BY from the
  child class mapping. With it, the rows of one owner come back in a sequence
  that the fixture can assert position by position; without it the fixture
  would be asserting whatever order the storage engine happened to use. The
  seeded rows are written in an order that does NOT match the sorted order, so
  an ordered assertion is a real assertion here and not a restatement of the
  insert order.

  THE LAZY DECLARATION IS THE CANONICAL ONE

  `Lazy<TObjectList<T>>` behind a read-only property, exactly as
  Examples\Delphi\Data\Object Lazy\Model.Procedimento declares SetoresList.
  Reading the property with no factory injected creates an EMPTY owning list
  (Lazy<T>.CreateDefaultValue), which is the state the load has to change.

  THE SHAPE

      lzroot.rkey  --(OneToMany, Lazy)-->  lzalfa.aowner
      lzroot.rkey  --(OneToMany, Lazy)-->  lzbeta.bowner

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Model.LazyTwoBranch;

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
  [Table('lzalfa', '')]
  [PrimaryKey('akey', TAutoIncType.AutoInc,
                      TGeneratorType.SequenceInc,
                      TSortingOrder.NoSort,
                      True, 'Primary key')]
  [Sequence('lzalfa')]
  [OrderBy('atag')]
  TLazyBranchAlfa = class
  private
    Fakey: Integer;
    Faowner: Integer;
    Fatag: String;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('akey', ftInteger)]
    property akey: Integer read Fakey write Fakey;

    /// The foreign key onto lzroot.rkey. Deliberately NOT called `rkey`.
    [Column('aowner', ftInteger)]
    property aowner: Integer read Faowner write Faowner;

    [Column('atag', ftString, 20)]
    property atag: String read Fatag write Fatag;
  end;

  [Entity]
  [Table('lzbeta', '')]
  [PrimaryKey('bkey', TAutoIncType.AutoInc,
                      TGeneratorType.SequenceInc,
                      TSortingOrder.NoSort,
                      True, 'Primary key')]
  [Sequence('lzbeta')]
  [OrderBy('btag')]
  TLazyBranchBeta = class
  private
    Fbkey: Integer;
    Fbowner: Integer;
    Fbtag: String;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('bkey', ftInteger)]
    property bkey: Integer read Fbkey write Fbkey;

    /// The foreign key onto lzroot.rkey. Deliberately NOT called `rkey`.
    [Column('bowner', ftInteger)]
    property bowner: Integer read Fbowner write Fbowner;

    [Column('btag', ftString, 20)]
    property btag: String read Fbtag write Fbtag;
  end;

  [Entity]
  [Table('lzroot', '')]
  [PrimaryKey('rkey', TAutoIncType.AutoInc,
                      TGeneratorType.SequenceInc,
                      TSortingOrder.NoSort,
                      True, 'Primary key')]
  [Sequence('lzroot')]
  TLazyBranchRoot = class
  private
    Frkey: Integer;
    Frtag: String;
    Falfas: Lazy<TObjectList<TLazyBranchAlfa>>;
    Fbetas: Lazy<TObjectList<TLazyBranchBeta>>;
    function GetAlfas: TObjectList<TLazyBranchAlfa>;
    function GetBetas: TObjectList<TLazyBranchBeta>;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('rkey', ftInteger)]
    property rkey: Integer read Frkey write Frkey;

    [Column('rtag', ftString, 20)]
    property rtag: String read Frtag write Frtag;

    /// Both branches are Lazy. Neither is reachable through FillAssociation,
    /// which injects a proxy factory and moves on; the only entry point that
    /// fills them from the owner is LoadLazy.
    [Association(TMultiplicity.OneToMany, 'rkey', 'lzalfa', 'aowner', True)]
    property alfas: TObjectList<TLazyBranchAlfa> read GetAlfas;

    [Association(TMultiplicity.OneToMany, 'rkey', 'lzbeta', 'bowner', True)]
    property betas: TObjectList<TLazyBranchBeta> read GetBetas;
  end;

implementation

{ TLazyBranchRoot }

function TLazyBranchRoot.GetAlfas: TObjectList<TLazyBranchAlfa>;
begin
  Result := Falfas.Value;
end;

function TLazyBranchRoot.GetBetas: TObjectList<TLazyBranchBeta>;
begin
  Result := Fbetas.Value;
end;

initialization
  TRegisterClass.RegisterEntity(TLazyBranchAlfa);
  TRegisterClass.RegisterEntity(TLazyBranchBeta);
  TRegisterClass.RegisterEntity(TLazyBranchRoot);

end.
