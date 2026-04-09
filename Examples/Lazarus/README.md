# Lazarus Console Example — Janus ORM via DLL

Este exemplo demonstra o consumo do **Janus ORM** a partir do **Lazarus/FPC** por meio da `JanusFramework.dll`.

## Pré-requisitos

| Ferramenta | Versão mínima |
|---|---|
| Lazarus | 2.x |
| FPC | 3.x |
| JanusFramework.dll | SPRINT-01 |
| Delphi XE+ | Necessário para **compilar** a DLL |

## Estrutura de arquivos

```
Examples/Lazarus/
  LazarusConsoleExample.lpi  — projeto Lazarus (CRUD + Criteria)
  Main.pas                   — programa console com CRUD completo
  MasterDetail/
    example_master_detail.lpi  — projeto Lazarus (Master/Detail)
    example_master_detail.lpr  — exemplo Master/Detail com FK, JOIN, Cascade
  README.md                  — este arquivo

Projects/Janus DLL Framework/
  Janus.IncludeDll.pas       — contrato público (incluir no projeto Lazarus)
  Janus.Lazarus.Helper.pas   — helper layer com sintaxe simplificada
  JanusFramework.dll         — DLL compilada (copiar para a pasta do executável)
```

## Como compilar a DLL

1. Abra o Delphi XE+ e carregue `Projects/Janus DLL Framework/JanusFramework.dproj`
2. Compile em modo **Release** para gerar `JanusFramework.dll`
3. Copie `JanusFramework.dll` para `Examples/Lazarus/`

## Como compilar o exemplo Lazarus

```bash
# Via Lazarus IDE:
#   File > Open Project > Examples/Lazarus/LazarusConsoleExample.lpi
#   Run > Build

# Via linha de comando (FPC):
fpc Main.pas -Fu"../../Projects/Janus DLL Framework"
```

## Como executar

```bash
cd Examples/Lazarus
LazarusConsoleExample.exe
```

Saída esperada:
```
Janus ORM via DLL -- Lazarus Example
-------------------------------------
Connected to test.db
INSERT done.
Records found: 1
Name : Isaque Pinheiro
Email: isaque@janus.com
DELETE done.
Done. No Access Violation.
```

## Sintaxe Simplificada (Helper Layer)

A partir do SPRINT-05/06, o projeto inclui a unit **`Janus.Lazarus.Helper`** que elimina a verbosidade de `PWideChar(WideString(...))` em todas as chamadas.

### Como usar

Adicione `Janus.Lazarus.Helper` à cláusula `uses`:

```pascal
uses
  Janus.IncludeDll,
  Janus.Lazarus.Helper;
```

### Conexão

```pascal
// Helper (recomendado):
LConn := JanusConnectSQLiteStr('test.db');

// Também disponível: JanusConnectFirebirdStr, JanusConnectMySQLStr,
// JanusConnectPostgreSQLStr, JanusConnectMSSQLStr, JanusConnectOracleStr
```

### ObjectSet

```pascal
// Variável do tipo TJanusSetHelper (record wrapper):
var LSet: TJanusSetHelper;

LSet := JanusObjectSetStr('TClientModel', LConn);
```

### Get/Set de campos

```pascal
// Variável do tipo TJanusRecordHelper (record wrapper):
var LRec: TJanusRecordHelper;

LRec := LSet.NewRecord;
LRec.SetStr('client_name', 'Isaque Pinheiro');
LRec.SetInt('quantity', 10);

// Leitura:
WriteLn(LRec.GetStr('client_name'));
WriteLn(LRec.GetInt('quantity'));
```

### Entity Builder (Strategy 2)

```pascal
if not JanusBuilder()
  .EntityName('TOrder')
  .TableName('orders')
  .AddColumn('id', 'integer', 0)
  .AddColumn('descr', 'string', 100)
  .PrimaryKey('id')
  .Build
then
  WriteLn('ERROR: Build failed.');
```

### Query (IJanusQuery)

`IJanusQuery` não possui record wrapper. Use `JW()` para conversão de strings e `JanusSet()` para wrapping do resultado:

```pascal
var
  LQuery: IJanusQuery;
  LFiltered: TJanusSetHelper;

LQuery := JanusCreateQuery(JW('TClientModel'), LConn);
LFiltered := JanusSet(LQuery
  .Where(JW('client_name LIKE ''A%'''))
  .OrderBy(JW('client_name'))
  .PageSize(5)
  .Execute);
```

### Liberação de records

Records helpers usam `Default()` em vez de `:= nil`:

```pascal
LRec := Default(TJanusRecordHelper);
LSet := Default(TJanusSetHelper);
```

> **Nota:** `IJanusConnection` permanece como tipo de variável (sem wrapper record). Use `:= nil` normalmente para liberação.

## Conversão Explícita (Referência)

O padrão explícito com `PWideChar`/`WideString` continua funcional e não requer `Janus.Lazarus.Helper`. Use-o como referência ou quando o helper não for desejado.

Lazarus usa `AnsiString` (UTF-8) por padrão. Na fronteira da DLL, todas as strings são `PWideChar` (UTF-16). Use as conversões abaixo:

| Sentido | Código |
|---|---|
| FPC → DLL | `PWideChar(UTF8Decode('texto'))` |
| DLL → FPC | `UTF8Encode(WideString(ptr))` |
| WideString → PWideChar | `PWideChar(WideString('texto'))` |

> **Recomendação:** prefira o Helper Layer para novos projetos. O padrão explícito é mantido para retrocompatibilidade.

## Adicionando novos modelos

1. No Delphi, crie a classe do modelo em `Projects/Janus DLL Framework/Source/Models/`
   e aplique os atributos `[Entity]`, `[Table]`, `[Column]` conforme o padrão de `Janus.DLL.Model.Client.pas`
2. Registre o modelo em `RegisterAllModels` dentro de `Janus.DLL.Models.Registry.pas`
3. Recompile `JanusFramework.dll`
4. No consumer, substitua `'TClientModel'` pelo nome da nova classe
