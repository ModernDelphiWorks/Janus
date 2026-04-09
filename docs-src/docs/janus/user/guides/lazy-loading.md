---
title: Guia - Lazy Loading (Carregamento Adiado)
displayed_sidebar: janusSidebar
---

Lazy Loading adia a carga de entidades relacionadas. O objeto relacionado so e buscado no banco no momento em que voce acessar a propriedade pela primeira vez.

Na `v2.19.0`, o Janus passou a aplicar esse comportamento com proxy transparente nos tres fluxos suportados pelo framework. A `v2.19.3` apenas consolida a documentacao desse contrato ja estabilizado:

- `ObjectSet` para servicos e listas orientadas a objetos.
- `DataSet` para navegacao visual e operacoes em tela.
- `REST` para materializacao de relacionamentos no contexto HTTP.

## Quando usar

- Entidades com associações que nem sempre são necessárias.
- Evitar JOINs desnecessários em listagens.
- Melhorar desempenho de abertura inicial de dados.
- Preservar o caminho explicito `LoadLazy` apenas quando voce precisar manter compatibilidade com fluxo antigo.

## Mapeando uma propriedade lazy

```delphi
uses Janus.Types.Lazy, MetaDbDiff.Mapping.Attributes;

[Entity]
[Table('pedido', '')]
Tpedido = class
private
  Fpedido_id: Integer;
  Fclient: Lazy<Tclient>;    // sera carregado so quando acessado
public
  [Column('pedido_id', ftInteger)]
  property pedido_id: Integer read Fpedido_id write Fpedido_id;

  [Lazy]
  [Association(atManyToOne, [caNone])]
  property client: Lazy<Tclient> read Fclient write Fclient;
end;
```

## Acessando o valor

```delphi
var LPedido: Tpedido;
begin
  LPedido := FContainer.Find(10);

  // Ate aqui: nenhuma query para Tclient foi executada

  // Primeiro acesso -> dispara SELECT automatico no banco
  ShowMessage(LPedido.client.Value.client_name);

  // Segundo acesso -> usa cache, sem nova query
  ShowMessage(LPedido.client.Value.client_id.ToString);
end;
```

## Onde o proxy transparente funciona

| Contexto | Comportamento para o usuario |
|----------|-------------------------------|
| ObjectSet | A propriedade lazy carrega no primeiro acesso em fluxos de sessao orientados a objeto |
| DataSet | A navegacao do registro atual injeta o proxy automaticamente para a entidade materializada |
| REST | O manager REST injeta a factory lazy durante o preenchimento da associacao |

## Compatibilidade com LoadLazy

Se voce ja tem codigo antigo usando `LoadLazy`, ele continua valido. O recurso transparente foi adicionado sem quebrar o caminho explicito.

```delphi
var LPedido: Tpedido;
begin
  LPedido := FContainer.Find(10);
  FContainer.LoadLazy<Tclient>(LPedido);
  ShowMessage(LPedido.client.Value.client_name);
end;
```

## Regra importante: sessão deve estar aberta

O lazy so consegue carregar dados enquanto a sessao/container estiver ativa. Nao guarde a propriedade lazy para acessar depois de fechar o container.

```delphi
// CORRETO
LNome := LPedido.client.Value.client_name;  // container aberto
FContainer.Free;

// ERRADO - dispara excecao ELazyLoadException
FContainer.Free;
LNome := LPedido.client.Value.client_name;  // container já fechado
```

## Como verificar se funcionou

1. Abra a entidade principal com o container ou manager.
2. Acesse a propriedade lazy apenas depois da abertura da sessao.
3. Confirme no monitor SQL que a consulta do relacionamento acontece apenas no primeiro acesso.
4. Acesse a mesma propriedade novamente e confirme que nao houve nova carga desnecessaria.

## Reset automático ao navegar (DataSet)

No contexto de um `DataSet`, quando você navega para um novo registro (ex.: `Next`, `Prior`), o framework automaticamente reseta os proxies do registro anterior. Isso garante que o próximo acesso a uma propriedade lazy carregue os dados corretos do novo registro, sem confundir dados cacheados de registros anteriores.

**Exemplo prático:**

```delphi
LDataSet.First;
LPedido := LDataSet.Current as Tpedido;  // Pedido 10
var LClient1 := LPedido.client.Value;    // Carrega cliente do Pedido 10

LDataSet.Next;                            // Navega para Pedido 20
// Framework reseta proxies do Pedido 10 automaticamente

LPedido := LDataSet.Current as Tpedido;  // Agora é Pedido 20
var LClient2 := LPedido.client.Value;    // Carrega cliente do Pedido 20
// LClient2 é diferente de LClient1, dados corretos são carregados
```

Este comportamento impede bugs silenciosos onde dados antigos permanecem em cache durante navegacao. A regressao dirigida da issue `#95` revalidou nominalmente esse fluxo nos testes `TestProxy_ResetProducesNewLoad` e `TestProxy_ResetAllowsReload`.

## Entidades View (somente-leitura)

Se voce mapear uma entidade apenas com `[View]` sem `[Table]`, o framework reconhece que se trata de um mapeamento de leitura. A partir da `v2.19.2`, os helpers de mapeamento diferenciam esse caso de uma entidade baseada em tabela.

```delphi
[View]  // Sem [Table] — apenas leitura
Tclient_view = class
private
  Fclient_id: Integer;
  Fclient_name: String;
public
  property client_id: Integer read Fclient_id;
  property client_name: String read Fclient_name;
end;
```

Na pratica, isso significa que `GetTable` nao deve expor tabela fisica para essa classe, enquanto o mapeamento de view continua acessivel internamente pelo framework.
