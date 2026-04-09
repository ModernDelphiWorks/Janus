# Roadmap do Projeto Janus

Este arquivo registra apenas direcao estrategica, fase atual, milestones proximos e backlog resumido. Historico de release, status operacional por issue, evidencias de teste e reports da pipeline ficam fora deste artefato.

**Ultima atualizacao:** 2026-04-09

## Visao

Consolidar o Janus como ORM Delphi multi-contexto com evolucao previsivel do nucleo, documentacao coerente e abertura controlada de novos ciclos. O roadmap deve responder rapidamente onde o projeto esta, o que vem a seguir e quais frentes seguem candidatas para a proxima rodada.

## Estado estrategico atual

- Versao mais recente: v2.19.3.
- Fase atual: execucao de R18.1 — pacote minimo de smoke validation do lazy loading transparente.
- Leitura do ciclo: R17.x encerrado e consolidado; R18.1 em fechamento operacional (issues #99/#101/#102 em QA Testing) e preparacao da proxima demanda R18.2 para ampliar baseline de confiabilidade antes de expansao funcional ampla.

## Marcos recentes

- R15.x encerrou a transicao Criteria -> FluentSQL e a limpeza principal do legado associado.
- R16.x reorganizou backlog, governanca de pipeline e baseline de RTTI/cache para o ciclo seguinte.
- R17.x entregou o lazy loading transparente, executou hardening interno e fechou a consolidacao operacional pos-hotfix antes da abertura do proximo ciclo funcional.

## Ciclo atual

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

*Ultima atualizacao: 2026-04-09*

