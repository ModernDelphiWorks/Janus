---
title: Guia - LiveBindings (VCL)
displayed_sidebar: janusSidebar
---

O Janus oferece um engine de LiveBindings (R22+) baseado em atributos e em `TJanusBinder` para vincular propriedades de entidades a controles VCL automaticamente, sem necessidade de código manual de binding, herança especial ou truques de ordenação no `uses`.

## TJanusBinder

O `TJanusBinder` é o ponto central do novo engine. Ele lê os atributos `[Bind]` da entidade via RTTI, cria os vínculos e mantém os controles sincronizados.

Padrão de ciclo de vida:

```delphi
// FormCreate
FBinder := TJanusBinder.Create(Self);
FBinder.Bind(FEntidade);    // lê [Bind] via RTTI e cria os links
FBinder.Refresh;            // propaga valores iniciais para os controles

// FormDestroy
FBinder.Free;               // antes de liberar a entidade
```

- `Bind(AEntity)` percorre as propriedades da entidade via RTTI e cria um `TLinkPropertyToField` por anotação `[Bind]` encontrada.
- `Refresh` força a re-leitura do adapter e atualiza todos os controles. Chamar após alterações programáticas nas propriedades da entidade.
- `FBinder` deve ser liberado antes da entidade que foi passada para `Bind`.

## Atributos disponíveis

| Atributo | Uso |
|----------|-----|
| `[Bind('controle', 'propriedade')]` | Vincula uma propriedade da entidade a uma propriedade do controle via `TLinkPropertyToField` |
| `[BindGrid('grid')]` | Declara que a propriedade alimenta uma grade (chamada imperativa: `BindGrid<T>`) |
| `[BindGridDetail('grid', 'propMestre')]` | Declara binding de detalhe (chamada imperativa: `BindMasterDetail<M,D>`) |
| `[BindListControl('controle', 'campo')]` | Declara binding de lista (chamada imperativa: `BindList<T>`) |
| `[BindGridColumn('título', largura, visível)]` | Metadados de coluna para uso com `ConfigureGridColumns` |

:::note
`[BindGrid]`, `[BindGridDetail]` e `[BindListControl]` são declarativos. O dispatch automático via RTTI (equivalente ao que `[Bind]` faz) está previsto para um ciclo futuro; por enquanto, use as chamadas imperativas correspondentes.
:::

## Exemplo: controles simples (VCL)

Entidade (PODO — sem herança especial):

```delphi
unit produto;

interface

uses
  Janus.Binder.Attributes;

type
  TProduto = class
  private
    FID: Integer;
    FPreco: Double;
    FSoma: Double;
    procedure SetID(const AValue: Integer);
    procedure SetPreco(const AValue: Double);
  public
    [Bind('EditID', 'Text')]
    [Bind('LabelID', 'Caption')]
    property ID: Integer read FID write SetID;

    [Bind('EditPreco', 'Text')]
    property Preco: Double read FPreco write SetPreco;

    [Bind('EditSoma', 'Text')]  // campo computado: somente leitura
    property Soma: Double read FSoma;
  end;

implementation

procedure TProduto.SetID(const AValue: Integer);
begin
  FID := AValue;
  FSoma := FID * FPreco;  // recalcula campo derivado
end;

procedure TProduto.SetPreco(const AValue: Double);
begin
  FPreco := AValue;
  FSoma := FID * FPreco;
end;

end.
```

Formulário (trecho):

```delphi
uses Janus.Binder;

type
  TFormPrincipal = class(TForm)
    EditID: TEdit;
    EditPreco: TEdit;
    EditSoma: TEdit;    // somente leitura — campo computado
    LabelID: TLabel;
    BtnAtualizar: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure BtnAtualizarClick(Sender: TObject);
  private
    FProduto: TProduto;
    FBinder: TJanusBinder;
  end;

procedure TFormPrincipal.FormCreate(Sender: TObject);
begin
  FProduto := TProduto.Create;
  FBinder := TJanusBinder.Create(Self);
  FBinder.Bind(FProduto);
  FProduto.ID := 1;
  FProduto.Preco := 10;
  FBinder.Refresh;          // exibe valores iniciais nos controles
  EditSoma.ReadOnly := True; // campo derivado não deve ser editado pelo usuário
end;

procedure TFormPrincipal.FormDestroy(Sender: TObject);
begin
  FBinder.Free;    // libere o binder antes da entidade
  FProduto.Free;
end;

procedure TFormPrincipal.BtnAtualizarClick(Sender: TObject);
begin
  FProduto.ID := FProduto.ID * 2;
  FProduto.Preco := FProduto.Preco * 4.5;
  FBinder.Refresh;  // propaga as alterações programáticas para os controles
end;
```

## Exemplo: grade (VCL)

```delphi
// Entidade com metadados de coluna
type
  TPedido = class
  private
    FId: Integer;
    FDescricao: string;
  published
    [BindGridColumn('Código', 60)]
    property Id: Integer read FId write FId;

    [BindGridColumn('Descrição', 200)]
    property Descricao: string read FDescricao write FDescricao;
  end;

// No formulário
var LPedidos: TObjectList<TPedido>;
begin
  LPedidos := // carregue a lista...
  FBinder.BindGrid<TPedido>(LPedidos, 'GridPedidos');
  FBinder.ConfigureGridColumns('GridPedidos', TPedido);
end;
```

## Exemplo: controle de lista (VCL)

```delphi
FBinder.BindList<TPedido>(LPedidos, 'ListBoxPedidos', 'Descricao');
```

## Metadados de colunas com `[BindGridColumn]`

Campos do atributo:

- `ATitle: string` — título da coluna no cabeçalho da grade.
- `AWidth: Integer` (padrão `-1`) — largura em pixels; `-1` mantém a largura padrão da grade.
- `AVisible: Boolean` (padrão `True`) — se `False`, a coluna é omitida por `ConfigureGridColumns`.

Fluxo de uso:

1. Anote as propriedades `published` da entidade com `[BindGridColumn]`.
2. Chame `FBinder.BindGrid<T>(lista, 'NomeDaGrade')` para criar o vínculo.
3. Chame `FBinder.ConfigureGridColumns('NomeDaGrade', T)` para aplicar os metadados.

:::note
`ConfigureGridColumns` suporta `TStringGrid`. Grades do tipo `TDBGrid` ou de terceiros não são suportadas nesta versão.
:::

## FMX

O suporte a projetos FMX em `TJanusBinder` requer unidades condicionais por plataforma em `Janus.Binder.pas` (que atualmente declara `Vcl.Controls` e `Vcl.Grids`). O engine FMX nativo está previsto para um ciclo futuro. O exemplo FMX legado foi removido junto com o engine legado.
