# Janus Framework for Delphi

[🇬🇧 English](README.en.md)

<p align="center">
  <a href="https://www.isaquepinheiro.com.br">
    <img src="https://github.com/HashLoad/Janus/blob/master/Images/janusbitbucket.png">
  </a>
</p>

[![License](https://img.shields.io/badge/Licence-LGPL--3.0-blue.svg)](https://opensource.org/licenses/LGPL-3.0)

**Janus** é um framework moderno de Mapeamento Objeto-Relacional (ORM) para Delphi que encurta a distância entre a programação orientada a objetos e o modelo de banco de dados relacional. Ele gerencia o mapeamento objeto-banco, permitindo construir aplicações com uma abordagem puramente OO enquanto persiste objetos em bancos de dados relacionais.

O ORM fornece métodos integrados para interações comuns com o banco de dados, como CRUD (Create, Read, Update, Delete), gerencia todos os detalhes de mapeamento e reduz drasticamente a quantidade de código de conexão e SQL que você precisa escrever — resultando em aplicações mais limpas e fáceis de manter.

Embora o ORM satisfaça a maioria das necessidades de interação com o banco de dados, você ainda pode usar consultas SQL customizadas quando um acesso mais especializado for necessário.

por: Bárbara Ranieri

---

## Matriz de Features

| Feature | Status |
|---------|--------|
| CRUD completo (Create, Read, Update, Delete) | ✅ |
| Geração de DML multi-banco | ✅ |
| Containers DataSet (TClientDataSet, TFDMemTable) | ✅ |
| Containers ObjectSet (listas tipadas de objetos) | ✅ |
| Criteria API (consultas orientadas a objetos) | ✅ |
| Middleware Pipeline (Before/After Insert/Update/Delete) | ✅ |
| Engine de Comparação de Metadata (Model ↔ DB) | ✅ |
| Integração RESTful (middleware Horse) | ✅ |
| LiveBindings (VCL + FMX) | ✅ |
| Monitor de Comandos SQL | ✅ |
| Tipos Nullable | ✅ |
| Tipos Blob | ✅ |
| Lazy Loading Transparente (Proxy) | ✅ |
| DataSet Auto-Lazy | ✅ |
| Sistema de Plugins (IJanusPlugin, hooks, eventos customizados) | ✅ |
| Biblioteca CodeGen (schema → units de modelo Delphi) | ✅ |
| IDE Wizard (wizard de 4 páginas dentro do Delphi IDE) | ✅ |
| Gerador de Modelos Standalone | ✅ |
| DLL Bridge (integração multi-linguagem) | ✅ |
| Testes Automatizados (DUnitX + FPCUnit) | ✅ |
| Hierarquia Master-Detail (TManagerDataSet) | ✅ |
| Paginação (NextPacket) & Navegação Sequencial | ✅ |

### Bancos de Dados Suportados

Firebird · Firebird 3 · InterBase · SQLite · MySQL · PostgreSQL · MSSQL · Oracle · MongoDB · ADS · AbsoluteDB · ElevateDB · NexusDB

---

## Versões Delphi

Embarcadero Delphi XE e superior.

## Instalação

Instalação usando o [`boss`](https://github.com/HashLoad/boss):

```sh
boss install "https://github.com/HashLoad/Janus"
```

## Dependências

- [MetaDbDiff Framework for Delphi](https://github.com/hashload/MetaDbDiff) — Mapeamento & metadata
- [DataEngine Framework for Delphi/Lazarus](https://github.com/hashload/DataEngine) — Abstração de conexão
- [FluentSQL Framework for Delphi/Lazarus](https://github.com/hashload/FluentSQL) — Construção de SQL
- [JsonFlow Framework for Delphi](https://github.com/hashload/JsonFlow) — Serialização JSON

Todas as dependências são resolvidas automaticamente pelo Boss.

---

## Quick Start

### 1. Defina um Modelo

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
  [PrimaryKey('client_id', 'Chave primária')]
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
    [Dictionary('client_id','Mensagem de validação','','','',taCenter)]
    property client_id: Integer read Fclient_id write Fclient_id;

    [Column('client_name', ftString, 40)]
    [Dictionary('client_name','Mensagem de validação','','','',taLeftJustify)]
    property client_name: String read Fclient_name write Fclient_name;

    [Column('client_foto', ftBlob)]
    [Dictionary('client_foto','Mensagem de validação')]
    property client_foto: TBlob read Fclient_foto write Fclient_foto;
  end;

implementation

initialization
  TRegisterClass.RegisterEntity(Tclient);

end.
```

### 2. Use um Container DataSet (CRUD)

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
  // Cria a conexão via FireDAC
  FConn := TFactoryFireDAC.Create(FDConnection1, dnSQLite);
  // Cria o container DataSet tipado
  FContainerClient := TContainerFDMemTable<Tclient>.Create(FConn, FDClient);
  FContainerClient.Open;
end;

procedure TForm3.Button2Click(Sender: TObject);
begin
  FContainerClient.ApplyUpdates(0);
end;
```

### 3. Master-Detail com TManagerDataSet

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
                                            'Descrição Lookup');
  FManager.Open<Tmaster>;
end;
```

---

## Documentação

| Documento | Descrição |
|-----------|-----------|
| [Visão Geral](docs-src/docs/janus/index.md) | Entrada principal da documentação técnica |
| [Getting Started](docs-src/docs/janus/getting-started/quickstart.md) | Do zero ao primeiro CRUD |
| [Guia de Arquitetura](docs-src/docs/janus/architecture/overview.md) | Camadas, padrões, fluxo de dados |
| [Referência de API](docs-src/docs/janus/reference/api.md) | Regras, contratos e entradas/saídas |
| [Testes](docs-src/docs/janus/tests/overview.md) | Estratégia de validação e cobertura |
| [Troubleshooting](docs-src/docs/janus/troubleshooting/common-errors.md) | Erros comuns e resolução |

---

## Licença

[![License](https://img.shields.io/badge/Licence-LGPL--3.0-blue.svg)](https://opensource.org/licenses/LGPL-3.0)

## Contribuição

Nossa equipe adoraria receber contribuições para este projeto open source. Se você tiver alguma ideia ou correção de bug, sinta-se à vontade para abrir uma issue ou enviar uma pull request.

[![Issues](https://img.shields.io/badge/Issues-channel-orange)](https://github.com/HashLoad/Janus/issues)

Para enviar uma pull request, siga estas etapas:

1. Faça um fork do projeto
2. Crie uma nova branch (`git checkout -b minha-nova-funcionalidade`)
3. Faça suas alterações e commit (`git commit -am 'Adicionando nova funcionalidade'`)
4. Faça push da branch (`git push origin minha-nova-funcionalidade`)
5. Abra uma pull request

## Contato
[![Telegram](https://img.shields.io/badge/Telegram-channel-blue)](https://t.me/hashload)

## Doação
[![Doação](https://img.shields.io/badge/PagSeguro-contribua-green)](https://pag.ae/bglQrWD)
