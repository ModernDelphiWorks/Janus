---
displayed_sidebar: janusSidebar
title: Testes
---

## Estratégia

A suite de testes DUnitX está dividida em quatro executores independentes. Cada executor compila e executa um conjunto específico de fixtures; o NUnit XML produzido por cada `.exe` é a fonte de verdade em tempo de execução para a contagem real de `[Test]`.

- **JanusSmoke.dpr** — suite unitária rápida: mapeamento, lazy, middleware, plugins, CodeGen, JSON, DML, FluentSQL, REST QueryParse
- **JanusRestHorse.dpr** — integração REST/Horse: CRUD sobre HTTP, endpoints read-only, join views, driver prefix, controle de verbo
- **JanusLiveBindings.dpr** — LiveBindings R22.x: TJanusBinder com atributos [Bind]/[BindGrid]/[BindGridColumn]
- **JanusRESTHorseOracle.dpr** — Oracle AutoView: integração REST com Oracle XE (requer infraestrutura local)
- **FPCUnit** — compatibilidade Lazarus em `Test/Lazarus/` (fora do escopo DUnitX)

Aggregate pré-`#170`: 300 atributos `[Test]` executados (217 + 48 + 31 + 4). Alvo pós-`#170` após rebuild CI: ≥289 em `JanusSmoke.exe` (7 fixtures recém-vinculadas); total ≥372 nos 4 executores.

Os arquivos XML de resultado (`Test/Delphi/dunitx-*.xml`) são a fonte de verdade em runtime. Inspecione-os após uma execução local ou pelo self-hosted Delphi CI.

## JanusSmoke.dpr — suite unitária rápida

| Arquivo de teste | Count | Área coberta |
|-----------------|-------|-------------|
| `TestMappingCache` | 11 | `TMappingExplorer`, caches lazy |
| `TestRttiSingleton` | 3 | `RttiSingleton` unificado |
| `TestNullable` | 3 | `Nullable<T>` |
| `TestSmokeLazyLoading` | 10 | smoke lazy loading |
| `TestObjectSetLazyProxy` | 4 | proxy lazy em ObjectSet |
| `TestLazyMapping` | 4 | `TLazyMappingExplorer` |
| `TestLazyProxy` | 7 | proxy transparente e `FillAssociation` |
| `TestDataSetLazyProxy` | 8 | proxy lazy em DataSet |
| `TestRestLazyProxy` | 7 | proxy lazy em REST |
| `TestLazyProxyMultiplicity` | 9 | multiplicidades one-to-many / many-to-one |
| `TestLazyWrapper` | 2 | `Lazy<T>` |
| `TestGetDictionary` | 1 | overload `GetDictionary` |
| `TestQueryCache` | 1 | crescimento limitado `TQueryCache` |
| `TestDataSetAutoLazy` | 6 | lazy loading em fluxos DataSet |
| `TestCriteriaAdvanced` | 11 | expressões Criteria avançadas |
| `TestMiddlewarePipeline` | 6 | ordenação Before/After |
| `TestDMLGenerator` | 29 | gerador DML (caminho SQLite) |
| `TestFluentSQLIntegration` | 39 | integração FluentSQL |
| `TestJanusRESTQueryParse` | 56 | REST QueryParse — parser OData |
| `TestPluginRegistry` | 10 | plugins, hooks, abort, eventos customizados — *wired #170* |
| `TestPluginIntegration` | 6 | abort em insert, update e delete — *wired #170* |
| `TestCrudEndToEnd` | 8 | hooks middleware Before/After CRUD — *wired #170* |
| `TestCodeGenEngine` | 21 | engine CodeGen — *wired #170* |
| `TestCodeGenComplex` | 6 | FKs compostas e múltiplos indexes — *wired #170* |
| `TestCodeGenTemplate` | 6 | template engine — *wired #170* |
| `TestJanusJson` | 15 | wrapper `TJanusJson` — *wired #170* |

As 7 fixtures marcadas *wired #170* foram compiladas mas não estavam registradas no runner antes do commit `26256a8` (issue #170, v2.22.2).

## JanusRestHorse.dpr — integração REST/Horse

| Arquivo de teste | Count | Área coberta |
|-----------------|-------|-------------|
| `TestJanusRESTHorseIntegration` | 12 | integração REST/Horse (CRUD sobre HTTP) |
| `TestJanusRESTReadOnly` | 6 | endpoints `[RESTReadOnly]` |
| `TestJanusRESTJoinView` | 6 | join views via REST |
| `TestJanusRESTHorseDriver` | 8 | driver com prefixo `api/Janus` |
| `TestJanusRESTMethodGrant` | 16 | controle de verbo por `[RESTAllowGET/POST/PUT/DELETE]` |

Requer SQLite FireDAC disponível no ambiente; o servidor Horse sobe no fixture-setup e encerra no fixture-teardown.

## JanusLiveBindings.dpr — LiveBindings R22.x

| Arquivo de teste | Count | Área coberta |
|-----------------|-------|-------------|
| `Tests.Janus.LiveBindings.R221` | 4 | R22.1 — `TJanusBinder` básico |
| `Tests.Janus.LiveBindings.R222` | 9 | R22.2 — `BindGrid<T>` e master-detail |
| `Tests.Janus.LiveBindings.R223` | 8 | R22.3 — backend DataSet (`BindSourceDB`) |
| `Tests.Janus.LiveBindings.R224` | 10 | R22.4 — `BindGridColumn`, regressão R22.1–R22.3 |

## JanusRESTHorseOracle.dpr — Oracle AutoView

| Arquivo de teste | Count | Área coberta |
|-----------------|-------|-------------|
| `TestJanusRESTOracleAutoView` | 4 | AutoView com Oracle XE (requer Oracle XE em localhost:1521) |

Requer Oracle Instant Client 11.2 (32-bit) em `Test/Delphi/` e `tnsnames.ora` com entrada `XE`.

## Como executar

**JanusSmoke** (suite padrão):
```
cd Test/Delphi
JanusSmoke.exe --exitbehavior:Continue --xmlfile:dunitx-results.xml
```

**JanusRestHorse** (integração REST/Horse):
```
cd Test/Delphi
JanusRestHorse.exe --exitbehavior:Continue --xmlfile:dunitx-rest-horse-results.xml
```

**JanusLiveBindings** (LiveBindings R22.x):
```
cd Test/Delphi
JanusLiveBindings.exe --exitbehavior:Continue --xmlfile:dunitx-livebindings-results.xml
```

**JanusRESTHorseOracle** (Oracle — requer infraestrutura):
```
cd Test/Delphi
TNS_ADMIN="<abs-path-to-Test/Delphi>" JanusRESTHorseOracle.exe --exitbehavior:Continue --xmlfile:dunitx-oracle-results.xml
```

Saída esperada: todos os testes verdes em cada executor. Os arquivos XML de resultado são gerados no diretório de trabalho.

## Notas de versão

- A partir de v2.18.6, o legado `Source/Criteria/*.pas` foi removido; queries usam exclusivamente `TCQ()` via FluentSQL.
- A partir de v2.18.16, `TestMappingCache` cobre regressão para entidade anotada apenas com `[View]`.
- A partir de v2.19.0, a suite inclui lazy transparente em ObjectSet, DataSet e REST com validação de multiplicidades.
- A partir de v2.20.0, `JanusRestHorse.dpr` cobre CRUD REST/Horse, OData parser, `[RESTReadOnly]` e join views.
- A partir de v2.20.1, `TestJanusRESTMethodGrant` cobre controle de acesso por verbo HTTP.
- A partir de v2.21.0, `JanusLiveBindings.dpr` cobre `TJanusBinder` (R22.1–R22.3) e Oracle AutoView.
- A partir de v2.22.0, R22.4 (`BindGridColumn`) integrada em `JanusLiveBindings.dpr`.
- A partir de v2.22.2, 7 fixtures previamente não registradas foram vinculadas ao `JanusSmoke.dpr` (#170).
