---
displayed_sidebar: janusSidebar
title: Introdução
---

O Janus resolve o mapeamento objeto-relacional em Delphi com foco em produtividade e neutralidade de banco.

A biblioteca expõe um fluxo orientado a entidades e atributos, reduzindo SQL manual para operações comuns.

## Conceitos-chave

- **Entidade mapeada**: classe Delphi anotada com `[Entity]`, `[Table]`, `[Column]`, `[PrimaryKey]`.
- **Session / Container**: camada que orquestra CRUD (DataSet ou ObjectSet).
- **DML Generator**: geração de SQL orientada por driver via FluentSQL.
- **Middleware**: interceptação Before/After de operações DML.
- **`Lazy<T>`**: carga adiada de associações via proxy transparente.
- **`Nullable<T>`**: suporte a NULL em propriedades tipadas.

## Público-alvo

Times Delphi que precisam de persistência consistente, suporte multi-banco (14 drivers) e extensão por middleware/plugins.

> Para foco operacional, consulte o [Manual do Usuário](./user/).
