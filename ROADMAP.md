# Roadmap do Projeto Janus

Este arquivo registra apenas direcao estrategica, fase atual, milestones proximos e backlog resumido. Historico de release, status operacional por issue, evidencias de teste e reports da pipeline ficam fora deste artefato.

**Ultima atualizacao:** 2026-04-21

## Visao

Consolidar o Janus como ORM Delphi multi-contexto com evolucao previsivel do nucleo, documentacao coerente e abertura controlada de novos ciclos. O roadmap deve responder rapidamente onde o projeto esta, o que vem a seguir e quais frentes seguem candidatas para a proxima rodada.

## Estado estrategico atual

- Versao mais recente: v2.20.0 (released 2026-04-20).
- Fase atual: pos-release v2.20.0 — tres commits (#133, #134, #135) em develop pendentes de release v2.20.1.
- Leitura do ciclo: R19 entregue como v2.20.0 (#130); R19.1 fechado (#133); R19.2 fechado (#134, #135); artefatos de governanca sendo consolidados para gate do /release v2.20.1.

## Marcos recentes

- R15.x encerrou a transicao Criteria -> FluentSQL e a limpeza principal do legado associado.
- R16.x reorganizou backlog, governanca de pipeline e baseline de RTTI/cache para o ciclo seguinte.
- R17.x entregou o lazy loading transparente, executou hardening interno e fechou a consolidacao operacional pos-hotfix antes da abertura do proximo ciclo funcional.

## Ciclo atual

### R18.4 — XML evidence portability hardening (em execucao)

- Objetivo estrategico: fechar o caveat de portabilidade da evidencia XML herdado de #108, garantindo que o smoke lazy-loading produza evidencias deterministicas em ambientes relativos e com caminho explicito.
- Estado atual: issue #111 aberta e em implementacao.
- Demanda ativa: issue #111 (ESP-002, feature) — endurecer contrato de portabilidade XML, preconditions, fallback e rastreabilidade de evidencia.
- Proxima decisao: apos QA, avaliar expansao funcional do ciclo R18.x.

### R18.1 — Pacote minimo de smoke validation (em execucao)

- Objetivo estrategico: consolidar evidencia auditavel de comportamento do lazy loading transparente antes de abrir novo trabalho funcional.
- Estado atual: baseline minimo de smoke consolidado para ObjectSet + DataSet, com evidencias recentes em rodadas de QA e preparo da formalizacao R18.2 em andamento.
- Demanda ativa: issue #99 (especificacao), issue #101 (correcao de handoff) e issue #102 (execucao/QA), todas dentro do trilho ESP-002.
- Proxima decisao: abrir a rodada R18.2 via `/task` com escopo de confiabilidade ampliada e contrato de evidencia deterministico.

## Proximos milestones

1. Formalizar a primeira demanda de R18.x no pipeline antes de expandir o roadmap.
2. Preservar coerencia entre documentacao publica, changelog e baseline operacional consolidada do ciclo lazy.
3. Reavaliar o backlog candidato apenas quando houver aprovacao explicita de nova direcao estrategica.
4. Publicar a demanda candidata R18.1 (origem textual "proxiam demanda", normalizada como "proxima demanda"), mantendo classificacao ESP-002 (feature), escopo funcional fechado, criterios de aceite auditaveis e handoff pronto para `/task`.
5. Detalhar o recorte funcional executavel de R18.1 (modulo alvo, comportamento esperado e evidencia de validacao) antes de abrir nova issue de implementacao.
6. Recorte proposto para R18.1: pacote de smoke validation do lazy loading transparente (ObjectSet + DataSet), com cenarios minimos executaveis em `Test/Delphi/` e evidencia objetiva de execucao para gate de implementacao.
7. Demanda ativa da rodada atual: issue #99 (especificacao em arquiteto) + issue #102 (implementacao) - entregar o pacote minimo de smoke validation do lazy loading transparente, mantendo classificacao ESP-002, evidencia auditavel e handoff alinhado entre architect, task, implement, review e test.
8. Validar o pacote smoke via gates de review e test; consolidar evidencia de execucao nos artefatos de pipeline antes de abrir expansao funcional do ciclo R18.x.
9. Formalizar a proxima demanda R18.2 como ESP-002 (feature): ampliar baseline smoke de lazy loading transparente com criterios de evidencia deterministicos e rastreabilidade entre diff e reports.
10. Abrir a issue da rodada R18.2 via `/task` apos alinhamento de assumptions (ausencia de card em `Ready`) e manter o escopo restrito a confiabilidade (ObjectSet + DataSet) sem redesign arquitetural.
11. Formalizar a proxima demanda R18.3 como ESP-002 (feature): consolidar comando canonico do smoke lazy, pre-condicoes deterministicas para evidencias XML e matriz de rastreabilidade de cenarios para reduzir caveats recorrentes de QA.
12. Formalizar a proxima demanda R18.4 como ESP-002 (feature): endurecer portabilidade da evidencia XML (modo relativo e caminho explicito), com contrato deterministico de fallback e rastreabilidade obrigatoria entre comando, estrategia de caminho e artefato gerado.
13. Formalizar a proxima demanda R18.10 como ESP-002 (feature): estabelecer baseline deterministico de validacao pre-gate para freshness de evidencias e isolamento de escopo (diff in-scope vs out-of-scope) antes de `/review`, `/test` e `/develop`.
14. Formalizar a demanda de correcao R18.11 como ESP-003 (bug): reconciliar explicitamente o diff tracked pre-existente de `ROADMAP.md` para eliminar bloqueio recorrente em `/develop` (`NO_COMMITTABLE_FILES`) com evidencia objetiva de escopo.

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

*Ultima atualizacao: 2026-04-21 — R20 entregue como v2.20.1: RESTReadOnly method-level granularity ([RESTAllowGET/POST/PUT/DELETE]); todos os cinco itens marcados [x]; ciclo encerrado*

