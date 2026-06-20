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

unit Janus.Server.DMVC;

{$IFDEF JANUS_REST_DMVC}

interface

uses
  Classes,
  SysUtils,
  Janus.RestComponent,
  /// Janus Conexão
  Janus.Factory.Interfaces,
  /// WiRL
  MVCFramework;

type
  TRESTServerDMVC = class(TJanusComponent)
  private
    class var
    FConnection: IDBConnection;
  private
    FMVCEngine: TMVCEngine;
    procedure SetMVCEngine(const Value: TMVCEngine);
    procedure SetConnection(const AConnection: IDBConnection);
    procedure AddResource;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    class function GetConnection: IDBConnection;
    property Connection: IDBConnection read GetConnection write SetConnection;
  published
    property MVCEngine: TMVCEngine read FMVCEngine write SetMVCEngine;
  end;

implementation

uses
  Janus.Server.Resource.DMVC;

{ TRESTServerDMVC }

procedure TRESTServerDMVC.AddResource;
begin
  if FMVCEngine <> nil then
    FMVCEngine.AddController(TAppResource, '/Janus');
end;

constructor TRESTServerDMVC.Create(AOwner: TComponent);
begin
  inherited;
end;

destructor TRESTServerDMVC.Destroy;
begin
  FMVCEngine := nil;
  inherited;
end;

class function TRESTServerDMVC.GetConnection: IDBConnection;
begin
  Result := FConnection;
end;

procedure TRESTServerDMVC.SetConnection(const AConnection: IDBConnection);
begin
  FConnection := AConnection;
end;

procedure TRESTServerDMVC.SetMVCEngine(const Value: TMVCEngine);
begin
  /// <summary> Atualiza o valor da VAR </summary>
  FMVCEngine := Value;
  /// <summary> Adiciona a App REST no Delphi MVC </summary>
  AddResource;
end;

{$ELSE}
interface
implementation
{$ENDIF}

end.
