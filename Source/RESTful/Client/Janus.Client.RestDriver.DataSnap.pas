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

unit Janus.Client.RestDriver.DataSnap;

{$IFDEF JANUS_REST_DATASNAP}

interface

uses
  Classes,
  SysUtils,
  Janus.Client.DataSnap,
  Janus.Client.RestDriver,
  Janus.Client.Methods;

type
  /// <summary>
  /// Classe de conexão concreta com dbExpress
  /// </summary>
  TRESTDriverDatasnap = class(TRESTDriver)
  protected
    FConnection: TRESTClientDataSnap;
  public
    constructor Create(AConnection: TComponent); override;
    destructor Destroy; override;
    function GetBaseURL: string; override;
    function GetMethodGET: string; override;
    function GetMethodGETId: string; override;
    function GetMethodGETWhere: string; override;
    function GetMethodPOST: string; override;
    function GetMethodPUT: string; override;
    function GetMethodDELETE: string; override;
    function GetMethodGETNextPacket: string; override;
    function GetMethodGETNextPacketWhere: string; override;
    function GetServerUse: Boolean; override;
    function Execute(const AResource, ASubResource: string;
      const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc = nil): string; overload; override;
    procedure SetClassNotServerUse(const Value: Boolean); override;
    procedure AddParam(const AValue: string); override;
    procedure AddQueryParam(const AValue: string); override;
    procedure AddBodyParam(const AValue: string); override;
  end;

implementation

{ TDriverRestDatasnap }

procedure TRESTDriverDatasnap.AddBodyParam(const AValue: string);
begin
  inherited;
  FConnection.AddBodyParam(AValue);
end;

procedure TRESTDriverDatasnap.AddParam(const AValue: string);
begin
  inherited;
  FConnection.AddParam(AValue);
end;

procedure TRESTDriverDatasnap.AddQueryParam(const AValue: string);
begin
  inherited;
  FConnection.AddQueryParam(AValue);
end;

constructor TRESTDriverDatasnap.Create(AConnection: TComponent);
begin
  inherited;
  FConnection := AConnection as TRESTClientDataSnap;
end;

destructor TRESTDriverDatasnap.Destroy;
begin
  FConnection := nil;
  inherited;
end;

function TRESTDriverDatasnap.Execute(const AResource, ASubResource: string;
  const ARequestMethod: TRESTRequestMethodType; const AParams: TProc): string;
begin
  Result := FConnection
              .Execute(AResource, ASubResource, ARequestMethod, AParams);
end;

function TRESTDriverDatasnap.GetBaseURL: string;
begin
  Result := FConnection.BaseURL;
end;

function TRESTDriverDatasnap.GetMethodDELETE: string;
begin
  Result := FConnection.MethodDelete;
end;

function TRESTDriverDatasnap.GetMethodPOST: string;
begin
  Result := FConnection.MethodPOST;
end;

function TRESTDriverDatasnap.GetMethodGETNextPacket: string;
begin
  Result := FConnection.MethodGETNextPacket;
end;

function TRESTDriverDatasnap.GetMethodGETNextPacketWhere: string;
begin
  Result := FConnection.MethodGETNextPacketWhere;
end;

function TRESTDriverDatasnap.GetMethodGET: string;
begin
  Result := FConnection.MethodGET;
end;

function TRESTDriverDatasnap.GetMethodGETId: string;
begin
  Result := FConnection.MethodGETId;
end;

function TRESTDriverDatasnap.GetMethodGETWhere: string;
begin
  Result := FConnection.MethodGETWhere;
end;

function TRESTDriverDatasnap.GetMethodPUT: string;
begin
  Result := FConnection.MethodPUT;
end;

function TRESTDriverDatasnap.GetServerUse: Boolean;
begin
  Result := FConnection.JanusServerUse;
end;

procedure TRESTDriverDatasnap.SetClassNotServerUse(const Value: Boolean);
begin
  FConnection.SetClassNotServerUse(Value);
end;

{$ELSE}
interface
implementation
{$ENDIF}

end.
