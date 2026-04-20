---
sidebar_position: 12
---

# JOIN Strategy: RTTI vs VIEW

Janus REST/Horse supports two complementary strategies for returning joined data over HTTP.

## Strategy A — RTTI via `$expand`

Use the `$expand` query parameter with a relationship name defined via `[ForeignKey]` / `[Association]` attributes.

```
GET /api/Janus/Customer(1)?$expand=Orders
```

### When to use

- Simple one-to-one or one-to-many associations.
- Moderate data volumes (dozens to low hundreds of related rows).
- When DDL access to the database is unavailable.

### Limitation

Each `$expand` generates additional queries via RTTI reflection (N+1 pattern). For large result sets or complex multi-join queries, prefer Strategy B.

### Delphi model example

```delphi
[Entity]
[Table('customer', '')]
[PrimaryKey('id', 'Primary key')]
TCustomer = class
  [Column('id', ftInteger)]
  property Id: Integer ...;
end;

[Entity]
[Table('order', '')]
[PrimaryKey('id', 'Primary key')]
TOrder = class
  [Column('customer_id', ftInteger)]
  [ForeignKey('fk_order_customer', 'TCustomer', 'id', 'customer_id')]
  property CustomerId: Integer ...;
end;
```

---

## Strategy B — VIEW via FluentSQL + DataEngine

Define a database VIEW containing the desired JOIN query. Map a Delphi class to the view using `[View]` and/or `[Table]`. Use `TRESTViewManager.EnsureView` at startup to create/update the view.

```
GET /api/Janus/CustomerOrderSummary
```

### When to use

- Complex multi-table JOINs.
- Aggregations (COUNT, SUM, AVG).
- High-traffic endpoints where per-request N+1 overhead is unacceptable.
- When the DBA can own and optimize the view independently.

### `TRESTViewManager.EnsureView` — startup call

```delphi
uses
  FluentSQL,
  Janus.Server.RestView.Manager;

// In your application startup:
var
  LSelect: IFluentSQL;
begin
  LSelect := FluentSQL.Query(dbnFirebird)
    .Select(['c.id AS customer_id', 'c.name AS customer_name',
             'COUNT(o.id) AS order_count', 'SUM(o.total) AS total_amount'])
    .From('customer c')
    .LeftJoin('order o', 'o.customer_id = c.id')
    .GroupBy(['c.id', 'c.name']);

  TRESTViewManager.EnsureView(TCustomerOrderSummary, LSelect, FConnection);
end;
```

> **Important:** `EnsureView` is an administrative setup operation. **Never call it inside a REST request handler.** Call it once during application initialization.

### Delphi model example

```delphi
[Entity]
[View('customer_order_summary', '')]
[Table('customer_order_summary', '')]
TCustomerOrderSummary = class
  [Column('customer_id', ftInteger)]   property CustomerId: Integer ...;
  [Column('customer_name', ftString, 100)] property CustomerName: String ...;
  [Column('order_count', ftInteger)]   property OrderCount: Integer ...;
  [Column('total_amount', ftFloat)]    property TotalAmount: Double ...;
end;
```

The class automatically inherits read-only semantics because it has a `[View]` attribute — no `[RESTReadOnly]` needed.

### Database compatibility

| Database | Strategy used |
|----------|--------------|
| PostgreSQL, MySQL, Oracle | `CREATE OR REPLACE VIEW` |
| SQLite, Firebird, MSSQL, others | `DROP VIEW IF EXISTS` + `CREATE VIEW` |

---

## Summary

| | RTTI `$expand` | VIEW Strategy |
|-|---------------|--------------|
| Setup | Zero DDL | Requires `EnsureView` at startup |
| SQL | N+1 queries | Single optimized VIEW query |
| Complexity | Simple associations | Complex JOINs / aggregations |
| Write protection | Not applicable | Automatic (implied by `[View]`) |
| Recommended for | Low-volume joins | Production-grade reporting queries |
