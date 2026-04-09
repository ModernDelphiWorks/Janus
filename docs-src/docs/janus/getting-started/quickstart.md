---
displayed_sidebar: janusSidebar
title: Quickstart
---

## Pré-requisitos

- Delphi XE+
- Boss package manager
- Driver de banco (ex.: FireDAC)

## Instalação

```bash
boss install "https://github.com/HashLoad/Janus"
```

## 1. Entidade mapeada

```delphi
uses MetaDbDiff.Mapping.Attributes;

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

## 2. Registrar entidade e driver

```delphi
// Na unit da entidade:
initialization
  TRegisterClass.RegisterEntity(Tclient);

// No projeto, incluir a unit do driver desejado:
uses Janus.DML.Generator.Firebird;   // registra dbnFirebird automaticamente
// ou: Janus.DML.Generator.SQLite, Janus.DML.Generator.PostgreSQL, etc.
```

## 3. Abrir dados via DataSet

```delphi
var LSession: TSessionDataSet;
    LDS: TJanusDataSet;
begin
  LSession := TSessionDataSet.Create(FConnection, dbnFirebird);
  LDS := LSession.OpenDataSet<Tclient>;
  // LDS agora é um TDataSet mapeado para Tclient
end;
```

## 4. Persistir alterações

```delphi
LDS.Edit;
LDS.FieldByName('client_name').AsString := 'Novo Nome';
LDS.Post;
LSession.ApplyUpdates;  // executa INSERT/UPDATE/DELETE no banco
```

## Próximos passos

- [Arquitetura](../architecture/overview)
- [Referência de API](../reference/api)
- [Middleware](../guides/middleware)
- [FluentSQL](../guides/criteria-fluentsql)
- [Manual do Usuário](../user/)
- Se preferir uma visão orientada ao uso diário (operador/dev de aplicação), consulte também o [Manual do Usuário](../user/).
