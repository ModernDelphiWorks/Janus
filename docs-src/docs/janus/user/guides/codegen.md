---
title: Guia - CodeGen (Geração de Entidades)
displayed_sidebar: janusSidebar
---

O **CodeGen** gera automaticamente as classes de entidade Delphi a partir do schema do banco de dados, eliminando a necessidade de escrever mapeamentos na mão.

## O que é gerado

Para cada tabela selecionada, o CodeGen produz:
- Classe Delphi com atributos `[Entity]`, `[Table]`, `[Column]`, `[PrimaryKey]`
- Propriedades tipadas para cada coluna
- Campos `Lazy<T>` para chaves estrangeiras
- Bloco `initialization` com `TRegisterClass.RegisterEntity`

## Como usar

### 1. Criar o engine com a conexão

```delphi
uses
  Janus.CodeGen.Engine,
  Janus.CodeGen.Options,
  Janus.CodeGen.Schema;

var
  LOptions: TJanusCodeGenOptions;
  LEngine: TJanusCodeGenEngine;
begin
  LOptions := TJanusCodeGenOptions.Create;
  LOptions.OutputPath := 'C:\MeuProjeto\Models';
  LOptions.GenerateLazy := True;

  LEngine := TJanusCodeGenEngine.Create(
    TJanusSchemaReader.Create(FConn),
    LOptions
  );
end;
```

### 2. Gerar uma única tabela

```delphi
var LTableInfo: TTableInfo;
    LCode: String;
begin
  LTableInfo := LEngine.SchemaReader.ReadTable('client');
  LCode := LEngine.GenerateUnit(LTableInfo);
  // LCode contém o código Delphi pronto
end;
```

### 3. Gerar todas as tabelas de uma vez

```delphi
var LTables: TArray<TTableInfo>;
begin
  LTables := LEngine.SchemaReader.ReadAllTables;
  LEngine.GenerateAll(LTables, 'C:\MeuProjeto\Models');
  // Gera um arquivo .pas por tabela na pasta especificada
end;
```

## Exemplo de saída gerada

```delphi
unit Model.Client;

interface

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

initialization
  TRegisterClass.RegisterEntity(Tclient);
end.
```

## Dicas

- Revise o código gerado antes de usar em produção.
- Para tabelas com FKs complexas, verifique se os tipos `Lazy<T>` foram gerados corretamente.
- Use a opção `GenerateLazy := True` para incluir carregamento adiado nas FK automaticamente.
