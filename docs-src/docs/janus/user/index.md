---
title: Manual do Usuario Janus
displayed_sidebar: janusSidebar
---

Manual do usuario do Janus para Delphi, com foco em instalacao, primeiros fluxos de uso e todas as features do framework.

Estado atual do manual: alinhado com a release `v2.19.10`, incluindo lazy loading transparente em ObjectSet, DataSet e REST.
A v2.19.5 refatorou internamente o runtime MARS para padronizar a serializacao JSON via fachada `Janus.Json`; a v2.19.6 encerrou a validacao ESP-006 com 155/155 aprovados; a v2.19.7 formalizou a regra canônica de validação processual da pipeline; a v2.19.8 formalizou a demanda R18.1 (ESP-002) para handoff operacional; e as v2.19.9/v2.19.10 consolidaram editorialmente o milestone R18.1 no roadmap. Nenhuma dessas releases alterou o contrato publico de uso do framework.
A issue `#103` (ESP-004) consolidou apenas governanca de pipeline, sem impacto funcional para usuarios do framework.
A issue `#108` consolidou a formalizacao documental da R18.1, tambem sem impacto funcional para usuarios do framework.
A issue `#110` consolidou editorialmente o milestone R18.1 em item unico no `ROADMAP.md`, mantendo escopo processual sem alteracoes de uso no framework.

## Para quem este manual foi feito

- Desenvolvedores Delphi que precisam persistir objetos em banco relacional.
- Equipes que querem reduzir SQL manual em operacoes de CRUD.
- Operadores tecnicos que mantem aplicacoes VCL/FMX com DataSet e rotinas de integracao.

## Jornada recomendada

- [Introducao](./introduction)
- [Primeiros passos](./getting-started/quickstart)

## Guias por feature

### Persistência e dados
- [Primeiro CRUD com DataSet](./guides/primeiro-crud-com-dataset) — fluxo visual VCL/FMX
- [Operacao Master-Detail](./guides/operacao-master-detail) — TManagerDataSet
- [ObjectSet (sem DataSet visual)](./guides/objectset) — para servicos e APIs
- [Consultas personalizadas](./guides/consultas-personalizadas) — filtros e paginacao via FluentSQL (`TCQ`)

### Tipos especiais
- [Campos opcionais com Nullable](./guides/nullable) — Nullable\<T\> para campos NULL
- [Lazy Loading](./guides/lazy-loading) — carregamento adiado com proxy transparente e compatibilidade com `LoadLazy`

### Interface e binding
- [LiveBindings VCL/FMX](./guides/livebindings) — binding automatico via atributos
- [Monitor SQL](./guides/monitor-sql) — diagnostico de comandos em tempo real

### Features avancadas
- [Eventos Before e After](./guides/eventos-middleware) — interceptar operacoes DML
- [CodeGen](./guides/codegen) — gerar entidades a partir do banco
- [Serializacao JSON](./guides/json) — converter entidades para/de JSON
- [Driver RESTful](./guides/restful) — persistencia via HTTP

## Referencias
- [Configuracao](./reference/configuration)
- [Troubleshooting](./troubleshooting/common-errors)
