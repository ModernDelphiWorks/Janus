---
displayed_sidebar: janusSidebar
title: Middleware e Plugins
---

## Middleware — interceptação de DML

O sistema de middleware permite executar callbacks antes e depois de cada operação DML. Útil para auditoria, validação e cancelamento.

### Registrar um middleware

```delphi
uses Janus.Register.Middleware;

// Callback simples (TEvent)
TMiddlewareRegister.RegisterEvent(
  'client',                          // recurso (entidade)
  TJanusEventType.onBeforeInsert,    // tipo de evento
  procedure(AEntity: TObject)
  begin
    // validar ou modificar AEntity antes do INSERT
  end
);
```

### Middleware com contexto (IJanusHookContext)

```delphi
TMiddlewareRegister.RegisterContextEvent(
  'client',
  TJanusEventType.onBeforeDelete,
  0,  // prioridade
  procedure(ACtx: IJanusHookContext)
  begin
    if not TemPermissao then
      ACtx.Abort;  // cancela a operação
  end
);
```

`IJanusHookContext` expõe:
- `OperationType: TJanusEventType`
- `EntityClass: TClass`
- `Entity: TObject`
- `Aborted: Boolean`
- `Metadata: TDictionary<String, TValue>`

### QueryScope — filtros globais

```delphi
TMiddlewareQueryScope.Register(
  'client',
  function(const AResource: String): TQueryScopeList
  var LList: TQueryScopeList;
  begin
    LList := TQueryScopeList.Create;
    LList.Add('ativo', function: String begin Result := 'ativo = 1' end);
    Result := LList;
  end
);
```

## Plugins

Plugins ampliam o comportamento do Janus sem alterar o core.

```delphi
uses Janus.Plugin.Interfaces, Janus.Plugin.Registry;

// Implementar interface de plugin e registrar:
TPluginRegistry.Register(TMyPlugin.Create);
```

Ver testes: `TestPluginRegistry`, `TestPluginIntegration`, `TestMiddlewarePipeline`.
