# Janus — Project Overview

## What the project is

Janus is a Delphi ORM and data persistence framework. Evolved from ORMBr and keeps the same architectural base while adopting the Janus name to increase international visibility.

Functional scope, confirmed in the audited source material, includes:

- complete CRUD through mapping Delphi classes to database tables
- metadata comparison between object models and physical database structure
- DML generation for relational databases and NoSQL targets
- DataSet containers integrated with `TClientDataSet` and `TFDMemTable`
- `ObjectSet` support for direct work with persisted object lists
- Criteria API for object-oriented query construction
- middleware pipeline for persistence lifecycle events
- REST integration through Horse middleware
- LiveBindings for VCL and FMX
- SQL command monitor at runtime
- advanced types including Nullable, Blob and lazy loading
- multiplatform DLL Bridge and COM-like interfaces
- helper utilities, LiveBindings integration and factories
- automated multiplatform tests with FPCUnit and DUnitX
- advanced criteria, mapping strategies, sequential navigation and pagination
- examples and tests split by platform
- CodeGen engine for entity generation from database schema
- Delphi IDE wizard with connection, tables, options and preview flow
- formal plugin system with lifecycle, hooks, custom events and abort/cancel behavior
- transparent lazy loading proxy and DataSet auto-lazy support
- public roadmap aligned with changelog
- consolidated automated suite with 300+ DUnitX tests across 4 executors and CI pipeline prepared

Janus exists to reduce the gap between object-oriented Delphi code and the entity-relational database model through an explicit mapping bridge.

## Stack and ecosystem

Independent Delphi framework focused on object-relational persistence across multiple databases.

| Component | Role | Confirmation status |
|---|---|---|
| Janus | Main ORM and persistence engine | Confirmed |
| MetaDbDiff | Attribute and metadata mapping support | Confirmed |
| DataEngine | Connection and driver abstraction | Confirmed |
| FluentSQL | Modern fluent SQL framework intended to replace legacy Criteria | Confirmed; dependency installed, integration pending |
| JsonFluent | JSON serialization and deserialization | Confirmed |
| Delphi XE+ | Supported language and platform line | Confirmed |

## Important ecosystem note

This is not a Flutter or Dart project. Do not infer Flutter packages, widgets, state management patterns or Dart modules unless a source explicitly introduces them.

## Identity and naming continuity

- Janus is the international evolution of ORMBr.
- The rename preserves the same project lineage, architecture and business intent.
- Agents should recognize legacy references to `ORMBr` as referring to the same project family.
