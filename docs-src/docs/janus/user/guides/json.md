---
title: Guia - Serialização JSON
displayed_sidebar: janusSidebar
---

O **TJanusJson** converte entidades Delphi para JSON e vice-versa, usando o mapeamento RTTI da entidade — sem precisar escrever código de serialização manualmente.

## Quando usar

- Enviar ou receber entidades via API REST.
- Salvar estado de um objeto em arquivo ou banco.
- Integrar com sistemas externos que consomem JSON.

## Objeto → JSON

```delphi
uses Janus.Json;

var LClient: Tclient;
    LJson: String;
begin
  LClient := Tclient.Create;
  LClient.client_id := 1;
  LClient.client_name := 'Maria Silva';

  LJson := TJanusJson.ObjectToJsonString(LClient);
  // → {"client_id":1,"client_name":"Maria Silva"}
end;
```

## Lista de objetos → JSON

```delphi
var LList: TObjectList<Tclient>;
    LJson: String;
begin
  LList := FContainer.Find;
  LJson := TJanusJson.ObjectListToJsonString<Tclient>(LList);
  // → [{"client_id":1,...}, {"client_id":2,...}]
end;
```

## JSON → Objeto

```delphi
var LJson: String;
    LClient: Tclient;
begin
  LJson := '{"client_id":1,"client_name":"Joao"}';
  LClient := TJanusJson.JsonToObject<Tclient>(LJson);
end;
```

## Configurações

```delphi
// Usar formato ISO 8601 para datas (padrão para APIs)
TJanusJson.UseISO8601DateFormat := True;

// Incluir nome da classe no JSON
LJson := TJanusJson.ObjectToJsonString(LClient, True);
// → {"$type":"Tclient","client_id":1,...}
```

## Dica

O Janus usa o **JsonFlow** internamente para construção do JSON. As propriedades mapeadas com `[Column]` são incluídas automaticamente. Propriedades sem `[Column]` são ignoradas.
