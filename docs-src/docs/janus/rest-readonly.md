---
sidebar_position: 11
---

# RESTReadOnly Attribute

The `[RESTReadOnly]` attribute marks a mapped class as read-only at the REST layer. GET requests (SELECT) are always allowed; POST, PUT, and DELETE return a deterministic JSON error.

## Declaration

```delphi
uses MetaDbDiff.Mapping.Attributes;

[Entity]
[Table('product', '')]
[PrimaryKey('id', 'Primary key')]
[RESTReadOnly]
TProduct = class
  // ...
end;
```

## Behaviour

| HTTP verb | Behaviour |
|-----------|-----------|
| `GET` | Passes through normally |
| `POST` | Returns `{"exception":"Resource TProduct is read-only (RESTReadOnly)"}` |
| `PUT` | Returns `{"exception":"Resource TProduct is read-only (RESTReadOnly)"}` |
| `DELETE` | Returns `{"exception":"Resource TProduct is read-only (RESTReadOnly)"}` |

The check runs **before** any database operation, so no row is ever touched on a blocked write.

## Implicit read-only via `[View]`

Classes decorated with `[View]` are implicitly read-only. You do not need to add `[RESTReadOnly]` to a view class — the server blocks writes automatically.

## cURL example

```bash
# GET succeeds
curl http://localhost:9000/api/Janus/Product

# POST blocked
curl -X POST http://localhost:9000/api/Janus/Product \
     -H "Content-Type: application/json" \
     -d '{"name":"New","price":9.99}'
# → {"exception":"Resource TProduct is read-only (RESTReadOnly)"}
```

## Delphi registration example

```delphi
TRegisterClass.RegisterEntity(TProduct);

LServer := TRESTServerHorse.Create(Self, FConnection);
THorse.Listen(9000);
```

## Comparison with `[NotServerUse]`

| Attribute | Effect |
|-----------|--------|
| `[NotServerUse]` | Blocks ALL REST access (GET + write) |
| `[RESTReadOnly]` | Allows GET; blocks POST/PUT/DELETE |
