# Roadmap do Projeto Janus

Este arquivo registra apenas direcao estrategica, fase atual, milestones proximos e backlog resumido. Historico de release, status operacional por issue, evidencias de teste e reports da pipeline ficam fora deste artefato.

**Ultima atualizacao:** 2026-04-22

## Visao

Consolidar o Janus como ORM Delphi multi-contexto com evolucao previsivel do nucleo, documentacao coerente e abertura controlada de novos ciclos. O roadmap deve responder rapidamente onde o projeto esta, o que vem a seguir e quais frentes seguem candidatas para a proxima rodada.

## Estado estrategico atual

- Versao mais recente: v2.20.2 (released 2026-04-22).
- Fase atual: pos-release v2.20.2 — R21 entregue (3 bugs OData parser + O(1) lookup + ESP-003 #145); candidato R22 (expansao multi-framework) ainda nao aberto.
- Leitura do ciclo: R21 corrigiu URL decode, virgula em literal, operadores multi-char no parser OData e migrou lookup para TDictionary O(1); divida tecnica residual aberta em #150 (_EmitOData double-space).

## Marcos recentes

- R15.x encerrou a transicao Criteria -> FluentSQL e a limpeza principal do legado associado.
- R16.x reorganizou backlog, governanca de pipeline e baseline de RTTI/cache para o ciclo seguinte.
- R17.x entregou o lazy loading transparente, executou hardening interno e fechou a consolidacao operacional pos-hotfix antes da abertura do proximo ciclo funcional.
- R19/R20 entregou RESTReadOnly por verbo, suite REST/Horse integrada e parser OData tokenizado.
- R21 corrigiu 3 bugs no parser OData, melhorou performance de lookup para O(1) e fechou ESP-003.

## Ciclo atual

### Aguardando abertura de R22

- Objetivo: expansao da suite de integracao REST para segundo framework web Delphi (DMVC, WiRL ou MARS).
- Estado: candidato nao formalizado — abrir via `/task` quando pronto para o proximo ciclo.
- Pre-requisito concluido: R21 entregue e base OData estabilizada.

## Proximos milestones

1. Normalizar espacamento em `_EmitOData` (#150, divida tecnica) — permite tightening das assertions CA-005/006/007 para `AreEqual`.
2. Expandir suite de integracao REST/Horse para outro framework web Delphi (DMVC, WiRL ou MARS) como candidato principal R22 — portar cenarios CRUD existentes como baseline de compatibilidade multi-framework.
3. Avaliar disponibilizacao do cliente REST (`Source/RESTful/Client/`) como demanda formal de ciclo futuro.
4. Avaliar reescrita completa do parser OData como biblioteca PEG/ANTLR (longo prazo — ADR-001 usa abordagem incremental; reescrita so se justifica se o OData virar pilar central do Janus).

### R19.1 — Post-release caveat closure for v2.20.0 — delivered 2026-04-20

- [x] Fix: `FluentSQL.Interfaces` duplicate removed from `implementation uses` in `RestView.Manager.pas` — delivered #133 2026-04-20
- [x] Fix: Docusaurus sidebar updated with `RESTful` category linking `odata-reference`, `rest-readonly`, `rest-join-strategy` — delivered #133 2026-04-20
- [x] Fix: `HorseJanus.dpr` extended with `[RESTReadOnly]` model + controller example — delivered #133 2026-04-20

### R19.2 — REST/Horse via Driver: suite de testes de integração (entregue)

- Objetivo estrategico: fechar lacuna de cobertura de testes — `TRESTServerHorse` com prefixo de URL (`'api/Janus'`) não tinha suite de testes dedicada.
- Estado atual: entregue — commits b70aecf (#134) e 61a02c7 (#135) em develop 2026-04-20.
- Demanda ativa: nenhuma — rodada encerrada.
- Itens da rodada:
  - [x] Estender `RestHorseTest.Base.pas` com campo `FPrefix` e método `BuildResourceURL` — delivered #134 2026-04-20
  - [x] Criar `TestJanusRESTHorseDriver.pas` — fixture com prefixo `api/Janus` e mínimo 8 testes CRUD — delivered #134 2026-04-20
  - [x] Atualizar `JanusRestHorse.dpr` com a nova unit de testes — delivered #134 2026-04-20
- Proxima decisao: apos QA, avaliar expansao de cobertura (outros frameworks via Driver: DMVC, MARS, WiRL).

### R19 — REST/Horse OData hardening, RESTReadOnly e JOIN via View (entregue como v2.20.0)

- Objetivo estrategico: consolidar a camada REST/Horse como base OData testada, com granularidade read-only por classe e alternativa explicita de JOIN via VIEW gerada por FluentSQL + DataEngine.
- Estado atual: entregue como v2.20.0 (#130) e complementos em develop (#133).
- Demanda ativa: nenhuma — rodada encerrada.
- Itens da rodada:
  - [x] Suite de testes unitarios do parser OData (`TestJanusRESTQueryParse.pas` ≥ 30 cenarios) — delivered #130 2026-04-20
  - [x] Suite de integracao CRUD Horse + SQLite (`TestJanusRESTHorseIntegration.pas` ≥ 12 cenarios) — delivered #130 2026-04-20
  - [x] Atributo `[RESTReadOnly]` com cache em `MetaDbDiff` e guard em `TAppResourceBase` — delivered #130 2026-04-20
  - [x] Parser OData tokenizado com operadores logicos (and/or/not) e funcoes (contains/startswith/endswith/tolower/toupper) — delivered #130 2026-04-20
  - [x] Validacao de `$expand` RTTI via teste master/detail — delivered #130 2026-04-20
  - [x] Utilitario `TRESTViewManager` para geracao/atualizacao de VIEW via FluentSQL DDL + DataEngine — delivered #130 2026-04-20
  - [x] Atualizacao do exemplo `Examples/Delphi/RESTful/Horse/` e documentacao em `docs-src/docs/janus/` — delivered #130 2026-04-20, complemento #133 2026-04-20
- Proxima decisao: apos QA, avaliar expansao para outros web frameworks (DMVC/MARS/WiRL/DataSnap) e Cliente REST.

### R20 — RESTReadOnly method-level granularity (entregue como v2.20.1)

- Objetivo estrategico: estender o controle de acesso REST de binario (tudo/somente-leitura) para por-verbo HTTP, habilitando casos como audit logs (POST permitido, PUT/DELETE bloqueados) e tabelas de referencia (GET+POST, sem UPDATE/DELETE).
- Estado atual: entregue como v2.20.1 — commits #137 em develop, incluídos no PR #139 2026-04-21.
- Demanda ativa: nenhuma — rodada encerrada.
- Itens da rodada:
  - [x] Definir atributos `[RESTAllowGET]`, `[RESTAllowPOST]`, `[RESTAllowPUT]`, `[RESTAllowDELETE]` em `MetaDbDiff.Mapping.Attributes` — delivered v2.20.1 2026-04-21
  - [x] Estender cache MetaDbDiff com conjunto de verbos permitidos por classe — delivered v2.20.1 2026-04-21
  - [x] Implementar guard de grant-list em `TAppResourceBase` (com precedencia de `[RESTReadOnly]`) — delivered v2.20.1 2026-04-21
  - [x] Testes unitarios de deteccao RTTI e testes de integracao via Horse (CA-001..CA-012) — delivered v2.20.1 2026-04-21
  - [x] Atualizar `rest-readonly.md` com novos atributos e tabela de comportamento combinado — delivered v2.20.1 2026-04-21

## Backlog resumido

- Evolucoes futuras de lazy loading permanecem como backlog exploratorio, com detalhamento tecnico fora deste roadmap.
- Melhorias de governanca ou arquitetura documental podem entrar neste arquivo apenas quando mudarem fase, prioridade ou direcao do programa.
- Estudos tecnicos ainda nao convertidos em demanda formal seguem como insumo de priorizacao, nao como execucao ativa.

## Destino do detalhe operacional

- Releases, hotfixes, versoes publicadas e historico entregue: `CHANGELOG.md`.
- Estudos, analises e racional tecnico que alimentam priorizacao: `DISCUSSIONS.md`.
- Backlog exploratorio detalhado da frente lazy: `PLAN_LOAD_LAZY.md`.
- Escopo operacional da rodada, status de gates, review, test e release reports: `.claude/pipeline/`.

## Referencias do ciclo

- [CHANGELOG.md](CHANGELOG.md)
- [DISCUSSIONS.md](DISCUSSIONS.md)
- [PLAN_LOAD_LAZY.md](PLAN_LOAD_LAZY.md)
- [.claude/pipeline/esp.md](.claude/pipeline/esp.md)
- [.claude/pipeline/plan.md](.claude/pipeline/plan.md)
- [.claude/pipeline/task.md](.claude/pipeline/task.md)
- [.claude/pipeline/review-report.md](.claude/pipeline/review-report.md)
- [.claude/pipeline/test-report.md](.claude/pipeline/test-report.md)
- [.claude/pipeline/release-report.md](.claude/pipeline/release-report.md)

## Regra de manutencao futura

1. Atualize este roadmap somente quando houver nova direcao estrategica, mudanca de fase, milestone aprovado ou decisao de continuidade/encerramento de ciclo.
2. Nao registre checklist operacional, status por issue, contagem de testes, hotfix detalhado, inventario de arquivos ou historico extensivo de execucao neste arquivo.
3. Registre entregas concluidas no changelog, analises em discussoes e execucao da rodada nos artefatos da pipeline.
4. Se a informacao nao altera prioridade, fase ou direcao do projeto, ela nao deve aumentar o roadmap.

*Ultima atualizacao: 2026-04-22 — R21 aberto: correcao de 3 bugs no parser OData + melhoria de lookup O(1); expansao multi-framework deslocada para R22; milestones reordenados.*

