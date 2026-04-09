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

unit Janus.Client;

interface

uses
  DB,
  SysUtils,
  StrUtils,
  Classes,
  Janus.Client.Methods,
  Janus.Client.Base;

type
  TClientParam = array of String;
  PClientParam = ^TClientParam;

  TAuthentication = procedure of object;
  TBeforeCommandEvent = procedure (ARequestMethod: String) of object;
  TAfterCommandEvent = procedure (AStatusCode: Integer;
                              var AResponseString: String;
                                  ARequestMethod: String) of object;
  TErrorCommandEvent = procedure (const AURLBase: String;
                                  const AResource: String;
                                  const ASubResource: String;
                                  const ARequestMethod: String;
                                  const AMessage: String;
                                  const AResponseCode: Integer) of object;

  TRestProtocol = (Http, Https);

  TJanusClient = class(TJanusClientBase)
  private
    FBeforeCommand: TBeforeCommandEvent;
    FAfterCommand: TAfterCommandEvent;
    function GetMethodGET: String;
    procedure SetMethodGET(const Value: String);
    function GetMethodGETId: String;
    procedure SetMethodGETId(const Value: String);
    function GetMethodGETWhere: String;
    procedure SetMethodGETWhere(const Value: String);
    function GetMethodPOST: String;
    procedure SetMethodPOST(const Value: String);
    function GetMethodPUT: String;
    procedure SetMethodPUT(const Value: String);
    function GetMethodDELETE: String;
    procedure SetMethodDELETE(const Value: String);
    function GetMethodGETNextPacketWhere: String;
    procedure SetMethodGETNextPacketWhere(const Value: String);
    function GetMethodGETNextPacket: String;
    procedure SetMethodGETNextPacket(const Value: String);
    function GetMethodToken: String;
    procedure SetMethodToken(const Value: String);
    function GetHost: String;
    procedure SetHost(const Value: String);
    function GetPort: Integer;
    procedure SetPort(const Value: Integer);
    function GetAPIContext: String;
    procedure SetAPIContext(const Value: String);
    function GetRESTContext: String;
    procedure SetRESTContext(const Value: String);
    function GetProtocol: TRestProtocol;
    procedure SetProtocol(const Value: TRestProtocol);
  protected
    FErrorCommand: TErrorCommandEvent;
    FProtocol: TRestProtocol;
    FParams: TParams;
    FBodyParams: TParams;
    FQueryParams: TParams;
    FBaseURL: String;
    FAPIContext: String;
    FRESTContext: String;
    FHost: String;
    FPort: Integer;
    FServerUse: Boolean;
    FClassNotServerUse: Boolean;
    // Vari�vel de controle, para conseguir chamar o m�todo Execute()
    // de dentro do evento de autentica��o.
    FPerformingAuthentication: Boolean;
    FMethodSelect: String;
    FMethodSelectID: String;
    FMethodSelectWhere: String;
    FMethodInsert: String;
    FMethodUpdate: String;
    FMethodDelete: String;
    FMethodNextPacket: String;
    FMethodNextPacketWhere: String;
    FMethodToken: String;
    // Variables the Events
    FRequestMethod: String;
    FResponseString: String;
    FStatusCode: Integer;
    FAuthentication: TAuthentication;
    procedure SetServerUse(const Value: Boolean); virtual;
    procedure SetBaseURL; virtual;
    function GetBaseURL: String;
    function GetFullURL: String; virtual;
    procedure DoBeforeCommand; virtual;
    procedure DoAfterCommand; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetClassNotServerUse(const Value: Boolean);
    procedure AddParam(AValue: String); virtual;
    procedure AddBodyParam(AValue: String); virtual;
    procedure AddQueryParam(AValue: String); virtual;
    property MethodGET: String read GetMethodGET write SetMethodGET;
    property MethodPOST: String read GetMethodPOST write SetMethodPOST;
    property MethodPUT: String read GetMethodPUT write SetMethodPUT;
    property MethodDELETE: String read GetMethodDELETE write SetMethodDELETE;
    property MethodToken: String read GetMethodToken write SetMethodToken;
    property APIContext: String read GetAPIContext write SetAPIContext;
    property RESTContext: String read GetRESTContext write SetRESTContext;
    property JanusServerUse: Boolean read FServerUse write SetServerUse;
  published
    property Protocol: TRestProtocol read GetProtocol write SetProtocol;
    property Host: String read GetHost write SetHost;
    property Port: Integer read GetPort write SetPort;
    property MethodGETId: String read GetMethodGETId write SetMethodGETId;
    property MethodGETWhere: String read GetMethodGETWhere write SetMethodGETWhere;
    property MethodGETNextPacket: String read GetMethodGETNextPacket write SetMethodGETNextPacket;
    property MethodGETNextPacketWhere: String read GetMethodGETNextPacketWhere write SetMethodGETNextPacketWhere;
    property BaseURL: String read GetBaseURL;
    property FullURL: String read GetFullURL;
    property OnAuthentication: TAuthentication read FAuthentication write FAuthentication;
    property OnBeforeCommand: TBeforeCommandEvent read FBeforeCommand write FBeforeCommand;
    property OnAfterCommand: TAfterCommandEvent read FAfterCommand write FAfterCommand;
    property OnErrorCommand: TErrorCommandEvent read FErrorCommand write FErrorCommand;
  end;

implementation

{ TJanusClient }

procedure TJanusClient.AddQueryParam(AValue: String);
begin
  with FQueryParams.Add as TParam do
  begin
    Name := 'param_' + IntToStr(FQueryParams.Count -1);
    DataType := ftString;
    ParamType := ptInput;
    Value := AValue;
  end;
end;

constructor TJanusClient.Create(AOwner: TComponent);
begin
  inherited;
  FParams := TParams.Create(Self);
  FBodyParams := TParams.Create(Self);
  FQueryParams := TParams.Create(Self);
  FServerUse := False;
  FClassNotServerUse := False;
  FPerformingAuthentication := False;
  FHost := 'localhost';
  FPort := 8080;
  FMethodSelect := '';
  FMethodInsert := '';
  FMethodUpdate := '';
  FMethodDelete := '';
  FMethodSelectID := 'selectid';
  FMethodSelectWhere := 'selectwhere';
  FMethodNextPacket := 'nextpacket';
  FMethodNextPacketWhere := 'nextpacketwhere';
  FMethodToken := 'token';
  FAPIContext := '';
  FRESTContext := '';
  FProtocol := TRestProtocol.Http;
  FResponseString := '';
  FRequestMethod := '';
  FStatusCode := 0;
  // Monta a URL base
  SetBaseURL;
end;

destructor TJanusClient.Destroy;
begin
  FParams.Clear;
  FParams.Free;
  FQueryParams.Clear;
  FQueryParams.Free;
  FBodyParams.Clear;
  FBodyParams.Free;
  inherited;
end;

procedure TJanusClient.DoAfterCommand;
begin
  if Assigned(FAfterCommand) then
    FAfterCommand(FStatusCode, FResponseString, FRequestMethod);
end;

procedure TJanusClient.DoBeforeCommand;
begin
  if Assigned(FBeforeCommand) then
    FBeforeCommand(FRequestMethod);
end;

procedure TJanusClient.AddBodyParam(AValue: String);
begin
  with FBodyParams.Add as TParam do
  begin
    Name := 'body';
    DataType := ftString;
    ParamType := ptInput;
    Value := AValue;
  end;
end;

procedure TJanusClient.AddParam(AValue: String);
begin
  with FParams.Add as TParam do
  begin
    Name := 'param_' + IntToStr(FParams.Count -1);
    DataType := ftString;
    ParamType := ptInput;
    Value := AValue;
  end;
end;

procedure TJanusClient.SetBaseURL;
var
  LProtocol: String;
begin
  LProtocol := ifThen(FProtocol = TRestProtocol.Http, 'http://', 'https://');
  FBaseURL := LProtocol + FHost;
  if FPort > 0 then
    FBaseURL := FBaseURL + ':' + IntToStr(FPort) + '/';
end;

procedure TJanusClient.SetClassNotServerUse(const Value: Boolean);
begin
  FClassNotServerUse := Value;
end;

function TJanusClient.GetBaseURL: String;
begin
  Result := FBaseURL;
end;

function TJanusClient.GetFullURL: String;
begin
  Result := FBaseURL;
end;

function TJanusClient.GetAPIContext: String;
begin
  Result := FAPIContext;
end;

function TJanusClient.GetMethodDELETE: String;
begin
  Result := FMethodDelete;
end;

function TJanusClient.GetHost: String;
begin
  Result := FHost;
end;

function TJanusClient.GetMethodPOST: String;
begin
  Result := FMethodInsert;
end;

function TJanusClient.GetMethodGETNextPacket: String;
begin
  Result := FMethodNextPacket;
end;

function TJanusClient.GetMethodGETNextPacketWhere: String;
begin
  Result := FMethodNextPacketWhere;
end;

function TJanusClient.GetPort: Integer;
begin
  Result := FPort;
end;

function TJanusClient.GetProtocol: TRestProtocol;
begin
  Result := FProtocol;
end;

function TJanusClient.GetRESTContext: String;
begin
  Result := FRESTContext;
end;

function TJanusClient.GetMethodGET: String;
begin
  Result := FMethodSelect;
end;

function TJanusClient.GetMethodGETId: String;
begin
  Result := FMethodSelectID;
end;

function TJanusClient.GetMethodGETWhere: String;
begin
  Result := FMethodSelectWhere;
end;

function TJanusClient.GetMethodToken: String;
begin
  Result := FMethodToken;
end;

function TJanusClient.GetMethodPUT: String;
begin
  Result := FMethodUpdate;
end;

procedure TJanusClient.SetAPIContext(const Value: String);
begin
  if FAPIContext = Value then
    Exit;

  FAPIContext := Value;
  // Monta a URL base
  SetBaseURL;
end;

procedure TJanusClient.SetMethodDELETE(const Value: String);
begin
  if FMethodDelete <> Value then
    FMethodDelete := Value;
end;

procedure TJanusClient.SetHost(const Value: String);
begin
  if FHost = Value then
    Exit;

  FHost := Value;
  // Monta a URL base
  SetBaseURL;
end;

procedure TJanusClient.SetMethodPOST(const Value: String);
begin
  if FMethodInsert <> Value then
    FMethodInsert := Value;
end;

procedure TJanusClient.SetMethodGETNextPacket(const Value: String);
begin
  if FMethodNextPacket <> Value then
    FMethodNextPacket := Value;
end;

procedure TJanusClient.SetMethodGETNextPacketWhere(const Value: String);
begin
  if FMethodNextPacketWhere <> Value then
    FMethodNextPacketWhere := Value;
end;

procedure TJanusClient.SetPort(const Value: Integer);
begin
  if FPort = Value then
    Exit;

  FPort := Value;
  // Monta a URL base
  SetBaseURL;
end;

procedure TJanusClient.SetProtocol(const Value: TRestProtocol);
begin
  if FProtocol = Value then
    Exit;

  FProtocol := Value;
  // Monta a URL base
  SetBaseURL;
end;

procedure TJanusClient.SetRESTContext(const Value: String);
begin
  if FRESTContext = Value then
    Exit;

  FRESTContext := Value;
  // Monta a URL base
  SetBaseURL;
end;

procedure TJanusClient.SetServerUse(const Value: Boolean);
begin
  if FServerUse = Value then
    Exit;

  FServerUse := Value;
  if FServerUse then
  begin
    if Pos('/Janus', LowerCase(FAPIContext)) = 0 then
      FAPIContext := FAPIContext + '/Janus';
  end
  else
    FAPIContext := ReplaceStr(FAPIContext, '/Janus', '');
end;

procedure TJanusClient.SetMethodGET(const Value: String);
begin
  if FMethodSelect <> Value then
    FMethodSelect := Value;
end;

procedure TJanusClient.SetMethodGETId(const Value: String);
begin
  if FMethodSelectID <> Value then
    FMethodSelectID := Value;
end;

procedure TJanusClient.SetMethodGETWhere(const Value: String);
begin
  if FMethodSelectWhere <> Value then
    FMethodSelectWhere := Value;
end;

procedure TJanusClient.SetMethodToken(const Value: String);
begin
  if FMethodToken <> Value then
    FMethodToken := Value;
end;

procedure TJanusClient.SetMethodPUT(const Value: String);
begin
  if FMethodUpdate <> Value then
    FMethodUpdate := Value;
end;

end.
