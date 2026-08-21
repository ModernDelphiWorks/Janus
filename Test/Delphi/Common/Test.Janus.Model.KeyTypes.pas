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

{ @abstract(Janus Framework - test fixture models: one entity per PRIMARY KEY
  FIELD TYPE, issue #311.)

  WHY THESE EXIST

  The insert response the REST server emits names the primary key of the row it
  just wrote. AT 865370e, the commit this branch starts from, the whole tree of
  test models declared its primary key as ftInteger with a single exception -
  Test.Janus.Model.RestLazyKeys.TStrMaster, whose `smkey` is ftString - and
  that entity is linked only into Janus.Tests.RESTfulDriver and
  Janus.Tests.Units, neither of which compiles Janus.Server.Resource. Measured,
  not assumed: a scan of every [PrimaryKey] under Test\ resolved to its
  [Column] declaration returned 39 ftInteger and 1 ftString THERE.

  THE COUNT IS PINNED TO THAT COMMIT AND THIS UNIT IS WHY IT MOVED. The
  entities below are themselves textual, GUID, date, fractional, boolean,
  64-bit, unsigned and composite keys, so the same scan on any commit of this
  branch answers something larger. The figure is quoted for the state it
  describes - the state in which the defect went unseen - and re-deriving it
  means checking out that commit.

  So the server side had no model at all whose key was not a bare integer, and
  a response that only ever has to render an integer never has to answer the
  question this issue is about.

  ONE ENTITY PER TYPE, ON PURPOSE

  A single entity carrying five columns of five types would exercise the
  rendering of five values, but only ONE of them would be a primary key, and
  the primary key is the only value the insert response emits. Each type
  therefore needs its own entity.

  EVERY KEY HERE IS SUPPLIED BY THE CALLER

  TAutoIncType.NotInc and no [Sequence]: the key arrives in the request body
  and the insert writes it as it stands. That is what a textual key IS - there
  is no generator for it in this framework - and it keeps these fixtures out of
  the sequence machinery entirely.

  THE STORAGE IS SQLITE

  SQLite has no static column typing, so a VARCHAR / NUMERIC / DATE declaration
  is a hint rather than a constraint. That is deliberate here: the subject is
  what the SERVER RENDERS out of the property, not what the database stores. }

unit Test.Janus.Model.KeyTypes;

interface

uses
  Classes,
  DB,
  SysUtils,
  Janus.Types.Nullable,
  MetaDbDiff.mapping.attributes,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Register;

type
  /// A textual primary key. The headline of issue #311.
  [Entity]
  [Table('kttext', '')]
  [PrimaryKey('ktcode', TAutoIncType.NotInc,
                        TGeneratorType.NoneInc,
                        TSortingOrder.NoSort,
                        True, 'Textual primary key')]
  TKeyTypeText = class
  private
    Fktcode: String;
    Fkttag: String;
  public
    [Restrictions([TRestriction.NotNull])]
    [Column('ktcode', ftString, 60)]
    property ktcode: String read Fktcode write Fktcode;

    [Column('kttag', ftString, 60)]
    property kttag: String read Fkttag write Fkttag;
  end;

  /// The control. An integer key must keep rendering as a JSON NUMBER - a fix
  /// that quotes everything would turn {"ktid":10} into {"ktid":"10"} and no
  /// assertion about textual keys would notice.
  [Entity]
  [Table('ktnum', '')]
  [PrimaryKey('ktid', TAutoIncType.NotInc,
                      TGeneratorType.NoneInc,
                      TSortingOrder.NoSort,
                      True, 'Integer primary key')]
  TKeyTypeNum = class
  private
    Fktid: Integer;
    Fkttag: String;
  public
    [Restrictions([TRestriction.NotNull])]
    [Column('ktid', ftInteger)]
    property ktid: Integer read Fktid write Fktid;

    [Column('kttag', ftString, 60)]
    property kttag: String read Fkttag write Fkttag;
  end;

  /// A GUID key that the SERVER generates. This is the shape that matters most
  /// to issue #311: the caller cannot know the key, so the insert response is
  /// the ONLY way it ever learns what was written.
  ///
  /// It is declared ftString + TGeneratorType.Guid38Inc, not ftGuid, and that
  /// is the framework's own documented contract rather than a preference:
  /// Janus.DML.Generator raises a NAMED error for an ftGuid column mapped onto
  /// a String property, and its message says verbatim that a GUID key stored
  /// as TEXT must be declared ftString with Guid32Inc/Guid36Inc/Guid38Inc.
  /// Guid38Inc writes the braced, hyphenated form - every one of those five
  /// characters is illegal in a bare JSON token.
  [Entity]
  [Table('ktguid', '')]
  [PrimaryKey('ktuid', TAutoIncType.AutoInc,
                       TGeneratorType.Guid38Inc,
                       TSortingOrder.NoSort,
                       True, 'Server-generated GUID primary key')]
  TKeyTypeGuid = class
  private
    Fktuid: String;
    Fkttag: String;
  public
    [Restrictions([TRestriction.NotNull])]
    [Column('ktuid', ftString, 38)]
    property ktuid: String read Fktuid write Fktuid;

    [Column('kttag', ftString, 60)]
    property kttag: String read Fkttag write Fkttag;
  end;

  /// A date key. The value renders through the AMBIENT FormatSettings, so it
  /// carries separators - and on this machine it carries a slash.
  [Entity]
  [Table('ktdate', '')]
  [PrimaryKey('ktday', TAutoIncType.NotInc,
                       TGeneratorType.NoneInc,
                       TSortingOrder.NoSort,
                       True, 'Date primary key')]
  TKeyTypeDate = class
  private
    Fktday: TDateTime;
    Fkttag: String;
  public
    [Restrictions([TRestriction.NotNull])]
    [Column('ktday', ftDate)]
    property ktday: TDateTime read Fktday write Fktday;

    [Column('kttag', ftString, 60)]
    property kttag: String read Fkttag write Fkttag;
  end;

  /// A fractional key. JSON only knows the DOT as a decimal separator; the
  /// ambient FormatSettings of a pt-BR machine renders a comma.
  [Entity]
  [Table('ktfloat', '')]
  [PrimaryKey('ktnum', TAutoIncType.NotInc,
                       TGeneratorType.NoneInc,
                       TSortingOrder.NoSort,
                       True, 'Fractional primary key')]
  TKeyTypeFloat = class
  private
    Fktnum: Double;
    Fkttag: String;
  public
    [Restrictions([TRestriction.NotNull])]
    [Column('ktnum', ftFloat, 18, 4)]
    property ktnum: Double read Fktnum write Fktnum;

    [Column('kttag', ftString, 60)]
    property kttag: String read Fkttag write Fkttag;
  end;

  /// A key declared ftSingle. It is NOT a variant of TKeyTypeFloat: the two
  /// exist to pin different things. TKeyTypeFloat asks whether the DECIMAL
  /// SEPARATOR is normalised; this one asks whether the LABEL ftSingle reaches
  /// the branch that normalises it at all.
  ///
  /// ftSingle and ftExtended are the two binary-float labels that the
  /// server-side literal table left out, and they are not exotic here:
  /// Janus.DataSet.Base.Adapter declares cBINARYFLOATFIELDKINDS as
  /// [ftFloat, DB.ftSingle, DB.ftExtended] and Janus.DataSet.Fields creates a
  /// TSingleField and a TExtendedField for them (both anchored by SYMBOL, not
  /// by line).
  ///
  /// DB.ftSingle QUALIFIED, and not by style: TypInfo declares an ftSingle of
  /// its own, so an unqualified reference resolves by uses-clause order rather
  /// than by intent. Janus.DataSet.Base.Adapter says the same thing about the
  /// same two labels.
  [Entity]
  [Table('ktsingle', '')]
  [PrimaryKey('ktsng', TAutoIncType.NotInc,
                       TGeneratorType.NoneInc,
                       TSortingOrder.NoSort,
                       True, 'Single-precision fractional primary key')]
  TKeyTypeSingle = class
  private
    Fktsng: Single;
    Fkttag: String;
  public
    [Restrictions([TRestriction.NotNull])]
    [Column('ktsng', DB.ftSingle, 18, 4)]
    property ktsng: Single read Fktsng write Fktsng;

    [Column('kttag', ftString, 60)]
    property kttag: String read Fkttag write Fkttag;
  end;

  /// The COLUMN and the PROPERTY are deliberately named differently. The
  /// response names the PROPERTY - it always did - and swapping one for the
  /// other was invisible until this entity existed.
  ///
  /// The claim has to be narrow to be true, and the narrow version is the one
  /// that matters: the response emits PRIMARY KEY columns and nothing else,
  /// and every PRIMARY KEY column in the units this project links spells the
  /// same as its property, ignoring case. Re-measured at THIS commit over the
  /// 26 units named with a path in Janus.Tests.RESTHorse.dpr: 31 key columns,
  /// exactly one divergent - this one.
  ///
  /// THE FIGURES USED TO READ 24 AND 29 AND WERE CORRECT WHEN WRITTEN. Issue
  /// #320's branch moved both without touching this sentence: it added one
  /// unit to that .dpr, and TKeyTypeSingle above added one key column. They
  /// are re-derived by scanning the .dpr's path-named units and resolving
  /// every [PrimaryKey] against its [Column]; the scan answers 24/29 at
  /// ea0208f, 26/30 at 0546a51 and 26/31 here, and the FINDING has not moved
  /// through any of it.
  ///
  /// THE UNIT COUNT WAS ALREADY WRONG BEFORE THIS BRANCH TOUCHED IT, and the
  /// honest thing is to say so rather than quietly correct it: the sentence
  /// read 25 while the same scan answered 26 at 0546a51. Issue #325 moved the
  /// COLUMN count, from 30 to 31, by adding TKeyTypeUnsignedAsText below.
  ///
  /// "IGNORING CASE" IS ALSO NEW WORDING FOR AN OLD MEASUREMENT. A
  /// case-SENSITIVE scan answers EIGHT divergent, seven of them the same
  /// id/Id pair in RestHorseTest.Models. The claim was always the
  /// case-insensitive one - it is about a column being swapped for a property,
  /// not about capitalisation - and now it says which it is.
  /// NON-key columns are a different story and diverge freely; there are
  /// five in RestHorseTest.Models alone (customer_id/CustomerId and four more
  /// in TCustomerOrderSummary), which is why the sentence says KEY.
  [Entity]
  [Table('ktalias', '')]
  [PrimaryKey('kt_code', TAutoIncType.NotInc,
                         TGeneratorType.NoneInc,
                         TSortingOrder.NoSort,
                         True, 'Textual key whose column is not its property')]
  TKeyTypeAlias = class
  private
    Fktcode: String;
    Fkttag: String;
  public
    [Restrictions([TRestriction.NotNull])]
    [Column('kt_code', ftString, 60)]
    property ktcode: String read Fktcode write Fktcode;

    [Column('kttag', ftString, 60)]
    property kttag: String read Fkttag write Fkttag;
  end;

  /// A boolean key. Absurd as a design and perfectly legal as a mapping, and
  /// it is the only shape that can tell whether VarIsOrdinal - which is TRUE
  /// for varBoolean - is allowed to swallow it into the number branch.
  [Entity]
  [Table('ktbool', '')]
  [PrimaryKey('ktflag', TAutoIncType.NotInc,
                        TGeneratorType.NoneInc,
                        TSortingOrder.NoSort,
                        True, 'Boolean primary key')]
  TKeyTypeBool = class
  private
    Fktflag: Boolean;
    Fkttag: String;
  public
    [Restrictions([TRestriction.NotNull])]
    [Column('ktflag', ftBoolean)]
    property ktflag: Boolean read Fktflag write Fktflag;

    [Column('kttag', ftString, 60)]
    property kttag: String read Fkttag write Fkttag;
  end;

  /// A 64-bit key whose value does not fit in 32 bits. Nothing about the
  /// SELECTION of the number branch depends on width, so a conversion narrowed
  /// to Integer inside that branch leaves every other clause green and
  /// truncates the key silently. The value is also above 2^53, so a repair
  /// that routed integers through Double would lose it too.
  [Entity]
  [Table('ktbig', '')]
  [PrimaryKey('ktbig', TAutoIncType.NotInc,
                       TGeneratorType.NoneInc,
                       TSortingOrder.NoSort,
                       True, '64-bit primary key')]
  TKeyTypeBig = class
  private
    Fktbig: Int64;
    Fkttag: String;
  public
    [Restrictions([TRestriction.NotNull])]
    [Column('ktbig', ftLargeint)]
    property ktbig: Int64 read Fktbig write Fktbig;

    [Column('kttag', ftString, 60)]
    property kttag: String read Fkttag write Fkttag;
  end;

  /// An UNSIGNED 64-bit key above High(Int64). The Variant arrives as
  /// varUInt64, and a cast through varInt64 REINTERPRETS the bit pattern as a
  /// negative number. Both the right answer and the wrong one are valid JSON,
  /// so no clause about parseability can tell them apart - only a clause about
  /// the VALUE can.
  [Entity]
  [Table('ktunsigned', '')]
  [PrimaryKey('ktu', TAutoIncType.NotInc,
                     TGeneratorType.NoneInc,
                     TSortingOrder.NoSort,
                     True, 'Unsigned 64-bit primary key')]
  TKeyTypeUnsigned = class
  private
    Fktu: UInt64;
    Fkttag: String;
  public
    [Restrictions([TRestriction.NotNull])]
    [Column('ktu', ftLargeint)]
    property ktu: UInt64 read Fktu write Fktu;

    [Column('kttag', ftString, 60)]
    property kttag: String read Fkttag write Fkttag;
  end;

  /// THE ESCAPE HATCH THE REFUSAL OF ISSUE #325 NAMES, so that the advice
  /// inside that message is MEASURED rather than asserted. The property is the
  /// SAME UInt64 as TKeyTypeUnsigned above - so the parameter still arrives as
  /// a Variant of VType varUInt64 - and only the COLUMN differs: ftString,
  /// which binds through TParam.AsString and keeps all twenty digits.
  ///
  /// IT IS ALSO WHAT MAKES THE ftLargeint TERM OF THAT GUARD LOAD-BEARING.
  /// Widening the guard to every integer label would refuse the very mapping
  /// its own message recommends, and this entity is the clause that says so.
  [Entity]
  [Table('ktutext', '')]
  [PrimaryKey('ktut', TAutoIncType.NotInc,
                      TGeneratorType.NoneInc,
                      TSortingOrder.NoSort,
                      True, 'Unsigned 64-bit primary key stored as text')]
  TKeyTypeUnsignedAsText = class
  private
    Fktut: UInt64;
    Fktw: UInt64;
    Fkttag: String;
  public
    [Restrictions([TRestriction.NotNull])]
    [Column('ktut', ftString, 20)]
    property ktut: UInt64 read Fktut write Fktut;

    /// A NON-KEY unsigned column, and the only shape in this repository that
    /// can ask whether the refusal of issue #325 is about VALUES or about
    /// KEYS. It rides on this entity rather than on TKeyTypeUnsigned because
    /// this one's KEY is accepted, so an insert gets far enough for the
    /// question about the non-key column to be asked at all.
    [Column('ktw', ftLargeint)]
    property ktw: UInt64 read Fktw write Fktw;

    [Column('kttag', ftString, 60)]
    property kttag: String read Fkttag write Fkttag;
  end;

  /// A COMPOSITE textual key. The pair list is a LOOP, and a loop that stops
  /// after its first turn is invisible to every single-column clause in the
  /// fixture. The declaration uses the comma form, which
  /// MetaDbDiff.Mapping.Attributes splits with ExtractStrings([',', ';']).
  [Entity]
  [Table('ktcomp', '')]
  [PrimaryKey('ktca,ktcb', TAutoIncType.NotInc,
                           TGeneratorType.NoneInc,
                           TSortingOrder.NoSort,
                           True, 'Composite textual primary key')]
  TKeyTypeComposite = class
  private
    Fktca: String;
    Fktcb: String;
    Fkttag: String;
  public
    [Restrictions([TRestriction.NotNull])]
    [Column('ktca', ftString, 60)]
    property ktca: String read Fktca write Fktca;

    [Restrictions([TRestriction.NotNull])]
    [Column('ktcb', ftString, 60)]
    property ktcb: String read Fktcb write Fktcb;

    [Column('kttag', ftString, 60)]
    property kttag: String read Fkttag write Fkttag;
  end;

  /// A NULLABLE key, left unset by the caller. It reaches the null branch of
  /// the value builder through the VarIsNull HALF of that guard:
  /// GetNullableValue answers a Variant NULL for a Nullable property whose
  /// FHasValue is clear.
  ///
  /// It is NOT the only shape that reaches that branch, and an earlier version
  /// of this comment said it was. TKeyTypeDecoy, in
  /// Test.Janus.Model.KeyTypeDecoy, reaches the same branch through the OTHER
  /// half - VarIsEmpty, with a varEmpty rather than a varNull. Measured:
  /// deleting the whole branch kills BOTH clauses, while deleting only the
  /// VarIsEmpty half kills only the decoy's. The decoy arrived two commits
  /// after this sentence and falsified it in place, which is exactly the way
  /// an absolute claim goes stale without anyone touching it.
  [Entity]
  [Table('ktnull', '')]
  [PrimaryKey('ktopt', TAutoIncType.NotInc,
                       TGeneratorType.NoneInc,
                       TSortingOrder.NoSort,
                       True, 'Nullable primary key')]
  TKeyTypeNullable = class
  private
    Fktopt: Nullable<String>;
    Fkttag: String;
  public
    [Column('ktopt', ftString, 60)]
    property ktopt: Nullable<String> read Fktopt write Fktopt;

    [Column('kttag', ftString, 60)]
    property kttag: String read Fkttag write Fkttag;
  end;

implementation

initialization
  /// Registered HERE, not in a [SetupFixture]. TMappingExplorer.GetRepositoryMapping
  /// builds its repository ONCE, lazily, from whatever TRegisterClass holds at
  /// the moment of the first lookup, and caches it forever - a registration in
  /// a fixture setup can arrive after that snapshot is already sealed.
  TRegisterClass.RegisterEntity(TKeyTypeText);
  TRegisterClass.RegisterEntity(TKeyTypeNum);
  TRegisterClass.RegisterEntity(TKeyTypeGuid);
  TRegisterClass.RegisterEntity(TKeyTypeDate);
  TRegisterClass.RegisterEntity(TKeyTypeFloat);
  TRegisterClass.RegisterEntity(TKeyTypeSingle);
  TRegisterClass.RegisterEntity(TKeyTypeAlias);
  TRegisterClass.RegisterEntity(TKeyTypeBool);
  TRegisterClass.RegisterEntity(TKeyTypeBig);
  TRegisterClass.RegisterEntity(TKeyTypeUnsigned);
  TRegisterClass.RegisterEntity(TKeyTypeUnsignedAsText);
  TRegisterClass.RegisterEntity(TKeyTypeComposite);
  TRegisterClass.RegisterEntity(TKeyTypeNullable);

end.
