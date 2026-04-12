---
displayed_sidebar: janusSidebar
title: Testes
---

## Estratégia

- **DUnitX** — suite principal em `Test/Delphi/JanusSmoke.dpr`
- **FPCUnit** — compatibilidade Lazarus em `Test/Lazarus/`
- Cobertura: geração SQL (FluentSQL), bind, lazy/proxy, middleware, plugins, CodeGen
- A partir de v2.18.6, o legado `Source/Criteria/*.pas` foi removido; as queries usam exclusivamente `TCQ()` via FluentSQL.
- A partir de v2.18.16, `TestMappingCache` cobre regressao para entidade anotada apenas com `[View]`, validando os caminhos de `GetTable` e `GetMappingView`.
- A partir de v2.19.0, a suíte inclui validação dedicada do lazy transparente em ObjectSet, DataSet e REST, além de multiplicidades e retrocompatibilidade do `LoadLazy` explícito.
- A v2.19.1 corrigiu os gates finais de compilação da suíte (`Supports` e `SysUtils`) sem alteração de contrato público da API.
- A v2.19.2 estabilizou os cenarios funcionais de reset/reload lazy e o contrato `[View]` sem `[Table]`.
- A v2.19.3 consolidou a baseline operacional dessa estabilizacao com nova validacao dirigida em execucao completa da suite, sem alterar a API publica.
- A v2.19.4 publicou apenas o refactor documental do `ROADMAP.md`; a baseline validada da suíte permanece a mesma da rodada `v2.19.3`.
- A v2.19.5 refatorou internamente o runtime MARS para padronizar a serializacao JSON via fachada `Janus.Json`, sem alterar contrato HTTP nem assinaturas publicas; a baseline de 155/155 permanece inalterada.
- A v2.19.6 encerrou operacionalmente a validacao ESP-006: build/smoke confirmados com `155/155` aprovados; dívida técnica anterior fechada; contrato de suite sem alteracao.
- A issue `#103` (ESP-004) foi uma rodada processual de governanca da pipeline; nao houve alteracao na suite de produto nem nova baseline funcional publicada.
- A issue `#105` foi release process-only e manteve o mesmo contrato de validacao: sem mudancas na suite de produto e sem nova baseline funcional alem da rodada `v2.19.6`.
- A v2.19.7 formalizou o contrato canônico de validacao processual para `/test` e `/release` (Path A/Path B), sem alterar a suite de produto, baseline funcional ou cobertura publicada.
- A v2.19.8 formalizou documentalmente a demanda R18.1 (ESP-002) para handoff operacional, sem alterar a suite de produto, baseline funcional ou cobertura publicada.
- A v2.19.9 atualizou estrategicamente o `ROADMAP.md` para consolidar a demanda candidata R18.1, mantendo o mesmo contrato de suite e baseline funcional publicada.
- A v2.19.10 consolidou editorialmente o milestone R18.1 em item unico no `ROADMAP.md` (issue `#110`), sem alteracao de suite, cobertura ou baseline funcional.
- A v2.19.11 normalizou editorialmente a redacao da origem de R18.1 no `ROADMAP.md` (de "proxiam demanda" para "proxima demanda"), sem alterar classificacao ESP-002, escopo funcional ou baseline de testes (issue `#113`).
- A v2.19.13 reforcou a confiabilidade da evidencia smoke para Strategy A com semantica deterministica de geracao XML e corrigiu o bloqueio de release no gate de develop, sem alteracao na suite de produto, cobertura publicada ou baseline funcional (issues `#118` e `#122`).
- A v2.19.14 publicou reconciliacao de escopo documental do manual do usuario (issue `#127`) sem alteracao na suite de produto, cobertura publicada ou baseline funcional.

## Suíte DUnitX — arquivos de teste

| Arquivo | Foco |
|---------|------|
| `TestDMLGenerator` | Geração SQL para todos os drivers |
| `TestFluentSQLIntegration` | Integração FluentSQL ↔ Janus (baseline de drivers prioritários) |
| `TestCriteriaAdvanced` | Queries complexas via FluentSQL (`TCQ`) — AND/OR, LIKE, IN, BETWEEN, OrderBy, GroupBy, IS NULL |
| `TestLazyMapping` | Mapeamento de propriedades `[Lazy]` |
| `TestLazyProxy` | Proxy transparente e ciclo de vida |
| `TestSmokeLazyLoading` | Baseline de segurança para infraestrutura lazy sem conexão real |
| `TestDataSetLazyProxy` | Contrato de injeção lazy no contexto DataSet |
| `TestRestLazyProxy` | Contrato de injeção lazy no contexto REST |
| `TestLazyProxyMultiplicity` | Multiplicidades `OneToOne`/`OneToMany`/`ManyToOne`/`ManyToMany` e retrocompatibilidade |
| `TestLazyWrapper` | `Lazy<T>` / `ILazy<T>` |
| `TestMiddlewarePipeline` | Ciclo Before/After eventos |
| `TestPluginRegistry` / `TestPluginIntegration` | Sistema de plugins |
| `TestCrudEndToEnd` | Fluxo completo DataSet ↔ banco |
| `TestDataSetAutoLazy` | Lazy automático no DataSet |
| `TestQueryCache` | Cache de queries |
| `TestMappingCache` | Cache de mapeamento RTTI |
| `TestNullable` | `Nullable<T>` |
| `TestCodeGenEngine` / `TestCodeGenComplex` | Geração de código |
| `TestGetDictionary` | `GetDictionary` na sessão |
| `TestJanusJson` | Serialização JSON |
| `TestRttiSingleton` | Singleton RTTI |

## Como executar

Abrir `Test/Delphi/JanusSmoke.dpr` no Delphi e executar a suíte DUnitX (F9).

Saida esperada: todos os testes verdes. A validacao publicada com execucao completa mais recente registrou `155/155` testes aprovados em `Test/Delphi/JanusSmoke.exe --hidebanner --exit:Continue` na rodada `v2.19.6` (issue `#101`).

Evidencias nominais revalidadas nessa rodada:

- `TestSmokeLazyLoading.TestProxy_ResetAllowsReload`
- `TestDataSetLazyProxy.TestProxy_ResetProducesNewLoad`
- `TestMappingCache.TestHelperGetTable_ReturnsNilForViewEntity`

Relatório XML é gerado em `output/` quando configurado.
