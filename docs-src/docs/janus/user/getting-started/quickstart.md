---
title: Quickstart
displayed_sidebar: janusSidebar
---

## Pre-requisitos

- Delphi XE+
- Boss package manager
- Driver de banco configurado (ex.: FireDAC)

Este quickstart reflete o contrato de uso publicado na versao `v2.19.10`.

As releases `v2.19.5`, `v2.19.6`, `v2.19.7`, `v2.19.8`, `v2.19.9` e `v2.19.10` nao alteraram este fluxo: a primeira realizou refactor interno do runtime MARS para JSON via `Janus.Json`; a segunda encerrou a validacao ESP-006 sem mudancas no contrato publico; a terceira formalizou regra de validacao processual para a pipeline; a quarta formalizou a demanda R18.1 (ESP-002) para handoff; e as duas ultimas consolidaram editorialmente o milestone R18.1 no `ROADMAP.md`.
A rodada processual da issue `#103` (ESP-004) tambem nao introduziu mudancas neste fluxo.

## Instalacao

```bash
boss install "https://github.com/HashLoad/Janus"
```

## Passo 1: criar entidade mapeada

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

## Passo 2: registrar entidade

```delphi
initialization
  TRegisterClass.RegisterEntity(Tclient);
```

## Passo 3: configurar conexao e container

```delphi
procedure TForm3.FormCreate(Sender: TObject);
begin
  FConn := TFactoryFireDAC.Create(FDConnection1, dnSQLite);
  FContainerClient := TContainerFDMemTable<Tclient>.Create(FConn, FDClient);
  FContainerClient.Open;
end;
```

Se o projeto usar propriedades com `[Lazy]`, inclua tambem a unit do driver DML correspondente no `uses` do projeto para garantir a geracao correta de SQL:

```delphi
uses Janus.DML.Generator.SQLite;
```

## Passo 4: persistir alteracoes

```delphi
procedure TForm3.ButtonSalvarClick(Sender: TObject);
begin
  FContainerClient.ApplyUpdates(0);
end;
```

## Checklist de validacao rapida

1. O pacote Janus foi instalado via Boss sem erro.
2. A entidade foi registrada no initialization.
3. O DataSet abre com Open sem excecao.
4. O ApplyUpdates(0) executa e grava no banco.
5. Se houver propriedade lazy, o primeiro acesso a `.Value` retorna o relacionamento esperado com a sessao ainda aberta.

## Proximos passos

- [Guia: Primeiro CRUD com DataSet](../guides/primeiro-crud-com-dataset)
- [Guia: Operacao Master-Detail](../guides/operacao-master-detail)
- [Referencia de configuracao](../reference/configuration)
