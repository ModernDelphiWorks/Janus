---
title: Guia - Driver RESTful
displayed_sidebar: janusSidebar
---

O **driver RESTful** do Janus permite persistir entidades via API HTTP em vez de banco de dados direto. O cliente Janus se comunica com um servidor que expõe endpoints do próprio Janus.

## Frameworks de servidor suportados

- Horse
- WiRL
- MARS
- DataSnap
- dMVCFramework (DMVC)
- WebSocket (WS)

## Configurar o cliente

```delphi
uses Janus.Client, Janus.Client.Horse;

var LClient: TJanusClient;
begin
  LClient := TJanusClient.Create;
  LClient.Host := 'localhost';
  LClient.Port := 9000;
  LClient.Protocol := Http;
  LClient.Resource := 'client';
end;
```

## Usar o container RESTful

```delphi
uses
  Janus.Session.RESTful,
  Janus.RestDataSet.FDMemTable;

var LSession: TSessionRestFul<Tclient>;
begin
  LSession := TSessionRestFul<Tclient>.Create(LRestConn, LAdapter);

  // Buscar todos
  var LList := LSession.Find;

  // Buscar por ID
  var LClient := LSession.Find(42);

  // Inserir
  LSession.Insert(LNewClient);

  // Atualizar
  LSession.Update(LClientList);

  // Excluir
  LSession.Delete(LClient);
end;
```

## Configurar o servidor com Horse

```delphi
uses Horse.Janus;

// No servidor Horse, registrar as rotas Janus automaticamente:
THorse.Use(HorseJanus);
THorse.Listen(9000);
```

## Fluxo de dados

```
App Delphi (cliente)
    ↓ HTTP JSON
Servidor Horse/WiRL/MARS/etc.
    ↓
Janus Session (server-side)
    ↓
Banco de dados
```

## Quando usar

- Aplicações cliente-servidor via HTTP.
- Quando o banco não pode ser acessado diretamente do cliente.
- Multi-camada com autenticação centralizada no servidor.

## Versões de terceiros contra as quais os drivers foram escritos

Os drivers de servidor de terceiros não são vendorizados neste repositório. Cada
um é localizado por uma propriedade de diretório no `.dproj` e foi escrito
contra uma revisão concreta. Quem for mexer num driver deve conferir a revisão
abaixo antes: essas bibliotecas renomeiam tipos entre versões e a quebra
aparece só na compilação.

| Driver | Repositório | Revisão fixada | Data | Propriedade de diretório |
|--------|-------------|----------------|------|--------------------------|
| WiRL | [delphi-blocks/WiRL](https://github.com/delphi-blocks/WiRL) | `aac8562c810b98fef590f3035f56bdf9ea3bad76` | 2026-07-13 | `$(WIRLDIR)` (convenção; nenhum `.dproj` a usa ainda) |
| MARS | [andrea-magni/MARS](https://github.com/andrea-magni/MARS) | não registrada | — | `$(MARSDIR)` (usada por `Janus.Tests.RESTMARS.dproj`) |

Search path esperado para `$(WIRLDIR)`: `Source\Core`, `Source\Client`,
`Source\Data`, `Source\Data\FireDAC`, `Libs\Neon\Source`,
`Libs\JWT\Source\Common`, `Libs\JWT\Source\JOSE`, `Libs\OpenAPI\Source`.

### O que mudou no WiRL

A revisão fixada acima é posterior à divisão do motor do WiRL. Contra ela:

- `WiRL.Core.Engine` não existe mais. O motor virou uma família:
  `TWiRLCustomEngine` (base abstrata, `WiRL.Engine.Core`), `TWiRLRESTEngine`
  (`WiRL.Engine.REST`), `TWiRLHTTPEngine` (`WiRL.Engine.HTTP`),
  `TWiRLFileSystemEngine` (`WiRL.Engine.FileSystem`) e `TWiRLWebServerEngine`
  (`WiRL.Engine.WebServer`). O driver do Janus usa `TWiRLRESTEngine`, que é o
  único que hospeda aplicações e resources — os outros três servem arquivo
  estático ou despacham um evento.
- Os componentes de cliente `TWiRLClientResourceJSON`,
  `TWiRLClientSubResourceJSON` e `TWiRLClientToken` foram removidos. Um único
  `TWiRLClientResource` carrega o caminho inteiro, e a autenticação passou a ser
  feita pelos resources de autenticação do servidor (`WiRL.Core.Auth.Resource`),
  que devolvem um `access_token` que o cliente reenvia como
  `Authorization: Bearer`.

### Compatibilidade com WiRL antigo

Não há. O driver faz corte limpo na revisão acima. Compilação condicional foi
considerada e descartada: os tipos mudaram de unit **e** de nome, o
`TWiRLClientToken` não tem equivalente na versão nova, e manter os dois lados
exigiria uma matriz de compilação que ninguém executa — nenhum projeto de teste
deste repositório compila o driver WiRL hoje.

## Referências de funcionalidade avançada (ESP-002)

| Tópico | Documento |
|--------|-----------|
| Consulta OData (operadores, funções, lógica) | [OData Query Reference](../../odata-reference.md) |
| Atributo `[RESTReadOnly]` | [RESTReadOnly](../../rest-readonly.md) |
| Estratégia de JOIN (RTTI vs VIEW) | [JOIN Strategy](../../rest-join-strategy.md) |
