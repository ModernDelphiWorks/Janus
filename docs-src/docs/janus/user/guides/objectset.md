---
title: Guia - ObjectSet (Sem DataSet Visual)
displayed_sidebar: janusSidebar
---

O **ObjectSet** é o container headless do Janus — persiste objetos Delphi diretamente sem necessidade de TDataSet ou componentes visuais. Ideal para serviços, APIs e processos batch.

## Quando usar

- Serviços REST/API sem formulário visual.
- Processamento em lote (importação, exportação).
- Casos onde não há grade ou formulário ligado a um DataSet.

## Passo a passo

### 1. Instanciar o container

```delphi
uses Janus.Container.ObjectSet;

FContainer := TContainerObjectSet<Tclient>.Create(FConn);
```

### 2. Buscar registros

```delphi
// Todos os registros
var LClients: TObjectList<Tclient>;
LClients := FContainer.Find;

// Por ID
var LClient: Tclient;
LClient := FContainer.Find(42);

// Com filtro SQL
LClients := FContainer.FindWhere('ativo = 1', 'client_name');
```

### 3. Inserir, atualizar e excluir

```delphi
// Inserir
var LNew: Tclient;
LNew := Tclient.Create;
LNew.client_name := 'Novo Cliente';
FContainer.Insert(LNew);

// Atualizar
LClient.client_name := 'Nome Atualizado';
FContainer.Update(LClient);

// Excluir
FContainer.Delete(LClient);
```

### 4. Paginação com NextPacket

```delphi
// Primeira página (pageSize=20)
var LPage: TObjectList<Tclient>;
LPage := FContainer.NextPacket(20, 1);

// Próxima página
LPage := FContainer.NextPacket(20, 2);
```

## Diferença entre DataSet e ObjectSet

| | DataSet | ObjectSet |
|-|---------|----------|
| Vinculação visual | Sim (grid, campos) | Não |
| Tipo de retorno | TDataSet | TObjectList\<T\> |
| Uso típico | Telas VCL/FMX | Serviços, APIs, batch |
| ApplyUpdates | Sim | Não (operações diretas) |
