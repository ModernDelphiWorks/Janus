---
title: Quickstart
displayed_sidebar: janusSidebar
---

## Prerequisites

- Delphi XE+
- Boss package manager
- Configured database driver (for example, FireDAC)

This quickstart reflects the published usage contract up to version `v2.19.14`.
Releases `v2.19.5` through `v2.19.14` did not change this end-user operational flow.

## Installation

```bash
boss install "https://github.com/ModernDelphiWorks/Janus"
```

## Step 1: Create a mapped entity

```delphi
[Entity]
[Table('client', '')]
[PrimaryKey('client_id', 'PK')]
Tclient = class
private
  Fclient_id: Integer;
  Fclient_name: String;
public
  [Column('client_id', ftInteger)]
  property client_id: Integer read Fclient_id write Fclient_id;

  [Column('client_name', ftString, 40)]
  property client_name: String read Fclient_name write Fclient_name;
end;
```

## Step 2: Register the entity

```delphi
initialization
  TRegisterClass.RegisterEntity(Tclient);
```

## Step 3: Configure connection and container

```delphi
procedure TForm3.FormCreate(Sender: TObject);
begin
  FConn := TFactoryFireDAC.Create(FDConnection1, dnSQLite);
  FContainerClient := TContainerFDMemTable<Tclient>.Create(FConn, FDClient);
  FContainerClient.Open;
end;
```

If your project uses properties marked with `[Lazy]`, include the matching DML generator unit in the project `uses` section so SQL generation is registered correctly:

```delphi
uses Janus.DML.Generator.SQLite;
```

## Step 4: Persist changes

```delphi
procedure TForm3.ButtonSalvarClick(Sender: TObject);
begin
  FContainerClient.ApplyUpdates(0);
end;
```

## Quick validation checklist

1. Janus is installed via Boss without errors.
2. The entity is registered in initialization.
3. DataSet opens with Open without exception.
4. ApplyUpdates(0) executes and writes to the database.
5. If lazy properties exist, first access to `.Value` resolves while the session is still active.

## Next steps

- [Guide: Primeiro CRUD com DataSet](../guides/primeiro-crud-com-dataset)
- [Guide: Operacao Master-Detail](../guides/operacao-master-detail)
- [Configuration reference](../reference/configuration)
