# Changelog

Todas as mudanças notáveis do projeto Janus (anteriormente ORMBr) serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
e este projeto adere ao [Semantic Versioning](https://semver.org/lang/pt-BR/).

## [Unreleased]

### Added
- Suite de testes de integração REST/Horse via Driver: extensão de `RestHorseTest.Base.pas` com campo `FPrefix` e método `BuildResourceURL`; criação de `TestJanusRESTHorseDriver.pas` com 8 cenários CRUD via prefixo `api/Janus`; atualização de `JanusRestHorse.dpr` ([#134](https://github.com/ModernDelphiWorks/Janus/issues/134))

### Fixed
- Fechamento dos três caveats pós-release de v2.20.0: remoção da cláusula `uses FluentSQL.Interfaces` duplicada em `Janus.Server.RestView.Manager.pas`; adição da categoria `RESTful` no sidebar do Docusaurus com links para `odata-reference`, `rest-readonly` e `rest-join-strategy`; adição de exemplo `[RESTReadOnly]` em `HorseJanus.dpr` com controller e model dedicados ([#133](https://github.com/ModernDelphiWorks/Janus/issues/133))
- Alinhamento do contrato de prefixo nas fixtures de teste: adição de `FPrefix := 'api/Janus'` antes de `inherited Setup` em `TestJanusRESTReadOnly` e `TestJanusRESTJoinView`; substituição de `_BuildURL` hardcoded por delegação a `BuildResourceURL` da classe base ([#135](https://github.com/ModernDelphiWorks/Janus/issues/135))

## [v2.19.14](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.19.14) — 2026-04-12

### Changed
- Reconciliacao do escopo da documentacao de manual do usuario, consolidando os arquivos `docs-src/docs/janus/user/index.md`, `docs-src/docs/janus/user/introduction.md` e `docs-src/docs/janus/user/getting-started/quickstart.md` como entrega explicita e validada da rodada ESP-004 ([#127](https://github.com/ModernDelphiWorks/Janus/issues/127))

## [v2.19.13](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.19.13) — 2026-04-10

### Fixed
- Correcao do bloqueio de release no gate de develop ao reconciliar o diff tracked preexistente do roadmap, restabelecendo o fluxo deterministico sem alterar runtime/produto ([#122](https://github.com/ModernDelphiWorks/Janus/issues/122))
- Fechamento do gap de confiabilidade na evidencia smoke para Strategy A com semantica de geracao XML deterministica, reduzindo variabilidade ambiental na coleta de provas ([#118](https://github.com/ModernDelphiWorks/Janus/issues/118))

## [v2.19.11](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.19.11) — 2026-04-08

### Changed
- Normalizacao editorial no `ROADMAP.md` para explicitar a origem textual de R18.1 (de "proxiam demanda" para "proxima demanda") sem alterar classificacao ESP-002, escopo funcional ou handoff planejado ([#113](https://github.com/ModernDelphiWorks/Janus/issues/113))

## [v2.19.10](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.19.10) — 2026-04-08

### Changed
- Consolidacao editorial do milestone R18.1 no `ROADMAP.md`, unificando o texto em um item unico com origem "proxiam demanda", classificacao ESP-002 (feature), escopo fechado e handoff pronto para `/task` ([#110](https://github.com/ModernDelphiWorks/Janus/issues/110))

## [v2.19.9](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.19.9) — 2026-04-08

### Changed
- Atualizacao estrategica do `ROADMAP.md` para registrar a formalizacao da demanda candidata R18.1 (ESP-002) com escopo fechado para handoff via `/task` ([#110](https://github.com/ModernDelphiWorks/Janus/issues/110))

## [v2.19.8](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.19.8) — 2026-04-08

### Changed
- Formalizacao da demanda R18.1 (ESP-002) como feature com escopo funcional fechado, criterios de aceite auditaveis e handoff pronto para `/task`, com item de milestone registrado no `ROADMAP.md` ([#108](https://github.com/ModernDelphiWorks/Janus/issues/108))

## [v2.19.7](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.19.7) — 2026-04-08

### Changed
- Formalizacao da regra canonica de validacao processual para `/test` e `/release`, com decisao objetiva entre Path A (comando obrigatorio quando executavel) e Path B (N/A formal sob contrato de evidencia), reforcando auditabilidade da pipeline sem alteracao funcional do framework ([#107](https://github.com/ModernDelphiWorks/Janus/issues/107))

## [v2.19.6](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.19.6) — 2026-04-08

### Changed
- Encerramento operacional da validacao ESP-006 com confirmacao de build/smoke (155/155), fechamento da issue de divida tecnica anterior e consolidacao do status de release com caveat ambiental residual no caminho MARS ([#101](https://github.com/ModernDelphiWorks/Janus/issues/101))

## [v2.19.5](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.19.5) — 2026-04-08

### Changed
- Refactor do runtime MARS para padronizar a serializacao JSON via fachada `Janus.Json`, removendo o acoplamento direto a helpers JSON legados no caminho REST ativo sem alterar contrato HTTP/assinaturas publicas ([#99](https://github.com/ModernDelphiWorks/Janus/issues/99))

## [v2.19.4](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.19.4) — 2026-04-08

### Changed
- Refactor documental do `ROADMAP.md` para restaurar seu papel de artefato estrategico, removendo checklist operacional, status por issue e evidencias de pipeline do corpo principal, com destino explicito para historico e rastreabilidade ([#97](https://github.com/ModernDelphiWorks/Janus/issues/97))

## [v2.19.3](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.19.3) — 2026-04-08

### Changed
- Consolidacao operacional da R17.3 com atualizacao do `ROADMAP.md` e formalizacao do gate go/no-go para continuidade de R18.x sem introduzir mudancas arquiteturais ([#95](https://github.com/ModernDelphiWorks/Janus/issues/95))
- Documentacao tecnica de lazy loading atualizada para refletir o comportamento consolidado de reset/reload de proxies e tratamento de entidades anotadas com `[View]` apos v2.19.2 ([#95](https://github.com/ModernDelphiWorks/Janus/issues/95))

## [v2.19.2](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.19.2) — 2026-04-07

### Fixed
- Correcao das 3 falhas funcionais remanescentes da suite JanusSmoke (`TestProxy_ResetProducesNewLoad`, `TestHelperGetTable_ReturnsNilForViewEntity`, `TestProxy_ResetAllowsReload`) com evidencia de 155/155 testes aprovados ([#90](https://github.com/ModernDelphiWorks/Janus/issues/90))
- Fechamento tecnico da divida de estabilizacao pos-release registrada anteriormente, com rastreabilidade consolidada na rodada de correcao ([#89](https://github.com/ModernDelphiWorks/Janus/issues/89))

## [v2.19.1](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.19.1) — 2026-04-07

### Changed
- Hardening interno do lazy transparente: `TSQLCommandExecutor` e `TRESTObjectManager` passaram a reutilizar helpers compartilhados em `Janus.Mapping.Lazy`, eliminando a duplicacao operacional de `_InjectLazyFactory` sem alterar o contrato publico de `LoadLazy` e do proxy transparente ([#84](https://github.com/ModernDelphiWorks/Janus/issues/84))
- Rastreabilidade da R17.2 alinhada no `ROADMAP.md` e em `docs-src/docs/janus/`, deixando explicito que o ciclo atual endurece a implementacao da `v2.19.0` sem reabrir a API publicada ([#84](https://github.com/ModernDelphiWorks/Janus/issues/84))

### Fixed
- Desbloqueio dos gates finais de compilacao da release com resolucao dos erros `E2003 Undeclared identifier: 'Supports'` em `TestSmokeLazyLoading.pas` e `F2613 Unit 'SysUtils' not found` no fluxo `JanusSmoke` ([#88](https://github.com/ModernDelphiWorks/Janus/issues/88))

## [v2.19.0](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.19.0) — 2026-04-07

### Added
- `TestSmokeLazyLoading` (10 testes): baseline de seguranca R17.1 — valida existencia de lazy mapping, ciclo de vida do token, invocacao explicita de proxy e retrocompatibilidade do caminho explicito `LoadLazy` ([#81](https://github.com/ModernDelphiWorks/Janus/issues/81))
- `TestDataSetLazyProxy` (8 testes): contrato de lazy proxy para contexto DataSet — PK-change reset, deferred load, cache por acesso e idempotencia de re-injecao ([#81](https://github.com/ModernDelphiWorks/Janus/issues/81))
- `TestRestLazyProxy` (7 testes): contrato de lazy proxy para contexto REST — detectabilidade de associacoes lazy, ciclo de vida de token, idempotencia de reset ([#81](https://github.com/ModernDelphiWorks/Janus/issues/81))
- `TestLazyProxyMultiplicity` (9 testes): validacao de multiplicidades (OneToOne, OneToMany, ManyToOne, ManyToMany) nos tres contextos suportados, com retrocompatibilidade de `LoadLazy` explicito ([#81](https://github.com/ModernDelphiWorks/Janus/issues/81))
- `InjectLazyFactories` e `_InjectLazyFactory` adicionados a `TRESTObjectManager`: o contexto REST agora injeta proxy factory para associacoes lazy em `FillAssociation` em vez de pular (mesma semantica do ObjectSet) ([#81](https://github.com/ModernDelphiWorks/Janus/issues/81))
- `FLazyToken` e `FProcessingObjects` adicionados a `TRESTObjectManager` para gerenciar ciclo de vida correto do proxy REST e evitar loops recursivos ([#81](https://github.com/ModernDelphiWorks/Janus/issues/81))

### Changed
- `FillAssociation` em `TRESTObjectManager`: associacoes com `Lazy = True` agora chamam `_InjectLazyFactory` em vez de `Continue`, unificando o contrato lazy nos tres contextos (ObjectSet, DataSet, REST) ([#81](https://github.com/ModernDelphiWorks/Janus/issues/81))
- `JanusSmoke.dpr` ampliado com 4 novos modulos de teste: `TestSmokeLazyLoading`, `TestDataSetLazyProxy`, `TestRestLazyProxy`, `TestLazyProxyMultiplicity` ([#81](https://github.com/ModernDelphiWorks/Janus/issues/81))

## [v2.18.17](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.18.17) — 2026-04-07

### Changed
- Publicacao da demanda candidata R17.2 (pos-R17.1) no `ROADMAP.md`, com foco em hardening e adocao do lazy loading transparente, mantendo rastreabilidade e criterios auditaveis para abertura via `/task` ([#79](https://github.com/ModernDelphiWorks/Janus/issues/79))

## [v2.18.16](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.18.16) — 2026-04-07

### Added
- Cobertura de regressao para classe anotada apenas com `[View]` sem `[Table]`: testes `TestHelperGetTable_ReturnsNilForViewEntity` e `TestGetMappingView_ReturnsViewMappingForViewEntity` em `TestMappingCache.pas` ([#78](https://github.com/ModernDelphiWorks/Janus/issues/78))

### Changed
- `ROADMAP.md` normalizado pos-R16.3: tres itens de R16.3 marcados como completos e item de reavalicao resolvido com decisao go para R17.x ([#78](https://github.com/ModernDelphiWorks/Janus/issues/78))

## [v2.18.15](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.18.15) — 2026-04-07

### Added
- Cobertura de regressao para entidade anotada apenas com `[View]`, incluindo cenarios em `GetTable` e `GetMappingView` no `TestMappingCache.pas` ([#75](https://github.com/ModernDelphiWorks/Janus/issues/75))

### Changed
- `ROADMAP.md` normalizado para refletir o estado consolidado pos-R16.3 e registrar a decisao de continuidade do ciclo ([#75](https://github.com/ModernDelphiWorks/Janus/issues/75))

## [v2.18.14](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.18.14) — 2026-04-07

### Changed
- Refatoração interna do caminho RTTI/cache: `TObjectHelper` (`GetTable`, `GetSequence`, `GetNotServerUse`) passou a consumir `TMappingExplorer` com reaproveitamento de cache, mantendo API pública e itens fora de escopo inalterados ([#74](https://github.com/ModernDelphiWorks/Janus/issues/74))

## [v2.18.13](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.18.13) — 2026-04-07

### Changed
- Registro da decisao pos-R16.2 em R16.1 com gate explicito: go abre R16.3 via `/task`; no-go encerra oficialmente o ciclo ([#71](https://github.com/ModernDelphiWorks/Janus/issues/71))

## [v2.18.12](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.18.12) — 2026-04-07

### Changed
- Publicacao da demanda candidata R16.2 reforcada em R16.1 com alinhamento entre `esp.md`, `adr.md`, `plan.md` e `task-input.md` como fonte unica da verdade para abertura imediata via `/task` ([#69](https://github.com/ModernDelphiWorks/Janus/issues/69))

## [v2.18.11](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.18.11) — 2026-04-07

### Changed
- Confirmacao operacional da R16.2 como proxima demanda oficial no `ROADMAP.md`, com handoff final registrado para abertura imediata via `/task` ([#67](https://github.com/ModernDelphiWorks/Janus/issues/67))

## [v2.18.10](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.18.10) — 2026-04-07

### Added
- Publicacao da demanda candidata R16.2 no roadmap com objetivo, escopo e criterios de aceite fechados para abertura imediata via `/task` ([#65](https://github.com/ModernDelphiWorks/Janus/issues/65))

## [v2.18.9](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.18.9) — 2026-04-07

### Added
- Gate decisorio go/no-go formalizado na fase R16.1 para decidir continuidade ou encerramento do ciclo de forma rastreavel ([#63](https://github.com/ModernDelphiWorks/Janus/issues/63))

## [v2.18.8](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.18.8) — 2026-04-07

### Added
- Formalização da demanda R16.1 com classificação ESP-002, especificação arquitetural e critérios de aceite auditáveis para pipeline ([#61](https://github.com/ModernDelphiWorks/Janus/issues/61))

## [v2.18.7](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.18.7) — 2026-04-07

### Fixed
- Saneamento operacional de contaminacao de branch/worktree para reexecucao limpa de review, com isolamento nao destrutivo de alteracoes externas e trilha de evidencias do pipeline ([#59](https://github.com/ModernDelphiWorks/Janus/issues/59)).

## [v2.18.6](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.18.6) — 2026-04-06

### Changed
- Conclusão da R15.6 com remoção definitiva do legado `Source/Criteria/*.pas` e hardening do caminho oficial FluentSQL, incluindo atualização dos consumidores e documentação ativa ([#53](https://github.com/ModernDelphiWorks/Janus/issues/53)).

### Fixed
- Desbloqueio da regressão crítica do runner `Test/Delphi/JanusSmoke.dpr`, com compilação validada sem erros fatais e execução smoke com 112/112 testes aprovados ([#55](https://github.com/ModernDelphiWorks/Janus/issues/55)).

## [v2.18.5](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.18.5) — 2026-04-06

### Changed
- Correção da documentação pós-migração para API tipada atual (`Janus.Query.ResultSet`, `IJanusQueryResultSet`, `IJanusQueryObject<M>`, `TJanusQueryObject<M>.New` e `TCQ()`), removendo referências legadas no portal Docusaurus ([#50](https://github.com/ModernDelphiWorks/Janus/issues/50))
- Registro formal no implement-report da validação de contrato de `Janus.Query.ResultSet.pas`, auditoria do DLL Bridge e catalogação dos 4 arquivos `Source/Criteria/` como código morto candidato à remoção em R15.6 ([#50](https://github.com/ModernDelphiWorks/Janus/issues/50))

## [v2.18.4](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.18.4) — 2026-04-06

### Changed
- Limpeza final de vestígios de nomenclatura/caminhos Criteria em exemplos Delphi ativos, concluindo a fatia R15.5 da migração para FluentSQL ([#46](https://github.com/ModernDelphiWorks/Janus/issues/46))
- Relatório de implementação da issue #46 normalizado para refletir evidências finais e caveats de forma consistente ([#46](https://github.com/ModernDelphiWorks/Janus/issues/46))

## [v2.18.3](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.18.3) — 2026-04-06

### Added
- Cobertura DUnitX ampliada no caminho runtime DataSet/Command/Generator com novos cenários em `TestDMLGenerator.pas` e baseline de drivers em `TestFluentSQLIntegration.pas` ([#44](https://github.com/ModernDelphiWorks/Janus/issues/44))

### Fixed
- Formalização da evidência de placeholders `:campo` sem aspas em cenários multi-coluna/multi-campo, consolidando o encerramento técnico da dívida da issue #43 no contexto da R15.3 ([#44](https://github.com/ModernDelphiWorks/Janus/issues/44))

## [v2.18.2](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.18.2) — 2026-04-05

### Fixed
- Core DML: correção de regressão para preservar placeholders de bind sem aspas em INSERT/UPDATE no gerador SQL FluentSQL ([#42](https://github.com/ModernDelphiWorks/Janus/issues/42))

## [v2.18.1](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.18.1) — 2026-04-05

### Changed
- `ROADMAP.md` atualizado com o programa de migração Criteria -> FluentSQL em 6 fatias (R15.1..R15.6), com escopo e metas por etapa ([#40](https://github.com/ModernDelphiWorks/Janus/issues/40))

## [v2.18.0](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.18.0) — 2026-04-05

### Added
- **37 novos testes DUnitX** — Expansão massiva da cobertura de testes automatizados ([#35](https://github.com/ModernDelphiWorks/Janus/issues/35))
  - `TestCriteriaAdvanced.pas` — 11 testes para Criteria API avançada (AND/OR, LIKE, IN, BETWEEN, OrderBy multi-campo, GroupBy, IS NULL)
  - `TestCrudEndToEnd.pas` — 8 testes para fluxos CRUD end-to-end via mocks
  - `TestPluginIntegration.pas` — 6 testes para Plugin System em cenário de integração
  - `TestCodeGenComplex.pas` — 6 testes para CodeGen com schemas complexos (FKs compostas, múltiplos indexes/checks)
  - `TestMiddlewarePipeline.pas` — 6 testes para middleware pipeline Before/After (Update, Delete, chain order)
- **CI Pipeline** — `.github/workflows/tests.yml` com self-hosted runner placeholder para execução automatizada ([#35](https://github.com/ModernDelphiWorks/Janus/issues/35))
- Total de testes: **131** (103 DUnitX + 28 FPCUnit) ([#35](https://github.com/ModernDelphiWorks/Janus/issues/35))

### Changed
- `JanusSmoke.dpr` — 5 novas units de teste registradas na cláusula uses ([#35](https://github.com/ModernDelphiWorks/Janus/issues/35))
- `ROADMAP.md` — SPRINT-14 marcado como concluído ([#35](https://github.com/ModernDelphiWorks/Janus/issues/35))

## [v2.17.0](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.17.0) — 2026-04-05

### Added
- **CodeGen: Indexe/Check attributes** — Geração automática de atributos `[Indexe(...)]` e `[Check(...)]` no CodeGen Engine a partir de metadados do banco de dados ([#33](https://github.com/ModernDelphiWorks/Janus/issues/33))
- `TIndexInfo` e `TCheckInfo` — Novos records em `Janus.CodeGen.Types.pas` para representar índices e check constraints ([#33](https://github.com/ModernDelphiWorks/Janus/issues/33))
- `GetIndexes` e `GetChecks` — Novos métodos em `IJanusSchemaReader` com implementação FireDAC via `TFDMetaInfoQuery` ([#33](https://github.com/ModernDelphiWorks/Janus/issues/33))
- `_BuildIndexAttributes` e `_BuildCheckAttributes` — Builders no `TJanusCodeGenEngine` para geração de atributos a partir de dados reais ([#33](https://github.com/ModernDelphiWorks/Janus/issues/33))
- **6 testes DUnitX** — Cobertura de cenários: sem índices, índice simples, composto, unique, check constraint, combinações múltiplas ([#33](https://github.com/ModernDelphiWorks/Janus/issues/33))

### Changed
- `GenerateUnit` agora substitui placeholders `{{IndexAttributes}}` e `{{CheckAttributes}}` com dados reais do schema reader ([#33](https://github.com/ModernDelphiWorks/Janus/issues/33))
- Índices de PK são filtrados automaticamente para não gerar `[Indexe]` redundante ([#33](https://github.com/ModernDelphiWorks/Janus/issues/33))

## [v2.16.0](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.16.0) — 2026-04-05

### Added
- **README bilíngue** — `README.en.md` com tradução completa e feature matrix; link para versão EN adicionado ao `README.md` ([#31](https://github.com/ModernDelphiWorks/Janus/issues/31))
- **Guia Getting Started** — `Doc/GETTING-STARTED.md` com tutorial "Do zero ao primeiro CRUD" ([#31](https://github.com/ModernDelphiWorks/Janus/issues/31))
- **Guia de Arquitetura** — `Doc/ARCHITECTURE.md` com camadas do framework e referências a units reais ([#31](https://github.com/ModernDelphiWorks/Janus/issues/31))
- **Guia de Migração** — `Doc/MIGRATION-ORMBR.md` com mapeamento de renomeações ORMBr → Janus ([#31](https://github.com/ModernDelphiWorks/Janus/issues/31))
- **Tutorial Plugin System** — `Doc/PLUGINS.md` com tutorial hands-on de IJanusPlugin e TPluginRegistry ([#31](https://github.com/ModernDelphiWorks/Janus/issues/31))
- **Tutorial CodeGen** — `Doc/CODEGEN.md` com tutorial hands-on do CodeGen Engine e IDE Wizard ([#31](https://github.com/ModernDelphiWorks/Janus/issues/31))
- **Help Online** — 4 novos artigos HTML: LazyLoading, PluginSystem, CodeGenWizard, RecursosAvancados ([#31](https://github.com/ModernDelphiWorks/Janus/issues/31))
- **Keywords** — `_keywords.json` populado com 49 keywords para busca no Help Online ([#31](https://github.com/ModernDelphiWorks/Janus/issues/31))

### Changed
- `README.md` — reestruturado com feature matrix e simplificação de conteúdo ([#31](https://github.com/ModernDelphiWorks/Janus/issues/31))
- `ROADMAP.md` — SPRINT-13 marcado como concluído, SPRINT-14 adicionado ([#31](https://github.com/ModernDelphiWorks/Janus/issues/31))
- `_toc.json` — 4 novas entradas de navegação para artigos avançados ([#31](https://github.com/ModernDelphiWorks/Janus/issues/31))

## [v2.15.0](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.15.0) — 2026-04-05

### Added
- **CodeGen Library** — 5 novas units em `Source/CodeGen/` para geração de modelos Delphi a partir de schema de banco ([#29](https://github.com/ModernDelphiWorks/Janus/issues/29))
- `IJanusSchemaReader` — Interface de leitura de schema com implementação FireDAC `TFireDACSchemaReader` ([#29](https://github.com/ModernDelphiWorks/Janus/issues/29))
- `TJanusCodeGenEngine` — Motor de geração que consome schema reader + options e produz units completas com atributos, FK, nullable, lazy ([#29](https://github.com/ModernDelphiWorks/Janus/issues/29))
- `TJanusCodeTemplate` — Sistema de templates com placeholders `{{...}}` e template padrão de unit ([#29](https://github.com/ModernDelphiWorks/Janus/issues/29))
- `TJanusCodeGenOptions` — Opções de geração com persistência INI ([#29](https://github.com/ModernDelphiWorks/Janus/issues/29))
- **IDE Wizard** — `JanusWizard.dpk` com `TJanusModelWizard` (IOTAWizard + IOTAMenuWizard) e wizard de 4 páginas ([#29](https://github.com/ModernDelphiWorks/Janus/issues/29))
- 21 novos testes DUnitX em `TestCodeGenEngine` e `TestCodeGenTemplate` (total 60 testes) ([#29](https://github.com/ModernDelphiWorks/Janus/issues/29))

### Changed
- `Frm_Principal.pas` (standalone generator) refatorado para consumir `Janus.CodeGen.*` em vez de lógica inline — preview ao clicar tabela ([#29](https://github.com/ModernDelphiWorks/Janus/issues/29))
- `JanusGeneratorModel.dpr` atualizado com referências aos 5 CodeGen units ([#29](https://github.com/ModernDelphiWorks/Janus/issues/29))
- `Connection.xml` — todas as referências ORMBr substituídas por Janus ([#29](https://github.com/ModernDelphiWorks/Janus/issues/29))
- `Janus.Reg.pas` — cabeçalho de licença atualizado de "ORM Brasil" para "Janus Framework" ([#29](https://github.com/ModernDelphiWorks/Janus/issues/29))

## [v2.14.0](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.14.0) — 2026-04-04

### Added
- `IJanusPlugin` + `IJanusPluginInfo` — contrato formal de plugin com lifecycle (`Init`, `Finalize`, `GetPluginInfo`, `Enabled`) ([#27](https://github.com/ModernDelphiWorks/Janus/issues/27))
- `IJanusHookContext` + `TJanusHookContext` — contexto rico para hooks de persistência (operação, classe, entidade, abort flag, metadata bag) ([#27](https://github.com/ModernDelphiWorks/Janus/issues/27))
- `TPluginRegistry` — registro central de plugins com `Register`/`Unregister`/`Enable`/`Disable` ([#27](https://github.com/ModernDelphiWorks/Janus/issues/27))
- `EJanusPluginException` — exceção dedicada para erros do sistema de plugins ([#27](https://github.com/ModernDelphiWorks/Janus/issues/27))
- Overloads com `TProc<IJanusHookContext>` e prioridade em todos os 6 middlewares de evento ([#27](https://github.com/ModernDelphiWorks/Janus/issues/27))
- Custom Events: `RegisterCustomEvent` / `ExecuteCustomEvent` com proteção contra nomes reservados ([#27](https://github.com/ModernDelphiWorks/Janus/issues/27))
- Abort/Cancel em hooks Before*: `IJanusHookContext.Abort` impede a operação; em After* lança `EJanusPluginException` ([#27](https://github.com/ModernDelphiWorks/Janus/issues/27))
- `onCustom` adicionado ao enum `TJanusEventType` para suporte a custom events ([#27](https://github.com/ModernDelphiWorks/Janus/issues/27))
- 10 novos testes DUnitX em `TestPluginRegistry` (total 39 testes) ([#27](https://github.com/ModernDelphiWorks/Janus/issues/27))

### Changed
- `TSessionAbstract<M>.Insert`/`Update`/`Delete` agora criam `IJanusHookContext` e executam hooks Before*/After* com contexto e abort ([#27](https://github.com/ModernDelphiWorks/Janus/issues/27))
- Assinaturas legadas (`TProc<TObject>`) marcadas como `deprecated` nos 6 middlewares de evento ([#27](https://github.com/ModernDelphiWorks/Janus/issues/27))

## [v2.13.0](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.13.0) — 2026-04-04

### Added
- Lazy loading transparente no contexto DataSet: scroll pelo dataset pai injeta proxies automaticamente sem `LoadLazy` explícito ([#25](https://github.com/ModernDelphiWorks/Janus/issues/25))
- `OpenDataSetChilds` seletivo: filhos com `Association.Lazy=True` não são abertos eagerly no scroll ([#25](https://github.com/ModernDelphiWorks/Janus/issues/25))
- PK tracking (`FLastPKValue`) e guard (`FProxiesInjectedForCurrentRow`) no `TDataSetBaseAdapter<M>` ([#25](https://github.com/ModernDelphiWorks/Janus/issues/25))
- Método `_InjectLazyProxiesOnScroll` chamado no `DoAfterScroll` ([#25](https://github.com/ModernDelphiWorks/Janus/issues/25))
- Método `_GetCurrentPKAsString` para PK simples e composta ([#25](https://github.com/ModernDelphiWorks/Janus/issues/25))
- Guard em `Current()` contra dupla injeção de proxies ([#25](https://github.com/ModernDelphiWorks/Janus/issues/25))
- 6 novos testes DUnitX em `TestDataSetAutoLazy` (total 29 testes) ([#25](https://github.com/ModernDelphiWorks/Janus/issues/25))

### Changed
- `PLAN_LOAD_LAZY.md`: FASE 3 (DataSet Auto-Lazy on Scroll) marcada como concluída ([#25](https://github.com/ModernDelphiWorks/Janus/issues/25))

## [v2.12.1](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.12.1) — 2026-04-04

### Added
- `ILazySessionToken` + `TLazySessionToken` + `ELazyLoadException` para proxy lifetime safety ([#22](https://github.com/ModernDelphiWorks/Janus/issues/22))
- `ILazyProxyResettable.Reset` para reutilizar proxies em scrolls repetidos sem novas alocações ([#22](https://github.com/ModernDelphiWorks/Janus/issues/22))
- `FillAssociation` recursivo nas closures do proxy lazy (sub-associações do child populadas automaticamente) ([#22](https://github.com/ModernDelphiWorks/Janus/issues/22))
- Guard contra recursão infinita via `TList<Pointer>` de objetos já processados ([#22](https://github.com/ModernDelphiWorks/Janus/issues/22))
- `TQueryCache.Clear` com contrato de crescimento bounded documentado ([#22](https://github.com/ModernDelphiWorks/Janus/issues/22))
- 4 novos testes DUnitX: `TestLazyProxy_InvalidSession`, `TestLazyProxy_RecursiveFill`, `TestLazyProxy_SkipReinjection`, `TestQueryCache_Clear` ([#22](https://github.com/ModernDelphiWorks/Janus/issues/22))

### Fixed
- Proxy lazy agora lança `ELazyLoadException` quando session é destruída antes da invocação (em vez de Access Violation) ([#22](https://github.com/ModernDelphiWorks/Janus/issues/22))

### Changed
- `boss.json`: removidas 4 dependências mortas (`hashload/*` → 404) ([#22](https://github.com/ModernDelphiWorks/Janus/issues/22))

## [v2.12.0](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.12.0) — 2026-04-04

### Added
- Proxy transparente para lazy loading: acessar `Owner.Child` dispara SQL automaticamente sem `LoadLazy<T>` explícito ([#20](https://github.com/ModernDelphiWorks/Janus/issues/20))
- `TLazyMappingExplorer` — cache singleton de campos lazy por classe, evitando re-iteração RTTI ([#20](https://github.com/ModernDelphiWorks/Janus/issues/20))
- `_InjectLazyFactory` no executor: injeta closures com contexto de banco em fields `Lazy<T>` ([#20](https://github.com/ModernDelphiWorks/Janus/issues/20))
- `InjectLazyProxies` / `InjectLazyFactories` para contexto DataSet ([#20](https://github.com/ModernDelphiWorks/Janus/issues/20))
- Overload `GetDictionary(ADictionary)` para pré-extração em loop único ([#20](https://github.com/ModernDelphiWorks/Janus/issues/20))
- 8 novos testes DUnitX: `TestLazyMapping`(4), `TestLazyProxy`(3), `TestGetDictionary`(1) ([#20](https://github.com/ModernDelphiWorks/Janus/issues/20))

### Changed
- `FillAssociation` agora injeta factory proxy em vez de `Continue` para campos lazy ([#20](https://github.com/ModernDelphiWorks/Janus/issues/20))
- `FillAssociationLazy` consulta `TLazyMappingExplorer` (cache) em vez de iterar atributos ([#20](https://github.com/ModernDelphiWorks/Janus/issues/20))
- `PopularColumn()` e `PopularCalcField()` pré-extraem Dictionary no loop principal, sem re-iteração ([#20](https://github.com/ModernDelphiWorks/Janus/issues/20))

### Removed
- Código comentado de `FLazyLoadMapping` no `MetaDbDiff.Mapping.Explorer.pas` ([#20](https://github.com/ModernDelphiWorks/Janus/issues/20))

## [v2.11.0](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.11.0) — 2026-04-04

### Added
- Projeto DUnitX com 11 smoke tests em `Test/Delphi/` ([#18](https://github.com/ModernDelphiWorks/Janus/issues/18))
  - `TestMappingCache`: 4 testes TMappingExplorer (Table, Column, Association, PrimaryKey)
  - `TestRttiSingleton`: 2 testes TRttiSingleton (GetRttiType, singleton identity)
  - `TestLazyWrapper`: 2 testes Lazy\<T\> (factory implicit operator, default RTTI creation)
  - `TestNullable`: 3 testes Nullable\<T\> (HasValue, default, clear)

### Changed
- `Janus.Bind.pas`: removido `FContext: TRttiContext` duplicado de `TBind`, delegado a `RttiSingleton` ([#18](https://github.com/ModernDelphiWorks/Janus/issues/18))
- `Janus.Objects.Helper.pas`: 7 métodos refatorados para usar `RttiSingleton` em vez de `TRttiContext.Create` local ([#18](https://github.com/ModernDelphiWorks/Janus/issues/18))
  - `GetTable`, `GetSequence`, `GetResource`, `GetSubResource`, `GetNotServerUse`: usam `RttiSingleton.GetRttiType` diretamente
  - `&GetType`, `MethodCall`: eliminado `TRttiContext.Create` local

## [v2.10.0](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.10.0) — 2026-04-03

### Changed
- Reorganização de pastas: exemplos Delphi movidos para `Examples/Delphi/`, testes FPCUnit movidos para `Test/Lazarus/` ([#17](https://github.com/ModernDelphiWorks/Janus/issues/17))
- Separação de `Examples/` (demonstrações) e `Test/` (testes automatizados) por plataforma

### Added
- `CHANGELOG.md` com histórico completo de versões
- Placeholder `Test/Delphi/.gitkeep` para futuros testes DUnit/DUnitX
- Engine Zeos migrada para `Test/Lazarus/Engines/Zeos/`

## [v2.9.0](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.9.0) — 2026-04-03

### Added
- Bateria de testes FPCUnit para a DLL Bridge do Janus ([#16](https://github.com/ModernDelphiWorks/Janus/issues/16))
- Suites: Strategy1, Strategy2, Criteria, EdgeCases

## [v2.8.0](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.8.0) — 2026-04-03

### Added
- Paginação NextPacket e navegação sequencial (First/Next/Prior/Eof/CurrentRecord) para IJanusObjectSet DLL Bridge ([#15](https://github.com/ModernDelphiWorks/Janus/issues/15))

## [v2.7.0](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.7.0) — 2026-04-03

### Changed
- Refatoração dos exemplos Lazarus para usar a helper layer ([#14](https://github.com/ModernDelphiWorks/Janus/issues/14))
- Atualização do README.md

## [v2.6.0](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.6.0) — 2026-04-03

### Added
- TJanusRecordHelper, TJanusSetHelper, connection wrappers e factories para Lazarus/FPC ([#13](https://github.com/ModernDelphiWorks/Janus/issues/13))

## [v2.5.0](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.5.0) — 2026-04-03

### Added
- `Janus.Lazarus.Helper.pas` — string helper layer para Lazarus/FPC ([#12](https://github.com/ModernDelphiWorks/Janus/issues/12))

### Removed
- Executável legado `ORMBrDependencies.exe` e `RESTFulInstall.ini`

## [v2.4.0](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.4.0) — 2026-04-03

### Added
- Relacionamentos programáticos via DLL: FK, JoinColumn, Association ([#11](https://github.com/ModernDelphiWorks/Janus/issues/11))

## [v2.3.1](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.3.1) — 2026-04-03

### Fixed
- Resolução de erro E2010 e migração para API DataEngine v0.2.0 ([#10](https://github.com/ModernDelphiWorks/Janus/issues/10))

## [v2.3.0](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.3.0) — 2026-04-02

### Added
- Strategy 2: Mapeamento Programático via IJanusEntityBuilder ([#9](https://github.com/ModernDelphiWorks/Janus/issues/9))

## [v2.2.0](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.2.0) — 2026-04-02

### Added
- ConnectMSSQL, ConnectOracle e IJanusCriteria via DLL ([#8](https://github.com/ModernDelphiWorks/Janus/issues/8))

## [v2.1.0](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.1.0) — 2026-04-02

### Added
- Exposição do Janus ORM via DLL Windows com interfaces COM-compatíveis ([#7](https://github.com/ModernDelphiWorks/Janus/issues/7))

## [v2.0.1](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.0.1) — 2026-04-02

### Fixed
- Correções no JanusDependencies: double-backslash, HRESULT, try/except, ModalResult, ALog global, URL por tag e renomeação de recursos ([#6](https://github.com/ModernDelphiWorks/Janus/issues/6))

## [v2.0.0](https://github.com/ModernDelphiWorks/Janus/releases/tag/v2.0.0) — 2026-04-01

### Changed
- **Renomeação do framework**: ORMBr → Janus ([#5](https://github.com/ModernDelphiWorks/Janus/issues/5))
- Canonização de nomenclatura em todo o framework
- Bump de versão para 2.0.0 (breaking change por renomeação)

## Histórico pré-Janus (ORMBr)

> As versões abaixo referem-se ao projeto sob o nome original **ORMBr**, antes da renomeação para Janus.

### Destaques do legado ORMBr (pré-v2.0.0)

- **Middleware Horse**: integração com framework Horse para APIs REST
- **Middleware de eventos**: BeforeInsert, AfterInsert, BeforeUpdate, AfterUpdate, BeforeDelete, AfterDelete
- **Monitor de comandos**: callback no Factory do Connection para rastrear comandos e params
- **Cache de SQL**: correção de bug que impedia cache de comandos SQL gerados
- **ORMBr LiveBindings**: suporte a VCL e FMX com correções de AV
- **MongoDB**: driver de acesso via engine MongoWire
- **TManagerDataSet / TManagerObjectSet**: uso simplificado dos recursos do ORM
- **SubResource**: atributo para uso do REST API
- **NextPacket**: aprimoramento para atender OpenWhere() e FindWhere()
- **Metadata Compare**: comparação Model ↔ DB com geração de DDL
- **Suporte multi-banco**: Firebird, InterBase, SQLite, MySQL, PostgreSQL, MSSQL, Oracle, MongoDB, ADS, AbsoluteDB, ElevateDB, NexusDB
- **Gerador de Modelos**: contribuição da comunidade
- **Nullable/Blob/Lazy**: tipos avançados para mapeamento
