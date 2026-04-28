# Janus — Support Matrix

## Dependencies and versions

| Dependency | Version | Use |
|---|---|---|
| `MetaDbDiff Framework for Delphi` | `^1.1.7` | Mapping attributes and persistence types |
| `DataEngine Framework for Delphi/Lazarus` | `^1.1.7` | Connection abstraction and database drivers |
| `FluentSQL Framework for Delphi/Lazarus` | `^1.1.6` | Planned modern fluent SQL replacement for legacy Criteria; 24 units under `Source/Dependencies/FluentSQL/Core/`; main interface `IFluentSQL` |
| `JsonFluent Framework for Delphi` | `^1.1.6` | JSON serialization and deserialization |
| `Delphi XE+` | support line | Target platform |

## JSON wrapper status

- central wrapper `TJanusJson` in `Source/Core/Janus.Json.pas` already uses `JsonFlow.Utils` and `JsonFlow.Builders`
- most of the framework core under `Source/` is aligned to the wrapper
- legacy naming remains in REST MARS and examples, including `Janus.rest.json`, `Janus.Json.utils` and `TJanusJSONUtil`
- production file `Source/RESTful/Server/Janus.Server.Resource.MARS.pas` is already aligned to `Janus.Json` and `TJanusJson`
- remaining legacy references in examples should migrate to `Janus.Json` and `TJanusJson`

Dependency evolution guideline:

- keep a central wrapper facade such as `Janus.Json`
- apply the same façade strategy during Criteria to FluentSQL migration
- avoid spreading third-party APIs directly across the framework

## Database support matrix

| Database | Generator |
|---|---|
| Firebird | `Janus.DML.Generator.Firebird.pas` |
| Firebird 3 | `Janus.DML.Generator.Firebird3.pas` |
| InterBase | `Janus.DML.Generator.InterBase.pas` |
| SQLite | `Janus.DML.Generator.SQLite.pas` |
| MySQL | `Janus.DML.Generator.MySQL.pas` |
| PostgreSQL | `Janus.DML.Generator.PostgreSQL.pas` |
| Microsoft SQL Server | `Janus.DML.Generator.MSSQL.pas` |
| Oracle | `Janus.DML.Generator.Oracle.pas` |
| MongoDB | `Janus.DML.Generator.MongoDB.pas` |
| Advantage Database Server | `Janus.DML.Generator.ADS.pas` |
| AbsoluteDB | `Janus.DML.Generator.AbsoluteDB.pas` |
| ElevateDB | `Janus.DML.Generator.ElevateDB.pas` |
| NexusDB | `Janus.DML.Generator.NexusDB.pas` |

## Permissions and ACL note

The audited public material does not define internal permission profiles or ACL models for Janus. Do not invent authorization layers without direct evidence in source.

## Test guardrails

The DUnitX suite is split across 4 executors. Compile-time references in each `.dpr` define which fixtures run; the NUnit XML produced by each `.exe` (`Test/Delphi/dunitx-*.xml`) is the runtime source-of-truth for the actual `[Test]` count.

### JanusSmoke.dpr — fast/unit suite

| Test file | Count | Covered area |
|---|---|---|
| `TestMappingCache` | 11 | `TMappingExplorer`, lazy caches |
| `TestRttiSingleton` | 3 | unified `RttiSingleton` |
| `TestNullable` | 3 | `Nullable<T>` |
| `TestSmokeLazyLoading` | 10 | lazy loading smoke |
| `TestObjectSetLazyProxy` | 4 | ObjectSet lazy proxy |
| `TestLazyMapping` | 4 | `TLazyMappingExplorer` |
| `TestLazyProxy` | 7 | transparent proxy and `FillAssociation` |
| `TestDataSetLazyProxy` | 8 | DataSet lazy proxy |
| `TestRestLazyProxy` | 7 | REST lazy proxy |
| `TestLazyProxyMultiplicity` | 9 | one-to-many / many-to-one multiplicity |
| `TestLazyWrapper` | 2 | `Lazy<T>` |
| `TestGetDictionary` | 1 | `GetDictionary` overload |
| `TestQueryCache` | 1 | bounded `TQueryCache` growth |
| `TestDataSetAutoLazy` | 6 | lazy loading in DataSet flows |
| `TestCriteriaAdvanced` | 11 | advanced Criteria expressions |
| `TestMiddlewarePipeline` | 6 | before and after ordering |
| `TestDMLGenerator` | 29 | DML generator (SQLite path) |
| `TestFluentSQLIntegration` | 39 | FluentSQL integration |
| `TestJanusRESTQueryParse` | 56 | REST QueryParse |
| `TestPluginRegistry` | 10 | plugins, hooks, abort, custom events — wired #170 |
| `TestPluginIntegration` | 6 | abort behavior on insert, update and delete — wired #170 |
| `TestCrudEndToEnd` | 8 | middleware hooks before and after CRUD — wired #170 |
| `TestCodeGenEngine` | 21 | CodeGen engine — wired #170 |
| `TestCodeGenComplex` | 6 | composite foreign keys and multiple indexes — wired #170 |
| `TestCodeGenTemplate` | 6 | template engine — wired #170 |
| `TestJanusJson` | 15 | `TJanusJson` wrapper — wired #170 |

### JanusRestHorse.dpr — REST/Horse integration

| Test file | Count | Covered area |
|---|---|---|
| `TestJanusRESTHorseIntegration` | 12 | REST/Horse integration |
| `TestJanusRESTReadOnly` | 6 | REST read-only endpoints |
| `TestJanusRESTJoinView` | 6 | REST join view |
| `TestJanusRESTHorseDriver` | 8 | Horse driver |
| `TestJanusRESTMethodGrant` | 16 | REST method grants |

### JanusLiveBindings.dpr — LiveBindings R22.x

| Test file | Count | Covered area |
|---|---|---|
| `Tests.Janus.LiveBindings.R221` | 4 | LiveBindings release R22.1 |
| `Tests.Janus.LiveBindings.R222` | 9 | LiveBindings release R22.2 |
| `Tests.Janus.LiveBindings.R223` | 8 | LiveBindings release R22.3 |
| `Tests.Janus.LiveBindings.R224` | 10 | LiveBindings release R22.4 |

### JanusRESTHorseOracle.dpr — Oracle integration

| Test file | Count | Covered area |
|---|---|---|
| `TestJanusRESTOracleAutoView` | 4 | Oracle AutoView (requires Oracle XE) |

Pre-`#170` aggregate: 217 + 48 + 31 + 4 = 300 executed `[Test]` attributes (audit §4.1, 2026-04-26). Post-`#170` target after CI rebuild: ≥289 in `JanusSmoke.exe` (217 baseline + 72 newly-wired fixtures); aggregate ≥372 across the 4 executors. Confirm by inspecting `Test/Delphi/dunitx-*.xml` after a self-hosted Delphi CI run.

Drift detection: `bash .claude/scripts/audit/detect-orphan-fixtures.sh` reports any fixture present on disk but absent from the 4 `.dpr` `uses` clauses (zero orphans expected after `#170`).

### Lazarus (FPCUnit) — `Test/Lazarus/`

| Test file | Count | Covered area |
|---|---|---|
| `TestBase` | — | infrastructure |
| `TestJanusStrategy1/2` | — | mapping strategies |
| `TestJanusCriteria` | 3 | `Where`, `OrderBy`, `PageSize` |
| `TestJanusEdgeCases` | 6 | edge cases |

### Critical validation areas

- full CRUD across supported databases
- metadata compare from model to database
- correct DML generation per target database
- Dataset and ObjectSet containers

## Routine matrix

| Routine | When to use |
|---|---|
| Metadata Compare | Mapped classes and database structure diverge → generates synchronization DDL |
| DML Generator | On CRUD operations; generated automatically by the engine |
| Boss Install | Install or update the project dependencies |
| Orphan-fixture detection | Detect drift between `Test/Delphi/Tests/*.pas` and the 4 `.dpr` `uses` clauses → run before `/verify` |

After expanding the framework, validate that DML generation remains correct, complete and compatible with all supported databases.
