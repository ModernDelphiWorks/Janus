---
displayed_sidebar: janusSidebar
title: FluentSQL
---

## Visão geral

O Janus usa o FluentSQL como query builder. Use `TCQ(conexao)` para montar SQL tipado e encadeado.

```delphi
uses FluentSQL;
```

## SELECT básico

```delphi
var LSQL: String;
begin
  LSQL := TCQ(FConnection)
    .Select
    .From('client')
    .Where('ativo = :ativo')
    .OrderBy('client_name')
    .AsString;
  // → SELECT * FROM client WHERE ativo = :ativo ORDER BY client_name
end;
```

## Operadores de comparação encadeados

```delphi
LSQL := TCQ(FConnection)
  .Select
  .Column(['client_id', 'client_name'])
  .From('client')
  .Where('created_at').GreaterEqThan(EncodeDate(2024, 1, 1))
  .AndOpe('status').InValues(['A', 'P'])
  .AsString;
```

## JOIN

```delphi
LSQL := TCQ(FConnection)
  .Select
  .From('pedido', 'p')
  .InnerJoin('client', 'c').OnCond('c.client_id = p.client_id')
  .Where('p.ativo').Equal(1)
  .AsString;
```

## INSERT / UPDATE / DELETE

```delphi
// INSERT
TCQ(FConnection).Insert.Into('client')
  .SetValue('client_name', ':client_name')
  .SetValue('ativo', ':ativo')
  .AsString;

// UPDATE
TCQ(FConnection).Update('client')
  .SetValue('client_name', ':client_name')
  .Where('client_id').Equal(':client_id')
  .AsString;

// DELETE
TCQ(FConnection).Delete.From('client')
  .Where('client_id').Equal(':client_id')
  .AsString;
```

## Paginação

```delphi
TCQ(FConnection).Select.From('client')
  .First(20).Skip(40)   // página 3 de 20 registros
  .AsString;
```

## Resultado tipado (IJanusQueryObject)

```delphi
uses FluentSQL, Janus.Query.ResultSet;

var LClients: TObjectList<Tclient>;
begin
  LClients := TJanusQueryObject<Tclient>
    .New
    .SetConnection(FConnection)
    .SQL(TCQ(FConnection).Select.From('client').Where('ativo = 1').AsString)
    .AsList;
end;
```

Ver testes: `TestCriteriaAdvanced`, `TestFluentSQLIntegration`.
