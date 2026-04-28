{
  ------------------------------------------------------------------------------
  Janus
  Modern Object-Relational Mapping (ORM) framework for Delphi.

  SPDX-License-Identifier: MIT
  Copyright (c) 2016-2026 Isaque Pinheiro

  Licensed under the MIT License.
  See the LICENSE file in the project root for full license information.
  ------------------------------------------------------------------------------
}

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit RestHorseOracleTest.Base;

interface

uses
  SysUtils,
  Classes,
  DUnitX.TestFramework,
  DataEngine.FactoryInterfaces,
  FireDAC.Comp.Client,
  MetaDbDiff.Mapping.Register,
  Janus.Server.Horse,
  Horse;

type
  TRestHorseOracleTestBase = class
  private
    FDConnection: TFDConnection;
    FConnection: IDBConnection;
    FHorseDConnection: TFDConnection;
    FHorseConnection: IDBConnection;
    FServer: TRESTServerHorse;
    FPort: Integer;
    FServerThread: TThread;
    procedure _StartHorse;
    procedure _StopHorse;
    procedure _RegisterOracleEntities;
  protected
    FPrefix: string;
    property Connection: IDBConnection read FConnection;
    property Port: Integer read FPort;
    procedure SeedOracleData;
    procedure DropView(const AViewName: string);
    function BuildResourceURL(const AResource: string): string;
    function ViewExists(const AViewName: string): Boolean;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
  end;

implementation

uses
  DataEngine.FactoryFireDAC,
  // FireDAC infrastructure units — required for Oracle driver registration.
  // These units register drivers and UI providers in their initialization
  // sections; no symbols are directly referenced in this file.
  FireDAC.Stan.Def,
  FireDAC.Stan.Intf,
  FireDAC.Phys,
  FireDAC.Phys.Oracle,
  FireDAC.Phys.OracleDef,
  FireDAC.ConsoleUI.Wait,
  FireDAC.Stan.Async,
  FireDAC.Comp.DataSet,
  Horse.Core.RouterTree,
  Janus.Oracle.Model.Cliente,
  Janus.Oracle.Model.Produto,
  Janus.Oracle.Model.Pedido,
  Janus.Oracle.Model.PedidosCompletos,
  Janus.DML.Generator.Oracle,
  Janus.Server.RestView.Manager,
  FluentSQL,
  FluentSQL.Interfaces;

{ TRestHorseOracleTestBase }

procedure TRestHorseOracleTestBase._RegisterOracleEntities;
var
  LSelect: IFluentSQL;
begin
  TRegisterClass.RegisterEntity(TModelCliente);
  TRegisterClass.RegisterEntity(TModelProduto);
  TRegisterClass.RegisterEntity(TModelPedido);
  TRegisterClass.RegisterEntity(TModelPedidosCompletos);
  LSelect := FluentSQL.Query(dbnOracle)
    .Select('p.id_pedido')
    .Select('p.data_pedido')
    .Select('c.id_cliente')
    .Select('c.nome AS cliente_nome')
    .Select('c.cidade AS cliente_cidade')
    .Select('pr.id_produto')
    .Select('pr.descricao AS produto_descricao')
    .Select('pr.categoria AS produto_categoria')
    .Select('pr.preco AS produto_preco')
    .Select('p.quantidade')
    .Select('p.valor_total')
    .From('pedidos p')
    .InnerJoin('clientes c')
    .OnCond('c.id_cliente = p.id_cliente')
    .InnerJoin('produtos pr')
    .OnCond('pr.id_produto = p.id_produto');
  TRESTViewManager.Register(TModelPedidosCompletos,
    function: IFluentSQL
    begin
      Result := LSelect;
    end);
end;

procedure TRestHorseOracleTestBase._StartHorse;
begin
  FPort := 9700 + Random(100);
  FServer := TRESTServerHorse.Create(nil, FHorseConnection, FPrefix);
  FServerThread := TThread.CreateAnonymousThread(
    procedure
    begin
      THorse.Listen(FPort);
    end);
  FServerThread.FreeOnTerminate := False;
  FServerThread.Start;
  Sleep(200);
end;

procedure TRestHorseOracleTestBase._StopHorse;
begin
  THorse.StopListen;
  if Assigned(FServerThread) then
  begin
    FServerThread.Terminate;
    FServerThread.WaitFor;
    FreeAndNil(FServerThread);
  end;
  FreeAndNil(FServer);
end;

procedure TRestHorseOracleTestBase.SeedOracleData;
begin
  FDConnection.ExecSQL(
    'MERGE INTO clientes c ' +
    'USING DUAL ON (c.id_cliente = 1) ' +
    'WHEN NOT MATCHED THEN INSERT (id_cliente, nome, email, cidade, data_cadastro) ' +
    'VALUES (1, ''Cliente Teste'', ''teste@teste.com'', ''Sao Paulo'', SYSDATE)');
  FDConnection.ExecSQL(
    'MERGE INTO produtos p ' +
    'USING DUAL ON (p.id_produto = 1) ' +
    'WHEN NOT MATCHED THEN INSERT (id_produto, descricao, preco, categoria) ' +
    'VALUES (1, ''Produto Teste'', 99.99, ''Categoria A'')');
  FDConnection.ExecSQL(
    'MERGE INTO pedidos p ' +
    'USING DUAL ON (p.id_pedido = 1) ' +
    'WHEN NOT MATCHED THEN INSERT (id_pedido, id_cliente, id_produto, quantidade, valor_total, data_pedido) ' +
    'VALUES (1, 1, 1, 2, 199.98, SYSDATE)');
end;

procedure TRestHorseOracleTestBase.DropView(const AViewName: string);
begin
  FDConnection.ExecSQL(
    'BEGIN EXECUTE IMMEDIATE ''DROP VIEW ' + AViewName + '''; ' +
    'EXCEPTION WHEN OTHERS THEN NULL; END;');
end;

function TRestHorseOracleTestBase.BuildResourceURL(const AResource: string): string;
begin
  if FPrefix <> '' then
    Result := Format('http://127.0.0.1:%d/%s/%s', [FPort, FPrefix, AResource])
  else
    Result := Format('http://127.0.0.1:%d/%s', [FPort, AResource]);
end;

function TRestHorseOracleTestBase.ViewExists(const AViewName: string): Boolean;
var
  LQuery: TFDQuery;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FDConnection;
    LQuery.SQL.Text :=
      'SELECT COUNT(1) FROM user_views WHERE view_name = UPPER(:VNAME)';
    LQuery.ParamByName('VNAME').AsString := AViewName;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger > 0;
  finally
    LQuery.Free;
  end;
end;

procedure TRestHorseOracleTestBase.SetupFixture;
begin
  Randomize;
  FDConnection := TFDConnection.Create(nil);
  FDConnection.Params.DriverID := 'Ora';
  FDConnection.Params.Values['Server'] := 'localhost';
  FDConnection.Params.Values['Port'] := '1521';
  FDConnection.Params.Values['Database'] := 'XE';
  FDConnection.Params.Values['User_Name'] := 'LOCAL';
  FDConnection.Params.Values['Password'] := 'local';
  FDConnection.Connected := True;
  FConnection := TFactoryFireDAC.Create(FDConnection, dnOracle);
  FHorseDConnection := TFDConnection.Create(nil);
  FHorseDConnection.Params.DriverID := 'Ora';
  FHorseDConnection.Params.Values['Server'] := 'localhost';
  FHorseDConnection.Params.Values['Port'] := '1521';
  FHorseDConnection.Params.Values['Database'] := 'XE';
  FHorseDConnection.Params.Values['User_Name'] := 'LOCAL';
  FHorseDConnection.Params.Values['Password'] := 'local';
  FHorseDConnection.Connected := True;
  FHorseConnection := TFactoryFireDAC.Create(FHorseDConnection, dnOracle);
  _RegisterOracleEntities;
  _StartHorse;
end;

procedure TRestHorseOracleTestBase.TearDownFixture;
var
  LOldRoutes: THorseRouterTree;
  LNewRoutes: THorseRouterTree;
begin
  _StopHorse;
  LOldRoutes := THorse.Routes;
  LNewRoutes := THorseRouterTree.Create;
  THorse.Routes := LNewRoutes;
  LOldRoutes.Free;
  TRESTViewManager.ClearCache;
  FHorseConnection := nil;
  FHorseDConnection.Connected := False;
  FreeAndNil(FHorseDConnection);
  FConnection := nil;
  FDConnection.Connected := False;
  FreeAndNil(FDConnection);
end;

procedure TRestHorseOracleTestBase.Setup;
begin
  // intentionally empty — override in subclasses if per-test setup is needed
end;

procedure TRestHorseOracleTestBase.TearDown;
begin
  // intentionally empty — override in subclasses if per-test teardown is needed
end;

end.
