---
displayed_sidebar: janusSidebar
title: API — Referência
---

## Atributos ORM

| Atributo | Alvo | Parâmetros |
|----------|------|-----------|
| `[Entity]` | Classe | — |
| `[Table('nome', 'schema')]` | Classe | nome da tabela, schema (opcional) |
| `[PrimaryKey('col', 'nome')]` | Classe | coluna PK, nome da constraint |
| `[Column('col', tipo, tamanho)]` | Property | coluna, `TFieldType`, tamanho |
| `[ForeignKey('col', 'ref')]` | Property | coluna FK, tabela referenciada |
| `[Association(tipo, cascata)]` | Property | tipo de join, cascata |
| `[Lazy]` | Property `Lazy<T>` | — (carga adiada via proxy) |
| `[View('nome', 'schema')]` | Classe | nome da view, schema (opcional) |

## Interfaces principais

| Interface | Arquivo | Papel |
|-----------|---------|-------|
| `IDMLGeneratorCommand` | `Janus.DML.Interfaces` | Contrato de driver DML |
| `IBind` | `Janus.Bind` | Bind DataSet ↔ objeto |
| `IFluentSQL` | `FluentSQL` | Query builder FluentSQL |
| `IJanusQueryResultSet` | `Janus.Query.ResultSet` | Execução de query → DataSet |
| `IJanusQueryObject<M>` | `Janus.Query.ResultSet` | Materialização de lista/objeto tipado |
| `ILazyProxy` | `Janus.Mapping.Lazy` | Proxy de carga adiada |
| `ILazySessionToken` | `Janus.Mapping.Lazy` | Token de vida da sessão lazy |
| `ILazyProxyResettable` | `Janus.Mapping.Lazy` | Reset interno do proxy para reinjeção idempotente |
| `IJanusHookContext` | `Janus.Register.Middleware` | Contexto de evento middleware |

## Factories e singletons

```delphi
TDriverRegister.RegisterDriver(dbnFirebird, TDMLGeneratorFirebird.Create);
TDriverRegister.GetDriver(dbnFirebird)          // → IDMLGeneratorCommand

TBind.Instance                                  // → IBind singleton
TRttiSingleton.GetInstance                      // → IRttiSingleton
TDMLCommandFactory.Create(AClass, cmd, session) // → TDMLCommandExecutor
TCQ(driver)                                     // → IFluentSQL (FluentSQL entry point)
TJanusQueryResultSet.New                        // → IJanusQueryResultSet
TJanusQueryObject<M>.New                        // → IJanusQueryObject<M>
```

## Drivers DML

`dbnMSSQL` · `dbnMySQL` · `dbnFirebird` · `dbnFirebird3` · `dbnSQLite` · `dbnInterbase` · `dbnOracle` · `dbnPostgreSQL` · `dbnADS` · `dbnAbsoluteDB` · `dbnElevateDB` · `dbnNexusDB` · `dbnMongoDB` · `dbnNoSQL`

Tipo: `TDBEngineDriver` (DataEngine). Inclua a unit `Janus.DML.Generator.<Driver>.pas` para registrar automaticamente.

## Tipos especiais

| Tipo | Uso |
|------|-----|
| `Nullable<T>` | Propriedade que aceita NULL no banco |
| `Lazy<T>` | Propriedade com carga adiada (ILazyProxy) |
| `TBlob` | Campo BLOB/CLOB |

## Infraestrutura lazy transparente

| Item | Tipo | Descrição |
|------|------|-----------|
| `TLazyProxyLoader` | Classe | Implementa `ILazyProxy` e executa a factory apenas no primeiro acesso |
| `TLazySessionToken` | Classe | Controla se a sessão ainda está válida para permitir o load |
| `TLazyMappingExplorer` | Classe | Mantém cache dos campos lazy por classe para evitar nova extração RTTI |
| `ELazyLoadException` | Exceção | Erro levantado quando o proxy tenta carregar dados após a sessão ter sido invalidada |

## Middleware — eventos disponíveis

`onBeforeInsert` · `onAfterInsert` · `onBeforeUpdate` · `onAfterUpdate` · `onBeforeDelete` · `onAfterDelete` · `onCustom`

Ver guia: [Middleware](../guides/middleware)

## Regras de contrato

- Placeholders de bind sem aspas: `:param_name`.
- Todo middleware pode chamar `Context.Abort` para cancelar a operação.
- Contratos públicos preservam compatibilidade entre releases patch.
- Para classes anotadas apenas com `[View]` (sem `[Table]`), `TObjectHelper.GetTable` retorna `nil` e `TMappingExplorer.GetMappingView` retorna o mapeamento de view quando presente.
- Em `v2.19.0`, o lazy transparente usa o mesmo contrato base em ObjectSet, DataSet e REST.
- O proxy respeita multiplicidade: `OneToOne`/`ManyToOne` retornam objeto único; `OneToMany`/`ManyToMany` retornam coleção.
- O caminho explícito `LoadLazy` permanece compatível com o proxy transparente.
- Quando o framework executa `ILazyProxyResettable.Reset`, `IsValueCreated` volta para `False` e o próximo `Invoke` deve usar a nova factory, produzindo novo carregamento em vez de reutilizar o valor antigo.
