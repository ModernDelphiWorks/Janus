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

unit Janus.Client.RestDriver.MARS;

{$IFDEF JANUS_REST_MARS}

interface

uses
  Classes,
  SysUtils,
  Janus.Client.MARS,
  Janus.Client.Methods,
  Janus.Driver.REST;

type
  /// <summary>
  /// Classe de conexão concreta com MARS
  /// </summary>
  TRESTDriverMARS = class(TRESTDriver)
  protected
    FConnection: TRESTClientMARS;
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
      const ARequestMethod: TRESTRequestMethodType; const AParams: TProc = nil): string; overload; override;
    procedure SetClassNotServerUse(const Value: Boolean); override;
    procedure AddParam(const AValue: string); override;
    procedure AddQueryParam(const AValue: string); override;
    procedure AddBodyParam(const AValue: string); override;
  end;

implementation

{ TDriverRestMARS }

procedure TRESTDriverMARS.AddBodyParam(const AValue: string);
begin
  inherited;
  FConnection.AddBodyParam(AValue);
end;

procedure TRESTDriverMARS.AddParam(const AValue: string);
begin
  inherited;
  FConnection.AddParam(AValue);
end;

procedure TRESTDriverMARS.AddQueryParam(const AValue: string);
begin
  inherited;
  FConnection.AddQueryParam(AValue);
end;

constructor TRESTDriverMARS.Create(AConnection: TComponent);
begin
  inherited;
  FConnection := AConnection as TRESTClientMARS;
end;

destructor TRESTDriverMARS.Destroy;
begin
  FConnection := nil;
  inherited;
end;

function TRESTDriverMARS.Execute(const AResource, ASubResource: string;
  const ARequestMethod: TRESTRequestMethodType; const AParams: TProc): string;
begin
  Result := FConnection
              .Execute(AResource, ASubResource, ARequestMethod, AParams);
end;

function TRESTDriverMARS.GetBaseURL: string;
begin
  Result := FConnection.BaseURL;
end;

function TRESTDriverMARS.GetMethodDELETE: string;
begin
  Result := FConnection.MethodDelete;
end;

function TRESTDriverMARS.GetMethodPOST: string;
begin
  Result := FConnection.MethodPOST;
end;

function TRESTDriverMARS.GetMethodGETNextPacket: string;
begin
  Result := FConnection.MethodGETNextPacket;
end;

function TRESTDriverMARS.GetMethodGETNextPacketWhere: string;
begin
  Result := FConnection.MethodGETNextPacketWhere;
end;

function TRESTDriverMARS.GetMethodGET: string;
begin
  Result := FConnection.MethodGET;
end;

function TRESTDriverMARS.GetMethodGETId: string;
begin
  Result := FConnection.MethodGETID;
end;

function TRESTDriverMARS.GetMethodGETWhere: string;
begin
  Result := FConnection.MethodGETWhere;
end;

function TRESTDriverMARS.GetMethodPUT: string;
begin
  Result := FConnection.MethodPUT;
end;

function TRESTDriverMARS.GetServerUse: Boolean;
begin
  Result := FConnection.JanusServerUse;
end;

procedure TRESTDriverMARS.SetClassNotServerUse(const Value: Boolean);
begin
  FConnection.SetClassNotServerUse(Value);
end;

{$ELSE}
interface
implementation
{$ENDIF}

end.
