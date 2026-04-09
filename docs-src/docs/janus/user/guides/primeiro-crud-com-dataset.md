---
title: Guia - Primeiro CRUD com DataSet
displayed_sidebar: janusSidebar
---

Este guia mostra o fluxo minimo para abrir dados, editar registros e persistir alteracoes usando container DataSet do Janus.

## Quando usar este fluxo

- Tela de cadastro em VCL/FMX.
- Manutencao de tabelas com edicao em grade.
- Cenarios com integracao direta em TFDMemTable ou TClientDataSet.

## Passo a passo

1. Configure a conexao com o banco via DataEngine.
2. Instancie o container DataSet tipado pela entidade.
3. Abra os dados com Open.
4. Edite ou inclua registros no DataSet.
5. Persista no banco com ApplyUpdates(0).

```delphi
uses
  DataEngine.FactoryInterfaces,
  DataEngine.FactoryFireDac,
  Janus.Container.FDMemTable,
  Janus.Model.Client;

procedure TFormCliente.FormCreate(Sender: TObject);
begin
  FConn := TFactoryFireDAC.Create(FDConnection1, dnSQLite);
  FContainerClient := TContainerFDMemTable<Tclient>.Create(FConn, FDClient);
  FContainerClient.Open;
end;

procedure TFormCliente.BtnSalvarClick(Sender: TObject);
begin
  FContainerClient.ApplyUpdates(0);
end;
```

## Boas praticas operacionais

- Valide campos obrigatorios antes do ApplyUpdates(0).
- Mantenha monitor de comandos SQL ativo em ambiente de homologacao para diagnostico.
- Trate excecoes de persistencia apresentando mensagem amigavel para o usuario final.

## Resultado esperado

- Os registros editados no DataSet sao gravados no banco.
- O modelo permanece desacoplado de SQL manual para operacoes comuns.
