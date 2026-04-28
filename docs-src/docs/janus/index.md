---
displayed_sidebar: janusSidebar
title: Janus
---

Framework ORM para Delphi com mapeamento por atributos, suporte multi-banco, DataSet/ObjectSet e geração de SQL com FluentSQL.

## Trilhas de documentação

- [Documentação Técnica](./introduction)
- [Manual do Usuário](./user/)

## Comece por aqui (Técnico)

- [Introdução](./introduction)
- [Quickstart](./getting-started/quickstart)
- [Arquitetura](./architecture/overview)
- [API](./reference/api)
- [Testes](./tests/overview)

## Escopo

- Cobre: persistência ORM, mapeamento de entidades, integrações de runtime e guias técnicos do framework.
- Não cobre: conteúdo legado removido e estrutura antiga da pasta Doc.

## Release status

- Most recent published version: `v2.22.5`.
- Most recent published tag: `v2.22.5`.
- `v2.22.5` closed the 8-demand audit-driven roadmap (round 61..68): reorganized `Test/Delphi/Tests/` into a layered tree (`Common`/`Unit`/`Integration`/`RESTHorse`/`RESTOracle`/`LiveBindings`) with 35 fixtures renamed to `Test.Janus.<area>.<subject>.pas` (issue #191); renamed the four DUnitX executors to canonical `Janus.Tests.{Unit,RESTHorse,LiveBindings,RESTOracle}.dpr` and consolidated four `Tests.Janus.LiveBindings.R22N.pas` into three release-agnostic units (`Test.Janus.LiveBindings.{Base,DataSet,GridColumn}`) with `[Category('R22.x')]` attributes (issue #192); ROADMAP "Gap Fixtures Era" phase added with 12 deferred candidates (issue #193).
- `v2.22.4` extracted DUnitX runner/bootstrap to `Test/Delphi/Common/`; standardized `DCC_UnitSearchPath` across 49 example `.dproj`; added Examples Build Gate workflow with TSV manifest (issues #185–#188).
- `v2.22.3` refreshed the knowledge-base reference files, replacing the stale "131 tests" claim with 300+ DUnitX tests across 4 executors; per-executor breakdown in `support-matrix.md` (issue #180).
- `v2.22.2` wired 7 orphan DUnitX fixtures into `JanusSmoke.dpr` (issue #170); fixed `TFakeConnection` mock contract (issue #171); prepended MIT license headers to 255 source artifacts (issue #175); replaced remaining LGPL badge with MIT (issue #178).
- `v2.22.1` replaced LGPL header with MIT in all 134 `Source/` `.pas` files (issue #168); consolidated ROADMAP post-v2.22.0 (issue #167).
- `v2.22.0` delivered R22.4 LiveBindings fixture (`Tests.Janus.LiveBindings.R224`, 10 tests, `BindGridColumn` attribute binding); removed legacy `TJanusLiveBindings` engine units (issue #164/#165).
- `v2.21.0` delivered `TJanusBinder` engine (R22.1–R22.3): adapter-based live-bindings with `[Bind]`/`[BindGrid]`/`[BindGridDetail]`/`[BindListControl]`/`[BindGridColumn]` attributes; Oracle REST Horse example; `TRESTViewManager` AutoView; `JanusRESTHorseConsole.dpr` demo (issues #152–#161).
- `v2.20.2` fixed filter-based DELETE in REST/Horse, DataEngine FireDAC row iteration, and OData URL-encoded filter parsing (issues #145/#147/#149).
- `v2.20.1` added REST/Horse driver test suite (`TestJanusRESTHorseDriver`, 8 tests) and HTTP verb access control attributes `[RESTAllowGET/POST/PUT/DELETE]` with 405 guard (issues #134/#137).
- `v2.20.0` added `[RESTReadOnly]`, `TRESTViewManager`, OData parser rewrite, `JanusRestHorse.dpr` executor, and documentation pages `odata-reference`, `rest-readonly`, `rest-join-strategy` (issue #130).
- `v2.19.14` reconciled user-manual documentation scope without runtime/product behavior changes (issue #127).
