{
      ORM Brasil � um ORM simples e descomplicado para quem utiliza Delphi

                   Copyright (c) 2016, Isaque Pinheiro
                          All rights reserved.

                    GNU Lesser General Public License
                      Vers�o 3, 29 de junho de 2007

       Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
       A todos � permitido copiar e distribuir c�pias deste documento de
       licen�a, mas mud�-lo n�o � permitido.

       Esta vers�o da GNU Lesser General Public License incorpora
       os termos e condi��es da vers�o 3 da GNU General Public License
       Licen�a, complementado pelas permiss�es adicionais listadas no
       arquivo LICENSE na pasta principal.
}

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Janus.RestFactory.Connection;

interface

uses
  Classes,
  SysUtils,
  Janus.Client.RestDriver,
  Janus.Client.Methods,
  Janus.RestFactory.Interfaces;

type
  // F�brica de conex�es abstratas
  TRESTFactoryConnection = class abstract(TInterfacedObject, IRESTConnection)
  private
    function GetBaseURL: String;
    function GetFullURL: String;
    function GetPassword: String;
    function GetUsername: String;
    function GetMethodGET: String;
    function GetMethodGETId: String;
    function GetMethodGETWhere: String;
    function GetMethodPOST: String;
    function GetMethodPUT: String;
    function GetMethodDELETE: String;
    function GetMethodGETNextPacket: String;
    function GetMethodGETNextPacketWhere: String;
    function GetMethodToken: String;
    function GetServerUse: Boolean;
  protected
    FCommandMonitor: ICommandMonitor;
    FDriverConnection: TRESTDriver;
  public
    constructor Create(AConnection: TComponent); virtual;
    destructor Destroy; override;
    procedure SetCommandMonitor(AMonitor: ICommandMonitor);
    procedure SetClassNotServerUse(const Value: Boolean);
    procedure AddParam(AValue: String); virtual;
    procedure AddBodyParam(AValue: String); virtual;
    procedure AddQueryParam(AValue: String); virtual;
    function CommandMonitor: ICommandMonitor;
    function Execute(const AResource, ASubResource: String;
      const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc = nil): String; overload; virtual; abstract;
    function Execute(const AResource: String; const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc = nil): String; overload; virtual; abstract;
    property BaseURL: String read GetBaseURL;
    property FullURL: String read GetFullURL;
    property Username: String read GetUsername;
    property Password: String read GetPassword;
    property MethodGET: String read GetMethodGET;
    property MethodGETId: String read GetMethodGETId;
    property MethodGETWhere: String read GetMethodGETWhere;
    property MethodPOST: String read GetMethodPOST;
    property MethodPUT: String read GetMethodPUT;
    property MethodDELETE: String read GetMethodDELETE;
    property MethodGETNextPacket: String read GetMethodGETNextPacket;
    property MethodGETNextPacketWhere: String read GetMethodGETNextPacketWhere;
    property MethodToken: String read GetMethodGETNextPacketWhere;
    property ServerUse: Boolean read GetServerUse;
  end;

implementation

{ TFactoryRestConnection }

constructor TRESTFactoryConnection.Create(AConnection: TComponent);
begin

end;

destructor TRESTFactoryConnection.Destroy;
begin
  if Assigned(FDriverConnection) then
    FDriverConnection.Free;
  inherited;
end;

procedure TRESTFactoryConnection.AddBodyParam(AValue: String);
begin
  FDriverConnection.AddBodyParam(AValue);
end;

procedure TRESTFactoryConnection.AddParam(AValue: String);
begin
  FDriverConnection.AddParam(AValue);
end;

procedure TRESTFactoryConnection.AddQueryParam(AValue: String);
begin
  FDriverConnection.AddQueryParam(AValue);
end;

function TRESTFactoryConnection.CommandMonitor: ICommandMonitor;
begin
  Result := FCommandMonitor;
end;

function TRESTFactoryConnection.GetBaseURL: String;
begin
  Result := FDriverConnection.GetBaseURL;
end;

function TRESTFactoryConnection.GetFullURL: String;
begin
  Result := FDriverConnection.GetFullURL;
end;

function TRESTFactoryConnection.GetMethodDELETE: String;
begin
  Result := FDriverConnection.GetMethodDELETE;
end;

function TRESTFactoryConnection.GetMethodPOST: String;
begin
  Result := FDriverConnection.GetMethodPOST;
end;

function TRESTFactoryConnection.GetMethodGETNextPacket: String;
begin
  Result := FDriverConnection.GetMethodGETNextPacket;
end;

function TRESTFactoryConnection.GetMethodGETNextPacketWhere: String;
begin
  Result := FDriverConnection.GetMethodGETNextPacketWhere;
end;

function TRESTFactoryConnection.GetMethodGET: String;
begin
  Result := FDriverConnection.GetMethodGET;
end;

function TRESTFactoryConnection.GetMethodGETId: String;
begin
  Result := FDriverConnection.GetMethodGETId;
end;

function TRESTFactoryConnection.GetMethodGETWhere: String;
begin
  Result := FDriverConnection.GetMethodGETWhere;
end;

function TRESTFactoryConnection.GetMethodToken: String;
begin
  Result := FDriverConnection.GetMethodToken;
end;

function TRESTFactoryConnection.GetMethodPUT: String;
begin
  Result := FDriverConnection.GetMethodPUT;
end;

function TRESTFactoryConnection.GetPassword: String;
begin
  Result := FDriverConnection.GetPassword;
end;

function TRESTFactoryConnection.GetServerUse: Boolean;
begin
  Result := FDriverConnection.GetServerUse;
end;

function TRESTFactoryConnection.GetUsername: String;
begin
  Result := FDriverConnection.GetUsername;
end;

procedure TRESTFactoryConnection.SetClassNotServerUse(const Value: Boolean);
begin
  FDriverConnection.SetClassNotServerUse(Value);
end;

procedure TRESTFactoryConnection.SetCommandMonitor(AMonitor: ICommandMonitor);
begin
  FCommandMonitor := AMonitor;
end;

end.
