---
title: Guia - LiveBindings (VCL e FMX)
displayed_sidebar: janusSidebar
---

O Janus oferece atributos de LiveBindings para vincular propriedades de entidades a controles VCL/FMX automaticamente, sem código manual de binding.

## Atributos disponíveis

| Atributo | Uso |
|----------|-----|
| `[LiveBindingsControl('controle', 'campo')]` | Vincula uma propriedade a um controle pelo nome |
| `[LiveBindingsGridMaster('grid')]` | Vincula a entidade como mestre de uma grade |
| `[LiveBindingsGridDetail('grid', 'campoMestre')]` | Vincula como detalhe de uma grade |

## Incluir os controles estendidos

Para VCL, inclua no uses do formulário:

```delphi
uses Janus.VCL.Controls;
// O Janus redefine TEdit, TMaskEdit, TLabel, TComboBox, TMemo
// com suporte automático a LiveBindings
```

Para FMX:

```delphi
uses Janus.FMX.Controls;
```

## Anotar a entidade

```delphi
[Entity]
[Table('client', '')]
Tclient = class
private
  Fclient_name: String;
  Fclient_email: String;
public
  [Column('client_name', ftString, 40)]
  [LiveBindingsControl('EditNome', 'Text')]
  property client_name: String read Fclient_name write Fclient_name;

  [Column('client_email', ftString, 100)]
  [LiveBindingsControl('EditEmail', 'Text')]
  property client_email: String read Fclient_email write Fclient_email;
end;
```

## Ativar o binding no formulário

```delphi
uses Janus.LiveBindings;

procedure TFormCliente.FormCreate(Sender: TObject);
var LBindings: TJanusLivebindings;
begin
  LBindings := TJanusLivebindings.Create(Self);
  LBindings.Bind(LClientEntity);
end;
```

O Janus lê os atributos via RTTI e cria as expressões de binding automaticamente.

## Dicas

- Os nomes nos atributos devem corresponder exatamente ao nome do componente no formulário (`Name` do controle).
- Para grades, use `[LiveBindingsGridMaster]` na entidade pai e `[LiveBindingsGridDetail]` na entidade filha.
- Funciona com VCL e FMX sem alteração no code de negócio.
