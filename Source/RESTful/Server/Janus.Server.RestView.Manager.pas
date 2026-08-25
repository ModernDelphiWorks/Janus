{
  ------------------------------------------------------------------------------
  Janus ORM
  State-of-the-art Object-Relational Mapping (ORM) framework for Delphi.

  SPDX-License-Identifier: MIT
  Copyright (c) 2025-2026 Isaque Pinheiro

  Licensed under the MIT License.
  See the LICENSE file in the project root for full license information.
  ------------------------------------------------------------------------------
}

{
  @abstract(REST View Manager)
  @created(20 Apr 2026)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @abstract(Website : http://www.Janus.com.br)

  Administrative utility that generates or updates database VIEWs at application
  startup via FluentSQL DDL and DataEngine. Never call EnsureView inside a REST
  request handler - it is a setup-time operation only (ADR-003).
}

unit Janus.Server.RestView.Manager;

interface

uses
  SysUtils,
  TypInfo,
  Generics.Collections,
  DataEngine.FactoryInterfaces,
  MetaDbDiff.Mapping.Explorer,
  FluentSQL,
  FluentSQL.DDL,
  FluentSQL.Interfaces;

type
  ERegistryMissingException = class(Exception);

  TRESTViewManager = class
  private
    class var FViewDefinitionRegistry: TDictionary<string, TFunc<IFluentSQL>>;
    class var FViewEnsuredCache: TDictionary<string, Boolean>;
    class function _GetViewName(const AClassType: TClass): string;
    class function _MapDriverToFluent(const ADriver: TDriverName): TFluentSQLDriver;
    class function _SupportsCreateOrReplace(const ADriver: TDriverName): Boolean;
    class procedure _ExecuteDDL(const ASQL: string; const AConnection: IDBConnection);
  public
    class procedure EnsureView(const AClassType: TClass; const ASelect: IFluentSQL;
      const AConnection: IDBConnection);
    class procedure Register(const AClassType: TClass;
      const ASelectFactory: TFunc<IFluentSQL>);
    class procedure EnsureViewLazy(const AClassType: TClass;
      const AConnection: IDBConnection);
    class procedure ClearCache;
  end;

implementation

uses
  MetaDbDiff.Mapping.Classes;

{ TRESTViewManager }

class function TRESTViewManager._GetViewName(const AClassType: TClass): string;
var
  LTableMapping: TTableMapping;
  LViewMapping: TViewMapping;
begin
  Result := '';
  LTableMapping := TMappingExplorer.GetMappingTable(AClassType);
  if Assigned(LTableMapping) and (LTableMapping.Name <> '') then
    Exit(LTableMapping.Name);

  LViewMapping := TMappingExplorer.GetMappingView(AClassType);
  if Assigned(LViewMapping) and (LViewMapping.Name <> '') then
    Exit(LViewMapping.Name);
end;

/// <summary> WHICH FluentSQL DDL DIALECT WRITES THE VIEW FOR EACH DataEngine
///  DRIVER. Issue #357.
///
///  THIS IS THE SECOND DIALECT MAP IN THE TREE AND IT IS NOT THE ONE #355
///  REPAIRED. That one lives in TDMLGeneratorAbstract, is declared per generator
///  through the abstract SerializationDialect, and picks the dialect the DML -
///  INSERT/UPDATE/DELETE/SELECT - is serialized through. This one picks the
///  dialect the DDL serializer writes CREATE VIEW / DROP VIEW in. The two answer
///  DIFFERENT questions about the same TDriverName and they are ALLOWED TO
///  DISAGREE - see dnMySQL below, where agreeing would be a measured regression.
///  SerializationDialect being a class function of a generator is exactly why it
///  cannot govern this map: TRESTViewManager is not a generator.
///
///  The only reader is EnsureView below, reached from a plain GET on a class
///  carrying [View] (Janus.Server.Resource.pas:584-585 -> EnsureViewLazy), in
///  all five server adapters. It is not a debug path and it is not a vestige.
///
///  WHAT THIS MAP GOVERNS IS THE WRAPPER, NOT THE QUERY. The SELECT that goes
///  inside the view is rendered by the dialect of the IFluentSQL the caller
///  built, not by this one. Measured: walking all nineteen TDriverName members
///  through the public EnsureView, the wrapper changed with every dialect while
///  the embedded 'SELECT client_name FROM client' came out byte-identical.
///
///  UNTIL THIS REPAIR THE MAP ENDED IN 'else Result := dbnSQLite'. That else
///  caught NINE of the nineteen drivers - dnInformix, dnADS, dnASA, dnFirebase,
///  dnAbsoluteDB, dnMongoDB, dnElevateDB, dnNexusDB, dnMemory - and wrote their
///  view in SQLite, backticks and all, IN SILENCE. Measured on that same walk:
///  each of the nine produced 'DROP VIEW IF EXISTS `client`' followed by
///  'CREATE VIEW `client` AS ...'. A dialect that raises is a bug report; a
///  dialect that silently returns the wrong string is a view built in quoting
///  the target server does not use. The else is now a NAMED REFUSAL. </summary>
class function TRESTViewManager._MapDriverToFluent(
  const ADriver: TDriverName): TFluentSQLDriver;
begin
  case ADriver of
    /// DELIBERATELY NOT dbnMSSQL, WHICH IS WHAT THE DML SIDE DECLARES, AND THE
    /// DISAGREEMENT IS THE MEASUREMENT - NOT AN OVERSIGHT. The DML generator
    /// serializes MySQL through dbnMSSQL because the MySQL DML serializer
    /// rewrites every ':pN' to '?' over the whole string
    /// (FluentSQL.SerializeMySQL.pas:39-52) and the #337 guard refuses that. But
    /// that rewrite lives in the DML AsString and is guarded by
    /// Assigned(AAST.Params); DDL carries no params, so it never runs on this
    /// path. What runs here is the DDL serializer, and dbnMySQL emits
    /// 'CREATE OR REPLACE VIEW `client` AS SELECT ...' - correct for both MySQL
    /// and MariaDB, and measured emitting it. Following the DML side "for
    /// symmetry" was MEASURED by mutating this very line to dbnMSSQL: it sends
    /// 'CREATE OR ALTER VIEW [client] AS ...' to a MySQL server - MSSQL brackets
    /// and MSSQL's spelling of OR REPLACE, because dnMySQL is in
    /// _SupportsCreateOrReplace below and MSSQL renders OrReplace as OR ALTER.
    /// Both halves measured. DO NOT UNIFY THE TWO MAPS.
    dnMySQL, dnMariaDB:      Result := dbnMySQL;
    dnFirebird, dnFirebird3: Result := dbnFirebird;
    /// NOT dbnInterbase, WHICH IS WHAT THIS MAP SAID BEFORE. dbnInterbase exists
    /// in TFluentSQLDriver, but its {$DEFINE} is off in FluentSQL.inc and
    /// _RegisterInterbase never calls RegisterDDLSerialize
    /// (FluentSQL.Register.pas:175-181) - there is no
    /// FluentSQL.DDL.Serialize.Interbase.pas for it to register. Turning the
    /// {$DEFINE} on would NOT have fixed it; the missing serializer is the
    /// second lock. Measured: dbnInterbase turned every InterBase [View] GET
    /// into ENotSupportedException, so no view was ever created for an InterBase
    /// connection. dbnFirebird is what the DML side already chose for InterBase
    /// (Janus.DML.Generator.InterBase.pas:61-64), and measured here it emits
    /// 'DROP VIEW IF EXISTS "client"' + 'CREATE VIEW "client" AS ...' - the
    /// SQL-standard double quoting InterBase shares with Firebird, which is
    /// where Firebird inherited it from.
    ///
    /// NOT MEASURED - AND THE REPO ITSELF SUPPLIES A REASON TO DOUBT THE DROP
    /// HALF. There is no InterBase server on this machine, so acceptance was
    /// never measured. But the Firebird DDL serializer treats IF EXISTS as
    /// unsafe in three neighbouring verbs, by declared measurement, and emits it
    /// here anyway. Enumerating all eight Drop* verbs of
    /// FluentSQL.DDL.Serialize.Firebird.pas (FluentSQL @ 9476416): THREE REFUSE
    /// the modifier - DROP TABLE (:158-160), DROP INDEX (:267-269, "Firebird 5.0
    /// rejects it (-104 Token unknown - EXISTS)", measured on
    /// firebirdsql/firebird:5.0.4 per the note at :260-266) and DROP SEQUENCE
    /// (:319-320, ADR-054); FOUR EMIT it - DROP VIEW (:302-303), DROP PROCEDURE
    /// (:356-357), DROP TRIGGER (:389-390), DROP FUNCTION (:427-428); and DROP
    /// SCHEMA (:438-440) refuses the whole verb. So DROP VIEW is not the lone
    /// exception - it is in the larger half - which makes this a signal to
    /// declare, not a defect proven. IF EXISTS only arrived in Firebird 5.0 and
    /// InterBase is the more conservative engine of the two, so a live InterBase
    /// may reject the DROP. dnInterbase is NOT in _SupportsCreateOrReplace
    /// below, so this path takes exactly that DROP VIEW IF EXISTS branch.
    ///
    /// DELIBERATELY NOT FIXED HERE, AND NOT A REGRESSION OF THIS REPAIR. Before
    /// it, dnInterbase raised and NO view was ever created for an InterBase
    /// connection; now it emits DDL a server may or may not accept, and the
    /// CREATE VIEW "client" half is right either way. dnFirebird and dnFirebird3
    /// have been taking that same DROP branch since long before this issue and
    /// are untouched by it. What was wrong was this boundary being
    /// under-declared, not the mapping.
    dnInterbase:             Result := dbnFirebird;
    dnSQLite:                Result := dbnSQLite;
    dnMSSQL:                 Result := dbnMSSQL;
    dnOracle:                Result := dbnOracle;
    dnPostgreSQL:            Result := dbnPostgreSQL;
    /// KEPT AS A CLAUSE, AND IT STILL RAISES - on purpose. dbnDB2 sits exactly
    /// where dbnInterbase sat: {$DEFINE} off, no RegisterDDLSerialize
    /// (FluentSQL.Register.pas:183-189), no DDL serializer unit. It stays out of
    /// the else because the refusal it already produces names the database -
    /// 'O DDL serialize do banco DB2 no est registrado!'
    /// (FluentSQL.Register.pas:291) - and because "mapped dialect whose
    /// serializer is not compiled in" is a different fact from the else's "no
    /// dialect for this driver at all". Unlike InterBase there is no neighbour
    /// to borrow from: DB2 quotes like Firebird but disagrees on OR REPLACE and
    /// on view options, and picking one unmeasured would be the silent-wrong-
    /// dialect defect this issue is about.
    dnDB2:                   Result := dbnDB2;
  else
    /// THE ELSE THAT USED TO ANSWER dbnSQLite. It now names the driver that
    /// arrived and says there is no DDL dialect for it, so the nine drivers
    /// listed in the summary above stop receiving SQLite DDL in silence.
    ///
    /// ENotSupportedException AND NOT ERegistryMissingException, decided by
    /// measurement, not by taste. (a) Grepped repo-wide: ERegistryMissingException
    /// has exactly two occurrences OUTSIDE this comment - its own declaration in
    /// the type block above and its own raise inside EnsureViewLazy below, both
    /// in this unit - and none of the five adapters
    /// (Janus.Server.Resource.{Horse,WiRL,MARS,DMVC,DataSnap}.pas) contains a
    /// single 'except' - so no handler in this tree distinguishes the classes and
    /// the choice is about which condition the class already stands for.
    /// (b) ERegistryMissingException stands for "the application forgot to call
    /// Register", an app-configuration miss. (c) ENotSupportedException is what
    /// this exact condition - no DDL serializer for this dialect - already raises
    /// today, from FluentSQL.Register.pas:291, and it goes on raising it for
    /// dnDB2 after this repair. Any other class here would make one product fact
    /// speak with two exception classes depending on which of the two gates
    /// caught it.
    ///
    /// dnMongoDB IS IN HERE, AND THAT IS A DEPARTURE FROM THE APPROVED DESIGN.
    /// The design said dnMongoDB -> dbnMongoDB "because it has a DDL serializer
    /// registered". The registration is real (FluentSQL.Register.pas:219), but
    /// the inference is not: TFluentDDLSerializerMongoDB
    /// (FluentSQL.DDL.Serialize.MongoDB.pas:28-40) descends from
    /// TFluentDDLSerializeAbstract and overrides six DDL verbs - CreateTable,
    /// DropTable, CreateIndex, DropIndex, AlterTableRenameTable, TruncateTable.
    /// CreateView and DropView are NOT among them, and the base
    /// (FluentSQL.DDL.SerializeAbstract.pas:404-412) raises EAbstractError for
    /// both. So dbnMongoDB would not have emitted Mongo view DDL; it would have
    /// raised EAbstractError naming a serializer class instead of the driver the
    /// operator configured. MongoDB has no SQL views to create either way. The
    /// silent SQLite DDL is removed as the design intended, by the route the
    /// design's own point 3 already provides.
    ///
    /// AND THAT IS WHY THE MESSAGE BELOW DOES NOT SAY "REGISTERS A DDL
    /// SERIALIZER". It said exactly that at first, and the criterion was the
    /// same inference the paragraph above disproves: an operator who followed it
    /// literally would pick a registered dialect, get EAbstractError, and land in
    /// the defect this comment documents. The criterion that decides the outcome
    /// is whether the serializer OVERRIDES CreateView and DropView -
    /// registration only gets past FluentSQL.Register's own gate. Do not shorten
    /// the message back; the short form is the wrong test. It names no dialect on
    /// purpose, so that it stays true whichever serializers gain or lose those
    /// two overrides later.
    raise ENotSupportedException.CreateFmt(
      'Driver %s has no FluentSQL DDL dialect, so TRESTViewManager cannot ' +
      'build the CREATE VIEW for it. Map %s to a dialect whose DDL serializer ' +
      'OVERRIDES CreateView and DropView - a serializer merely being registered ' +
      'is not enough, since one that does not override them raises ' +
      'EAbstractError - or drop the [View] attribute for this connection.',
      [GetEnumName(TypeInfo(TDriverName), Ord(ADriver)),
       GetEnumName(TypeInfo(TDriverName), Ord(ADriver))]);
  end;
end;

// Returns True for databases that natively support CREATE OR REPLACE VIEW.
class function TRESTViewManager._SupportsCreateOrReplace(
  const ADriver: TDriverName): Boolean;
begin
  Result := ADriver in [dnMySQL, dnMariaDB, dnPostgreSQL, dnOracle];
end;

class procedure TRESTViewManager._ExecuteDDL(const ASQL: string;
  const AConnection: IDBConnection);
begin
  if ASQL = '' then
    Exit;
  AConnection.ExecuteDirect(ASQL);
end;

class procedure TRESTViewManager.EnsureView(const AClassType: TClass;
  const ASelect: IFluentSQL; const AConnection: IDBConnection);
var
  LViewName: string;
  LDriver: TDriverName;
  LDialect: TFluentSQLDriver;
  LCreateSQL: string;
  LDropSQL: string;
  LSchema: IFluentSchema;
begin
  if not Assigned(AClassType) then
    raise EArgumentNilException.Create('AClassType must not be nil');
  if not Assigned(ASelect) then
    raise EArgumentNilException.Create('ASelect must not be nil');
  if not Assigned(AConnection) then
    raise EArgumentNilException.Create('AConnection must not be nil');

  LViewName := _GetViewName(AClassType);
  if LViewName = '' then
    raise Exception.CreateFmt(
      'Class %s has no [Table] or [View] attribute with a name '#$2014' cannot derive view name.',
      [AClassType.ClassName]);

  LDriver  := AConnection.GetDriver;
  LDialect := _MapDriverToFluent(LDriver);
  LSchema  := FluentSQL.Schema(LDialect);

  if _SupportsCreateOrReplace(LDriver) then
  begin
    LCreateSQL := LSchema.CreateView(LViewName).OrReplace.&As(ASelect).AsString;
    _ExecuteDDL(LCreateSQL, AConnection);
  end
  else
  begin
    // Databases without CREATE OR REPLACE VIEW support (SQLite, Firebird < 3.x, etc.)
    LDropSQL   := LSchema.DropView(LViewName).IfExists.AsString;
    LCreateSQL := LSchema.CreateView(LViewName).&As(ASelect).AsString;
    _ExecuteDDL(LDropSQL, AConnection);
    _ExecuteDDL(LCreateSQL, AConnection);
  end;
  FViewEnsuredCache.AddOrSetValue(AClassType.ClassName, True);
end;

class procedure TRESTViewManager.Register(const AClassType: TClass;
  const ASelectFactory: TFunc<IFluentSQL>);
begin
  if not Assigned(AClassType) then
    raise EArgumentNilException.Create('AClassType must not be nil');
  if not Assigned(ASelectFactory) then
    raise EArgumentNilException.Create('ASelectFactory must not be nil');
  FViewDefinitionRegistry.AddOrSetValue(AClassType.ClassName, ASelectFactory);
end;

class procedure TRESTViewManager.EnsureViewLazy(const AClassType: TClass;
  const AConnection: IDBConnection);
var
  LFactory: TFunc<IFluentSQL>;
  LSelect: IFluentSQL;
begin
  if FViewEnsuredCache.ContainsKey(AClassType.ClassName) then
    Exit;
  if not FViewDefinitionRegistry.TryGetValue(AClassType.ClassName, LFactory) then
    raise ERegistryMissingException.CreateFmt(
      'No view definition registered for class %s. ' +
      'Call TRESTViewManager.Register before the server handles GET requests.',
      [AClassType.ClassName]);
  LSelect := LFactory;
  EnsureView(AClassType, LSelect, AConnection);
end;

class procedure TRESTViewManager.ClearCache;
begin
  FViewEnsuredCache.Clear;
end;

initialization
  TRESTViewManager.FViewDefinitionRegistry :=
    TDictionary<string, TFunc<IFluentSQL>>.Create;
  TRESTViewManager.FViewEnsuredCache :=
    TDictionary<string, Boolean>.Create;

finalization
  FreeAndNil(TRESTViewManager.FViewDefinitionRegistry);
  FreeAndNil(TRESTViewManager.FViewEnsuredCache);

end.
