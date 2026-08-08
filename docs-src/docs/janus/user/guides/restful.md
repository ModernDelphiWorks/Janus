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

### AVISO: o pin é master sem tag, e a última release NÃO serve

`aac8562` é um snapshot do `master`, **à frente de todas as releases**. Quem
instalar WiRL por release recebe outra coisa e **este driver não compila**.

Verificado na API do GitHub em 2026-08-08:

| | Última release `v4.6.0` (2024-05-27) | Pin `aac8562` (master, sem tag) |
|---|---|---|
| `Source/Core/WiRL.Core.Engine.pas` | **existe** | não existe |
| `Source/Core/WiRL.Engine.*.pas` | **nenhum arquivo** | 5 arquivos |
| Motor que hospeda aplicações | `TWiRLEngine` | `TWiRLRESTEngine` |
| `WiRL.Client.Token.pas` | já removido | removido |
| `WiRL.Client.SubResource[.JSON].pas` | já removido | removido |
| `WiRL.Client.Resource.JSON.pas` | já removido | removido |

As duas metades da quebra aconteceram em momentos diferentes:

- **O lado cliente já estava quebrado na `v4.6.0`.** As cinco units de cliente
  que o Janus usava sumiram na release ou antes dela — o código de cliente
  escrito aqui é necessário nos dois casos.
- **A divisão do motor é exclusiva do master.** Contra a `v4.6.0` o nome antigo
  `WiRL.Core.Engine`/`TWiRLEngine` continua sendo o correto.

Consequência prática: para fazer este driver compilar contra a `v4.6.0` basta
uma mudança — a unit e o tipo do motor em `Janus.Server.WiRL.pas`. O resto do
driver serve às duas.

### O que mudou no master

- `WiRL.Core.Engine` foi dividido. O motor virou uma família:
  `TWiRLCustomEngine` (base abstrata, `WiRL.Engine.Core`), `TWiRLRESTEngine`
  (`WiRL.Engine.REST`), `TWiRLHTTPEngine` (`WiRL.Engine.HTTP`),
  `TWiRLFileSystemEngine` (`WiRL.Engine.FileSystem`) e `TWiRLWebServerEngine`
  (`WiRL.Engine.WebServer`). O driver do Janus usa `TWiRLRESTEngine`, que é o
  único que hospeda aplicações e resources — os outros três servem arquivo
  estático ou despacham um evento. Trocar por engano por outro dá erro de
  compilação (`E2003`), não falha silenciosa.
- Os componentes de cliente `TWiRLClientResourceJSON`,
  `TWiRLClientSubResourceJSON` e `TWiRLClientToken` foram removidos (já na
  `v4.6.0`). Um único `TWiRLClientResource` carrega o caminho inteiro.

### Autenticação: capacidade nova, não migrada

O `TWiRLClientToken` extinto POSTava `username`/`password` no corpo, ou seja
falava com o `TWiRLAuthFormResource`. O `AcquireAccessToken` do
`Janus.Client.WiRL.pas` POSTa corpo vazio com cabeçalho `Authorization: Basic`,
ou seja fala com o `TWiRLAuthBasicResource` — **endpoints diferentes**. O
upstream tem três sabores (Form, Basic e Body, em `WiRL.Core.Auth.Resource`).

Portanto isto é **capacidade nova, num sabor de autenticação diferente do
componente extinto, e não exercitada em execução por nada deste repositório**.
Não houve regressão porque o componente antigo era casca: em `f6d6c50` o
`FRESTToken` era declarado, criado, ligado à aplicação e recebia credenciais,
mas nunca era chamado para fazer o POST.

### Compatibilidade com WiRL antigo

Não há. O driver faz corte limpo no pin acima. Compilação condicional foi
considerada e descartada: os tipos mudaram de unit **e** de nome, o
`TWiRLClientToken` não tem equivalente, e manter os dois lados exigiria uma
matriz de compilação que ninguém executa — nenhum projeto de teste deste
repositório compila o driver WiRL hoje.

### Defeitos pré-existentes registrados aqui para não se perderem

Nenhum dos dois é da issue #228 e nenhum foi corrigido:

- **`TRESTServerWiRL.SetWiRLEngine` → `AddResource`
  (`Janus.Server.WiRL.pas:70-73`) sai em silêncio quando
  `Applications.Count = 0`.** Atribuir o engine antes de adicionar a aplicação
  não registra resource nenhum e não acusa erro. Esta é a falha silenciosa
  real — no wiring, não na escolha do motor.
- **`TRESTDriverWiRL` não sobrescreve o abstrato `TRESTDriver.GetFullURL`**
  (`Janus.Client.RestDriver.pas:37`; o driver Horse sobrescreve em
  `Janus.Client.RestDriver.Horse.pas:43`). A compilação acusa `W1020` em
  `Janus.Client.RestWiRL.Factory.pas(53)`; chamar `GetFullURL` neste driver é
  *abstract method error* em execução.

## Referências de funcionalidade avançada (ESP-002)

| Tópico | Documento |
|--------|-----------|
| Consulta OData (operadores, funções, lógica) | [OData Query Reference](../../odata-reference.md) |
| Atributo `[RESTReadOnly]` | [RESTReadOnly](../../rest-readonly.md) |
| Estratégia de JOIN (RTTI vs VIEW) | [JOIN Strategy](../../rest-join-strategy.md) |
