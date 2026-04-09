---
displayed_sidebar: janusSidebar
title: Lazy Loading
---

## Conceito

Lazy Loading adia a carga de associações até o primeiro acesso. A partir da `v2.19.0`, o Janus injeta automaticamente um proxy transparente quando a propriedade tem o atributo `[Lazy]` e o tipo `Lazy<T>`.

O mesmo contrato agora vale para os três contextos suportados pelo framework:

- `ObjectSet`: o carregamento transparente ocorre no fluxo orientado a objetos.
- `DataSet`: o scroll da linha atual injeta proxies para associações lazy e mantém as associações não lazy em abertura ansiosa.
- `REST`: `TRESTObjectManager.FillAssociation` injeta factories lazy em vez de pular a associação.

Na R17.2, o framework endurece apenas a implementação interna desse fluxo. A `v2.19.3` consolida a documentacao e a rastreabilidade desse comportamento sem redefinir a API publica.

## Mapeamento

```delphi
uses Janus.Types.Lazy, MetaDbDiff.Mapping.Attributes;

[Entity]
[Table('pedido', '')]
Tpedido = class
private
  Fpedido_id: Integer;
  Fclient: Lazy<Tclient>;
public
  [Column('pedido_id', ftInteger)]
  property pedido_id: Integer read Fpedido_id write Fpedido_id;

  [Lazy]
  [Association(atManyToOne, [caNone])]
  property client: Lazy<Tclient> read Fclient write Fclient;
end;
```

## Acesso ao valor

```delphi
var LPedido: Tpedido;
    LClient: Tclient;
begin
  LPedido := LSession.Find<Tpedido>(42);

  // Primeiro acesso -> dispara SELECT automático
  LClient := LPedido.client.Value;
  // Acessos subsequentes: usa cache (sem nova query)
end;
```

O proxy carrega uma única vez por instância e reutiliza o valor nas leituras seguintes.

## Compatibilidade com LoadLazy explícito

O caminho explícito continua suportado para retrocompatibilidade. A `v2.19.0` adiciona o comportamento transparente, mas não quebra o fluxo anterior.

```delphi
var LPedido: Tpedido;
begin
  LPedido := LSession.Find<Tpedido>(42);
  LSession.LoadLazy<Tclient>(LPedido);
  ShowMessage(LPedido.client.Value.client_name);
end;
```

## Ciclo de vida — ILazySessionToken

O proxy precisa da sessão ativa para carregar dados. Ao fechar a sessão, o token é invalidado e qualquer acesso posterior lança `ELazyLoadException`.

```delphi
// Correto: acessar dentro do escopo da sessão
LClient := LPedido.client.Value;  // OK — sessão aberta

LSession.Free;

LClient := LPedido.client.Value;  // → ELazyLoadException (sessão fechada)
```

## Multiplicidades suportadas

- `OneToOne` e `ManyToOne`: o proxy retorna um único objeto.
- `OneToMany` e `ManyToMany`: o proxy retorna uma coleção tipada.

O contrato foi validado nos testes de multiplicidade para ObjectSet, DataSet e REST.

## Reset e reinjeção

O reset de proxy existe via `ILazyProxyResettable`, mas esse contrato é usado internamente pelo framework para cenários como mudança de PK no DataSet ou reinjeção idempotente no REST. Para código de aplicação, o fluxo recomendado continua sendo acessar `.Value` com a sessão viva.

Na `v2.19.2`, o ciclo interno de reset foi estabilizado para garantir novo carregamento deterministico apos `Reset`, sem reutilizar o valor antigo em cenarios como `Invoke -> Reset -> Invoke`.

Nos testes de regressao, esse contrato aparece de forma objetiva:

- `TestSmokeLazyLoading.TestProxy_ResetAllowsReload`: `Reset` marca `IsValueCreated = False` e o `Invoke` seguinte usa a nova factory.
- `TestDataSetLazyProxy.TestProxy_ResetProducesNewLoad`: o proximo `Invoke` apos `Reset` retorna uma nova instancia, nao o objeto anterior em cache.
- `TestMappingCache.TestHelperGetTable_ReturnsNilForViewEntity`: entidades anotadas apenas com `[View]` nao expoem tabela fisica via `GetTable`.

Ver testes: `TestSmokeLazyLoading`, `TestDataSetLazyProxy`, `TestRestLazyProxy`, `TestLazyProxyMultiplicity`, `TestDataSetAutoLazy`.

### Comportamento após reset

Quando o proxy é explicitamente resetado (por exemplo, ao navegar para um novo registro no DataSet), o próximo acesso a `.Value` dispara uma nova consulta SQL, não reutilizando o valor anterior em cache. Isso garante consistência de dados quando o contexto muda (ex.: mudança de chave primária).

**Cenário validado (v2.19.2):** Recarregar uma associação lazy após mudança de chave do registro principal no DataSet:

```delphi
LPedido := LDataSet.Current as Tpedido;  // Pedido 10
var LClient1 := LPedido.client.Value;    // Carrega cliente do Pedido 10

// Navega para outro pedido (chave muda)
LDataSet.Next;
// Framework injeta proxy novo e reseta o anterior automaticamente

LPedido := LDataSet.Current as Tpedido;  // Pedido 20
var LClient2 := LPedido.client.Value;    // Carrega cliente do Pedido 20
// LClient2 não é o cache de LClient1, mas sim nova query
```

## Entidades marcadas apenas com [View]

Entidades anotadas com o atributo `[View]` sao tratadas como mapeamentos de leitura. A partir da `v2.19.2`, o caminho de RTTI/cache diferencia corretamente entidades `view-only` de entidades com `[Table]`.

**Comportamento esperado:** uma entidade com apenas `[View]` sem `[Table]` nao expoe tabela fisica via `TObjectHelper.GetTable`, e o mapeamento de view continua disponivel por `TMappingExplorer.GetMappingView`.

Ver teste: `TestMappingCache.TestHelperGetTable_ReturnsNilForViewEntity` (v2.19.2).
