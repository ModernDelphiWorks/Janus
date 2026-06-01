# Janus Framework for Delphi

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

*   [🇬🇧 English](#-english)
*   [🇧🇷 Português](#-português)

---

## 🇬🇧 English

**Janus** is a state-of-the-art Object-Relational Mapping (ORM) framework for Delphi that bridges the gap between object-oriented programming and relational database models. 

It manages database mapping transparently, allowing developers to build enterprise applications with a pure object-oriented approach while persisting objects securely into relational databases.

<p align="center">
  <a href="https://www.isaquepinheiro.com.br">
    <img src="https://github.com/HashLoad/Janus/blob/master/Images/janusbitbucket.png" alt="Janus Logo">
  </a>
</p>

Janus provides built-in methods for all common database operations, such as CRUD (Create, Read, Update, Delete), handles metadata mapping via attributes, and drastically reduces connection and SQL boilerplate code — resulting in cleaner, safer, and highly maintainable systems.

---

### 🚀 Feature Matrix

| Feature | Status |
|---------|--------|
| Complete CRUD Operations (Create, Read, Update, Delete) | ✅ |
| Multi-Database DML generation | ✅ |
| DataSet Containers (`TClientDataSet`, `TFDMemTable`) | ✅ |
| ObjectSet Containers (Typed lists of Pascal objects) | ✅ |
| Criteria API (Object-oriented query builder) | ✅ |
| Middleware Pipeline (Before/After Hooks on DML) | ✅ |
| Metadata Comparison Engine (Pascal Model ↔ DB Schema) | ✅ |
| RESTful integration (Horse middleware) | ✅ |
| LiveBindings support (VCL + FMX) | ✅ |
| SQL Command execution monitor | ✅ |
| Nullable Types Support | ✅ |
| Blob / Stream Types Support | ✅ |
| Transparent Lazy Loading (RTTI Proxies) | ✅ |
| Auto-Lazy DataSet loading | ✅ |
| Extensible Plugin System (`IJanusPlugin`, custom hooks) | ✅ |
| CodeGen Library (DB Schema → Delphi Pascal model units) | ✅ |
| Delphi IDE Wizard integration (4-page Wizard inside the IDE) | ✅ |
| Standalone Model Generator CLI | ✅ |
| DLL Bridge (Multi-language integration) | ✅ |
| Automated Testing (DUnitX + FPCUnit coverage) | ✅ |
| Master-Detail Hierarchy Management (`TManagerDataSet`) | ✅ |
| Pagination (`NextPacket`) & Sequential cursor navigation | ✅ |

#### 🏛 Supported Databases
Firebird · Firebird 3 · InterBase · SQLite · MySQL · PostgreSQL · MSSQL · Oracle · MongoDB · ADS · AbsoluteDB · ElevateDB · NexusDB

---

### ⚙️ Installation
To install using [`boss`]:
```sh
boss install "https://github.com/HashLoad/Janus"
```

### ⚠ Dependencies
All dependencies are resolved automatically by Boss:
*   [MetaDbDiff](https://github.com/hashload/MetaDbDiff) — Mapping & metadata comparer
*   [DataEngine](https://github.com/hashload/DataEngine) — Connection abstraction
*   [FluentSQL](https://github.com/hashload/FluentSQL) — SQL script generation
*   [JsonFlow](https://github.com/hashload/JsonFlow) — JSON serialization

---

### ⚡️ Quick Start

#### 1. Define your Entity Model
```delphi
unit Janus.Model.Client;

interface

uses
  Classes, DB, SysUtils, Generics.Collections,
  MetaDbDiff.Mapping.Attributes,
  Janus.Types.Nullable,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Register,
  Janus.Types.Blob;

type
  [Entity]
  [Table('client','')]
  [PrimaryKey('client_id')]
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
    property client_id: Integer read Fclient_id write Fclient_id;

    [Column('client_name', ftString, 40)]
    property client_name: String read Fclient_name write Fclient_name;

    [Column('client_foto', ftBlob)]
    property client_foto: TBlob read Fclient_foto write Fclient_foto;
  end;

implementation

initialization
  TRegisterClass.RegisterEntity(Tclient);

end.
```

#### 2. Perform CRUD using a DataSet Container (`TFDMemTable`)
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
  // Create FireDAC connection factory wrapper
  FConn := TFactoryFireDAC.Create(FDConnection1, dnSQLite);
  
  // Bind typed Janus container to memory table
  FContainerClient := TContainerFDMemTable<Tclient>.Create(FConn, FDClient);
  FContainerClient.Open;
end;

procedure TForm3.ButtonSaveClick(Sender: TObject);
begin
  FContainerClient.ApplyUpdates(0); // Saves changes back to database
end;
```

#### 3. Manage Master-Detail relationships via `TManagerDataSet`
```delphi
procedure TForm3.FormCreate(Sender: TObject);
begin
  FConn := TFactoryFireDAC.Create(FDConnection1, dnMySQL);

  FManager := TManagerDataSet.Create(FConn);
  FConn.SetCommandMonitor(TCommandMonitor.GetInstance);
  
  // Fluidly attach adapters and manage lookups
  FManager.AddAdapter<Tmaster>(FDMaster, 3)
          .AddAdapter<Tdetail, Tmaster>(FDDetail)
          .AddAdapter<Tclient, Tmaster>(FDClient)
          .AddAdapter<Tlookup>(FDLookup)
          .AddLookupField<Tdetail, Tlookup>('fieldname','lookup_id','lookup_id','lookup_description','Lookup Description');
          
  FManager.Open<Tmaster>;
end;
```

---

### ⛏️ Contributing
Our team would love to receive contributions to this open-source project. Feel free to open issues or submit pull requests.

### 📬 Contact & Support
*   **Telegram**: [HashLoad Channel](https://t.me/hashload)
*   **Website**: [isaquepinheiro.com.br](https://www.isaquepinheiro.com.br)

---

## 🇧🇷 Português

**Janus** é um framework moderno de Mapeamento Objeto-Relacional (ORM) de alta performance para Delphi que preenche a distância entre a programação orientada a objetos e o modelo de banco de dados relacional.

Ele gerencia o mapeamento objeto-banco de forma totalmente transparente, permitindo construir aplicações corporativas complexas com uma abordagem puramente orientada a objetos enquanto persiste dados em bancos de dados relacionais.

O ORM fornece métodos integrados para todas as interações comuns com o banco de dados, como CRUD (Create, Read, Update, Delete), gerencia o mapeamento de metadados por atributos e reduz drasticamente a quantidade de código de conexão e SQL que você precisa escrever — resultando em aplicações limpas e fáceis de manter.

---

### 🚀 Matriz de Features

| Feature | Status |
|---------|--------|
| CRUD completo (Create, Read, Update, Delete) | ✅ |
| Geração de DML multi-banco | ✅ |
| Containers DataSet (TClientDataSet, TFDMemTable) | ✅ |
| Containers ObjectSet (listas tipadas de objetos Pascal) | ✅ |
| Criteria API (consultas puramente orientadas a objetos) | ✅ |
| Middleware Pipeline (Hooks Before/After em DML) | ✅ |
| Engine de Comparação de Metadata (Modelo Pascal ↔ Base de Dados) | ✅ |
| Integração RESTful (middleware Horse) | ✅ |
| LiveBindings (VCL + FMX) | ✅ |
| Monitor de Comandos SQL Executados | ✅ |
| Suporte a Tipos Nullable | ✅ |
| Suporte a Tipos Blob / Stream | ✅ |
| Lazy Loading Transparente (Proxies RTTI) | ✅ |
| DataSet Auto-Lazy | ✅ |
| Sistema de Plugins Extensível (`IJanusPlugin`, hooks) | ✅ |
| Biblioteca CodeGen (Schema DB ↔ units de modelo Delphi) | ✅ |
| IDE Wizard (wizard de 4 páginas dentro do Delphi IDE) | ✅ |
| Gerador de Modelos Standalone | ✅ |
| DLL Bridge (integração multi-linguagem) | ✅ |
| Testes Automatizados (DUnitX + FPCUnit) | ✅ |
| Hierarquia Master-Detail (TManagerDataSet) | ✅ |
| Paginação (NextPacket) & Navegação Sequencial | ✅ |

#### 🏛 Bancos de Dados Suportados
Firebird · Firebird 3 · InterBase · SQLite · MySQL · PostgreSQL · MSSQL · Oracle · MongoDB · ADS · AbsoluteDB · ElevateDB · NexusDB

---

### ⚙️ Instalação
Para instalar usando o [`boss`]:
```sh
boss install "https://github.com/HashLoad/Janus"
```

### ⚠ Dependências
Todas as dependências são resolvidas de forma totalmente automática pelo Boss:
*   [MetaDbDiff](https://github.com/hashload/MetaDbDiff) — Mapeamento & metadata
*   [DataEngine](https://github.com/hashload/DataEngine) — Abstração de conexão
*   [FluentSQL](https://github.com/hashload/FluentSQL) — Geração de SQL
*   [JsonFlow](https://github.com/hashload/JsonFlow) — Serialização JSON

---

### ⚡️ Início Rápido

#### 1. Defina um Modelo de Entidade
```delphi
unit Janus.Model.Client;

interface

uses
  Classes, DB, SysUtils, Generics.Collections,
  MetaDbDiff.Mapping.Attributes,
  Janus.Types.Nullable,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Register,
  Janus.Types.Blob;

type
  [Entity]
  [Table('client','')]
  [PrimaryKey('client_id')]
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
    property client_id: Integer read Fclient_id write Fclient_id;

    [Column('client_name', ftString, 40)]
    property client_name: String read Fclient_name write Fclient_name;

    [Column('client_foto', ftBlob)]
    property client_foto: TBlob read Fclient_foto write Fclient_foto;
  end;

implementation

initialization
  TRegisterClass.RegisterEntity(Tclient);

end.
```

#### 2. Executando operações CRUD usando um Container DataSet (`TFDMemTable`)
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
  // Cria a conexão via FireDAC wrapper
  FConn := TFactoryFireDAC.Create(FDConnection1, dnSQLite);
  
  // Vincula o container Janus ao MemTable
  FContainerClient := TContainerFDMemTable<Tclient>.Create(FConn, FDClient);
  FContainerClient.Open;
end;

procedure TForm3.ButtonSaveClick(Sender: TObject);
begin
  FContainerClient.ApplyUpdates(0); // Persiste as modificações no banco de dados
end;
```

#### 3. Controle Master-Detail com `TManagerDataSet`
```delphi
procedure TForm3.FormCreate(Sender: TObject);
begin
  FConn := TFactoryFireDAC.Create(FDConnection1, dnMySQL);

  FManager := TManagerDataSet.Create(FConn);
  FConn.SetCommandMonitor(TCommandMonitor.GetInstance);
  
  // Vincula adaptadores de forma fluida
  FManager.AddAdapter<Tmaster>(FDMaster, 3)
          .AddAdapter<Tdetail, Tmaster>(FDDetail)
          .AddAdapter<Tclient, Tmaster>(FDClient)
          .AddAdapter<Tlookup>(FDLookup)
          .AddLookupField<Tdetail, Tlookup>('fieldname','lookup_id','lookup_id','lookup_description','Descrição Lookup');
          
  FManager.Open<Tmaster>;
end;
```

---

### ⛏️ Contribuição
Adoramos contribuições! Sinta-se à vontade para abrir issues ou enviar pull requests.

### 📬 Contato & Suporte
*   **Telegram**: [Canal HashLoad](https://t.me/hashload)
*   **Website**: [isaquepinheiro.com.br](https://www.isaquepinheiro.com.br)

---
*Copyright © 2025-2026 Isaque Pinheiro. Licensed under MIT License.*
