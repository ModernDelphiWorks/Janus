---
title: Guia - Consultas Personalizadas
displayed_sidebar: janusSidebar
---

Para além do CRUD automático, o Janus oferece o **FluentSQL** como query builder para construir SELECT personalizado com filtros, JOINs e ordenação sem escrever SQL manual.

## Quando usar

- Relatórios e listagens com filtros dinâmicos.
- Queries com condições que variam por usuário ou contexto.
- Busca com múltiplos critérios (nome, data, status).

## SELECT simples com filtro

```delphi
uses FluentSQL, Janus.Query.ResultSet;

// Buscar todos os clientes ativos ordenados por nome
var LClients: TObjectList<Tclient>;
begin
  LClients := TJanusQueryObject<Tclient>
    .New
    .SetConnection(FConn)
    .SQL(
      TCQ(FConn)
        .Select
        .From('client')
        .Where('ativo').Equal(1)
        .OrderBy('client_name')
        .AsString
    )
    .AsList;
end;
```

## Filtros encadeados

```delphi
var LSQL: String;
begin
  LSQL := TCQ(FConn)
    .Select
    .Column(['client_id', 'client_name', 'email'])
    .From('client')
    .Where('ativo').Equal(1)
    .AndOpe('created_at').GreaterEqThan(EncodeDate(2024, 1, 1))
    .OrderBy('client_name')
    .AsString;
end;
```

## Busca com LIKE (texto parcial)

```delphi
LSQL := TCQ(FConn)
  .Select.From('client')
  .Where('client_name').LikeFull('silva')  // %silva%
  .AsString;
```

## Paginação

```delphi
// Página 2 com 20 registros por página
LSQL := TCQ(FConn)
  .Select.From('client')
  .OrderBy('client_name')
  .First(20).Skip(20)   // skip = (página - 1) * tamanho
  .AsString;
```

## Resultado como objeto único

```delphi
var LClient: Tclient;
begin
  LClient := TJanusQueryObject<Tclient>
    .New
    .SetConnection(FConn)
    .SQL(TCQ(FConn).Select.From('client')
           .Where('client_id').Equal(42).AsString)
    .AsValue;
end;
```

## Dica

O `TCQ()` gera SQL compatível com o driver configurado na conexão, com troca automática de dialeto entre Firebird, MySQL, PostgreSQL, SQLite e outros bancos suportados.
