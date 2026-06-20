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

unit Janus.Client.RestDriver.WiRL;

{$IFDEF JANUS_REST_WIRL}

interface

uses
  Classes,
  SysUtils,
  Janus.Client.WiRL,
  Janus.Client.Methods,
  Janus.Driver.REST;

type
  TRESTDriverWiRL = class(TRESTDriver)
  protected
    FConnection: TRESTClientWiRL;
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
    function GetUsername: string; override;
    function GetPassword: string; override;
    function GetMethodToken: string; override;
    function Execute(const AResource, ASubResource: string;
      const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc = nil): string; overload; override;
    procedure SetClassNotServerUse(const Value: Boolean); override;
    procedure AddParam(const AValue: string); override;
    procedure AddQueryParam(const AValue: string); override;
    procedure AddBodyParam(const AValue: string); override;
  end;

implementation

{ TDriverRestWiRL }

procedure TRESTDriverWiRL.AddBodyParam(const AValue: string);
begin
  inherited;
  FConnection.AddBodyParam(AValue);
end;

procedure TRESTDriverWiRL.AddParam(const AValue: string);
begin
  inherited;
  FConnection.AddParam(AValue);
end;

procedure TRESTDriverWiRL.AddQueryParam(const AValue: string);
begin
  inherited;
  FConnection.AddQueryParam(AValue);
end;

constructor TRESTDriverWiRL.Create(AConnection: TComponent);
begin
  inherited;
  FConnection := AConnection as TRESTClientWiRL;
end;

destructor TRESTDriverWiRL.Destroy;
begin
  FConnection := nil;
  inherited;
end;

function TRESTDriverWiRL.Execute(const AResource, ASubResource: string;
  const ARequestMethod: TRESTRequestMethodType; const AParams: TProc): string;
begin
  Result := FConnection
              .Execute(AResource, ASubResource, ARequestMethod, AParams);
end;

function TRESTDriverWiRL.GetBaseURL: string;
begin
  Result := FConnection.BaseURL;
end;

function TRESTDriverWiRL.GetMethodDELETE: string;
begin
  Result := FConnection.MethodDelete;
end;

function TRESTDriverWiRL.GetMethodPOST: string;
begin
  Result := FConnection.MethodPOST;
end;

function TRESTDriverWiRL.GetMethodGETNextPacket: string;
begin
  Result := FConnection.MethodGETNextPacket;
end;

function TRESTDriverWiRL.GetMethodGETNextPacketWhere: string;
begin
  Result := FConnection.MethodGETNextPacketWhere;
end;

function TRESTDriverWiRL.GetMethodGET: string;
begin
  Result := FConnection.MethodGET;
end;

function TRESTDriverWiRL.GetMethodGETId: string;
begin
  Result := FConnection.MethodGETId;
end;

function TRESTDriverWiRL.GetMethodGETWhere: string;
begin
  Result := FConnection.MethodGETWhere;
end;

function TRESTDriverWiRL.GetMethodPUT: string;
begin
  Result := FConnection.MethodPUT;
end;

function TRESTDriverWiRL.GetMethodToken: string;
begin

end;

function TRESTDriverWiRL.GetPassword: string;
begin

end;

function TRESTDriverWiRL.GetServerUse: Boolean;
begin
  Result := FConnection.JanusServerUse;
end;

function TRESTDriverWiRL.GetUsername: string;
begin

end;

procedure TRESTDriverWiRL.SetClassNotServerUse(const Value: Boolean);
begin
  FConnection.SetClassNotServerUse(Value);
end;

{$ELSE}
interface
implementation
{$ENDIF}

end.
