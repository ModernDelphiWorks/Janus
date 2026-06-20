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

{$IFDEF JANUS_REST_WIRL}

interface

uses
  Classes,
  SysUtils,
  Janus.RestComponent,
  /// Janus Conexão
  Janus.Factory.Interfaces,
  /// WiRL
  WiRL.Core.Engine;

type
  TRESTServerWiRL = class(TJanusComponent)
  private
    class var
    FConnection: IDBConnection;
  private
    FWiRLEngine: TWiRLEngine;
    procedure SetWiRLEngine(const Value: TWiRLEngine);
    procedure SetConnection(const AConnection: IDBConnection);
    procedure AddResource;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    class function GetConnection: IDBConnection;
    property Connection: IDBConnection read GetConnection write SetConnection;
    property WiRLEngine: TWiRLEngine read FWiRLEngine write SetWiRLEngine;
  published

  end;

implementation

uses
  Janus.Server.Resource.WiRL;

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

procedure TRESTServerWiRL.SetWiRLEngine(const Value: TWiRLEngine);
begin
  /// <summary> Atualiza o valor da VAR </summary>
  FWiRLEngine := Value;
  /// <summary> Adiciona a App REST no WiRL </summary>
  AddResource;
end;

{$ELSE}
interface
implementation
{$ENDIF}

end.
