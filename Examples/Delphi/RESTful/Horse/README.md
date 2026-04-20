# HorseJanus Example

Demonstrates Janus REST/Horse with three scenarios introduced in v2.19+:

1. **Read-only endpoint** — a class decorated with `[RESTReadOnly]` that accepts only GET
2. **RTTI expand** — master/detail relationship via `$expand`
3. **VIEW-based JOIN** — a summary view created by `TRESTViewManager` at startup

## Requirements

- Delphi 11+ (Win32 or Win64 VCL)
- Firebird client (`fbclient.dll`) in the executable directory
- BOSS package manager for dependencies

## Running

```bash
# Install dependencies (from the project folder)
boss install

# Open HorseJanus.dpr in Delphi IDE and run F9, or:
# Compile and start from the command line
HorseJanus.exe
```

The server starts on **port 9000** by default. Press `Enter` to stop.

## Endpoints

| Verb | URL | Notes |
|------|-----|-------|
| GET | `/api/Janus/Customer` | List all customers |
| GET | `/api/Janus/Customer(1)` | Customer by ID |
| GET | `/api/Janus/Customer?$filter=name eq 'Alice'` | Filter |
| GET | `/api/Janus/Customer(1)?$expand=Orders` | Expand orders via RTTI |
| GET | `/api/Janus/CustomerOrderSummary` | VIEW-based aggregated summary |
| GET | `/api/Janus/ReadOnlyProduct` | Returns data |
| POST | `/api/Janus/ReadOnlyProduct` | **Blocked** — returns `{"exception":"...read-only (RESTReadOnly)"}` |

## cURL examples

```bash
# List customers
curl http://localhost:9000/api/Janus/Customer

# Get with filter
curl "http://localhost:9000/api/Janus/Customer?\$filter=name eq 'Alice'"

# Expand orders
curl "http://localhost:9000/api/Janus/Customer(1)?\$expand=Orders"

# View-based join
curl http://localhost:9000/api/Janus/CustomerOrderSummary

# Test read-only block
curl -X POST http://localhost:9000/api/Janus/ReadOnlyProduct \
     -H "Content-Type: application/json" \
     -d '{"name":"Test","price":1.0}'
```
