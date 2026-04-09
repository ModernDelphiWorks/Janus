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
