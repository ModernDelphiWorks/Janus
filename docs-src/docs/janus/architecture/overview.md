---
displayed_sidebar: janusSidebar
title: Visão Geral
---

## Contexto

O Janus organiza persistência ORM, materialização e integrações de runtime em módulos independentes, mantendo neutralidade de banco e compatibilidade entre os modos DataSet, ObjectSet e REST.

## Módulos do Source/

| Módulo | Responsabilidade |
|--------|-----------------|
| `Core/` | Session, Commands, DML Generator, Bind, Driver Register, Nullable, Lazy, RTTI helpers e cache `TLazyMappingExplorer` |
| `Dataset/` | `TJanusDataSet`, `TManagerDataSet`, adapters (FDMemTable, ClientDataSet) e injeção de proxy lazy por scroll |
| `Objectset/` | Container object-oriented (sem DataSet visual) com lazy transparente preservando `LoadLazy` explícito |
| `Middleware/` | Interceptação Before/After Insert/Update/Delete; QueryScope; Plugin Registry |
| `Query/ResultSet` | Execução de SQL e materialização tipada via `IJanusQueryResultSet` e `IJanusQueryObject<M>` |
| `CodeGen/` | Geração de código Delphi a partir de schema (templates, engine, wizard) |
| `Metadata/` | Mapeamento RTTI de atributos → metadados de entidade |
| `RESTful/` | Driver RESTful para persistência via HTTP com injeção de proxy lazy em `FillAssociation` |
| `Dependencies/` | FluentSQL, MetaDbDiff, DataEngine, JsonFlow |

## Drivers DML suportados

Firebird · Firebird 3 · InterBase · MySQL · PostgreSQL · SQLite · MSSQL · Oracle · ADS · AbsoluteDB · ElevateDB · NexusDB · MongoDB · NoSQL

Cada driver vive em `Janus.DML.Generator.<Driver>.pas` e é registrado via `TDriverRegister.RegisterDriver`.

## Camadas e dependências

```
Form / App
    ↓
TManagerDataSet / TSessionDataSet  (Dataset/)
    ↓
TSessionAbstract / Commands        (Core/)
    ↓
TDMLGeneratorAbstract + IFluentSQL (Core/ + Dependencies/FluentSQL)
    ↓
TDriverRegister → IDMLGeneratorCommand  (Core/)
    ↓
DataEngine IDBConnection           (Dependencies/DataEngine)
```

## Pontos de extensão

- **Middleware**: registrar callbacks `Before*/After*` via `TMiddlewareRegister`
- **Plugin**: implementar interface de plugin e registrar em `TPluginRegistry`
- **Driver customizado**: implementar `IDMLGeneratorCommand` e chamar `TDriverRegister.RegisterDriver`
- **QueryScope**: filtros globais automáticos via `TMiddlewareQueryScope`
- **Lazy transparente**: reutilizar `TLazyProxyLoader`, `ILazySessionToken` e `TLazyMappingExplorer` para manter o mesmo contrato entre ObjectSet, DataSet e REST
