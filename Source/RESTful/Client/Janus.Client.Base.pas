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

unit Janus.Client.Base;

interface

uses
  Classes,
  SysUtils,
  Janus.RestComponent,
  Janus.Client.Consts,
  Janus.RestFactory.Interfaces;

type
  TAuthenticatorType = (atNoAuth, atBasicAuth, atBearerToken,
                        atOAuth1, atOAuth2);

  TAuthenticator = class(TPersistent)
  private
    FUsername: String;
    FPassword: String;
    FToken: String;
    FAuthenticatorType: TAuthenticatorType;
    function GetUsername: String;
    procedure SetUsername(const Value: String);
    function GetPassword: String;
    procedure SetPassword(const Value: String);
    function GetAuthenticatorType: TAuthenticatorType;
    procedure SetAuthenticatorType(const Value: TAuthenticatorType);
  public
    constructor Create;
    destructor Destroy; override;
    property Token: String read FToken write FToken;
  published
    property Username: String read GetUsername write SetUsername;
    property Password: String read GetPassword write SetPassword;
    property AuthenticatorType: TAuthenticatorType read GetAuthenticatorType write SetAuthenticatorType;
  end;

  TRestProxyInfo = class(TPersistent)
  private
    FBasicByDefault: Boolean;
    FProxyPort: Integer;
    FPassword: String;
    FUsername: String;
    FProxyServer: String;
  protected
    procedure AssignTo(ADestination: TPersistent); override;
  published
    property BasicAuthentication: Boolean read FBasicByDefault write FBasicByDefault;
    property ProxyPassword: String read FPassword write FPassword;
    property ProxyPort: Integer read FProxyPort write FProxyPort;
    property ProxyServer: String read FProxyServer write FProxyServer;
    property ProxyUsername: String read FUsername write FUserName;
  end;

  TJanusClientBase = class(TJanusComponent)
  private
    procedure SetProxyParams(const Value: TRestProxyInfo);
    procedure SetAuthenticator(const Value: TAuthenticator);
  protected
    FRESTFactory: IRESTConnection;
    FProxyParams: TRestProxyInfo;
    FAuthenticator: TAuthenticator;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function AsConnection: IRESTConnection; deprecated 'use SetCommandMonitor(AMonitor: ICommandMonitor)';
    procedure SetCommandMonitor(AMonitor: ICommandMonitor);
  published
    // Proxy Settings to be used by the client
    property ProxyParams: TRestProxyInfo read FProxyParams write SetProxyParams;
    property Authenticator: TAuthenticator read FAuthenticator write SetAuthenticator;
  end;

implementation

{ TJanusClientBase }

function TJanusClientBase.AsConnection: IRESTConnection;
begin
  Result := FRESTFactory;
end;

constructor TJanusClientBase.Create(AOwner: TComponent);
begin
  inherited;
  FProxyParams := TRestProxyInfo.Create;
  FAuthenticator := TAuthenticator.Create;
end;

destructor TJanusClientBase.Destroy;
begin
  FProxyParams.Free;
  FAuthenticator.Free;
  inherited;
end;

procedure TJanusClientBase.SetAuthenticator(const Value: TAuthenticator);
begin
  FAuthenticator := Value;
end;

procedure TJanusClientBase.SetCommandMonitor(AMonitor: ICommandMonitor);
begin
  FRESTFactory.SetCommandMonitor(AMonitor);
end;

procedure TJanusClientBase.SetProxyParams(const Value: TRestProxyInfo);
begin
  FProxyParams := Value;
end;

{ TRestProxyInfo }

procedure TRestProxyInfo.AssignTo(ADestination: TPersistent);
var
  LDest: TRestProxyInfo;
begin
  if ADestination is TRestProxyInfo then
  begin
    LDest := TRestProxyInfo(ADestination);
    LDest.FPassword := FPassword;
    LDest.FProxyPort := FProxyPort;
    LDest.FProxyServer := FProxyServer;
    LDest.FUsername := FUsername;
    LDest.FBasicByDefault := FBasicByDefault;
  end
  else
  begin
    inherited AssignTo(ADestination);
  end;
end;

{ TAuthenticator }

constructor TAuthenticator.Create;
begin
  FUsername := '';
  FPassword := '';
  FToken    := '';
end;

destructor TAuthenticator.Destroy;
begin

  inherited;
end;

function TAuthenticator.GetAuthenticatorType: TAuthenticatorType;
begin
  Result := FAuthenticatorType;
end;

function TAuthenticator.GetPassword: String;
begin
  Result := FPassword;
end;

function TAuthenticator.GetUsername: String;
begin
  Result := FUsername;
end;

procedure TAuthenticator.SetAuthenticatorType(const Value: TAuthenticatorType);
begin
  FAuthenticatorType := Value;
end;

procedure TAuthenticator.SetPassword(const Value: String);
begin
  FPassword := Value;
end;

procedure TAuthenticator.SetUsername(const Value: String);
begin
  FUsername := Value;
end;

end.
