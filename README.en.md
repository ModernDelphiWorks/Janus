# Janus Framework for Delphi

[🇧🇷 Português](README.md)

<p align="center">
  <a href="https://www.isaquepinheiro.com.br">
    <img src="https://github.com/HashLoad/Janus/blob/master/Images/janusbitbucket.png">
  </a>
</p>

[![License](https://img.shields.io/badge/Licence-LGPL--3.0-blue.svg)](https://opensource.org/licenses/LGPL-3.0)

**Janus** is a modern Object-Relational Mapping (ORM) framework for Delphi that bridges the gap between object-oriented programming and the relational database model. It manages object-to-database mapping, enabling you to build applications with a pure OO approach while persisting objects to relational databases.

The ORM provides built-in methods for common database interactions such as CRUD (Create, Read, Update, Delete), manages all mapping details, and dramatically reduces the amount of connection and SQL code you need to write — resulting in cleaner, more maintainable applications.

While the ORM satisfies most database interaction needs, you can still use custom SQL queries when more specialized access is required.

by: Bárbara Ranieri

---

## Feature Matrix

| Feature | Status |
|---------|--------|
| Full CRUD (Create, Read, Update, Delete) | ✅ |
| Multi-database DML generation | ✅ |
| DataSet Containers (TClientDataSet, TFDMemTable) | ✅ |
| ObjectSet Containers (typed object lists) | ✅ |
| Criteria API (object-oriented queries) | ✅ |
| Middleware Pipeline (Before/After Insert/Update/Delete) | ✅ |
| Metadata Compare Engine (Model ↔ DB) | ✅ |
| RESTful Integration (Horse middleware) | ✅ |
| LiveBindings (VCL + FMX) | ✅ |
| SQL Command Monitor | ✅ |
| Nullable Types | ✅ |
| Blob Types | ✅ |
| Transparent Lazy Loading (Proxy) | ✅ |
| DataSet Auto-Lazy | ✅ |
| Plugin System (IJanusPlugin, hooks, custom events) | ✅ |
| CodeGen Library (schema → Delphi model units) | ✅ |
| IDE Wizard (4-page wizard inside Delphi IDE) | ✅ |
| Standalone Model Generator | ✅ |
| DLL Bridge (multi-language integration) | ✅ |
| Automated Tests (DUnitX + FPCUnit) | ✅ |
| Master-Detail Hierarchy (TManagerDataSet) | ✅ |
| Pagination (NextPacket) & Sequential Navigation | ✅ |

### Supported Databases

Firebird · Firebird 3 · InterBase · SQLite · MySQL · PostgreSQL · MSSQL · Oracle · MongoDB · ADS · AbsoluteDB · ElevateDB · NexusDB

---

## Delphi Versions

Embarcadero Delphi XE and higher.

## Installation

Install using [`boss`](https://github.com/HashLoad/boss):

```sh
boss install "https://github.com/HashLoad/Janus"
```

## Dependencies

- [MetaDbDiff Framework for Delphi](https://github.com/hashload/MetaDbDiff) — Mapping & metadata
- [DataEngine Framework for Delphi/Lazarus](https://github.com/hashload/DataEngine) — Connection abstraction
- [FluentSQL Framework for Delphi/Lazarus](https://github.com/hashload/FluentSQL) — SQL building
- [JsonFlow Framework for Delphi](https://github.com/hashload/JsonFlow) — JSON serialization

All dependencies are resolved automatically by Boss.

---

## Quick Start

### 1. Define a Model

```delphi
unit Janus.Model.Client;

interface

uses
  Classes,
  DB,
  SysUtils,
  Generics.Collections,
  /// orm
  MetaDbDiff.Mapping.Attributes,
  Janus.Types.Nullable,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Register,
  Janus.Types.Blob;

type
  [Entity]
  [Table('client','')]
  [PrimaryKey('client_id', 'Primary key')]
  [Indexe('idx_client_name','client_name')]
  [OrderBy('client_id Desc')]
  Tclient = class
  private
    Fclient_id: Integer;
    Fclient_name: String;
    Fclient_foto: TBlob;
  public
    [Restrictions([NoUpdate, NotNull])]
    [Column('client_id', ftInteger)]
    [Dictionary('client_id','Validation message','','','',taCenter)]
    property client_id: Integer read Fclient_id write Fclient_id;

    [Column('client_name', ftString, 40)]
    [Dictionary('client_name','Validation message','','','',taLeftJustify)]
    property client_name: String read Fclient_name write Fclient_name;

    [Column('client_foto', ftBlob)]
    [Dictionary('client_foto','Validation message')]
    property client_foto: TBlob read Fclient_foto write Fclient_foto;
  end;

implementation

initialization
  TRegisterClass.RegisterEntity(Tclient);

end.
```

### 2. Use a DataSet Container (CRUD)

```delphi
uses
  DataEngine.FactoryInterfaces,
  Janus.Container.DataSet.Interfaces,
  Janus.Container.FDMemTable,
  DataEngine.FactoryFireDac,
  Janus.DML.Generator.SQLite,
  Janus.Model.Client;

procedure TForm3.FormCreate(Sender: TObject);
begin
  // Create connection via FireDAC
  FConn := TFactoryFireDAC.Create(FDConnection1, dnSQLite);
  // Create typed DataSet container
  FContainerClient := TContainerFDMemTable<Tclient>.Create(FConn, FDClient);
  FContainerClient.Open;
end;

procedure TForm3.Button2Click(Sender: TObject);
begin
  FContainerClient.ApplyUpdates(0);
end;
```

### 3. Master-Detail with TManagerDataSet

```delphi
procedure TForm3.FormCreate(Sender: TObject);
begin
  FConn := TFactoryFireDAC.Create(FDConnection1, dnMySQL);

  FManager := TManagerDataSet.Create(FConn);
  FConn.SetCommandMonitor(TCommandMonitor.GetInstance);
  FManager.AddAdapter<Tmaster>(FDMaster, 3)
          .AddAdapter<Tdetail, Tmaster>(FDDetail)
          .AddAdapter<Tclient, Tmaster>(FDClient)
          .AddAdapter<Tlookup>(FDLookup)
          .AddLookupField<Tdetail, Tlookup>('fieldname',
                                            'lookup_id',
                                            'lookup_id',
                                            'lookup_description',
                                            'Lookup Description');
  FManager.Open<Tmaster>;
end;
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [Overview](docs-src/docs/janus/index.md) | Main technical documentation entry point |
| [Getting Started](docs-src/docs/janus/getting-started/quickstart.md) | From zero to first CRUD |
| [Architecture Guide](docs-src/docs/janus/architecture/overview.md) | Layers, patterns, data flow |
| [API Reference](docs-src/docs/janus/reference/api.md) | Rules, contracts, inputs and outputs |
| [Tests](docs-src/docs/janus/tests/overview.md) | Validation strategy and coverage |
| [Troubleshooting](docs-src/docs/janus/troubleshooting/common-errors.md) | Common errors and resolution |

---

## License

[![License](https://img.shields.io/badge/Licence-LGPL--3.0-blue.svg)](https://opensource.org/licenses/LGPL-3.0)

Copyright © Isaque Pinheiro. All Rights Reserved.
