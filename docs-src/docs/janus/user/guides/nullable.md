---
title: Guia - Campos Opcionais com Nullable
displayed_sidebar: janusSidebar
---

`Nullable<T>` permite mapear campos do banco que podem ser NULL para propriedades tipadas em Delphi, sem usar `Variant` ou verificações manuais.

## Tipos prontos disponíveis

```delphi
uses Janus.Types.Nullable;

// Aliases já definidos no framework:
NullString    = Nullable<String>
NullBoolean   = Nullable<Boolean>
NullInteger   = Nullable<Integer>
NullInt64     = Nullable<Int64>
NullDouble    = Nullable<Double>
NullCurrency  = Nullable<Currency>
NullDate      = Nullable<TDate>
NullDateTime  = Nullable<TDateTime>
```

## Mapeando na entidade

```delphi
[Entity]
[Table('client', '')]
Tclient = class
private
  Fclient_id: Integer;
  Fdiscounted_pct: NullDouble;   // pode ser NULL no banco
  Fobservation: NullString;
public
  [Column('client_id', ftInteger)]
  property client_id: Integer read Fclient_id write Fclient_id;

  [Column('discounted_pct', ftBCD)]
  property discounted_pct: NullDouble read Fdiscounted_pct write Fdiscounted_pct;

  [Column('observation', ftString, 200)]
  property observation: NullString read Fobservation write Fobservation;
end;
```

## Lendo e escrevendo o valor

```delphi
// Verificar se tem valor antes de ler
if LClient.discounted_pct.HasValue then
  ShowMessage(LClient.discounted_pct.Value.ToString);

// Ler com default se NULL
var LPct: Double := LClient.discounted_pct.GetValueOrDefault(0.0);

// Atribuir valor
LClient.discounted_pct := 5.5;

// Atribuir NULL
LClient.discounted_pct := Nullable<Double>(Null);
```

## Comparação

```delphi
// Operadores = e <> funcionam normalmente
if LClient.discounted_pct = LOutro.discounted_pct then ...
```

> O Janus detecta `Nullable<T>` via RTTI e envia NULL ao banco quando `HasValue = False`.
