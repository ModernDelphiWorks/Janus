{
  ------------------------------------------------------------------------------
  Janus ORM
  State-of-the-art Object-Relational Mapping (ORM) framework for Delphi.

  SPDX-License-Identifier: MIT
  Copyright (c) 2025-2026 Isaque Pinheiro

  Licensed under the MIT License.
  See the LICENSE file in the project root for full license information.
  ------------------------------------------------------------------------------
}

{
  @abstract(REST Componentes)
  @created(20 Jun 2018)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Janus.Server.WiRL;

interface

uses
  Classes,
  SysUtils,
  Janus.RestComponent,
  /// Janus Conexao
  DataEngine.FactoryInterfaces,
  /// WiRL
  /// Pinned to delphi-blocks/WiRL @ aac8562c810b98fef590f3035f56bdf9ea3bad76
  /// (2026-07-13), registered in docs-src/docs/janus/user/guides/restful.md.
  /// WiRL.Core.Engine was split into four engines; TWiRLRESTEngine
  /// (WiRL.Engine.REST) is the only one that hosts applications and resources,
  /// which is exactly what this component needs.
  WiRL.Engine.REST;

type
  TRESTServerWiRL = class(TJanusComponent)
  private
    class var
    FConnection: IDBConnection;
  private
    FWiRLEngine: TWiRLRESTEngine;
    procedure SetWiRLEngine(const Value: TWiRLRESTEngine);
    procedure SetConnection(const AConnection: IDBConnection);
    procedure AddResource;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    class function GetConnection: IDBConnection;
    property Connection: IDBConnection read GetConnection write SetConnection;
    property WiRLEngine: TWiRLRESTEngine read FWiRLEngine write SetWiRLEngine;
  published

  end;

implementation

uses
  Janus.Server.Resource.WiRL,
  /// <summary> Obrigatoria: o lado servidor serializa TODA resposta pelo
  ///   registro de MessageBodyWriter da APLICACAO
  ///   (TWiRLApplicationWorker.InternalHandleRequest ->
  ///   FAppConfig.WriterRegistry.FindWriter, WiRL.Core.Application.Worker.pas:
  ///   524-537), e esse registro por aplicacao e semeado do singleton GLOBAL
  ///   em TWiRLApplication.Startup (WiRL.Core.Application.pas:445-453). Sem
  ///   esta unit linkada o global fica vazio, a aplicacao herda vazio e o WiRL
  ///   levanta EWiRLServerException 'MessageBodyWriters registry is empty'
  ///   (WiRL.Core.MessageBodyWriter.pas:206-213) em toda chamada de
  ///   TAppResource, GET inclusive - e ate a serializacao do proprio erro cai
  ///   no mesmo buraco (WiRL.Core.Exceptions.pas:505, overload de :198-203).
  ///   A unit registra writers e readers padrao na sua initialization
  ///   (WiRL.Core.MessageBody.Default.pas:693-694); referencia-la e o que
  ///   garante o link. Ate agora so nao quebrava porque o app da aplicacao
  ///   lembrava de cita-la - o exemplo faz isso em Server.Forms.Main.pas:27 e
  ///   Server.Resources.pas:26 - e o driver nao pode depender dessa memoria.
  ///   Vale por Janus.Server.Resource.WiRL tambem: as duas units se citam
  ///   mutuamente na implementation, entao linkam sempre juntas.
  ///   Medido em harness sem a unit no .dpr: 0/0 writers/readers e HTTP 500
  ///   com a mensagem acima num GET; com ela, 9/6 e o GET chega ao recurso.
  /// </summary>
  WiRL.Core.MessageBody.Default;

{ TRESTServerWiRL }

procedure TRESTServerWiRL.AddResource;
begin
  if FWiRLEngine = nil then
    Exit;
  if FWiRLEngine.Applications.Count = 0 then
    Exit;
  FWiRLEngine.Applications
             .Items[0]
             .Application
             .SetResources('Janus.Server.Resource.WiRL.TAppResource');
end;

constructor TRESTServerWiRL.Create(AOwner: TComponent);
begin
  inherited;
end;

destructor TRESTServerWiRL.Destroy;
begin
  FWiRLEngine := nil;
  inherited;
end;

class function TRESTServerWiRL.GetConnection: IDBConnection;
begin
  Result := FConnection;
end;

procedure TRESTServerWiRL.SetConnection(const AConnection: IDBConnection);
begin
  FConnection := AConnection;
end;

procedure TRESTServerWiRL.SetWiRLEngine(const Value: TWiRLRESTEngine);
begin
  /// <summary> Atualiza o valor da VAR </summary>
  FWiRLEngine := Value;
  /// <summary> Adiciona a App REST no WiRL </summary>
  AddResource;
end;

end.
