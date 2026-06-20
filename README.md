# Janus ORM Framework for Delphi

[![Delphi XE+](https://img.shields.io/badge/Delphi-XE%20or%20superior-blue.svg)]()
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

*   [🇬🇧 English](#-english)
*   [🇧🇷 Português](#-português)

---

## 🇬🇧 English

**Janus** is a state-of-the-art Object-Relational Mapping (ORM) framework for Delphi designed to bridge the gap between rich object-oriented domain models and relational database structures. It transparently handles metadata mappings via RTTI attributes, reduces SQL/connection boilerplate, and provides seamless DataSet/ObjectSet containers. With built-in support for master-detail hierarchies (`TManagerDataSet`), transparent lazy loading via RTTI proxies, custom middleware pipelines, and an interactive Delphi IDE code-generation wizard, Janus is the ultimate database access toolkit for high-performance Pascal systems.

### 🚀 Key Features

*   **Bidirectional Metadata Mapping:** Declare entities using clean, descriptive Pascal attributes (`[Table]`, `[PrimaryKey]`, `[Indexe]`, `[Column]`).
*   **Dual Persist Containers:** Work with typed memory containers: `TContainerDataSet` (for visual bindings using `TClientDataSet` or `TFDMemTable`) or `TContainerObjectSet` (for typed object collections).
*   **TManagerDataSet (Master-Detail System):** Automatically manage deep database master-detail hierarchies, lookup joins, and multi-table operations out of the box.
*   **Performance & Lazy Loading:** Features high-precision client-side navigation caching, transparent proxy-based lazy loading, and paginated query packages (`NextPacket`).
*   **Rich Enterprise Tools:** Standalone Model Generator CLI, DLL bridge for multi-language systems, and an interactive 4-page Delphi IDE Wizard.

### 🏛 Compatibility Matrix

| Environment / IDE | Platform / Compiler | RTTI Proxies | CodeGen Wizard |
| :--- | :--- | :---: | :---: |
| **Delphi XE or superior** | VCL, FMX, Console, IDE (Win/Linux/macOS/iOS/Android) | ✅ Yes | ✅ Yes (Delphi IDE) |

### 🐧 Cross-Platform Build — Win32 / Win64 / Linux64 (verified)

> **✅ Verified 2026-06-20** in a real production backend: Janus compiles as a dependency on **Win32, Win64 and Linux64** (`dcclinux64`), and the Linux server boots and serves routes/ORM. macOS/iOS/Android follow from the Delphi RTL but are **not build-verified** here yet.

`HAS_VCL` — and the `Janus.Types.Blob` image-blob helpers (`ToPicture`/`ToBitmap` over `Vcl.Imaging`) — is now enabled only under `{$IFDEF MSWINDOWS}`. It was being defined unconditionally, which pulled VCL `Graphics`/`JPEG`/`PngImage` on Linux; image-blob conversion is a desktop-only feature, while the rest of the ORM is platform-neutral. Windows behaviour is unchanged.

**Building a consumer app for Linux64:** install the Linux 64-bit platform (RAD Studio GetIt / `GetItCmd -if=delphi_linux -ae`), provide a Linux SDK (RAD Studio SDK Manager + PAServer, **or** a sysroot assembled from a WSL/Linux toolchain passed to `dcclinux64` via `--syslibroot` / `--libpath`), then compile with `dcclinux64`.

### ⚙️ Installation

To install using the package manager [**Boss**](https://github.com/HashLoad/boss):

```sh
boss install "https://github.com/HashLoad/Janus"
```

### ⚠ Dependencies

All dependencies are resolved automatically by Boss:
*   [MetaDbDiff](https://github.com/hashload/MetaDbDiff) — Mapping & database comparison engine.
*   [DataEngine](https://github.com/hashload/DataEngine) — Uniform connection abstraction layer.
*   [FluentSQL](https://github.com/hashload/FluentSQL) — Fluent SQL generation library.
*   [JsonFlow](https://github.com/hashload/JsonFlow) — Modern JSON serialization.

---

### ⚡️ Quick Start

#### 1. Define your Entity Model
```delphi
unit Janus.Model.Client;

interface

uses
  Classes, DB, SysUtils,
  MetaDbDiff.Mapping.Attributes,
  Janus.Types.Nullable,
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
    Fclient_name: string;
    Fclient_foto: TBlob;
  public
    [Restrictions([NoUpdate, NotNull])]
    [Column('client_id', ftInteger)]
    property client_id: Integer read Fclient_id write Fclient_id;

    [Column('client_name', ftString, 40)]
    property client_name: string read Fclient_name write Fclient_name;

    [Column('client_foto', ftBlob)]
    property client_foto: TBlob read Fclient_foto write Fclient_foto;
  end;

implementation

initialization
  TRegisterClass.RegisterEntity(Tclient);

end.
```

#### 2. Execute CRUD Operations (MemTable Wrapper)
```delphi
uses
  DataEngine.Interfaces,
  DataEngine.Factory.FireDAC,
  Janus.Container.DataSet.Interfaces,
  Janus.Container.FDMemTable,
  Janus.Model.Client;

var
  FConn: IDBConnection;
  FContainerClient: IContainerDataSet<Tclient>;
begin
  // Establish native connection wrapper
  FConn := TFactoryFireDAC.Create(FDConnection1, dnSQLite);
  
  // Bind Janus container directly to a standard Memory Table
  FContainerClient := TContainerFDMemTable<Tclient>.Create(FConn, FDClientMemTable);
  FContainerClient.Open;
  
  // Apply changes back to physical database
  FContainerClient.ApplyUpdates(0);
end;
```

#### 3. Master-Detail Hierarchy (`TManagerDataSet`)
```delphi
var
  FManager: TManagerDataSet;
begin
  FConn := TFactoryFireDAC.Create(FDConnection1, dnMySQL);
  FManager := TManagerDataSet.Create(FConn);
  
  // Fluidly chain master-detail-lookup structures
  FManager.AddAdapter<Tmaster>(FDMaster, 3)
          .AddAdapter<Tdetail, Tmaster>(FDDetail)
          .AddAdapter<Tclient, Tmaster>(FDClient)
          .AddAdapter<Tlookup>(FDLookup)
          .AddLookupField<Tdetail, Tlookup>('lookup_id', 'lookup_id', 'description');
          
  FManager.Open<Tmaster>;
end;
```

---

## 🇧🇷 Português

**Janus** é um ORM (Object-Relational Mapping) de última geração para Delphi projetado para aproximar o modelo de domínio orientado a objetos das estruturas relacionais de banco de dados. Ele gerencia mapeamentos estruturais de metadados transparentemente via atributos de RTTI, reduz códigos repetitivos e consultas manuais no banco de dados e oferece contêineres unificados de dados (`DataSet` e `ObjectSet`). Trazendo controle automático de hierarquias master-detail (`TManagerDataSet`), lazy loading transparente, pipelines de customização de DML e um gerador interativo de classes acoplado à IDE do Delphi, o Janus é o ecossistema perfeito para persistência corporativa em Object Pascal.

### 🚀 Recursos Principais

*   **Mapeamento Bidirecional de Metadados:** Decore e estruture classes usando atributos descritivos em Pascal (`[Table]`, `[PrimaryKey]`, `[Indexe]`, `[Column]`).
*   **Contêineres Duplos de Persistência:** Trabalhe de forma otimizada com `TContainerDataSet` (para vinculo visual nativo em tela usando `TClientDataSet`/`TFDMemTable`) ou `TContainerObjectSet` (para manipulação orientada estritamente a objetos).
*   **TManagerDataSet (Sistema Master-Detail):** Gerenciamento fluido de profundas hierarquias master-detail, resolvendo joins de lookup e atualizações em lote de forma transparente.
*   **Alta Performance & Lazy Loading:** Navegação indexada local com cache, carga sob demanda baseada em proxies RTTI (`Lazy Loading`) e pacotes de paginação sob demanda (`NextPacket`).
*   **Ferramentas Avançadas:** Gerador de Modelos CLI standalone, DLL bridge de integração para sistemas escritos em outras linguagens de programação e um Wizard integrado de 4 páginas na IDE do Delphi.

### 🏛 Matriz de Compatibilidade

| Ambiente / IDE | Plataforma / Compilador | Proxies RTTI | Wizard na IDE |
| :--- | :--- | :---: | :---: |
| **Delphi XE ou superior** | VCL, FMX, Console, IDE (Win/Linux/macOS/iOS/Android) | ✅ Sim | ✅ Sim (Delphi IDE) |

### 🐧 Build Multiplataforma — Win32 / Win64 / Linux64 (verificado)

> **✅ Verificado em 2026-06-20** num backend real em produção: o Janus compila como dependência em **Win32, Win64 e Linux64** (`dcclinux64`), e o servidor Linux sobe e serve rotas/ORM. macOS/iOS/Android seguem da RTL Delphi, mas **ainda não foram verificados** em build aqui.

O `HAS_VCL` — e os helpers de blob↔imagem do `Janus.Types.Blob` (`ToPicture`/`ToBitmap` sobre `Vcl.Imaging`) — agora só ficam ativos sob `{$IFDEF MSWINDOWS}`. Ele estava sendo definido incondicionalmente, o que puxava `Graphics`/`JPEG`/`PngImage` (VCL) no Linux; a conversão blob↔imagem é uma feature desktop-only, enquanto o resto do ORM é neutro de plataforma. O comportamento no Windows não muda.

**Para buildar um app consumidor no Linux64:** instale a plataforma Linux 64-bit (RAD Studio GetIt / `GetItCmd -if=delphi_linux -ae`), forneça um SDK Linux (SDK Manager do RAD Studio + PAServer, **ou** um sysroot montado de um toolchain WSL/Linux passado ao `dcclinux64` via `--syslibroot` / `--libpath`), e compile com `dcclinux64`.

### ⚙️ Instalação

Para instalar usando o gerenciador de pacotes [**Boss**](https://github.com/HashLoad/boss):

```sh
boss install "https://github.com/HashLoad/Janus"
```

### ⚠ Dependências

Todas as dependências são resolvidas de forma totalmente automática pelo Boss:
*   [MetaDbDiff](https://github.com/hashload/MetaDbDiff) — Motor de mapeamento e comparação estrutural.
*   [DataEngine](https://github.com/hashload/DataEngine) — Abstração unificada de conexão.
*   [FluentSQL](https://github.com/hashload/FluentSQL) — Geração fluente de SQL.
*   [JsonFlow](https://github.com/hashload/JsonFlow) — Serialização JSON de alta performance.

---

### ⚡️ Início Rápido

#### 1. Defina o seu Modelo de Entidade
```delphi
unit Janus.Model.Client;

interface

uses
  Classes, DB, SysUtils,
  MetaDbDiff.Mapping.Attributes,
  Janus.Types.Nullable,
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
    Fclient_name: string;
    Fclient_foto: TBlob;
  public
    [Restrictions([NoUpdate, NotNull])]
    [Column('client_id', ftInteger)]
    property client_id: Integer read Fclient_id write Fclient_id;

    [Column('client_name', ftString, 40)]
    property client_name: string read Fclient_name write Fclient_name;

    [Column('client_foto', ftBlob)]
    property client_foto: TBlob read Fclient_foto write Fclient_foto;
  end;

implementation

initialization
  TRegisterClass.RegisterEntity(Tclient);

end.
```

#### 2. Operações CRUD Rápidas (Wrapper de MemTable)
```delphi
uses
  DataEngine.Interfaces,
  DataEngine.Factory.FireDAC,
  Janus.Container.DataSet.Interfaces,
  Janus.Container.FDMemTable,
  Janus.Model.Client;

var
  FConn: IDBConnection;
  FContainerClient: IContainerDataSet<Tclient>;
begin
  // Estabelece a conexão usando o wrapper do FireDAC
  FConn := TFactoryFireDAC.Create(FDConnection1, dnSQLite);
  
  // Associa o container Janus diretamente a uma tabela em memória
  FContainerClient := TContainerFDMemTable<Tclient>.Create(FConn, FDClientMemTable);
  FContainerClient.Open;
  
  // Persiste todas as alterações no banco de dados físico
  FContainerClient.ApplyUpdates(0);
end;
```

#### 3. Controle Hierárquico Master-Detail (`TManagerDataSet`)
```delphi
var
  FManager: TManagerDataSet;
begin
  FConn := TFactoryFireDAC.Create(FDConnection1, dnMySQL);
  FManager := TManagerDataSet.Create(FConn);
  
  // Associa tabelas master-detail e lookup de forma encadeada
  FManager.AddAdapter<Tmaster>(FDMaster, 3)
          .AddAdapter<Tdetail, Tmaster>(FDDetail)
          .AddAdapter<Tclient, Tmaster>(FDClient)
          .AddAdapter<Tlookup>(FDLookup)
          .AddLookupField<Tdetail, Tlookup>('lookup_id', 'lookup_id', 'description');
          
  FManager.Open<Tmaster>;
end;
```

---
*Copyright © 2025-2026 Isaque Pinheiro. Licensed under MIT License.*
