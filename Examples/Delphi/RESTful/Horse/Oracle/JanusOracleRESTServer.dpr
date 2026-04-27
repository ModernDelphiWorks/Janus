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

program JanusOracleRESTServer;

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  System.Classes,
  FireDAC.ConsoleUI.Wait,
  FireDAC.Phys.Oracle,
  FireDAC.Phys.OracleDef,
  Janus.DML.Generator.Oracle,
  MetaDbDiff.Mapping.Register,
  DataEngine.FactoryInterfaces,
  DataEngine.FactoryFireDAC,
  Horse,
  Horse.Core.RouterTree,
  Janus.Oracle.Model.Cliente     in 'models\Janus.Oracle.Model.Cliente.pas',
  Janus.Oracle.Model.Produto     in 'models\Janus.Oracle.Model.Produto.pas',
  Janus.Oracle.Model.Pedido      in 'models\Janus.Oracle.Model.Pedido.pas',
  Janus.Oracle.Model.PedidosCompletos in 'models\Janus.Oracle.Model.PedidosCompletos.pas',
  JanusOracle.Interfaces         in 'providers\JanusOracle.Interfaces.pas',
  DM.Oracle.Connection           in 'providers\DM.Oracle.Connection.pas',
  JanusOracle.Provider           in 'providers\JanusOracle.Provider.pas';

procedure _RegisterModels;
begin
  TRegisterClass.RegisterEntity(TModelCliente);
  TRegisterClass.RegisterEntity(TModelProduto);
  TRegisterClass.RegisterEntity(TModelPedido);
  TRegisterClass.RegisterEntity(TModelPedidosCompletos);
end;

var
  LProvider: IProvider;
  LThread: TThread;
  LOldRoutes: THorseRouterTree;
  LNewRoutes: THorseRouterTree;
begin
  IsMultiThread := True;
  _RegisterModels;
  LProvider := TProviderOracleJanus.Create;
  LThread := TThread.CreateAnonymousThread(
    procedure
    begin
      THorse.Listen(9100);
    end);
  LThread.FreeOnTerminate := True;
  LThread.Start;
  Sleep(300);
  Writeln('=== JanusOracleRESTServer ===');
  Writeln('Server : http://127.0.0.1:9100/api/Janus');
  Writeln('View   : vw_pedidos_completos auto-created via TRESTViewManager');
  Writeln('Press ENTER to exit...');
  Readln;
  THorse.StopListen;
  LOldRoutes := THorse.Routes;
  LNewRoutes := THorseRouterTree.Create;
  THorse.Routes := LNewRoutes;
  LOldRoutes.Free;
  LProvider := nil;
end.
