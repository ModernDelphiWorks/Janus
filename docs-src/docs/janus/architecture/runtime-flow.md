---
displayed_sidebar: janusSidebar
title: Fluxo de Runtime
---

## Pipeline de uma operação DML

```
App chama ApplyUpdates / Insert / Update / Delete
    ↓
TSessionAbstract  →  Executa fila de Middleware Before*
    ↓
TDMLCommandFactory.Create(command)
    ↓
Command.Execute  →  TDMLGeneratorAbstract.<Driver>.GeneratorXxx()
    ↓
IFluentSQL (TCQ)  →  produz SQL com placeholders
    ↓
TBind.Instance.SetParamsFromObject  →  preenche TParams
    ↓
IDBConnection.Execute
    ↓
Middleware After*  →  notifica resultado
```

## Fluxo SELECT + materialização

1. SQL é montado via `TCQ(driver)` (FluentSQL) ou informado manualmente.
2. `TJanusQueryResultSet.New.SetConnection(...).SQL(...).AsResultSet` retorna `IDBDataSet`.
3. `TJanusQueryObject<M>.New.SetConnection(...).SQL(...).AsList/AsValue` materializa objetos tipados.
4. `TBind.Instance.SetFieldToProperty(resultSet, entity)` preenche propriedades e respeita mapeamento RTTI.
5. `TLazyMappingExplorer` resolve e reaproveita o cache de campos lazy da entidade.
6. O contexto corrente injeta a factory do proxy transparente:
    - `ObjectSet`: durante o fluxo de sessão/comando.
    - `DataSet`: no scroll da linha atual, pulando abertura ansiosa apenas das associações lazy.
    - `REST`: em `TRESTObjectManager.FillAssociation`, substituindo o caminho que antes fazia `Continue`.
7. O primeiro acesso a `.Value` executa `TLazyProxyLoader.Invoke`, valida `ILazySessionToken` e carrega o objeto ou coleção conforme a multiplicidade.
8. O caminho explícito `LoadLazy` continua funcional para retrocompatibilidade.

## Pontos de erro comuns

| Erro | Causa |
|------|-------|
| `EDriverNotFound` | Unit `Janus.DML.Generator.<Driver>.pas` não incluída no uses |
| `EEntityNotMapped` | `TRegisterClass.RegisterEntity` não chamado no `initialization` |
| Bind inválido | Mismatch entre atributo `[Column]` e campo real na tabela |
| `ELazyLoadException` | `ILazySessionToken` invalidado antes do acesso ao proxy |
| Associação lazy não recarrega após trocar a linha atual | O proxy não foi reinjetado para a nova PK; o framework resolve isso via `ILazyProxyResettable` no fluxo DataSet/REST |
