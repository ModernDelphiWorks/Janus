# Janus — Conventions and Architectural Decisions

## Architectural decisions

- mapping is attribute-driven; persistence configuration lives on model classes through Delphi attributes
- driver abstraction is mandatory through `IDBConnection` and factories such as `TFactoryFireDAC`
- the framework is split into independent concerns: Core ORM, Dataset, ObjectSet, Criteria, Middleware, CodeGen, Plugins and REST
- multi-database support is a core contract, not an optional feature
- framework evolution should strengthen the mapping and persistence core first
- current audited project version is `v2.18.0`
- fourteen sprints are marked as concluded in the audited material
- the DUnitX suite contains 300+ tests across 4 executors (post-#170 target ≥372 once CI rebuild lands); see support-matrix.md for the executor-by-executor breakdown

## Explicit continuity rules

### Janus is ORMBr's international evolution

- the Janus name is deliberate and symbolic: a bridge between object-oriented code and relational databases
- the rename aims at broader international visibility and adoption
- legacy names such as `ORMBr` remain semantically valid when reading code, issues and documentation

### Janus is a full ORM, not only simple mapping

Confirmed domain scope includes:

- automated CRUD persistence
- relationship support through `ForeignKey`, `JoinColumn` and `Association`
- master/detail hierarchy via `TManagerDataSet`
- advanced typing such as Nullable, Blob and Lazy
- lifecycle middleware events
- DDL generation through metadata compare
- integration with web frameworks such as Horse

### Database neutrality is non-negotiable

- database-specific generators are part of the public capability set
- connection factories must stay decoupled from consuming application code
- feature evolution should preserve the ability to switch databases without rewriting mapped application logic

## Naming and legacy evolution notes

- treat Janus and ORMBr references as part of the same lineage
- prefer current Janus names in new artifacts unless the source being referenced is explicitly legacy
- keep wrapper facades stable when modernizing dependencies to avoid leaking third-party APIs across the framework

## Language-rule pointers

Project-wide language rules live under `.claude/rules/<stack>/`.

Relevant audited rule families in this workspace:

- `.claude/rules/delphi/`
- `.claude/rules/csharp/`
- `.claude/rules/python/`
- `.claude/rules/fastapi/`
- `.claude/rules/flutter/`
