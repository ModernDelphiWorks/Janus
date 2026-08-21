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

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Test.Janus.DML.Generator.SQLite;

interface

uses
  Classes,
  DB,
  Rtti,
  SysUtils,
  StrUtils,
  Generics.Collections,
  DUnitX.TestFramework,
  FluentSQL,
  FluentSQL.Interfaces,
  DataEngine.FactoryInterfaces,
  MetaDbDiff.Mapping.Attributes,
  MetaDbDiff.Mapping.Classes,
  MetaDbDiff.Mapping.Explorer,
  MetaDbDiff.Mapping.Register,
  MetaDbDiff.Types.Mapping,
  Janus.Command.Inserter,
  Janus.Command.Updater,
  Janus.Command.Deleter,
  Janus.Command.Selecter,
  Janus.DML.Commands,
  Janus.DML.Interfaces,
  Janus.Types.Nullable,
  DataEngine.DriverConnection,
  Janus.DML.Generator,
  Janus.DML.Generator.SQLite,
  Janus.DML.Generator.PostgreSQL,
  Janus.Container.ObjectSet,
  Janus.Container.ObjectSet.Interfaces,
  Janus.Model.Client,
  Janus.Model.Master,
  Janus.Model.Detail,
  Test.Janus.Model.KeyOnly,
  Test.Janus.Model.RestLazyKeys;

type
  TFakeConnection = class(TInterfacedObject, IDBConnection)
  private
    FDriver: TDriverName;
    FOptions: IOptions;
  public
    constructor Create(ADriver: TDriverName); overload;
    /// Options is nil for every other test on purpose - a generator must
    /// survive a connection that answers nothing, and that nil-safety is what
    /// the four literal tests exercise for free. This overload exists only so
    /// the StoreGUIDAsOctet guard has a connection that really says True.
    constructor Create(ADriver: TDriverName; const AOptions: IOptions); overload;
    procedure Connect;
    procedure Disconnect;
    procedure ExecuteDirect(const ASQL: String); overload;
    procedure ExecuteDirect(const ASQL: String; const AParams: TParams); overload;
    procedure ExecuteScript(const AScript: String);
    procedure AddScript(const AScript: String);
    procedure ExecuteScripts;
    procedure ApplyUpdates(const ADataSets: array of IDBDataSet);
    function IsConnected: Boolean;
    function CreateQuery: IDBQuery;
    function CreateDataSet(const ASQL: String = ''): IDBDataSet;
    function GetSQLScripts: String;
    function RowsAffected: UInt32;
    function GetDriver: TDriverName;
    function CommandMonitor: ICommandMonitor;
    function MonitorCallback: TMonitorProc;
    function Options: IOptions;
    procedure SetCommandMonitor(AMonitor: ICommandMonitor);
    function BulkLoader: IDBBulkLoader;
    function Cache: IDBCacheProvider;
    function MetadataCache: IDBMetadataCache;
    procedure SetCacheProvider(ACache: IDBCacheProvider);
    procedure SetMetadataCacheProvider(AMetadataCache: IDBMetadataCache);
    procedure RefreshMetadata(const ATableName: string);
    function IsAlive: Boolean;
    function ResiliencePolicy: IDBResiliencePolicy;
    procedure SetResiliencePolicy(APolicy: IDBResiliencePolicy);
    procedure AddObserver(const AObserver: IDBObserver);
    procedure RemoveObserver(const AObserver: IDBObserver);
    function SlowQueryThreshold: Integer;
    procedure SetSlowQueryThreshold(const AValue: Integer);
    function _GetTransaction(const AKey: String): TComponent;
    procedure StartTransaction(const ALevel: TDBIsolationLevel = ilDefault);
    procedure Commit;
    procedure Rollback;
    procedure AddTransaction(const AKey: String; const ATransaction: TComponent);
    procedure UseTransaction(const AKey: String);
    function TransactionActive: TComponent;
    function InTransaction: Boolean;
  end;

  /// <summary> A DIALECT THAT FORGOT TO ANSWER ABOUT GUID.
  ///  Issue #284 chose an ABSTRACT GuidLiteral over a format field precisely
  ///  so that this class cannot exist silently. It implements the four other
  ///  abstract members of TDMLGeneratorAbstract and leaves GuidLiteral alone;
  ///  the compiler answers with W1020 at every construction site below, and
  ///  the run answers with EAbstractError the first time a ftGuid column is
  ///  formatted. TestGuid_ADialectThatDoesNotImplementGuidLiteral_FailsLoudly
  ///  is what turns that claim from prose into a measurement - a format field
  ///  in the FDateFormat mould would have compiled clean, run clean, and
  ///  emitted '1 = 0' again. </summary>
  TDMLGeneratorWithoutGuid = class(TDMLGeneratorAbstract)
  public
    constructor Create; override;
    function GeneratorSelectAll(AClass: TClass; APageSize: Integer;
      AID: TValue): String; override;
    function GeneratorSelectWhere(AClass: TClass; AWhere: String;
      AOrderBy: String; APageSize: Integer): String; override;
    function GeneratorAutoIncCurrentValue(AObject: TObject;
      AAutoInc: TDMLCommandAutoInc): Int64; override;
    function GeneratorAutoIncNextValue(AObject: TObject;
      AAutoInc: TDMLCommandAutoInc): Int64; override;
  end;

  /// <summary> A ftGuid COLUMN OVER A String PROPERTY - WRONG ON PURPOSE.
  ///  The owner's ruling for #284 is that ftGuid means a TGUID property, and
  ///  that is not a new rule: TCommandInserter._GetParamValue (by symbol),
  ///  Janus.Command.Updater.pas:118-119 and Janus.Command.Deleter.pas:97-98
  ///  have always read it as AsType<TGUID>.ToString. This pair exists so the
  ///  ruling has a test instead of a paragraph: the SELECT side must say WHICH
  ///  property is wrong and WHAT to do, not raise a bare EInvalidCast from
  ///  inside the RTTI. Test.Janus.Model.RestLazyKeys used to be shaped like
  ///  this by accident; #284 fixed it and moved the shape here, where it is
  ///  the subject of a test rather than a landmine. </summary>
  [Entity]
  [Table('gosschild', '')]
  [PrimaryKey('gckey', TAutoIncType.NotInc, TGeneratorType.NoneInc,
              TSortingOrder.NoSort, True, 'Primary key')]
  TGuidOverStringChild = class
  private
    Fgckey: Integer;
    Fgcparent: String;
  public
    [Column('gckey', ftInteger)]
    property gckey: Integer read Fgckey write Fgckey;
    [Column('gcparent', ftGuid, 38)]
    property gcparent: String read Fgcparent write Fgcparent;
  end;

  [Entity]
  [Table('gossmaster', '')]
  [PrimaryKey('gmkey', TAutoIncType.NotInc, TGeneratorType.NoneInc,
              TSortingOrder.NoSort, True, 'Primary key')]
  TGuidOverStringMaster = class
  private
    Fgmkey: Integer;
    Fgmparent: String;
    Fchilds: TObjectList<TGuidOverStringChild>;
  public
    constructor Create;
    destructor Destroy; override;
    [Column('gmkey', ftInteger)]
    property gmkey: Integer read Fgmkey write Fgmkey;
    [Column('gmparent', ftGuid, 38)]
    property gmparent: String read Fgmparent write Fgmparent;
    [Association(TMultiplicity.OneToMany, 'gmparent', 'gosschild', 'gcparent')]
    property childs: TObjectList<TGuidOverStringChild> read Fchilds write Fchilds;
  end;

  /// <summary> AN OPTIONAL GUID FOREIGN KEY - Nullable<TGUID>.
  ///  This is the only shape that reaches the Variant-Null arm of
  ///  TDMLGeneratorAbstract._GetGuidValue: for a Nullable<T> with HasValue
  ///  False, GetNullableValue returns TValue.From<Variant>(Null)
  ///  (MetaDbDiff.RTTI.Helper.pas:356-359), not a zeroed TGUID and not an
  ///  empty TValue. A plain TGUID property can only ever be all-zeros, which
  ///  is a DIFFERENT arm, so TCompMaster could never exercise this one - the
  ///  arm shipped load-bearing and untested, and the whole suite stayed green
  ///  with it deleted. Without it, an association whose optional GUID FK is
  ///  simply not set raises the named wrong-type error instead of selecting
  ///  zero children. </summary>
  [Entity]
  [Table('nguidchild', '')]
  [PrimaryKey('ngckey', TAutoIncType.NotInc, TGeneratorType.NoneInc,
              TSortingOrder.NoSort, True, 'Primary key')]
  TNullableGuidChild = class
  private
    Fngckey: Integer;
    Fngcparent: TGUID;
  public
    [Column('ngckey', ftInteger)]
    property ngckey: Integer read Fngckey write Fngckey;
    [Column('ngcparent', ftGuid, 38)]
    property ngcparent: TGUID read Fngcparent write Fngcparent;
  end;

  [Entity]
  [Table('nguidmaster', '')]
  [PrimaryKey('ngmkey', TAutoIncType.NotInc, TGeneratorType.NoneInc,
              TSortingOrder.NoSort, True, 'Primary key')]
  TNullableGuidMaster = class
  private
    Fngmkey: Integer;
    Fngmparent: Nullable<TGUID>;
    Fchilds: TObjectList<TNullableGuidChild>;
  public
    constructor Create;
    destructor Destroy; override;
    [Column('ngmkey', ftInteger)]
    property ngmkey: Integer read Fngmkey write Fngmkey;
    [Column('ngmparent', ftGuid, 38)]
    property ngmparent: Nullable<TGUID> read Fngmparent write Fngmparent;
    [Association(TMultiplicity.OneToMany, 'ngmparent', 'nguidchild', 'ngcparent')]
    property childs: TObjectList<TNullableGuidChild> read Fchilds write Fchilds;
  end;

  /// <summary> TWELVE COLUMNS, AND THE COUNT IS THE POINT. Issue #337.
  ///
  ///  Since FluentSQL parameterised the value slot, the marker this generator
  ///  asks for is handed back as ':pN' and TDMLGeneratorAbstract
  ///  ._RestoreNamedPlaceholders writes the column name over it. Every other
  ///  entity in this suite emits FEWER THAN TEN columns, and under ten every
  ///  wrong way of doing that rewrite still looks right:
  ///
  ///    - a ReplaceStr sweep in ascending order is correct up to :p9 and
  ///      CORRUPTS from :p10 on, because ':p1' is a prefix of ':p10' - the
  ///      sweep rewrites the head and leaves the '0', so the tenth marker
  ///      comes out as the FIRST column's name with a stray digit glued on;
  ///    - the widest existing fixture is Tdetail with five columns, so that
  ///      corruption cannot be reached by anything already written here.
  ///
  ///  Hence twelve. The clause below asserts the WHOLE statement, in order,
  ///  rather than Contains() per column: Contains() is blind to a permutation,
  ///  and the ordinal is exactly what a marker rewrite can get wrong.
  ///
  ///  It is deliberately flat - no key generator, no association, no nullable.
  ///  Anything else here would be a second reason for it to go red. </summary>
  [Entity]
  [Table('wideslot', '')]
  [PrimaryKey('w01', TAutoIncType.NotInc, TGeneratorType.NoneInc,
              TSortingOrder.NoSort, True, 'Primary key')]
  TWideSlot = class
  private
    Fw01, Fw02, Fw03, Fw04, Fw05, Fw06: Integer;
    Fw07, Fw08, Fw09, Fw10, Fw11, Fw12: Integer;
  public
    [Column('w01', ftInteger)] property w01: Integer read Fw01 write Fw01;
    [Column('w02', ftInteger)] property w02: Integer read Fw02 write Fw02;
    [Column('w03', ftInteger)] property w03: Integer read Fw03 write Fw03;
    [Column('w04', ftInteger)] property w04: Integer read Fw04 write Fw04;
    [Column('w05', ftInteger)] property w05: Integer read Fw05 write Fw05;
    [Column('w06', ftInteger)] property w06: Integer read Fw06 write Fw06;
    [Column('w07', ftInteger)] property w07: Integer read Fw07 write Fw07;
    [Column('w08', ftInteger)] property w08: Integer read Fw08 write Fw08;
    [Column('w09', ftInteger)] property w09: Integer read Fw09 write Fw09;
    [Column('w10', ftInteger)] property w10: Integer read Fw10 write Fw10;
    [Column('w11', ftInteger)] property w11: Integer read Fw11 write Fw11;
    [Column('w12', ftInteger)] property w12: Integer read Fw12 write Fw12;
  end;

  /// <summary> A KEY COLUMN NAMED LIKE A FLUENTSQL PLACEHOLDER. Issue #337.
  ///
  ///  The SET slot is parameterised and comes back as ':p1'; the key predicate
  ///  is written VERBATIM by GeneratorUpdate through the Where(String)
  ///  overload, so a key column called `p1` puts a SECOND ':p1' into the very
  ///  same statement - and the two are indistinguishable as text.
  ///
  ///  There is nothing exotic about the name: p1 is a legal identifier in
  ///  every engine Janus speaks, and this entity is otherwise the plainest one
  ///  that can be written. The trigger is a lowercase key named p&lt;N&gt; with
  ///  N no greater than the number of columns in the SET. </summary>
  [Entity]
  [Table('r337pk', '')]
  [PrimaryKey('p1', TAutoIncType.NotInc, TGeneratorType.NoneInc,
              TSortingOrder.NoSort, True, 'Primary key')]
  TPlaceholderNamedKey = class
  private
    Fp1: Integer;
    Fnm: String;
  public
    [Column('p1', ftInteger)]
    property p1: Integer read Fp1 write Fp1;
    [Column('nm', ftString, 20)]
    property nm: String read Fnm write Fnm;
  end;

  /// <summary> A GENERATOR THAT LETS A CLAUSE REACH THE TWO REFUSALS. #337.
  ///
  ///  Neither refusal can be produced by any statement Janus builds today, and
  ///  both are presented in the code as ACTIVE nets rather than as declared
  ///  survivors - so each needs a clause of its own, or an inverted condition
  ///  and a wrong message would ship unnoticed.
  ///
  ///  UseDialect reaches ConfigureFluentSQLDriver, which only the SQLite and
  ///  Firebird generators call for real; asking for MySQL makes FluentSQL
  ///  serialize as MySQL, and their MySQL serializer rewrites every ':pN' to
  ///  '?' (FluentSQL.SerializeMySQL.pas:52), so NOTHING is left to restore.
  ///  SpliceWith reaches the splice with a hand-made pair that is not a
  ///  prefix, which their serializer never produces. Descending from the
  ///  SQLite generator rather than from the abstract keeps the probe down to
  ///  the two lines that are actually the subject. </summary>
  TDMLGeneratorDialectProbe = class(TDMLGeneratorSQLite)
  public
    procedure UseDialect(const ADriver: TDriverName);
    function SpliceWith(const AValueRegion, AWholeStatement: String): String;
  end;

  [TestFixture]
  TTestDMLGenerator = class
  private
    FConnection: IDBConnection;
    function CreateClient: Tclient;
    function CreateDetail: Tdetail;
    function CreateCompMaster: TCompMaster;
    function GuidSelect(const ADriver: TDriverName; const AMany: Boolean): String;
    function NullableGuidSelect(const ASet: Boolean): String;
    function OctetSelect(const AOctet: Boolean): String;
    function FindAssociation(AClass: TClass; const AClassNameRef: String): TAssociationMapping;
    /// <summary> EVERY VALUE OF AN INSERT IS THE MARKER OF THE COLUMN IN ITS
    ///  OWN POSITION. Issue #337. It reads the two parenthesised lists out of
    ///  the statement and pairs them by ORDINAL, which is the invariant a
    ///  marker rewrite can break; it does NOT assert a fixed column order, so
    ///  the clause stays about the rewrite and not about the order RTTI hands
    ///  the properties over in. </summary>
    procedure _AssertEachValueIsItsOwnColumnsMarker(const ASQL: String;
      const AExpectedCount: Integer);
  public
    [Setup]
    procedure Setup;
    [Test]
    procedure TestGenerateInsert_ClientTargetsMappedTable;
    [Test]
    procedure TestGenerateInsert_ClientIncludesMappedColumns;
    [Test]
    procedure TestGenerateInsert_ClientOmitsNullBlob;
    [Test]
    procedure TestGenerateInsert_ClientBuildsExpectedParamCount;
    [Test]
    procedure TestGenerateInsert_ClientBuildsPrimaryKeyParam;
    [Test]
    procedure TestGenerateInsert_ClientBuildsNameParam;
    [Test]
    procedure TestGenerateInsert_ClientPreservesBindPlaceholderWithoutQuotes;
    [Test]
    procedure TestGenerateUpdate_ClientTargetsMappedTable;
    [Test]
    procedure TestGenerateUpdate_ClientBuildsSetClause;
    [Test]
    procedure TestGenerateUpdate_ClientBuildsWhereClause;
    [Test]
    procedure TestGenerateUpdate_ClientPreservesBindPlaceholderWithoutQuotes;
    [Test]
    procedure TestGenerateUpdate_EmptyChangesReturnsEmptySql;
    [Test]
    procedure TestGenerateUpdate_ClientBuildsExpectedParamCount;
    [Test]
    procedure TestGenerateDelete_ClientTargetsMappedTable;
    [Test]
    procedure TestGenerateDelete_ClientBuildsPrimaryKeyParam;
    [Test]
    procedure TestGenerateSelectAll_ClientBuildsSelect;
    [Test]
    procedure TestGenerateSelectAll_ClientIncludesConfiguredOrderBy;
    [Test]
    procedure TestGenerateSelectId_ClientBuildsPrimaryKeyPredicate;
    [Test]
    procedure TestGenerateSelectWhere_PreservesPercentWildcard;
    [Test]
    procedure TestGenerateSelect_FirebirdWithWhere_ProducesCorrectSQL;
    [Test]
    procedure TestGenerateSelect_SQLiteWithPagination_ProducesLimitOffset;
    [Test]
    procedure TestGenerateSelect_FirebirdWithJoin_ProducesJoinClause;
    [Test]
    procedure TestGenerateSelect_SQLiteOrderBy_AppendsOrderByClause;
    [Test]
    procedure TestGenerateInsert_MultiColumn_PreservesAllPlaceholders;
    [Test]
    procedure TestGenerateUpdate_MultiField_AllPlaceholdersWithoutQuotes;
    // Issue #337 - see the TWideSlot summary for why twelve columns and why
    // the whole statement is asserted instead of Contains() per column.
    [Test]
    procedure TestGenerateInsert_TwelveColumns_EveryMarkerLandsInItsOwnSlot;
    [Test]
    procedure TestGenerateUpdate_TwelveFields_EveryMarkerLandsInItsOwnSlot;
    // Issue #337 - see the TPlaceholderNamedKey summary.
    [Test]
    procedure TestGenerateUpdate_AKeyNamedLikeAPlaceholder_KeepsItsOwnMarker;
    [Test]
    procedure FluentSQLRendersTheValueRegionAsAPrefixOfTheWholeUpdate;
    // Issue #337 - the two refusals, reached through TDMLGeneratorDialectProbe.
    [Test]
    procedure TestGenerateInsert_ADialectThatEatsThePlaceholders_RefusesByName;
    [Test]
    procedure TestSplice_AValueRegionThatIsNotAPrefix_RefusesByName;
    [Test]
    procedure TestSplice_AValueRegionThatIsAPrefix_CarriesTheTailOverUntouched;
    [Test]
    procedure TestGenerateNextPacket_UsesSqlitePagination;
    [Test]
    procedure TestGenerateSelectOneToOne_UsesAssociationColumns;
    [Test]
    procedure TestGenerateSelectOneToMany_UsesAssociationColumns;
    [Test]
    procedure TestGenerateSelectAll_MasterIncludesJoinAndScope;
    // Regression: a no-op / keys-only ObjectSet Update (Modify + Update with no
    // changed column) must NOT raise EListError 'Item not found'. Before the fix,
    // ModifyFieldsCompare never inserts the per-row key (ClassName-<pk>) when
    // nothing changed, so TSessionAbstract.Update -> ModifiedFields.Items[AKey]
    // raised. The DataSet path already guarded this; the ObjectSet path did not.
    [Test]
    procedure TestObjectSetUpdate_NoModifiedFields_DoesNotRaiseItemNotFound;

    // ---------------------------------------------------------------------
    // Issue #284 - a ftGuid association key selected zero children in silence
    // ---------------------------------------------------------------------
    [Test]
    procedure TestGuid_OneToOne_SQLite_WritesTheGuidLiteralAndNotTheZeroRowsGuard;
    [Test]
    procedure TestGuid_OneToOneMany_SQLite_WritesTheGuidLiteralAndNotTheZeroRowsGuard;
    [Test]
    procedure TestGuid_OneToOne_PostgreSQL_AnswersWithItsOwnLiteral;
    [Test]
    procedure TestGuid_OneToOneMany_PostgreSQL_AnswersWithItsOwnLiteral;
    [Test]
    procedure TestGuid_AnUnsetGuidKeyStillBecomesTheZeroRowsGuard;
    [Test]
    procedure TestGuid_ADialectThatDoesNotImplementGuidLiteral_FailsLoudly;
    [Test]
    procedure TestGuid_AGuidColumnOverAStringProperty_RaisesANamedError;
    [Test]
    procedure TestGuid_ANullableGuidWithNoValue_BecomesTheZeroRowsGuard;
    [Test]
    procedure TestGuid_ANullableGuidWithAValue_ReachesTheDialectLiteral;
    [Test]
    procedure TestGuid_StoreGUIDAsOctetOn_RaisesInsteadOfMatchingNothing;
    [Test]
    procedure TestGuid_StoreGUIDAsOctetOff_EmitsTheLiteralAsUsual;
  end;

implementation

const
  /// The same GUID the REST family pinned for issue #251
  /// (Test.Janus.Rest.Lazy.pas:362), so the two halves of the same defect can
  /// be read side by side. Written here in the form TGUID.ToString emits:
  /// 38 characters, braces, hyphens, UPPERCASE hex.
  cGUIDKEY = '{6F9619FF-8B86-D011-B42D-00CF4FC964FF}';

  cSELECTCOMPCHILD =
    'SELECT compchild.cckey, compchild.cck1, compchild.cck2, ' +
    'compchild.cck3, compchild.cck4, compchild.cck5, compchild.cck6, ' +
    'compchild.cck7 FROM compchild';

  /// The seven terms, in order, each formatted by ITS OWN type: Integer bare,
  /// String quoted, GUID quoted in the 38-character braced UPPERCASE form,
  /// Date through FDateFormat, Currency with the decimal separator normalised
  /// to a dot, DateTime through FDateFormat too and Time through FTimeFormat.
  /// MEASURED AND NOT FIXED HERE: the cck6 term is ftDateTime and comes out as
  /// '2026-08-10' - the TIME IS DROPPED, because the ftDateTime branch shares
  /// FDateFormat with ftDate - they are ONE arm of
  /// TDMLGeneratorAbstract._GetPropertyValue, `ftDateTime, ftDate`. BY ARM:
  /// the ":623-626" this line used to carry rotted when issue #326 grew that
  /// unit. That is a
  /// pre-existing defect of a different branch, it is pinned here instead of
  /// being hidden by a substring assertion, and it is not what #284 is about.
  cWHEREGUIDKEY =
    ' WHERE compchild.cck1 = 7' +
    ' AND compchild.cck2 = ''BR''' +
    ' AND compchild.cck3 = ''' + cGUIDKEY + '''' +
    ' AND compchild.cck4 = ''2026-08-10''' +
    ' AND compchild.cck5 = 1234.56' +
    ' AND compchild.cck6 = ''2026-08-10''' +
    ' AND compchild.cck7 = ''14:07:53''';

  /// THE TWO DIALECTS EXPECT THE SAME TEXT, AND THAT IS A MEASUREMENT.
  /// Two constants rather than one use of a shared one, so that the day a
  /// dialect genuinely diverges the split is a one-line edit and not a
  /// redesign; equal today because the DDL this house INTENDS for ftGuid is
  /// CHAR(n) on both (MetaDbDiff.Metadata.Extract.pas:429-445 never creates a
  /// native uuid), so both compare text against text. "Intends" and not "emits" is measured - see CanonicalGuidLiteral. Inventing a difference
  /// to make the two-dialect proof look stronger would be inventing a defect;
  /// what proves the per-dialect dispatch is the mutation, and the abstract
  /// test below.
  cWHERESQLITE = cWHEREGUIDKEY;
  cWHEREPOSTGRES = cWHEREGUIDKEY;

constructor TFakeConnection.Create(ADriver: TDriverName);
begin
  inherited Create;
  FDriver := ADriver;
end;

constructor TFakeConnection.Create(ADriver: TDriverName;
  const AOptions: IOptions);
begin
  inherited Create;
  FDriver := ADriver;
  FOptions := AOptions;
end;

procedure TFakeConnection.AddScript(const AScript: String);
begin
end;

procedure TFakeConnection.AddTransaction(const AKey: String;
  const ATransaction: TComponent);
begin
end;

procedure TFakeConnection.ApplyUpdates(const ADataSets: array of IDBDataSet);
begin
end;

function TFakeConnection.CommandMonitor: ICommandMonitor;
begin
  Result := nil;
end;

procedure TFakeConnection.Commit;
begin
end;

procedure TFakeConnection.Connect;
begin
end;

function TFakeConnection.CreateDataSet(const ASQL: String): IDBDataSet;
begin
  Result := nil;
end;

function TFakeConnection.CreateQuery: IDBQuery;
begin
  Result := nil;
end;

procedure TFakeConnection.Disconnect;
begin
end;

procedure TFakeConnection.ExecuteDirect(const ASQL: String);
begin
end;

procedure TFakeConnection.ExecuteDirect(const ASQL: String; const AParams: TParams);
begin
end;

procedure TFakeConnection.ExecuteScript(const AScript: String);
begin
end;

procedure TFakeConnection.ExecuteScripts;
begin
end;

function TFakeConnection.GetDriver: TDriverName;
begin
  Result := FDriver;
end;

function TFakeConnection.GetSQLScripts: String;
begin
  Result := '';
end;

function TFakeConnection.InTransaction: Boolean;
begin
  Result := False;
end;

function TFakeConnection.IsConnected: Boolean;
begin
  Result := False;
end;

function TFakeConnection.MonitorCallback: TMonitorProc;
begin
  Result := nil;
end;

function TFakeConnection.Options: IOptions;
begin
  Result := FOptions;
end;

procedure TFakeConnection.Rollback;
begin
end;

function TFakeConnection.RowsAffected: UInt32;
begin
  Result := 0;
end;

procedure TFakeConnection.SetCommandMonitor(AMonitor: ICommandMonitor);
begin
end;

procedure TFakeConnection.StartTransaction(const ALevel: TDBIsolationLevel = ilDefault);
begin
end;

function TFakeConnection.BulkLoader: IDBBulkLoader;
begin
  Result := nil;
end;

function TFakeConnection.Cache: IDBCacheProvider;
begin
  Result := nil;
end;

function TFakeConnection.MetadataCache: IDBMetadataCache;
begin
  Result := nil;
end;

procedure TFakeConnection.SetCacheProvider(ACache: IDBCacheProvider);
begin
end;

procedure TFakeConnection.SetMetadataCacheProvider(AMetadataCache: IDBMetadataCache);
begin
end;

procedure TFakeConnection.RefreshMetadata(const ATableName: string);
begin
end;

function TFakeConnection.IsAlive: Boolean;
begin
  Result := False;
end;

function TFakeConnection.ResiliencePolicy: IDBResiliencePolicy;
begin
  Result := nil;
end;

procedure TFakeConnection.SetResiliencePolicy(APolicy: IDBResiliencePolicy);
begin
end;

procedure TFakeConnection.AddObserver(const AObserver: IDBObserver);
begin
end;

procedure TFakeConnection.RemoveObserver(const AObserver: IDBObserver);
begin
end;

function TFakeConnection.SlowQueryThreshold: Integer;
begin
  Result := 0;
end;

procedure TFakeConnection.SetSlowQueryThreshold(const AValue: Integer);
begin
end;

function TFakeConnection.TransactionActive: TComponent;
begin
  Result := nil;
end;

procedure TFakeConnection.UseTransaction(const AKey: String);
begin
end;

function TFakeConnection._GetTransaction(const AKey: String): TComponent;
begin
  Result := nil;
end;

function TTestDMLGenerator.CreateClient: Tclient;
begin
  Result := Tclient.Create;
  Result.client_id := 1;
  Result.client_name := 'Acme';
end;

function TTestDMLGenerator.CreateDetail: Tdetail;
begin
  Result := Tdetail.Create;
  Result.detail_id := 10;
  Result.master_id := 1;
  Result.lookup_id := 3;
  Result.lookup_description := 'Item A';
  Result.price := 25.5;
end;

function TTestDMLGenerator.FindAssociation(AClass: TClass;
  const AClassNameRef: String): TAssociationMapping;
var
  LAssociation: TAssociationMapping;
  LAssociations: TAssociationMappingList;
begin
  Result := nil;
  LAssociations := TMappingExplorer.GetMappingAssociation(AClass);
  for LAssociation in LAssociations do
    if SameText(LAssociation.ClassNameRef, AClassNameRef) then
      Exit(LAssociation);
end;

procedure TTestDMLGenerator.Setup;
begin
  FConnection := TFakeConnection.Create(dnSQLite);
end;

procedure TTestDMLGenerator.TestGenerateInsert_ClientTargetsMappedTable;
var
  LClient: Tclient;
  LInserter: TCommandInserter;
  LSQL: String;
begin
  LClient := CreateClient;
  try
    LInserter := TCommandInserter.Create(FConnection, dnSQLite, LClient);
    try
      LSQL := LowerCase(LInserter.GenerateInsert(LClient));
      Assert.Contains(LSQL, 'insert into client');
    finally
      LInserter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateInsert_ClientIncludesMappedColumns;
var
  LClient: Tclient;
  LInserter: TCommandInserter;
  LSQL: String;
begin
  LClient := CreateClient;
  try
    LInserter := TCommandInserter.Create(FConnection, dnSQLite, LClient);
    try
      LSQL := LowerCase(LInserter.GenerateInsert(LClient));
      Assert.Contains(LSQL, 'client_id');
      Assert.Contains(LSQL, 'client_name');
    finally
      LInserter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateInsert_ClientOmitsNullBlob;
var
  LClient: Tclient;
  LInserter: TCommandInserter;
  LSQL: String;
begin
  LClient := CreateClient;
  try
    LInserter := TCommandInserter.Create(FConnection, dnSQLite, LClient);
    try
      LSQL := LowerCase(LInserter.GenerateInsert(LClient));
      Assert.DoesNotContain(LSQL, 'client_foto');
    finally
      LInserter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateInsert_ClientBuildsExpectedParamCount;
var
  LClient: Tclient;
  LInserter: TCommandInserter;
begin
  LClient := CreateClient;
  try
    LInserter := TCommandInserter.Create(FConnection, dnSQLite, LClient);
    try
      LInserter.GenerateInsert(LClient);
      Assert.AreEqual(2, LInserter.Params.Count);
    finally
      LInserter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateInsert_ClientBuildsPrimaryKeyParam;
var
  LClient: Tclient;
  LInserter: TCommandInserter;
begin
  LClient := CreateClient;
  try
    LInserter := TCommandInserter.Create(FConnection, dnSQLite, LClient);
    try
      LInserter.GenerateInsert(LClient);
      Assert.AreEqual('client_id', LInserter.Params.ParamByName('client_id').Name);
      Assert.AreEqual(1, LInserter.Params.ParamByName('client_id').AsInteger);
    finally
      LInserter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateInsert_ClientBuildsNameParam;
var
  LClient: Tclient;
  LInserter: TCommandInserter;
begin
  LClient := CreateClient;
  try
    LInserter := TCommandInserter.Create(FConnection, dnSQLite, LClient);
    try
      LInserter.GenerateInsert(LClient);
      Assert.AreEqual('Acme', LInserter.Params.ParamByName('client_name').AsString);
    finally
      LInserter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateInsert_ClientPreservesBindPlaceholderWithoutQuotes;
var
  LClient: Tclient;
  LInserter: TCommandInserter;
  LSQL: String;
begin
  LClient := CreateClient;
  try
    LInserter := TCommandInserter.Create(FConnection, dnSQLite, LClient);
    try
      LSQL := LowerCase(LInserter.GenerateInsert(LClient));
      Assert.Contains(LSQL, ':client_name');
      Assert.DoesNotContain(LSQL, ''':client_name''');
    finally
      LInserter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateUpdate_ClientTargetsMappedTable;
var
  LChanges: TDictionary<String, String>;
  LClient: Tclient;
  LUpdater: TCommandUpdater;
  LSQL: String;
begin
  LChanges := TDictionary<String, String>.Create;
  LClient := CreateClient;
  try
    LChanges.Add('client_name', 'client_name');
    LUpdater := TCommandUpdater.Create(FConnection, dnSQLite, LClient);
    try
      LSQL := LowerCase(LUpdater.GenerateUpdate(LClient, LChanges));
      Assert.Contains(LSQL, 'update client');
    finally
      LUpdater.Free;
    end;
  finally
    LClient.Free;
    LChanges.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateUpdate_ClientBuildsSetClause;
var
  LChanges: TDictionary<String, String>;
  LClient: Tclient;
  LUpdater: TCommandUpdater;
  LSQL: String;
begin
  LChanges := TDictionary<String, String>.Create;
  LClient := CreateClient;
  try
    LChanges.Add('client_name', 'client_name');
    LUpdater := TCommandUpdater.Create(FConnection, dnSQLite, LClient);
    try
      LSQL := LowerCase(LUpdater.GenerateUpdate(LClient, LChanges));
      Assert.Contains(LSQL, 'set');
      Assert.Contains(LSQL, 'client_name');
    finally
      LUpdater.Free;
    end;
  finally
    LClient.Free;
    LChanges.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateUpdate_ClientBuildsWhereClause;
var
  LChanges: TDictionary<String, String>;
  LClient: Tclient;
  LUpdater: TCommandUpdater;
  LSQL: String;
begin
  LChanges := TDictionary<String, String>.Create;
  LClient := CreateClient;
  try
    LChanges.Add('client_name', 'client_name');
    LUpdater := TCommandUpdater.Create(FConnection, dnSQLite, LClient);
    try
      LSQL := LowerCase(LUpdater.GenerateUpdate(LClient, LChanges));
      Assert.Contains(LSQL, 'where');
      Assert.Contains(LSQL, 'client_id');
    finally
      LUpdater.Free;
    end;
  finally
    LClient.Free;
    LChanges.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateUpdate_ClientPreservesBindPlaceholderWithoutQuotes;
var
  LChanges: TDictionary<String, String>;
  LClient: Tclient;
  LUpdater: TCommandUpdater;
  LSQL: String;
begin
  LChanges := TDictionary<String, String>.Create;
  LClient := CreateClient;
  try
    LChanges.Add('client_name', 'client_name');
    LUpdater := TCommandUpdater.Create(FConnection, dnSQLite, LClient);
    try
      LSQL := LowerCase(LUpdater.GenerateUpdate(LClient, LChanges));
      Assert.Contains(LSQL, ':client_name');
      Assert.DoesNotContain(LSQL, ''':client_name''');
    finally
      LUpdater.Free;
    end;
  finally
    LClient.Free;
    LChanges.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateUpdate_EmptyChangesReturnsEmptySql;
var
  LChanges: TDictionary<String, String>;
  LClient: Tclient;
  LUpdater: TCommandUpdater;
begin
  LChanges := TDictionary<String, String>.Create;
  LClient := CreateClient;
  try
    LUpdater := TCommandUpdater.Create(FConnection, dnSQLite, LClient);
    try
      Assert.AreEqual('', LUpdater.GenerateUpdate(LClient, LChanges));
    finally
      LUpdater.Free;
    end;
  finally
    LClient.Free;
    LChanges.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateUpdate_ClientBuildsExpectedParamCount;
var
  LChanges: TDictionary<String, String>;
  LClient: Tclient;
  LUpdater: TCommandUpdater;
begin
  LChanges := TDictionary<String, String>.Create;
  LClient := CreateClient;
  try
    LChanges.Add('client_name', 'client_name');
    LUpdater := TCommandUpdater.Create(FConnection, dnSQLite, LClient);
    try
      LUpdater.GenerateUpdate(LClient, LChanges);
      Assert.AreEqual(2, LUpdater.Params.Count);
    finally
      LUpdater.Free;
    end;
  finally
    LClient.Free;
    LChanges.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateDelete_ClientTargetsMappedTable;
var
  LClient: Tclient;
  LDeleter: TCommandDeleter;
  LSQL: String;
begin
  LClient := CreateClient;
  try
    LDeleter := TCommandDeleter.Create(FConnection, dnSQLite, LClient);
    try
      LSQL := LowerCase(LDeleter.GenerateDelete(LClient));
      Assert.Contains(LSQL, 'delete from client');
    finally
      LDeleter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateDelete_ClientBuildsPrimaryKeyParam;
var
  LClient: Tclient;
  LDeleter: TCommandDeleter;
begin
  LClient := CreateClient;
  try
    LDeleter := TCommandDeleter.Create(FConnection, dnSQLite, LClient);
    try
      LDeleter.GenerateDelete(LClient);
      Assert.AreEqual(1, LDeleter.Params.Count);
      Assert.AreEqual('client_id', LDeleter.Params[0].Name);
    finally
      LDeleter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateSelectAll_ClientBuildsSelect;
var
  LClient: Tclient;
  LSelecter: TCommandSelecter;
  LSQL: String;
begin
  LClient := CreateClient;
  try
    LSelecter := TCommandSelecter.Create(FConnection, dnSQLite, LClient);
    try
      LSQL := LowerCase(LSelecter.GenerateSelectAll(Tclient));
      Assert.Contains(LSQL, 'select');
      Assert.Contains(LSQL, 'from client');
    finally
      LSelecter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateSelectAll_ClientIncludesConfiguredOrderBy;
var
  LClient: Tclient;
  LSelecter: TCommandSelecter;
  LSQL: String;
begin
  LClient := CreateClient;
  try
    LSelecter := TCommandSelecter.Create(FConnection, dnSQLite, LClient);
    try
      LSQL := LowerCase(LSelecter.GenerateSelectAll(Tclient));
      Assert.Contains(LSQL, 'order by');
      Assert.Contains(LSQL, 'client.client_id');
    finally
      LSelecter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateSelectId_ClientBuildsPrimaryKeyPredicate;
var
  LClient: Tclient;
  LSelecter: TCommandSelecter;
  LSQL: String;
begin
  LClient := CreateClient;
  try
    LSelecter := TCommandSelecter.Create(FConnection, dnSQLite, LClient);
    try
      LSQL := LowerCase(LSelecter.GenerateSelectID(Tclient, 10));
      Assert.Contains(LSQL, 'where');
      Assert.Contains(LSQL, 'client.client_id = 10');
    finally
      LSelecter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateSelectWhere_PreservesPercentWildcard;
var
  LClient: Tclient;
  LSelecter: TCommandSelecter;
  LSQL: String;
begin
  LClient := CreateClient;
  try
    LSelecter := TCommandSelecter.Create(FConnection, dnSQLite, LClient);
    try
      LSelecter.SetPageSize(-1);
      LSQL := LSelecter.GeneratorSelectWhere(Tclient, 'client_name LIKE ''A%''', 'client_name');
      Assert.Contains(LSQL, 'A%');
      Assert.DoesNotContain(LSQL, 'A$');
    finally
      LSelecter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateSelect_FirebirdWithWhere_ProducesCorrectSQL;
var
  LClient: Tclient;
  LConnection: IDBConnection;
  LSelecter: TCommandSelecter;
  LSQL: String;
begin
  LClient := CreateClient;
  LConnection := TFakeConnection.Create(dnFirebird);
  try
    LSelecter := TCommandSelecter.Create(LConnection, dnFirebird, LClient);
    try
      LSelecter.SetPageSize(10);
      LSQL := LowerCase(LSelecter.GeneratorSelectWhere(Tclient,
        'client_name like ''A%''', 'client_name'));
      Assert.Contains(LSQL, 'select first');
      Assert.Contains(LSQL, 'skip');
      Assert.Contains(LSQL, 'where client_name like ''a%''');
    finally
      LSelecter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateSelect_SQLiteWithPagination_ProducesLimitOffset;
var
  LClient: Tclient;
  LSelecter: TCommandSelecter;
  LSQL: String;
begin
  LClient := CreateClient;
  try
    LSelecter := TCommandSelecter.Create(FConnection, dnSQLite, LClient);
    try
      LSelecter.SetPageSize(10);
      LSQL := LowerCase(LSelecter.GeneratorSelectWhere(Tclient,
        'client_name like ''A%''', 'client_name'));
      Assert.Contains(LSQL, 'where client_name like ''a%''');
      Assert.Contains(LSQL, 'order by client_name');
      Assert.Contains(LSQL, 'limit');
      Assert.Contains(LSQL, 'offset');
    finally
      LSelecter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateSelect_FirebirdWithJoin_ProducesJoinClause;
var
  LMaster: Tmaster;
  LConnection: IDBConnection;
  LSelecter: TCommandSelecter;
  LSQL: String;
begin
  LMaster := Tmaster.Create;
  LConnection := TFakeConnection.Create(dnFirebird);
  try
    LSelecter := TCommandSelecter.Create(LConnection, dnFirebird, LMaster);
    try
      LSQL := LowerCase(LSelecter.GenerateSelectAll(Tmaster));
      Assert.Contains(LSQL, 'join client');
      Assert.Contains(LSQL, 'aliastable.client_name as aliascollumn');
    finally
      LSelecter.Free;
    end;
  finally
    LMaster.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateSelect_SQLiteOrderBy_AppendsOrderByClause;
var
  LClient: Tclient;
  LSelecter: TCommandSelecter;
  LSQL: String;
begin
  LClient := CreateClient;
  try
    LSelecter := TCommandSelecter.Create(FConnection, dnSQLite, LClient);
    try
      LSelecter.SetPageSize(-1);
      LSQL := LowerCase(LSelecter.GeneratorSelectWhere(Tclient,
        'client_id = 1', 'client_name desc'));
      Assert.Contains(LSQL, 'where client_id = 1');
      Assert.Contains(LSQL, 'order by client_name desc');
    finally
      LSelecter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateInsert_MultiColumn_PreservesAllPlaceholders;
var
  LDetail: Tdetail;
  LInserter: TCommandInserter;
  LSQL: String;
begin
  LDetail := CreateDetail;
  try
    LInserter := TCommandInserter.Create(FConnection, dnSQLite, LDetail);
    try
      LSQL := LowerCase(LInserter.GenerateInsert(LDetail));
      Assert.Contains(LSQL, ':detail_id');
      Assert.Contains(LSQL, ':master_id');
      Assert.Contains(LSQL, ':lookup_id');
      Assert.Contains(LSQL, ':lookup_description');
      Assert.DoesNotContain(LSQL, ''':detail_id''');
      Assert.DoesNotContain(LSQL, ''':lookup_description''');
    finally
      LInserter.Free;
    end;
  finally
    LDetail.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateUpdate_MultiField_AllPlaceholdersWithoutQuotes;
var
  LChanges: TDictionary<String, String>;
  LDetail: Tdetail;
  LUpdater: TCommandUpdater;
  LSQL: String;
begin
  LChanges := TDictionary<String, String>.Create;
  LDetail := CreateDetail;
  try
    LChanges.Add('lookup_id', 'lookup_id');
    LChanges.Add('lookup_description', 'lookup_description');
    LUpdater := TCommandUpdater.Create(FConnection, dnSQLite, LDetail);
    try
      LSQL := LowerCase(LUpdater.GenerateUpdate(LDetail, LChanges));
      Assert.Contains(LSQL, ':lookup_id');
      Assert.Contains(LSQL, ':lookup_description');
      Assert.DoesNotContain(LSQL, ''':lookup_id''');
      Assert.DoesNotContain(LSQL, ''':lookup_description''');
    finally
      LUpdater.Free;
    end;
  finally
    LDetail.Free;
    LChanges.Free;
  end;
end;

procedure TTestDMLGenerator._AssertEachValueIsItsOwnColumnsMarker(
  const ASQL: String; const AExpectedCount: Integer);
var
  LOpenCols, LCloseCols, LOpenVals, LCloseVals: Integer;
  LColumns: TArray<String>;
  LValues: TArray<String>;
  LFor: Integer;
begin
  LOpenCols  := Pos('(', ASQL);
  LCloseCols := PosEx(')', ASQL, LOpenCols);
  LOpenVals  := PosEx('(', ASQL, LCloseCols);
  LCloseVals := PosEx(')', ASQL, LOpenVals);
  Assert.IsTrue((LOpenCols > 0) and (LCloseCols > LOpenCols) and
                (LOpenVals > LCloseCols) and (LCloseVals > LOpenVals),
    'the statement does not carry a column list and a value list: [' + ASQL + ']');

  LColumns := SplitString(Copy(ASQL, LOpenCols + 1, LCloseCols - LOpenCols - 1), ',');
  LValues  := SplitString(Copy(ASQL, LOpenVals + 1, LCloseVals - LOpenVals - 1), ',');

  Assert.AreEqual(AExpectedCount, Length(LColumns),
    'column count of [' + ASQL + ']');
  Assert.AreEqual(Length(LColumns), Length(LValues),
    'one value per column in [' + ASQL + ']');

  for LFor := 0 to High(LColumns) do
    Assert.AreEqual(':' + Trim(LColumns[LFor]), Trim(LValues[LFor]),
      Format('value %d must be the marker of the column in slot %d, in [%s]',
             [LFor + 1, LFor + 1, ASQL]));
end;

procedure TTestDMLGenerator.TestGenerateInsert_TwelveColumns_EveryMarkerLandsInItsOwnSlot;
var
  LWide: TWideSlot;
  LInserter: TCommandInserter;
  LSQL: String;
  LFor: Integer;
begin
  LWide := TWideSlot.Create;
  try
    /// Every column has to carry a value, or GeneratorInsert skips it on
    /// IsNullValue and the statement stops being twelve wide - which is the
    /// one property this clause is here to exercise.
    LWide.w01 := 1;  LWide.w02 := 2;  LWide.w03 := 3;  LWide.w04 := 4;
    LWide.w05 := 5;  LWide.w06 := 6;  LWide.w07 := 7;  LWide.w08 := 8;
    LWide.w09 := 9;  LWide.w10 := 10; LWide.w11 := 11; LWide.w12 := 12;

    LInserter := TCommandInserter.Create(FConnection, dnSQLite, LWide);
    try
      LSQL := LowerCase(LInserter.GenerateInsert(LWide));
      _AssertEachValueIsItsOwnColumnsMarker(LSQL, 12);

      /// The tenth marker onwards is where an ascending ReplaceStr sweep
      /// corrupts, and it corrupts by leaving the SURVIVING digits behind.
      for LFor := 1 to 12 do
        Assert.Contains(LSQL, Format(':w%.2d', [LFor]),
          Format('marker %d must survive the rewrite whole', [LFor]));
      Assert.DoesNotContain(LSQL, ':p',
        'no positional placeholder may survive into the emitted statement');
    finally
      LInserter.Free;
    end;
  finally
    LWide.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateUpdate_TwelveFields_EveryMarkerLandsInItsOwnSlot;
var
  LChanges: TDictionary<String, String>;
  LWide: TWideSlot;
  LUpdater: TCommandUpdater;
  LSQL: String;
  LFor: Integer;
  LColumn: String;
begin
  LChanges := TDictionary<String, String>.Create;
  LWide := TWideSlot.Create;
  try
    LWide.w01 := 1;  LWide.w02 := 2;  LWide.w03 := 3;  LWide.w04 := 4;
    LWide.w05 := 5;  LWide.w06 := 6;  LWide.w07 := 7;  LWide.w08 := 8;
    LWide.w09 := 9;  LWide.w10 := 10; LWide.w11 := 11; LWide.w12 := 12;
    /// w01 is the key and stays out of SET; the other eleven are the change
    /// set, which is past :p9 and therefore past where the prefix bites.
    for LFor := 2 to 12 do
    begin
      LColumn := Format('w%.2d', [LFor]);
      LChanges.Add(LColumn, LColumn);
    end;

    LUpdater := TCommandUpdater.Create(FConnection, dnSQLite, LWide);
    try
      LSQL := LowerCase(LUpdater.GenerateUpdate(LWide, LChanges));
      /// PAIRWISE, not Contains() per name: a TDictionary does not promise an
      /// enumeration order, so the SET order is not the subject here - that
      /// each column sits next to ITS OWN marker is.
      for LFor := 2 to 12 do
      begin
        LColumn := Format('w%.2d', [LFor]);
        Assert.Contains(LSQL, LColumn + ' = :' + LColumn,
          'the SET slot of ' + LColumn + ' must carry its own marker');
      end;
      Assert.DoesNotContain(LSQL, ':p',
        'no positional placeholder may survive into the emitted statement');
    finally
      LUpdater.Free;
    end;
  finally
    LWide.Free;
    LChanges.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateUpdate_AKeyNamedLikeAPlaceholder_KeepsItsOwnMarker;
var
  LChanges: TDictionary<String, String>;
  LRow: TPlaceholderNamedKey;
  LUpdater: TCommandUpdater;
  LSQL: String;
begin
  LChanges := TDictionary<String, String>.Create;
  LRow := TPlaceholderNamedKey.Create;
  try
    LRow.p1 := 7;
    LRow.nm := 'NEWNAME';
    LChanges.Add('nm', 'nm');
    LUpdater := TCommandUpdater.Create(FConnection, dnSQLite, LRow);
    try
      LSQL := LowerCase(LUpdater.GenerateUpdate(LRow, LChanges));
      /// The SET slot took bind p1, so the statement carries TWO ':p1' before
      /// the rewrite. The key predicate is Janus's own verbatim text and must
      /// come out untouched; rewriting it points the lookup at the new NAME.
      Assert.Contains(LSQL, 'where p1 = :p1',
        'the key predicate is verbatim text and must keep its own marker');
      Assert.DoesNotContain(LSQL, 'where p1 = :nm',
        'the key would be compared against the new value of another column');
      Assert.Contains(LSQL, 'nm = :nm',
        'the SET slot still carries the marker of its own column');
    finally
      LUpdater.Free;
    end;
  finally
    LRow.Free;
    LChanges.Free;
  end;
end;

/// <summary> THE PROPERTY OF THEIR SERIALIZER THAT GeneratorUpdate LEANS ON.
///  Issue #337. The generator renders the UPDATE once BEFORE the key predicate
///  exists, to get the value region with no SQL parsing and no guess about
///  where SET ends, and then carries the tail of the finished statement over
///  untouched. That splice is only sound while the first render is a PREFIX of
///  the second - which is FluentSQL's behaviour, not ours, so it is pinned here
///  instead of assumed in a comment. The generator also re-checks it on every
///  call and refuses by name if it breaks; this clause is what makes the break
///  show up as one red test rather than as every UPDATE in the suite. </summary>
procedure TTestDMLGenerator.FluentSQLRendersTheValueRegionAsAPrefixOfTheWholeUpdate;
var
  LCQ: IFluentSQL;
  LBefore, LAfter: String;
begin
  LCQ := TCQ(dbnSQLite).Update('r337pk');
  LCQ.SetValue('nm', [':nm']);
  LBefore := LCQ.AsString;
  LCQ.Where('p1 = :p1');
  LAfter := LCQ.AsString;
  Assert.AreEqual(LBefore, Copy(LAfter, 1, Length(LBefore)),
    Format('the value region must be a prefix of the whole statement: ' +
           'before=[%s] whole=[%s]', [LBefore, LAfter]));
end;

{ TDMLGeneratorDialectProbe }

procedure TDMLGeneratorDialectProbe.UseDialect(const ADriver: TDriverName);
begin
  ConfigureFluentSQLDriver(ADriver);
end;

function TDMLGeneratorDialectProbe.SpliceWith(const AValueRegion,
  AWholeStatement: String): String;
begin
  /// No binds and no markers on purpose: the prefix refusal is decided before
  /// either is looked at, and the positive control must come back byte for
  /// byte so that a rewrite creeping into this path would show up as a diff.
  Result := _SpliceRestoredValueRegion(AValueRegion, AWholeStatement, nil, nil);
end;

procedure TTestDMLGenerator.TestGenerateInsert_ADialectThatEatsThePlaceholders_RefusesByName;
var
  LProbe: TDMLGeneratorDialectProbe;
  LRow: TPlaceholderNamedKey;
  LRaised: String;
begin
  LRow := TPlaceholderNamedKey.Create;
  LProbe := TDMLGeneratorDialectProbe.Create;
  try
    LRow.p1 := 7;
    LRow.nm := 'NEWNAME';
    /// MySQL turns every ':pN' into '?' on the way out, so the statement comes
    /// back with the value slots emptied of anything a consumer could bind to.
    /// Counting the BINDS would not notice - they were allocated, and they
    /// carry what this generator put there. Counting the SUBSTITUTIONS does.
    LProbe.UseDialect(dnMySQL);
    LRaised := '';
    try
      LProbe.GeneratorInsert(LRow);
    except
      on E: Exception do
        LRaised := E.Message;
    end;
    Assert.IsTrue(LRaised <> '',
      'a statement whose value slots carry no bindable marker must not be returned');
    Assert.Contains(LRaised, 'only 0 marker(s) could be put back',
      'the refusal must say how many of the expected markers survived');
    Assert.Contains(LRaised, 'Issue #337', 'the refusal must name its issue');
  finally
    LProbe.Free;
    LRow.Free;
  end;
end;

procedure TTestDMLGenerator.TestSplice_AValueRegionThatIsNotAPrefix_RefusesByName;
var
  LProbe: TDMLGeneratorDialectProbe;
  LRaised: String;
begin
  LProbe := TDMLGeneratorDialectProbe.Create;
  try
    LRaised := '';
    try
      LProbe.SpliceWith('UPDATE r337pk SET nm = :p1',
                        'DELETE FROM r337pk WHERE p1 = :p1');
    except
      on E: Exception do
        LRaised := E.Message;
    end;
    Assert.IsTrue(LRaised <> '',
      'splicing two strings that do not line up must not be done silently');
    Assert.Contains(LRaised, 'cannot be told',
      'the refusal must say that the two regions cannot be told apart');
    Assert.Contains(LRaised, 'Issue #337', 'the refusal must name its issue');
  finally
    LProbe.Free;
  end;
end;

procedure TTestDMLGenerator.TestSplice_AValueRegionThatIsAPrefix_CarriesTheTailOverUntouched;
const
  cREGION = 'UPDATE r337pk SET nm = :nm';
  cWHOLE  = 'UPDATE r337pk SET nm = :nm WHERE p1 = :p1';
var
  LProbe: TDMLGeneratorDialectProbe;
begin
  /// The control for the clause above: with a real prefix the splice must NOT
  /// refuse, and the verbatim tail - ':p1' being exactly the token a rewrite
  /// would be tempted by - has to come back untouched.
  LProbe := TDMLGeneratorDialectProbe.Create;
  try
    Assert.AreEqual(cWHOLE, LProbe.SpliceWith(cREGION, cWHOLE),
      'a prefix must splice back to the statement it came from, byte for byte');
  finally
    LProbe.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateNextPacket_UsesSqlitePagination;
var
  LClient: Tclient;
  LSelecter: TCommandSelecter;
  LSQL: String;
begin
  LClient := CreateClient;
  try
    LSelecter := TCommandSelecter.Create(FConnection, dnSQLite, LClient);
    try
      LSQL := LowerCase(LSelecter.GenerateNextPacket(Tclient, 10, 20));
      Assert.Contains(LSQL, 'limit 10');
      Assert.Contains(LSQL, 'offset 20');
    finally
      LSelecter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateSelectOneToOne_UsesAssociationColumns;
var
  LAssociation: TAssociationMapping;
  LMaster: Tmaster;
  LSelecter: TCommandSelecter;
  LSQL: String;
begin
  LMaster := Tmaster.Create;
  try
    LMaster.client_id := 5;
    LAssociation := FindAssociation(Tmaster, 'Tclient');
    LSelecter := TCommandSelecter.Create(FConnection, dnSQLite, LMaster);
    try
      LSQL := LowerCase(LSelecter.GenerateSelectOneToOne(LMaster, Tclient, LAssociation));
      Assert.Contains(LSQL, 'where');
      Assert.Contains(LSQL, 'client.client_id = 5');
    finally
      LSelecter.Free;
    end;
  finally
    LMaster.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateSelectOneToMany_UsesAssociationColumns;
var
  LAssociation: TAssociationMapping;
  LMaster: Tmaster;
  LSelecter: TCommandSelecter;
  LSQL: String;
begin
  LMaster := Tmaster.Create;
  try
    LMaster.master_id := 9;
    LAssociation := FindAssociation(Tmaster, 'Tdetail');
    LSelecter := TCommandSelecter.Create(FConnection, dnSQLite, LMaster);
    try
      LSQL := LowerCase(LSelecter.GenerateSelectOneToMany(LMaster, Tdetail, LAssociation));
      Assert.Contains(LSQL, 'where');
      Assert.Contains(LSQL, 'detail.master_id = 9');
    finally
      LSelecter.Free;
    end;
  finally
    LMaster.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateSelectAll_MasterIncludesJoinAndScope;
var
  LMaster: Tmaster;
  LSelecter: TCommandSelecter;
  LSQL: String;
begin
  LMaster := Tmaster.Create;
  try
    LSelecter := TCommandSelecter.Create(FConnection, dnSQLite, LMaster);
    try
      LSQL := LowerCase(LSelecter.GenerateSelectAll(Tmaster));
      Assert.Contains(LSQL, 'join client');
      Assert.Contains(LSQL, 'client_name');
      Assert.Contains(LSQL, 'master.master_id > 6');
      Assert.Contains(LSQL, 'master.description');
    finally
      LSelecter.Free;
    end;
  finally
    LMaster.Free;
  end;
end;

procedure TTestDMLGenerator.TestObjectSetUpdate_NoModifiedFields_DoesNotRaiseItemNotFound;
var
  LContainer: IContainerObjectSet<TKeyOnly>;
  LEntity: TKeyOnly;
begin
  // Canonical KEY-ONLY entity (all columns are the NoUpdate composite PK, declared
  // with a single ';'-separated [PrimaryKey]). Snapshot it (Modify) then Update
  // with zero changed columns: ModifyFieldsCompare adds no field, so the per-row
  // key (ClassName-<pk>) is never inserted into ModifiedFields. Before the fix,
  // TSessionAbstract.Update did ModifiedFields.Items[AKey] -> EListError
  // 'Item not found'. The framework must treat a no-op Update as a graceful no-op,
  // mirroring the DataSet path guard. Repro of the live E13_F01/EPV_F02/R01_F01
  // failure — independent of any [Association].
  LContainer := TContainerObjectSet<TKeyOnly>.Create(FConnection);
  LEntity := TKeyOnly.Create;
  try
    LEntity.k1 := 7;
    LEntity.k2 := 42;
    LContainer.Modify(LEntity);
    Assert.WillNotRaise(
      procedure
      begin
        LContainer.Update(LEntity);
      end,
      Exception,
      'No-op key-only ObjectSet Update must not raise "Item not found"');
  finally
    LEntity.Free;
  end;
end;

{ TDMLGeneratorWithoutGuid }

constructor TDMLGeneratorWithoutGuid.Create;
begin
  inherited;
  ConfigureFluentSQLDriver(dnSQLite);
  FDateFormat := 'yyyy-MM-dd';
  FTimeFormat := 'HH:MM:SS';
end;

function TDMLGeneratorWithoutGuid.GeneratorSelectAll(AClass: TClass;
  APageSize: Integer; AID: TValue): String;
begin
  Result := '';
end;

function TDMLGeneratorWithoutGuid.GeneratorSelectWhere(AClass: TClass;
  AWhere: String; AOrderBy: String; APageSize: Integer): String;
begin
  Result := '';
end;

function TDMLGeneratorWithoutGuid.GeneratorAutoIncCurrentValue(AObject: TObject;
  AAutoInc: TDMLCommandAutoInc): Int64;
begin
  Result := 0;
end;

function TDMLGeneratorWithoutGuid.GeneratorAutoIncNextValue(AObject: TObject;
  AAutoInc: TDMLCommandAutoInc): Int64;
begin
  Result := 0;
end;

{ TGuidOverStringMaster }

constructor TGuidOverStringMaster.Create;
begin
  Fchilds := TObjectList<TGuidOverStringChild>.Create;
end;

destructor TGuidOverStringMaster.Destroy;
begin
  Fchilds.Free;
  inherited;
end;

{ Issue #284 }

function TTestDMLGenerator.CreateCompMaster: TCompMaster;
begin
  Result := TCompMaster.Create;
  Result.cmkey := 1;
  Result.cmk1 := 7;
  Result.cmk2 := 'BR';
  Result.cmk3 := StringToGUID(cGUIDKEY);
  Result.cmk4 := EncodeDate(2026, 8, 10);
  Result.cmk5 := 1234.56;
  Result.cmk6 := EncodeDate(2026, 8, 10) + EncodeTime(14, 7, 53, 0);
  Result.cmk7 := EncodeTime(14, 7, 53, 0);
end;

function TTestDMLGenerator.GuidSelect(const ADriver: TDriverName;
  const AMany: Boolean): String;
var
  LAssociation: TAssociationMapping;
  LConnection: IDBConnection;
  LMaster: TCompMaster;
  LSaved: TFormatSettings;
  LSelecter: TCommandSelecter;
begin
  LMaster := CreateCompMaster;
  LConnection := TFakeConnection.Create(ADriver);
  // TWO GLOBALS ARE PINNED, AND FOR OPPOSITE REASONS.
  //   DecimalSeparator ',' - the Currency term goes through the global
  //     FormatSettings, and on a machine that already dots the number the
  //     ReplaceStr on the `ftCurrency, ftBCD, ftFMTBcd` arm of
  //     TDMLGeneratorAbstract._GetPropertyValue does nothing, so deleting it
  //     would survive. BY ARM, and the arm has to be named rather than the
  //     line: the neighbouring `ftFloat` arm carries a ReplaceStr that is
  //     character-for-character identical, so ":634" identified the right code
  //     only by accident even before issue #326 moved it.
  //   TimeSeparator ':'    - ':' inside a FormatDateTime pattern is the
  //     PLACEHOLDER for this setting, not a literal colon. Pinning it is what
  //     makes the expected string the same on every machine; it is NOT an
  //     endorsement of FTimeFormat, see the note in the SQLite test.
  // Restored in the finally, because FormatSettings is global and every other
  // test in this process reads it.
  LSaved := FormatSettings;
  try
    FormatSettings.DecimalSeparator := ',';
    FormatSettings.TimeSeparator := ':';
    LAssociation := FindAssociation(TCompMaster, 'TCompChild');
    LSelecter := TCommandSelecter.Create(LConnection, ADriver, LMaster);
    try
      if AMany then
        Result := LSelecter.GenerateSelectOneToMany(LMaster, TCompChild, LAssociation)
      else
        Result := LSelecter.GenerateSelectOneToOne(LMaster, TCompChild, LAssociation);
    finally
      LSelecter.Free;
    end;
  finally
    FormatSettings := LSaved;
    LMaster.Free;
  end;
end;

/// <summary> THE WHOLE WHERE, CHARACTER BY CHARACTER, AND NO LowerCase.
///
///  Assert.Contains is what the neighbours in this fixture use and it is not
///  enough here: it survives a spurious suffix, a swapped term order and an
///  extra predicate. And LowerCase - which four neighbours apply before
///  asserting - would erase HALF of what is being decided, because the case of
///  the hex digits IS the question: TGUID.ToString emits UPPERCASE, the INSERT
///  writes that text, and SQLite compares with the BINARY collation, i.e.
///  memcmp, i.e. case-SENSITIVE (https://www.sqlite.org/datatype3.html). A
///  lowercased assertion would go green against a literal that matches nothing.
///
///  HENCE THE THIRD ARGUMENT, False, AND IT IS NOT DECORATION. Assert.AreEqual
///  for strings takes an ignoreCase parameter and DEFAULTS IT TO True.
///  Measured, not read: with the default in place, the mutation that
///  lowercases the emitted literal SURVIVED all four assertions - the fixture
///  claimed a character-by-character comparison in its own comment and was not
///  making one. With False it dies.
///
///  SEVEN TERMS, BECAUSE ONE WOULD PROVE ALMOST NOTHING. With a single column
///  the ' AND ' separator is never written, so ' OR ' would look identical;
///  and with both ends spelled the same, ColumnsNameRef could be read as
///  ColumnsName and nothing would notice. TCompMaster writes cmk1..cmk7 on one
///  side and cck1..cck7 on the other, so both mutations die here.
///
///  Two more things this ordered string holds down, both of them measured and
///  neither of them the subject of #284: the cck6 term drops the time (see the
///  note on cWHEREGUIDKEY), and the cck5 term proves the decimal-separator
///  normalisation, which on an already-dotted machine would be a no-op - hence
///  the pinned FormatSettings in GuidSelect. </summary>
procedure TTestDMLGenerator.TestGuid_OneToOne_SQLite_WritesTheGuidLiteralAndNotTheZeroRowsGuard;
var
  LSQL: String;
begin
  LSQL := GuidSelect(dnSQLite, False);

  Assert.AreEqual(cSELECTCOMPCHILD + cWHERESQLITE, LSQL, False,
    'The ftGuid term is the whole issue: before #284 ftGuid had no branch in ' +
    '_GetPropertyValue, fell into that function''s final else, ' +
    'became '''' and the null-FK guard of GenerateSelectOneToOne wrote ' +
    '''1 = 0'' - a master WITH children returning none, in silence.');

  Assert.IsFalse(ContainsText(LSQL, '1 = 0'),
    'Explicit negative anchor. A test that only counted rows would go green ' +
    'against ''1 = 0'' whenever the scenario has zero children for some other ' +
    'reason; the equality above already pins the WHERE, but this names the ' +
    'defect - the null-FK guard inside ' +
    'TDMLGeneratorAbstract.GenerateSelectOneToOne - so a future reader knows ' +
    'what this fixture is holding down.');
end;

/// <summary> THE TWIN METHOD, WHICH THE ISSUE DOES NOT EVEN MENTION.
///  TDMLGeneratorAbstract.GenerateSelectOneToOneMany is a DIFFERENT
///  method with its OWN call to _GetPropertyValue and its OWN copy of the
///  null-FK guard. NAMED BY METHOD, because the three line anchors this
///  paragraph used to carry (:292-354, :304, :328-329) all rotted at once when
///  issue #326 inserted lines above them.
///  Covering only GenerateSelectOneToOne would leave half of the
///  defect with no test, and deleting the ftGuid branch would still be caught
///  - by the other test, not by this one. Hence a second full assertion rather
///  than a shared one. </summary>
procedure TTestDMLGenerator.TestGuid_OneToOneMany_SQLite_WritesTheGuidLiteralAndNotTheZeroRowsGuard;
var
  LSQL: String;
begin
  LSQL := GuidSelect(dnSQLite, True);

  Assert.AreEqual(cSELECTCOMPCHILD + cWHERESQLITE, LSQL, False,
    'GenerateSelectOneToOneMany carries its own copy of the null-FK guard ' +
    'and its own call to _GetPropertyValue. The issue names only the ' +
    'OneToOne sibling; the defect was in both.');

  Assert.IsFalse(ContainsText(LSQL, '1 = 0'),
    'Same negative anchor as the OneToOne twin, for the same reason.');
end;

/// <summary> THE SECOND DIALECT, AND WHAT IT REALLY PROVES.
///
///  Honest first: the PostgreSQL literal and the SQLite literal are the SAME
///  STRING, and that is a MEASUREMENT, not a shortcut. The DDL this house
///  INTENDS for ftGuid is CHAR(n) on PostgreSQL and text on SQLite
///  (MetaDbDiff.Metadata.Extract.pas:429-445 never creates a native `uuid`),
///  so both compare text against text and both need exactly the 38-character
///  braced uppercase form the INSERT wrote. Inventing a difference to make
///  this test look stronger would be inventing a defect.
///
///  What IS proved here is the MECHANISM, and it is proved by mutation, not by
///  the string: change TDMLGeneratorSQLite.GuidLiteral alone and only the
///  SQLite tests die; change TDMLGeneratorPostgreSQL.GuidLiteral alone and
///  only these die. Two dialects, two implementations, each answering for
///  itself - which is the restriction the owner set, and which a single
///  branch in the base class would NOT satisfy. The third leg of the same
///  proof is TestGuid_ADialectThatDoesNotImplementGuidLiteral_FailsLoudly. </summary>
procedure TTestDMLGenerator.TestGuid_OneToOne_PostgreSQL_AnswersWithItsOwnLiteral;
var
  LSQL: String;
begin
  LSQL := GuidSelect(dnPostgreSQL, False);

  Assert.AreEqual(cSELECTCOMPCHILD + cWHEREPOSTGRES, LSQL, False,
    'TDMLGeneratorPostgreSQL.GuidLiteral is the one consulted here. Mutate ' +
    'it and this test dies while the SQLite twin stays green - that, and not ' +
    'a difference in the text, is what makes the dispatch per-dialect.');

  Assert.IsFalse(ContainsText(LSQL, '1 = 0'),
    'PostgreSQL reached the same else as every other dialect before #284.');
end;

procedure TTestDMLGenerator.TestGuid_OneToOneMany_PostgreSQL_AnswersWithItsOwnLiteral;
var
  LSQL: String;
begin
  LSQL := GuidSelect(dnPostgreSQL, True);

  Assert.AreEqual(cSELECTCOMPCHILD + cWHEREPOSTGRES, LSQL, False,
    'The second method on the second dialect. Four cells, because the two ' +
    'axes are independent: a fix applied to one method or wired into one ' +
    'generator would leave three of them red.');

  Assert.IsFalse(ContainsText(LSQL, '1 = 0'),
    'Same negative anchor.');
end;

/// <summary> THE GUARD IS STILL THERE, AND THIS IS WHY IT MATTERS.
///  '1 = 0' is not the defect - it is the correct answer for an association
///  whose foreign key is not set. The defect was reaching it with a key that
///  WAS set. An unset TGUID key is TGUID.Empty, and the ftGuid branch maps it
///  back to '' on purpose so the existing null-FK guard inside
///  TDMLGeneratorAbstract.GenerateSelectOneToOne keeps its meaning;
///  emitting the all-zeros literal would also match zero rows, but by accident
///  instead of by contract. Without this test, deleting the TGUID.Empty check
///  would survive every other assertion in this file. </summary>
procedure TTestDMLGenerator.TestGuid_AnUnsetGuidKeyStillBecomesTheZeroRowsGuard;
var
  LAssociation: TAssociationMapping;
  LMaster: TCompMaster;
  LSelecter: TCommandSelecter;
  LSQL: String;
begin
  LMaster := CreateCompMaster;
  try
    LMaster.cmk3 := TGUID.Empty;
    LAssociation := FindAssociation(TCompMaster, 'TCompChild');
    LSelecter := TCommandSelecter.Create(FConnection, dnSQLite, LMaster);
    try
      LSQL := LSelecter.GenerateSelectOneToOne(LMaster, TCompChild, LAssociation);
      Assert.IsTrue(ContainsStr(LSQL, 'AND 1 = 0 AND compchild.cck4'),
        'An unset GUID foreign key must fall into the null guard exactly ' +
        'where it sits in the term list - between cck2 and cck4 - and NOT ' +
        'become a literal of the all-zeros GUID.');
      Assert.IsFalse(ContainsText(LSQL, '00000000-0000-0000-0000-000000000000'),
        'The all-zeros literal would match zero rows too, but by accident: ' +
        'it would also match a row that really stored a zero GUID, and it ' +
        'would read as a value where the code means "no parent".');
    finally
      LSelecter.Free;
    end;
  finally
    LMaster.Free;
  end;
end;

/// <summary> THE NOISE, MEASURED.
///  The whole argument for an abstract method over a FGuidFormat field is that
///  a dialect which does not answer must fail EARLY and LOUD instead of
///  emitting '1 = 0' again. That argument is worth exactly as much as this
///  test: TDMLGeneratorWithoutGuid implements every other abstract member and
///  omits GuidLiteral, and the first ftGuid column it meets raises
///  EAbstractError. The compiler already said the same thing at build time -
///  W1020 at the construction below - but a warning is not a gate. </summary>
procedure TTestDMLGenerator.TestGuid_ADialectThatDoesNotImplementGuidLiteral_FailsLoudly;
var
  LAssociation: TAssociationMapping;
  LGenerator: IDMLGeneratorCommand;
  LMaster: TCompMaster;
begin
  LMaster := CreateCompMaster;
  try
    LAssociation := FindAssociation(TCompMaster, 'TCompChild');
    LGenerator := TDMLGeneratorWithoutGuid.Create;
    LGenerator.SetConnection(FConnection);
    Assert.WillRaise(
      procedure
      begin
        LGenerator.GenerateSelectOneToOne(LMaster, TCompChild, LAssociation);
      end,
      EAbstractError,
      'A dialect that does not implement GuidLiteral must NOT compile-and-run ' +
      'quietly. With the FDateFormat mould - a format field set in the ' +
      'constructor - this same class would have produced an empty literal, ' +
      'tripped the guard and emitted ''1 = 0'': the cure would have carried ' +
      'the disease.');
  finally
    LMaster.Free;
  end;
end;

/// <summary> THE RULING OF #284, AS A TEST INSTEAD OF A PARAGRAPH.
///  ftGuid means a TGUID property. A String property under a ftGuid column is
///  the shape Test.Janus.Model.RestLazyKeys carried until #284 - it passed
///  because the REST filter reads the FIELD and never the property, and it
///  would have raised on the first local INSERT, from inside the RTTI, without
///  naming the column. The SELECT side now says which property is wrong and
///  what to do instead. </summary>
procedure TTestDMLGenerator.TestGuid_AGuidColumnOverAStringProperty_RaisesANamedError;
var
  LAssociation: TAssociationMapping;
  LMaster: TGuidOverStringMaster;
  LMessage: String;
  LRaised: Boolean;
  LSelecter: TCommandSelecter;
begin
  LRaised := False;
  LMessage := '';
  LMaster := TGuidOverStringMaster.Create;
  try
    LMaster.gmkey := 1;
    LMaster.gmparent := cGUIDKEY;
    LAssociation := FindAssociation(TGuidOverStringMaster, 'TGuidOverStringChild');
    LSelecter := TCommandSelecter.Create(FConnection, dnSQLite, LMaster);
    try
      try
        LSelecter.GenerateSelectOneToOne(LMaster, TGuidOverStringChild,
          LAssociation);
      except
        on E: Exception do
        begin
          LRaised := True;
          LMessage := E.Message;
        end;
      end;
    finally
      LSelecter.Free;
    end;
  finally
    LMaster.Free;
  end;

  Assert.IsTrue(LRaised,
    'ftGuid over a String property must not go through quietly. Silence here ' +
    'is how the shape survived in Test.Janus.Model.RestLazyKeys all the way ' +
    'through PR #286.');
  Assert.IsTrue(ContainsText(LMessage, 'gmparent'),
    'The error must NAME the offending property. A bare EInvalidCast from ' +
    'AsType<TGUID> says only that some cast failed, in a model with seven ' +
    'columns: message was "' + LMessage + '"');
  Assert.IsTrue(ContainsText(LMessage, 'TGUID'),
    'And it must say what the contract IS, so the reader does not have to ' +
    'find Inserter:213-217 to learn it: message was "' + LMessage + '"');
end;

{ TNullableGuidMaster }

constructor TNullableGuidMaster.Create;
begin
  Fchilds := TObjectList<TNullableGuidChild>.Create;
end;

destructor TNullableGuidMaster.Destroy;
begin
  Fchilds.Free;
  inherited;
end;

function TTestDMLGenerator.NullableGuidSelect(const ASet: Boolean): String;
var
  LAssociation: TAssociationMapping;
  LMaster: TNullableGuidMaster;
  LSelecter: TCommandSelecter;
begin
  LMaster := TNullableGuidMaster.Create;
  try
    LMaster.ngmkey := 1;
    if ASet then
      LMaster.ngmparent := StringToGUID(cGUIDKEY);
    LAssociation := FindAssociation(TNullableGuidMaster, 'TNullableGuidChild');
    LSelecter := TCommandSelecter.Create(FConnection, dnSQLite, LMaster);
    try
      Result := LSelecter.GenerateSelectOneToOne(LMaster, TNullableGuidChild,
                  LAssociation);
    finally
      LSelecter.Free;
    end;
  finally
    LMaster.Free;
  end;
end;

/// <summary> AN OPTIONAL GUID FK THAT WAS NEVER SET IS NOT A TYPE ERROR.
///  This is the test the Variant-Null arm of _GetGuidValue never had. A
///  Nullable<TGUID> with HasValue False arrives as TValue.From<Variant>(Null),
///  and TryAsType<TGUID> REFUSES that - so without the arm the generator
///  announces that the property is of the wrong type, on a model whose type is
///  exactly right, for a foreign key that is simply empty. Measured, not
///  assumed: delete the arm and this test dies with the named error in the
///  message; the other nine GUID tests stay green, because a plain TGUID
///  property can only ever be all-zeros and that is a different arm. </summary>
procedure TTestDMLGenerator.TestGuid_ANullableGuidWithNoValue_BecomesTheZeroRowsGuard;
begin
  Assert.AreEqual(
    'SELECT nguidchild.ngckey, nguidchild.ngcparent FROM nguidchild' +
    ' WHERE 1 = 0',
    NullableGuidSelect(False), False,
    'An unset Nullable<TGUID> foreign key must select zero children, which is ' +
    'what ''1 = 0'' means here - not raise, and not compare against the ' +
    'all-zeros GUID. Whole string and ignoreCase False, because "it did not ' +
    'raise" would also be satisfied by a WHERE that is quietly wrong.');
end;

/// <summary> AND THE SAME PROPERTY, WHEN IT DOES HAVE A VALUE, STILL REACHES
///  THE DIALECT. The null arm above would also be satisfied by a generator
///  that answered '1 = 0' for EVERY Nullable<TGUID>; this is the assertion
///  that stops that reading. It also pins the unwrap: GetNullableValue returns
///  the inner TGUID, not the Nullable<TGUID> record, so TryAsType succeeds and
///  the literal comes from TDMLGeneratorSQLite.GuidLiteral like any other
///  column. </summary>
procedure TTestDMLGenerator.TestGuid_ANullableGuidWithAValue_ReachesTheDialectLiteral;
begin
  Assert.AreEqual(
    'SELECT nguidchild.ngckey, nguidchild.ngcparent FROM nguidchild' +
    ' WHERE nguidchild.ngcparent = ''' + cGUIDKEY + '''',
    NullableGuidSelect(True), False,
    'A Nullable<TGUID> that HAS a value is an ordinary GUID key and must ' +
    'produce the ordinary canonical literal.');
end;

function TTestDMLGenerator.OctetSelect(const AOctet: Boolean): String;
var
  LAssociation: TAssociationMapping;
  LConnection: IDBConnection;
  LMaster: TNullableGuidMaster;
  LSelecter: TCommandSelecter;
begin
  LConnection := TFakeConnection.Create(dnSQLite,
                   TOptions.Create.StoreGUIDAsOctet(AOctet));
  LMaster := TNullableGuidMaster.Create;
  try
    LMaster.ngmkey := 1;
    LMaster.ngmparent := StringToGUID(cGUIDKEY);
    LAssociation := FindAssociation(TNullableGuidMaster, 'TNullableGuidChild');
    LSelecter := TCommandSelecter.Create(LConnection, dnSQLite, LMaster);
    try
      Result := LSelecter.GenerateSelectOneToOne(LMaster, TNullableGuidChild,
                  LAssociation);
    finally
      LSelecter.Free;
    end;
  finally
    LMaster.Free;
  end;
end;

/// <summary> THE ONE AXIS THAT GENUINELY DIVERGES, AND IT IS LIVE TODAY.
///  IOptions.StoreGUIDAsOctet is a public setter with a default of False
///  (DataEngine.DriverConnection.pas:123, :1904). Turn it on and this
///  ecosystem's DDL stops storing text: MetaDbDiff.Metadata.Extract.pas
///  :509-526 emits CHAR(16) CHARACTER SET OCTETS on Firebird and BYTE(16) on
///  PostgreSQL. The 38-character text literal this fix emits would then match
///  ZERO ROWS IN SILENCE - issue #284 all over again, through another door,
///  and inside the very change that claims to close it.
///  Octet support is NOT implemented here: the correct form is per dialect and
///  needs measuring against a live database, and the octet DDL itself is in
///  dispute (PostgreSQL has no BYTE type; its binary type is bytea). Choosing
///  a form without measuring would be inventing. So the silence becomes a
///  named error, which costs nothing to anyone on the default. </summary>
procedure TTestDMLGenerator.TestGuid_StoreGUIDAsOctetOn_RaisesInsteadOfMatchingNothing;
var
  LMessage: String;
  LRaised: Boolean;
begin
  LRaised := False;
  LMessage := '';
  try
    OctetSelect(True);
  except
    on E: Exception do
    begin
      LRaised := True;
      LMessage := E.Message;
    end;
  end;

  Assert.IsTrue(LRaised,
    'With StoreGUIDAsOctet on, emitting the text literal would select zero ' +
    'children against a 16-byte column and say nothing - the exact defect ' +
    'this issue exists to remove.');
  Assert.IsTrue(ContainsText(LMessage, 'StoreGUIDAsOctet'),
    'The error must NAME the option, so the reader knows which switch put ' +
    'them here: message was "' + LMessage + '"');
  Assert.IsTrue(ContainsText(LMessage, 'ngmparent'),
    'And name the column, like the sibling wrong-type error does: message ' +
    'was "' + LMessage + '"');
end;

/// <summary> THE CONTROL, AND IT IS NOT CEREMONY. Without it the guard could
///  be widened to "raise whenever Options is assigned" - or to raise always -
///  and every other GUID test would stay green, because they all run on a fake
///  connection whose Options is nil. This one runs on a connection that really
///  answers False. </summary>
procedure TTestDMLGenerator.TestGuid_StoreGUIDAsOctetOff_EmitsTheLiteralAsUsual;
begin
  Assert.AreEqual(
    'SELECT nguidchild.ngckey, nguidchild.ngcparent FROM nguidchild' +
    ' WHERE nguidchild.ngcparent = ''' + cGUIDKEY + '''',
    OctetSelect(False), False,
    'A connection that answers StoreGUIDAsOctet = False is the default, and ' +
    'must be indistinguishable from a connection that answers nothing.');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDMLGenerator);
  TRegisterClass.RegisterEntity(TGuidOverStringChild);
  TRegisterClass.RegisterEntity(TGuidOverStringMaster);
  TRegisterClass.RegisterEntity(TNullableGuidChild);
  TRegisterClass.RegisterEntity(TNullableGuidMaster);
  TRegisterClass.RegisterEntity(TWideSlot);
  TRegisterClass.RegisterEntity(TPlaceholderNamedKey);

end.