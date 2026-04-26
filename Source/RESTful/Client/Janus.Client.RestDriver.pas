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
  @author(Skype : ispinheiro)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Janus.Client.RestDriver;

interface

uses
  Classes,
  SysUtils,
  Janus.Client.Methods;

type
  TRESTDriver = class abstract
  public
    constructor Create(AConnection: TComponent); virtual;
    destructor Destroy; override;
    function GetBaseURL: String; virtual; abstract;
    function GetFullURL: String; virtual; abstract;
    function GetUsername: String; virtual; abstract;
    function GetPassword: String; virtual; abstract;
    function GetMethodGET: String; virtual; abstract;
    function GetMethodGETId: String; virtual; abstract;
    function GetMethodGETWhere: String; virtual; abstract;
    function GetMethodPOST: String; virtual; abstract;
    function GetMethodPUT: String; virtual; abstract;
    function GetMethodDELETE: String; virtual; abstract;
    function GetMethodGETNextPacket: String; virtual; abstract;
    function GetMethodGETNextPacketWhere: String; virtual; abstract;
    function GetMethodToken: String; virtual; abstract;
    function GetServerUse: Boolean; virtual; abstract;
    function Execute(const AResource, ASubResource: String;
      const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc = nil): String; overload; virtual; abstract;
    function Execute(const AResource: String; const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc = nil): String; overload; virtual; abstract;
    procedure SetClassNotServerUse(const Value: Boolean); virtual; abstract;
    procedure AddParam(const AValue: String); virtual; abstract;
    procedure AddQueryParam(const AValue: String); virtual; abstract;
    procedure AddBodyParam(const AValue: String); virtual; abstract;
  end;

implementation

{ TDriverRest }

constructor TRESTDriver.Create(AConnection: TComponent);
begin

end;

destructor TRESTDriver.Destroy;
begin
  inherited;
end;

end.
