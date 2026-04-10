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

## Release status (R18.1 formalized for handoff)

- Most recent published version: `v2.19.13`.
- Most recent published tag: `v2.19.13`.
- `v2.19.13` fixed a release-gate blockage by reconciling pre-existing tracked roadmap diff behavior, restoring deterministic release flow without changing runtime/product behavior (issue `#122`).
- `v2.19.13` closed a smoke-evidence reliability gap for Strategy A by formalizing deterministic XML generation semantics, reducing environment variance in evidence collection (issue `#118`).
- A issue `#81` entregou o lazy loading transparente com proxy unificado nos contextos ObjectSet, DataSet e REST, preservando o caminho explícito `LoadLazy`.
- A issue `#88` desbloqueou os gates finais de compilação da release, com correção para `E2003 Undeclared identifier: 'Supports'` no smoke test e `F2613 Unit 'SysUtils' not found` no fluxo `JanusSmoke`.
- A issue `#90` estabilizou os cenários funcionais remanescentes do lazy reset/reload e o contrato de entidade anotada com `[View]` sem `[Table]`.
- A issue `#95` consolidou a baseline operacional da R17.3, revalidou nominalmente os cenários críticos (`TestProxy_ResetProducesNewLoad`, `TestProxy_ResetAllowsReload`, `TestHelperGetTable_ReturnsNilForViewEntity`) e formalizou o gate go/no-go para continuidade da R18.x sem alterar o contrato público.
- A `v2.19.3` manteve o comportamento estabilizado em `v2.19.2` e registrou sua rastreabilidade operacional e documental.
- A `v2.19.4` publicou apenas o refactor documental do `ROADMAP.md`, sem alterar o contrato funcional do ciclo lazy.
- A `v2.19.5` refatorou internamente o runtime MARS para padronizar a serialização JSON via fachada `Janus.Json`, sem alterar o contrato HTTP nem assinaturas públicas.
- A `v2.19.6` encerrou operacionalmente a validação ESP-006 com baseline de `155/155` testes aprovados, sem alteração de API pública.
- A issue `#105` foi uma rodada process-only de release/governança; a versão publicada permaneceu `v2.19.6` e não houve mudança funcional no framework.
- A `v2.19.7` formalizou a regra canônica de validação processual para `/test` e `/release` (Path A/Path B), reforçando a auditabilidade da pipeline sem alteração funcional do framework.
- A `v2.19.8` formalizou a demanda R18.1 (ESP-002) para handoff de execução, com atualização de roadmap e critérios auditáveis sem alteração do contrato funcional do framework.
- A `v2.19.9` atualizou estrategicamente o `ROADMAP.md` para consolidar a demanda candidata R18.1 (ESP-002) para handoff, sem impacto no contrato funcional do framework.
- A `v2.19.10` consolidou editorialmente o milestone R18.1 no `ROADMAP.md` em item único rastreável da issue `#110`, mantendo a release como rodada documental/processual sem alteração funcional.
- A `v2.19.11` normalizou a redação da origem textual de R18.1 no `ROADMAP.md` (de "proxiam demanda" para "proxima demanda"), sem alterar classificação ESP-002, escopo funcional ou handoff planejado (issue `#113`).
