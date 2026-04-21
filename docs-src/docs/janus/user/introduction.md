---
title: Introduction
displayed_sidebar: janusSidebar
---

Janus is a Delphi ORM framework that maps classes to persisted entities and generates SQL automatically for multiple database drivers.

For daily usage, this means less manual SQL, less repetitive persistence code, and one consistent usage model across visual DataSet screens, object-oriented lists, and REST integration.

The public end-user usage contract remained stable across releases `v2.19.5` through `v2.19.14`.

## What Janus solves

- Reduces repetitive CRUD boilerplate.
- Centralizes mapping through attributes in the domain class.
- Allows switching supported databases with minimal application-code impact.
- Preserves natural DataSet integration for screens and legacy routines.

## Target audience

- Delphi developers working on VCL/FMX systems.
- Teams maintaining applications across multiple supported databases.
- Projects that need object-oriented persistence with lower coupling to native SQL.

## Core concepts

- Mapped entity: a Delphi class with attributes such as Entity, Table, PrimaryKey, and Column.
- Entity registration: required initialization-block step so runtime can resolve mapping metadata.
- DataSet/ObjectSet container: data-operation layer for reading, editing, and persisting data.
- DML driver: component that translates operations to the selected database dialect.
- Transparent lazy loading: associations marked with `[Lazy]` load on first access without mandatory manual `LoadLazy` in supported flows.

## Typical usage flow

1. Model a Delphi entity with attributes.
2. Register the entity in the unit initialization block.
3. Configure the connection through a DataEngine factory.
4. Create a container and open data.
5. Persist changes with ApplyUpdates.
