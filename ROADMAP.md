# Roadmap do Projeto Janus

Este arquivo registra apenas direcao estrategica, fase atual, milestones proximos e backlog resumido. Historico de release, status operacional por issue, evidencias de teste e reports da pipeline ficam fora deste artefato.

**Ultima atualizacao:** 2026-04-28

## Visao

Consolidar o Janus como ORM Delphi multi-contexto com evolucao previsivel do nucleo, documentacao coerente e abertura controlada de novos ciclos. O roadmap deve responder rapidamente onde o projeto esta, o que vem a seguir e quais frentes seguem candidatas para a proxima rodada.

## Estado estrategico atual

- Versao mais recente: v2.22.0 (released 2026-04-26).
- Fase atual: pos-release v2.22.0 — develop e main alinhados via PR #166.
- Leitura do ciclo: rework de LiveBindings (R22.x) entregue end-to-end; engine legado fisicamente removido; documentacao e exemplos atualizados.

## Marcos recentes

- R15.x encerrou a transicao Criteria -> FluentSQL e a limpeza principal do legado associado.
- R16.x reorganizou backlog, governanca de pipeline e baseline de RTTI/cache para o ciclo seguinte.
- R17.x entregou o lazy loading transparente, executou hardening interno e fechou a consolidacao operacional pos-hotfix antes da abertura do proximo ciclo funcional.
- R18.x consolidou o lazy loading transparente e estabeleceu o protocolo de scope-isolation, baseline de smoke e governanca pre-gate da pipeline.
- R19/R20 endureceu a camada REST/Horse com OData tokenizado, atributo [RESTReadOnly] por classe e granularidade [RESTAllow*] por verbo HTTP.
- R22.x reescreveu o engine de LiveBindings em torno de TJanusBinder com adapters publicos Data.Bind.*, eliminando o engine legado de uma vez (R22.4b).
- R23/R24 entregaram o exemplo Oracle REST Horse e o registry de auto-view com lazy-init para [View].

## Ciclo atual

- Nenhuma rodada ativa apos v2.22.0.
- Develop e main alinhados via PR #166.
- Pipeline pronto para abrir nova frente assim que houver decisao estrategica do dono do projeto.

## Proximos milestones

- Lazarus parity para o novo engine de LiveBindings — reimplementacao das primitivas Data.Bind.* ou padroes fpcunit/Lazarus-native equivalentes (candidata — direção a confirmar).
- Auditoria dos demais wrappers DataEngine (Firebird, PostgreSQL, MySQL, MSSQL, etc.) para o mesmo bug de transaction lifecycle corrigido em DataEngine.DriverFireDac (candidata — direção a confirmar).
- Suporte a grids de terceiros para LiveBindings (DevExpress, TMS, cxGrid) preservando uso de APIs publicas de TCustomGrid (candidata — direção a confirmar).
- Port da camada REST/Horse para outros frameworks web (DMVC, MARS, WiRL, DataSnap) e Cliente REST (candidata — direção a confirmar).
- Documentacao: lint/link-check leve para docs-src/docs/janus/user/ antes de /review (candidata — direção a confirmar).

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

### R21 — pre-release v2.21.0 / v2.21.1 / v2.20.2 caveat closure (entregue)

- Objetivo estrategico: fechar tres rodadas de caveats acumulados desde v2.20.1 — bug do filtro/DELETE no REST/Horse, transaction lifecycle no DataEngine FireDAC, e parser OData (URL-decoding + literais com virgula + lookahead de operadores).
- Estado atual: entregue como v2.20.2 (2026-04-22).
- Demanda ativa: nenhuma — rodada encerrada.
- Itens da rodada:
  - [x] Fix: filter-based DELETE em REST/Horse — FindWhere em FilterExecuteFind — delivered #145 2026-04-21
  - [x] Fix: seed isolation em GET filter tests — Alice insertion inline antes de cada assert — delivered #145 2026-04-21
  - [x] Fix: DataEngine FireDAC LResultSet.Next em 8 sites de loop em RestObject.Manager.pas — delivered #147 2026-04-22
  - [x] Fix: OData parser TNetEncoding.URL.Decode + iteracao de AArgTokens + lookahead 2-char + dicionario O(1) — delivered #149 2026-04-22
- Proxima decisao: nenhuma — rodada encerrada.

### R22-STUDY — LiveBindings attribute engine rework (estudo entregue)

- Objetivo estrategico: aprovar a direcao arquitetural do novo engine de LiveBindings antes de iniciar implementacao — adapter-based sobre Data.Bind.*, DSL unificado [Bind]/[BindGrid]/[BindList]/[BindGridColumn], dual backend Object+DataSet, remocao do shadowing VCL/FMX, plano em sprints R22.1..R22.6.
- Estado atual: estudo entregue (2026-04-22) — 9 ADRs aprovados; zero modificacao em Source/.
- Demanda ativa: nenhuma — rodada encerrada.
- Itens da rodada:
  - [x] 9 ADRs aprovados cobrindo engine adapter-based, DSL unificado, dual backend, kernel publico Janus.OneToMany.pas, scope por form, Lazarus fora da engine nova — delivered 2026-04-22
  - [x] Plano de sprints R22.1..R22.6 publicado em ROADMAP.md — delivered 2026-04-22
- Proxima decisao: nenhuma — rodada encerrada.

### R22.1 — TJanusBinder engine + Bind attribute DSL (entregue como v2.21.0)

- Objetivo estrategico: introduzir engine adapter-based para LiveBindings sem heranca de TJanusLiveBindings, com DSL de atributos [Bind]/[BindGrid]/[BindGridDetail]/[BindListControl]/[BindGridColumn] e ciclo de vida Bind/Refresh/Free.
- Estado atual: entregue como v2.21.0 (2026-04-26).
- Demanda ativa: nenhuma — rodada encerrada.
- Itens da rodada:
  - [x] TJanusBinder + Janus.Binder.Resolver + Janus.Binder.Attributes — delivered #154 (60084fd) 2026-04-23
  - [x] Tests.Janus.LiveBindings.R221 fixture com controles simples — delivered #154 (60084fd) 2026-04-23
- Proxima decisao: nenhuma — rodada encerrada.

### R22.2 — BindGrid Object backend + master/detail/sub-detail (entregue como v2.21.0)

- Objetivo estrategico: estender TJanusBinder com BindGrid<TItem>, BindMasterDetail<TMaster,TDetail> e BindMasterDetailSubdetail<TMaster,TDetail,TSubdetail> sobre adapters Object via TListBindSourceAdapter<T>, com propagacao de scroll via eventos AfterScroll/BeforeScroll diretos.
- Estado atual: entregue como v2.21.0 (2026-04-26).
- Demanda ativa: nenhuma — rodada encerrada.
- Itens da rodada:
  - [x] BindGrid + BindMasterDetail + BindMasterDetailSubdetail (Object backend) — delivered #155 (f5f7049) 2026-04-24
  - [x] Tests.Janus.LiveBindings.R222 fixture (31 testes) — delivered #155 (f5f7049) 2026-04-24
- Proxima decisao: nenhuma — rodada encerrada.

### R22.5 — LiveBindings user manual rewrite + VCL example PODO migration (entregue como v2.21.0)

- Objetivo estrategico: reescrever docs-src/docs/janus/user/guides/livebindings.md em torno da nova API TJanusBinder; migrar exemplo VCL para PODO + [Bind]; anotar exemplo FMX com nota de migracao.
- Estado atual: entregue como v2.21.0 (2026-04-26).
- Demanda ativa: nenhuma — rodada encerrada.
- Itens da rodada:
  - [x] livebindings.md reescrito (lifecycle, atributos, samples [Bind]/BindGrid<T>/BindList<T>/[BindGridColumn], guia de migracao com horizonte R22.6) — delivered #161 (b7f46f5) 2026-04-26
  - [x] Exemplo VCL migrado de TJanusLiveBindings para PODO + TJanusBinder — delivered #161 (b7f46f5) 2026-04-26
  - [x] Exemplo FMX anotado com bloco de comentario migration-note — delivered #161 (b7f46f5) 2026-04-26
- Proxima decisao: nenhuma — rodada encerrada.

### R23 — Oracle REST Horse example (entregue como v2.21.0)

- Objetivo estrategico: publicar exemplo completo de servidor REST Horse contra Oracle XE 11g em Examples/Delphi/RESTful/Horse/Oracle/, incluindo TProviderJanus + TProviderDM, modelos com [Table]+[RESTReadOnly]+[RESTAllow*], CRUD endpoints e view modelpedidoscompletos.
- Estado atual: entregue como v2.21.0 (2026-04-26).
- Demanda ativa: nenhuma — rodada encerrada.
- Itens da rodada:
  - [x] JanusOracleRESTServer.dpr + 4 modelos + 3 unidades de provider + Postman collection — delivered #157 (a9304f1) 2026-04-24
- Proxima decisao: nenhuma — rodada encerrada.

### R24 — Oracle AutoView lazy-init registry (entregue como v2.21.0)

- Objetivo estrategico: introduzir TRESTViewManager.Register/EnsureViewLazy/ClearCache para criacao lazy de VIEW Oracle no primeiro acesso GET; ParseFind detecta [View] e dispara EnsureViewLazy; mutations bloqueiam [View] implicitamente.
- Estado atual: entregue como v2.21.0 (2026-04-26).
- Demanda ativa: nenhuma — rodada encerrada.
- Itens da rodada:
  - [x] TRESTViewManager lazy-init + ParseFind [View] detection + implicit read-only guard para rotas nao mapeadas — delivered #158 (3982516) 2026-04-24
  - [x] TestJanusRESTOracleAutoView fixture (4 testes) PASS contra Oracle XE 11g Docker — delivered #158 (3982516) 2026-04-24
- Proxima decisao: nenhuma — rodada encerrada.

### R22.3 — LiveBindings DataSet backend: TBindSourceDB + grid + master-detail (entregue como v2.22.0)

- Objetivo estrategico: estender `TJanusBinder` com backend DataSet para aplicacoes que ja usam `TContainerClientDataSet<T>`, `TContainerFDMemTable<T>` ou `TManagerDataSet`, permitindo wiring visual de grids sem a camada de adapter generica do R22.2.
- Estado atual: entregue como v2.22.0 — commit `62448c6` (#159) 2026-04-26.
- Demanda ativa: nenhuma — rodada encerrada.
- Itens da rodada:
  - [x] `TJanusBinder.BindDataSetGrid(ADataSet, AGridName)` — wiring via `TBindSourceDB` + `TLinkGridToDataSource` — delivered #159 (62448c6) 2026-04-26
  - [x] `TJanusBinder.BindDataSetMasterDetail(...)` — 2-level DataSet grid binding — delivered #159 (62448c6) 2026-04-26
  - [x] `TJanusBinder.BindDataSetMasterDetailSubdetail(...)` — 3-level DataSet grid binding — delivered #159 (62448c6) 2026-04-26
  - [x] `Tests.Janus.LiveBindings.R223.pas` — 8 testes headless via TFDMemTable — delivered #159 (62448c6) 2026-04-26
  - [x] `JanusLiveBindings.dpr` atualizado com fixture R223 — delivered #159 (62448c6) 2026-04-26
- Proxima decisao: nenhuma — rodada encerrada.

### R22.4 — LiveBindings: BindList + Column metadata (entregue como v2.22.0)

- Objetivo estrategico: fechar lacunas entre o novo `TJanusBinder` engine e os goals AC-5/AC-6/A-5 do analyst: habilitar list controls (TListBox/TComboBox/TListView) via `BindList<TItem>`; introduzir metadata de coluna opt-in (`[BindGridColumn]` attribute + `ConfigureGridColumns`).
- Estado atual: entregue como v2.22.0 — commits R22.4-Commit (374fd3a) #165 e R22.4b (f4f50b1) #164 em 2026-04-26.
- Demanda ativa: nenhuma — rodada encerrada.
- Itens da rodada:
  - [x] `[BindGridColumn]` attribute em `Janus.Binder.Attributes.pas` — delivered R22.4-Commit (374fd3a) #165 2026-04-26
  - [x] `TJanusBinder.BindList<TItem>` — wiring de list control via `TListBindSourceAdapter<T>` + `TAdapterBindSource` + `TLinkListControlToField` — delivered R22.4b (f4f50b1) 2026-04-26
  - [x] `TJanusBinder.ConfigureGridColumns(AGridName, AItemType)` — opt-in column metadata via RTTI — delivered R22.4b (f4f50b1) 2026-04-26
  - [x] `Tests.Janus.LiveBindings.R224.pas` — 10 testes headless — delivered R22.4-Commit (374fd3a) #165 2026-04-26
  - [x] `JanusLiveBindings.dpr` atualizado com fixture R224 — delivered R22.4-Commit (374fd3a) #165 2026-04-26

### R22.4b — LiveBindings: remocao fisica do engine legado (entregue como v2.22.0)

- Objetivo estrategico: eliminar todos os artefatos do engine legado de uma vez, sem periodo de deprecacao (engine nunca foi usado em producao). Colapsa R22.6 completamente.
- Estado atual: entregue como v2.22.0 — commit f4f50b1 (#164) 2026-04-26.
- Demanda ativa: nenhuma — rodada encerrada.
- Itens da rodada:
  - [x] Deletar `Source/Livebindings/Janus.LiveBindings.pas` (`git rm -f`) — delivered #164 (f4f50b1) 2026-04-26
  - [x] Deletar `Source/Livebindings/Janus.Controls.Helpers.pas` (`git rm -f`) — delivered #164 (f4f50b1) 2026-04-26
  - [x] Deletar `Source/Livebindings/Janus.VCL.Controls.pas` (`git rm`) — delivered #164 (f4f50b1) 2026-04-26
  - [x] Deletar `Source/Livebindings/Janus.FMX.Controls.pas` (`git rm`) — delivered #164 (f4f50b1) 2026-04-26
  - [x] Deletar `Examples/Delphi/Livebindings/FMX/Janus_LiveBindingsFMX.dpr`, `produto.pas`, `UPrincipal.pas` — delivered #164 (f4f50b1) 2026-04-26
  - [x] Renomear `FGridBindSources → FAdapterBindSources` em `Janus.Binder.pas` (R22.6 pull-forward) — delivered #164 (f4f50b1) 2026-04-26
  - [x] Remover secao "Migracao do engine legado" de `livebindings.md`; atualizar secao "FMX" — delivered #164 (f4f50b1) 2026-04-26
- Proxima decisao: nenhuma — rodada encerrada.

### Gap Fixtures Era — deferred candidates pos-audit roadmap (demanda 8/8)

Esta fase consolida pendências surgidas no roadmap auditado de 8 demandas (round 61..68). Itens listados como candidatas; nenhuma execução compromissada — owner aprova nova rodada via `/architect` opening protocol.

- DML-per-database fixtures (12 tests gap from §3.1) (candidata — direção a confirmar)
- Metadata Compare fixtures (candidata — direção a confirmar)
- Bind fixtures (candidata — direção a confirmar)
- Monitor fixtures (candidata — direção a confirmar)
- ObjectSet CRUD fixtures (candidata — direção a confirmar)
- QueryScope direct fixtures (candidata — direção a confirmar)
- Driver Register fixtures (candidata — direção a confirmar)
- Examples regrouping into `00.GettingStarted/01.Data/...` families (P3, ~1 day) (candidata — direção a confirmar)
- Console (#153) parked-binary disposition decision (candidata — direção a confirmar)
- 4 carry-forward compile failures (PJson, SQLite Native, MetaDbDiff VCL, Horse RESTFul-via-Driver Server) (candidata — direção a confirmar)
- JanusMetadata Firemonkey RC2135 missing icon (candidata — direção a confirmar)
- Rolling slot for any future audit-tracked drift surfaced before next wave opens (candidata — direção a confirmar)

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

*Ultima atualizacao: 2026-04-26 — Post-v2.22.0-Roadmap-Consolidation: refresh do estado estrategico, secoes entregue R21/R22-STUDY/R22.1/R22.2/R22.5/R23/R24 inseridas, Ciclo atual e Proximos milestones reset; develop e main alinhados via PR #166*

*Ultima atualizacao: 2026-04-28 — Gap-Fixtures-Era: audit roadmap (round 61..68) CLOSED; 12 deferred candidates listed; next wave opens in new /architect opening protocol when owner approves*

