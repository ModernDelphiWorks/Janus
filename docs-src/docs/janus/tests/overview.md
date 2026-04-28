---
displayed_sidebar: janusSidebar
title: Testes
---

## Estratégia

A suite de testes DUnitX está dividida em quatro executores independentes. Cada executor compila e executa um conjunto específico de fixtures; o NUnit XML produzido por cada `.exe` é a fonte de verdade em tempo de execução para a contagem real de `[Test]`.

- **Janus.Tests.Unit.dpr** — suite unitária rápida: mapeamento, lazy, middleware, plugins, CodeGen, JSON, DML, FluentSQL, REST QueryParse
- **Janus.Tests.RESTHorse.dpr** — integração REST/Horse: CRUD sobre HTTP, endpoints read-only, join views, driver prefix, controle de verbo
- **Janus.Tests.LiveBindings.dpr** — LiveBindings R22.x: `TJanusBinder` com atributos `[Bind]`/`[BindGrid]`/`[BindGridColumn]`
- **Janus.Tests.RESTOracle.dpr** — Oracle AutoView: integração REST com Oracle XE (requer infraestrutura local)
- **FPCUnit** — compatibilidade Lazarus em `Test/Lazarus/` (fora do escopo DUnitX)

Aggregate pré-`#170`: 300 atributos `[Test]` executados (217 + 48 + 31 + 4). Alvo pós-`#170` após rebuild CI: ≥289 em `Janus.Tests.Unit.exe` (7 fixtures recém-vinculadas); total ≥372 nos 4 executores.

Os arquivos XML de resultado (`Test/Delphi/dunitx-*.xml`) são a fonte de verdade em runtime. Inspecione-os após uma execução local ou pelo self-hosted Delphi CI.

## Layout de fixtures

A partir de v2.22.5, as fixtures DUnitX estão organizadas em uma árvore em camadas sob `Test/Delphi/`:

| Pasta | Conteúdo |
|-------|----------|
| `Common/` | Infraestrutura compartilhada (`Janus.Test.Runner.pas`, `Janus.Test.Bootstrap.pas`) |
| `Unit/{Core,Mapping.Lazy,Container,Middleware,CodeGen,Criteria}/` | 22 fixtures unitárias canonicalizadas como `Test.Janus.<area>.<subject>.pas` |
| `Integration/` | 3 fixtures de integração |
| `RESTHorse/` (+ `Support/`) | 6 fixtures + 2 utilitários |
| `RESTOracle/` (+ `Support/`) | 1 fixture + 1 utilitário |
| `LiveBindings/` | 3 unidades release-agnostic (Base/DataSet/GridColumn) |

A pasta plana `Test/Delphi/Tests/` foi dissolvida em #191 (demanda 6/8 do audit-driven roadmap).

## Janus.Tests.Unit.dpr — suite unitária rápida

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

## Janus.Tests.RESTHorse.dpr — integração REST/Horse

| Arquivo de teste | Count | Área coberta |
|-----------------|-------|-------------|
| `TestJanusRESTHorseIntegration` | 12 | integração REST/Horse (CRUD sobre HTTP) |
| `TestJanusRESTReadOnly` | 6 | endpoints `[RESTReadOnly]` |
| `TestJanusRESTJoinView` | 6 | join views via REST |
| `TestJanusRESTHorseDriver` | 8 | driver com prefixo `api/Janus` |
| `TestJanusRESTMethodGrant` | 16 | controle de verbo por `[RESTAllowGET/POST/PUT/DELETE]` |

Requer SQLite FireDAC disponível no ambiente; o servidor Horse sobe no fixture-setup e encerra no fixture-teardown.

## Janus.Tests.LiveBindings.dpr — LiveBindings R22.x

A partir de v2.22.5, as quatro fixtures release-específicas (`Tests.Janus.LiveBindings.R221`/`R222`/`R223`/`R224`) foram consolidadas em três unidades release-agnostic. As tags de release sobrevivem como atributos `[Category('R22.x')]` em nível de classe.

| Arquivo de teste | Count | Área coberta |
|-----------------|-------|-------------|
| `Test.Janus.LiveBindings.Base` | 13 | Object backend `Bind` + `BindGrid` + master-detail (`[Category('R22.1')]` + `[Category('R22.2')]`) |
| `Test.Janus.LiveBindings.DataSet` | 8 | DataSet backend (`TBindSourceDB`, master-detail-subdetail) (`[Category('R22.3')]`) |
| `Test.Janus.LiveBindings.GridColumn` | 10 | `BindList<T>` + `BindGridColumn` metadata (`[Category('R22.4')]`) |

## Janus.Tests.RESTOracle.dpr — Oracle AutoView

| Arquivo de teste | Count | Área coberta |
|-----------------|-------|-------------|
| `TestJanusRESTOracleAutoView` | 4 | AutoView com Oracle XE (requer Oracle XE em localhost:1521) |

Requer Oracle Instant Client 11.2 (32-bit) em `Test/Delphi/` e `tnsnames.ora` com entrada `XE`.

## Infraestrutura compartilhada de runner

A partir de v2.22.4, a lógica de bootstrap e execução dos executores foi extraída para dois arquivos em `Test/Delphi/Common/`:

| Arquivo | Responsabilidade |
|---------|-----------------|
| `Janus.Test.Runner.pas` | Inicialização do runner DUnitX, configuração de listeners XML e console |
| `Janus.Test.Bootstrap.pas` | Setup de ambiente compartilhado (conexão, diretórios, teardown global) |

Os quatro executores (`Janus.Tests.Unit`, `Janus.Tests.RESTHorse`, `Janus.Tests.LiveBindings`, `Janus.Tests.RESTOracle`) importam esses arquivos via `uses` clause em vez de duplicar o código de runner internamente.

## Detecção de orphan fixtures

O script `.claude/scripts/audit/detect-orphan-fixtures.sh` detecta fixtures presentes em disco mas ausentes da cláusula `uses` em algum dos 4 `.dpr`. Ele é executado automaticamente no gate `/verify` antes de cada commit.

```bash
bash .claude/scripts/audit/detect-orphan-fixtures.sh
```

- **Saída 0** — nenhuma fixture órfã; suite está sincronizada.
- **Saída 1** — lista de arquivos `.pas` não registrados em nenhum executor.
- **Saída 2** — inputs faltando (glob vazio ou executor ausente).

Fixtures com `// orphan-detect: ignore` nas primeiras 5 linhas são excluídas da verificação.

## Examples Build Gate

A partir de v2.22.4, os 49 projetos de exemplo em `Examples/Delphi/` são verificados por um gate CI dedicado:

| Arquivo | Função |
|---------|--------|
| `Examples/Delphi/auto-validable.txt` | Manifesto TSV com modo por projeto (`compile`/`run`/`defer`/`exclude`) |
| `Examples/Delphi/scripts/build_auto_validable.cmd` | Driver msbuild Windows com `--dry-run` e drift check |
| `Examples/Delphi/scripts/build_auto_validable.sh` | Skeleton POSIX (delega ao `.cmd` no Git Bash; no-op em Linux/macOS) |
| `.github/workflows/examples.yml` | Workflow CI separado de `tests.yml`; mesmo runner `[self-hosted, delphi]` |

Distribuição de modos (v2.22.4):

| Modo | Count | Significado |
|------|-------|-------------|
| `compile` | 24 | Compilação headless via msbuild esperada passar |
| `run` | 0 | Reservado para versão futura |
| `defer` | 4 | Falhas pré-existentes; documentadas para correção em ciclo separado |
| `exclude` | 21 | Drivers externos ou projetos com dependências externas |

Para verificar localmente sem invocar o msbuild:
```
cd Examples/Delphi/scripts
build_auto_validable.cmd --dry-run
```

Saída esperada: `compile=24 run=0 defer=4 exclude=21` + `[dry-run] manifest valid; no msbuild invoked`.

## Como executar

**Janus.Tests.Unit** (suite padrão):
```
cd Test/Delphi
Janus.Tests.Unit.exe --exitbehavior:Continue --xmlfile:dunitx-results.xml
```

**Janus.Tests.RESTHorse** (integração REST/Horse):
```
cd Test/Delphi
Janus.Tests.RESTHorse.exe --exitbehavior:Continue --xmlfile:dunitx-rest-horse-results.xml
```

**Janus.Tests.LiveBindings** (LiveBindings R22.x):
```
cd Test/Delphi
Janus.Tests.LiveBindings.exe --exitbehavior:Continue --xmlfile:dunitx-livebindings-results.xml
```

**Janus.Tests.RESTOracle** (Oracle — requer infraestrutura):
```
cd Test/Delphi
TNS_ADMIN="<abs-path-to-Test/Delphi>" Janus.Tests.RESTOracle.exe --exitbehavior:Continue --xmlfile:dunitx-oracle-results.xml
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
- A partir de v2.22.4, lógica de runner extraída para `Janus.Test.Runner.pas` e `Janus.Test.Bootstrap.pas` em `Test/Delphi/Common/`; `DCC_UnitSearchPath` padronizado nos 49 exemplos; Examples Build Gate adicionado com manifesto `auto-validable.txt` e workflow `examples.yml` (#185–#188).
- A partir de v2.22.5, `Test/Delphi/Tests/` reorganizada em árvore em camadas (`Common`/`Unit`/`Integration`/`RESTHorse`/`RESTOracle`/`LiveBindings`) com 35 fixtures renomeadas para `Test.Janus.<area>.<subject>.pas` (#191); os quatro executores renomeados para `Janus.Tests.{Unit,RESTHorse,LiveBindings,RESTOracle}.dpr`; quatro fixtures `Tests.Janus.LiveBindings.R22N.pas` consolidadas em três unidades release-agnostic com `[Category('R22.x')]` (#192).
