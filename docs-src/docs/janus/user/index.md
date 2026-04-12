---
title: Janus User Manual
displayed_sidebar: janusSidebar
---

User manual for Janus in Delphi, focused on installation, first-use workflows, and day-to-day framework operations.

Current manual status: aligned with release `v2.19.14`, including transparent lazy loading in ObjectSet, DataSet, and REST.
Releases from `v2.19.5` to `v2.19.14` did not change the public usage contract of the framework.
The latest release (`v2.19.14`) preserved runtime behavior for end users.

## Who this manual is for

- Delphi developers who need to persist objects in relational databases.
- Teams that want to reduce manual SQL in CRUD operations.
- Technical operators maintaining VCL/FMX applications with DataSet and integration flows.

## Recommended journey

- [Introduction](./introduction)
- [Quickstart](./getting-started/quickstart)

## Guides by feature

### Persistence and data
- [Primeiro CRUD com DataSet](./guides/primeiro-crud-com-dataset) - VCL/FMX visual workflow
- [Operacao Master-Detail](./guides/operacao-master-detail) - TManagerDataSet
- [ObjectSet (sem DataSet visual)](./guides/objectset) - service and API workflows
- [Consultas personalizadas](./guides/consultas-personalizadas) - filters and pagination via FluentSQL (`TCQ`)

### Special types
- [Campos opcionais com Nullable](./guides/nullable) - Nullable\<T\> for database NULL values
- [Lazy Loading](./guides/lazy-loading) - deferred loading with transparent proxy and `LoadLazy` compatibility

### UI and binding
- [LiveBindings VCL/FMX](./guides/livebindings) - automatic binding via attributes
- [Monitor SQL](./guides/monitor-sql) - real-time SQL diagnostics

### Advanced features
- [Eventos Before e After](./guides/eventos-middleware) - intercept DML operations
- [CodeGen](./guides/codegen) - generate entities from database schema
- [Serializacao JSON](./guides/json) - serialize entities to/from JSON
- [Driver RESTful](./guides/restful) - persistence over HTTP

## References
- [Configuration](./reference/configuration)
- [Troubleshooting](./troubleshooting/common-errors)
