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

unit JanusOracle.Provider;

interface

uses
  System.SysUtils,
  System.Classes,
  DataEngine.FactoryInterfaces,
  DataEngine.FactoryFireDAC,
  Janus.DML.Generator.Oracle,
  Janus.Server.Horse,
  Janus.Server.RestView.Manager,
  FluentSQL,
  FluentSQL.Interfaces,
  DM.Oracle.Connection,
  JanusOracle.Interfaces,
  Janus.Oracle.Model.PedidosCompletos;

type
  TProviderOracleJanus = class(TInterfacedObject, IProvider)
  private
    FRESTServerHorse: TRESTServerHorse;
    FConnection: IDBConnection;
    FProviderDM: TOracleProviderDM;
  public
    constructor Create;
    destructor Destroy; override;
  end;

implementation

{ TProviderOracleJanus }

constructor TProviderOracleJanus.Create;
var
  LSelect: IFluentSQL;
begin
  FProviderDM := TOracleProviderDM.Create(nil);
  FConnection := TFactoryFireDAC.Create(FProviderDM.FDConnection1, dnOracle);
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
  FRESTServerHorse := TRESTServerHorse.Create(nil, FConnection, 'api/Janus');
end;

destructor TProviderOracleJanus.Destroy;
begin
  FreeAndNil(FRESTServerHorse);
  FreeAndNil(FProviderDM);
  inherited;
end;

end.
