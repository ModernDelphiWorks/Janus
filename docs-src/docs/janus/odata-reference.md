---
sidebar_position: 10
---

# OData Query Reference

Janus REST/Horse exposes OData v4-compatible query parameters over any mapped Delphi class.

## Supported query parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `$filter` | WHERE clause equivalent | `$filter=name eq 'Alice'` |
| `$orderby` | ORDER BY clause | `$orderby=name desc` |
| `$top` | Limit results (page size) | `$top=25` |
| `$skip` | Offset (used with `$top`) | `$skip=50` |
| `$count` | Returns record count in `ResultCount` header | `$count=true` |
| `$select` | Projections (column subset) | `$select=id,name` |
| `$expand` | Eager-load associations via RTTI | `$expand=Orders` |
| `$search` | Full-text style filter | `$search=Alice` |

## Comparison operators

| OData | SQL equivalent | Example |
|-------|---------------|---------|
| `eq` | `=` | `name eq 'Alice'` |
| `ne` | `<>` | `status ne 'inactive'` |
| `gt` | `>` | `age gt 18` |
| `ge` | `>=` | `score ge 90` |
| `lt` | `<` | `price lt 100` |
| `le` | `<=` | `discount le 0.5` |
| `add` | `+` | `qty add 1` |
| `sub` | `-` | `total sub tax` |
| `mul` | `*` | `price mul qty` |
| `div` | `/` | `total div count` |

> **Word-boundary safe:** operators are only replaced when they appear as complete words. A field named `sequence`, `address`, or `delete_date` is never corrupted by the parser (ADR-001).

## Logical operators

| OData | SQL | Example |
|-------|-----|---------|
| `and` | `AND` | `active eq true and age gt 18` |
| `or` | `OR` | `status eq 'a' or status eq 'b'` |
| `not` | `NOT` | `not (active eq false)` |

Parentheses are passed through to SQL unchanged, allowing complex expressions:

```
$filter=(name eq 'Alice' and age gt 18) or status eq 'vip'
```

## OData functions

| OData function | SQL equivalent | Example |
|----------------|---------------|---------|
| `contains(field,'x')` | `field LIKE '%x%'` | `contains(name,'ali')` |
| `startswith(field,'x')` | `field LIKE 'x%'` | `startswith(code,'INV')` |
| `endswith(field,'x')` | `field LIKE '%x'` | `endswith(email,'@corp.com')` |
| `tolower(field)` | `LOWER(field)` | `tolower(name) eq 'alice'` |
| `toupper(field)` | `UPPER(field)` | `toupper(status) eq 'ACTIVE'` |

## Pagination example

```
GET /api/Janus/Customer?$top=10&$skip=20&$orderby=name asc&$count=true
```

Returns records 21–30 ordered by name, and includes the total count in the `ResultCount` response header.

## cURL examples

```bash
# Filter by name
curl "http://localhost:9000/api/Janus/Customer?\$filter=name eq 'Alice'"

# Pagination
curl "http://localhost:9000/api/Janus/Customer?\$top=10&\$skip=0"

# Contains function
curl "http://localhost:9000/api/Janus/Customer?\$filter=contains(email,'@corp.com')"

# Expand related data
curl "http://localhost:9000/api/Janus/Customer(1)?\$expand=Orders"
```
