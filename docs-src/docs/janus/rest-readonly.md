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

## Method-level granularity

Four new attributes provide per-HTTP-verb access control using **grant-list semantics**: if any `[RESTAllow*]` attribute is present on a class, only the explicitly listed verbs are allowed. All others return a deterministic JSON error.

### Attribute declarations

```delphi
uses MetaDbDiff.Mapping.Attributes;

// Allow GET only (e.g. audit log — read but no insert)
[Entity]
[Table('audit_log', '')]
[RESTAllowGET]
TAuditLog = class
  // ...
end;

// Allow GET + POST only (e.g. append-only stream)
[Entity]
[Table('event_stream', '')]
[RESTAllowGET]
[RESTAllowPOST]
TEventStream = class
  // ...
end;

// Allow all verbs explicitly (equivalent to no restriction)
[Entity]
[Table('lookup_item', '')]
[RESTAllowGET]
[RESTAllowPOST]
[RESTAllowPUT]
[RESTAllowDELETE]
TLookupItem = class
  // ...
end;
```

### Combined behaviour table

| Attributes present | GET | POST | PUT | DELETE |
|--------------------|-----|------|-----|--------|
| _(none)_ | ✔ pass | ✔ pass | ✔ pass | ✔ pass |
| `[RESTReadOnly]` | ✔ pass | ✗ blocked (read-only) | ✗ blocked (read-only) | ✗ blocked (read-only) |
| `[RESTAllowGET]` | ✔ pass | ✗ blocked (not allowed) | ✗ blocked (not allowed) | ✗ blocked (not allowed) |
| `[RESTAllowGET]` + `[RESTAllowPOST]` | ✔ pass | ✔ pass | ✗ blocked (not allowed) | ✗ blocked (not allowed) |
| All four `[RESTAllow*]` | ✔ pass | ✔ pass | ✔ pass | ✔ pass |
| `[RESTReadOnly]` + `[RESTAllowPOST]` | ✔ pass | ✗ blocked (read-only wins) | ✗ blocked (read-only wins) | ✗ blocked (read-only wins) |

> **Note:** `[RESTReadOnly]` always takes precedence. Adding `[RESTAllow*]` attributes to a class that also has `[RESTReadOnly]` does not unlock writes.

### Error response format

Blocked verbs return:

```json
{"exception":"HTTP POST not allowed for TEventStream"}
```

The class name in the message is the Delphi resource name (with `T` prefix as registered).

### cURL examples — GET-only scenario

```bash
# GET succeeds
curl http://localhost:9000/api/Janus/AuditLog
# → [{"id":1,"..."}]

# POST blocked
curl -X POST http://localhost:9000/api/Janus/AuditLog \
     -H "Content-Type: application/json" \
     -d '{"description":"New entry"}'
# → {"exception":"HTTP POST not allowed for TAuditLog"}
```

### Precedence rules

- `[RESTReadOnly]` is checked **first**. If present, all writes are blocked regardless of any `[RESTAllow*]` attributes.
- `[RESTAllow*]` grant-list is checked **second**, only when `[RESTReadOnly]` is absent.
- A class with **no** `[RESTAllow*]` and no `[RESTReadOnly]` passes all verbs (unchanged default behaviour).
