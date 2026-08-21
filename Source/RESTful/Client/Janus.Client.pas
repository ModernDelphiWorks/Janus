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

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

{$INCLUDE ..\..\Janus.inc}

unit Janus.Client;

interface

uses
  DB,
  SysUtils,
  StrUtils,
  Classes,
  {$IFDEF DELPHI15_UP}
  JSON,
  {$ELSE}
  DBXJSON,
  {$ENDIF}
  Janus.Client.Methods,
  Janus.Client.RestException,
  Janus.Client.Base;

const
  /// <summary>
  ///   ISSUE #323 - the three malformed shapes ResponsePayload names. They are
  ///   constants and not literals so that a clause can say WHICH of the three
  ///   ran without repeating the sentence, and so that the three stay distinct
  ///   from one another - telling them apart is the whole point of naming them.
  /// </summary>
  cRESTNOJSONVALUE = 'The response carried no JSON value: the body was empty, ' +
                     'was not JSON, or the configured root element is absent ' +
                     'from it.';
  cRESTNOTANARRAY  = 'The response root element is not a JSON array, it is a ';
  cRESTEMPTYARRAY  = 'The response root element is a JSON array with no ' +
                     'element in it, so there is no payload to unwrap.';

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
    // Variavel de controle, para conseguir chamar o metodo Execute()
    // de dentro do evento de autenticacao.
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
    /// <summary>
    ///   ISSUE #323 - READS THE PAYLOAD OUT OF A RESPONSE THAT MAY NOT HAVE ONE.
    ///
    ///   AValue is what TRESTResponse.JSONValue answered. AUnwrapEnvelope says
    ///   whether the caller configured a ROOT ELEMENT: when it did, the value is
    ///   an envelope - an array whose FIRST element is the payload - and when it
    ///   did not, the value IS the payload. That rule is not invented here, it
    ///   is the one TRESTClientWS.DoGET already carried alone.
    ///
    ///   Every other outcome is an error, and it is raised as one instead of
    ///   escaping untyped. The three shapes and what they used to do:
    ///
    ///     nil                  `nil as TJSONArray` is nil in Delphi, so the
    ///                          index that followed dereferenced nil - an ACCESS
    ///                          VIOLATION, not a typed error
    ///     not an array         EInvalidCast, whose message names neither HTTP
    ///                          nor server nor response
    ///     empty array          Items[0] on a TList - EArgumentOutOfRange
    ///
    ///   WHY ALL THREE STAY ERRORS. nil is the state TCustomRESTResponse.
    ///   GetJSONValue answers for an empty body, a non-JSON body AND an absent
    ///   root element (Studio 37.0, REST.Client.pas, GetJSONValue swallows the
    ///   EJSONValueError that GetJSONResponse raises). For the DataSnap client
    ///   the root element is 'result', and a DataSnap SERVER ERROR answers a
    ///   body with no 'result' key at all - so nil is the ordinary shape of a
    ///   failed call, and answering '' to it would swallow every server error
    ///   this client can receive. An empty envelope is the same statement with
    ///   less evidence. Whether an empty envelope should instead be read as "no
    ///   data" and answered with '' is a CONTRACT VISIBLE TO THE CONSUMER; the
    ///   house does not answer it unanimously at this seam, so it is reported
    ///   and not decided here.
    /// </summary>
    class function ResponsePayload(const AValue: TJSONValue;
      const AUnwrapEnvelope: Boolean): String;
    /// <summary>
    ///   ISSUE #323 - THE HALF OF THAT RULE THAT THE HORSE CLIENT ALSO NEEDS.
    ///
    ///   Answers AValue, or raises when there is none. TRESTClientHorse casts
    ///   nothing - so it was outside the ten hard casts the issue enumerates -
    ///   but its four verbs all read JSONValue.ToJSON or .ToString with no
    ///   guard, and nil is exactly as reachable there as anywhere else.
    ///   Measured over a live server: all four answered "Access violation ...
    ///   Read of address 00000000" to a body that is not JSON.
    ///
    ///   It is separate from ResponsePayload because the Horse verbs do not
    ///   agree on how to render the value they got: three answer ToJSON and
    ///   DoDELETE answers ToString, and those two differ for every character
    ///   above 127 (Studio 37.0, System.JSON.pas: ToJSON is ToChars with
    ///   EncodeBelow32 and EncodeAbove127, ToString is ToChars with neither).
    ///   Guarding nil is not a licence to change the answer of a call that
    ///   currently succeeds, so the rendering is left exactly as each site
    ///   had it and the disagreement is reported instead.
    /// </summary>
    class function ResponseValue(const AValue: TJSONValue): TJSONValue;
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

class function TJanusClient.ResponseValue(const AValue: TJSONValue): TJSONValue;
begin
  if AValue = nil then
    raise EJanusRESTResponseShape.Create(cRESTNOJSONVALUE);
  Result := AValue;
end;

class function TJanusClient.ResponsePayload(const AValue: TJSONValue;
  const AUnwrapEnvelope: Boolean): String;
var
  LArray: TJSONArray;
begin
  ResponseValue(AValue);

  if not AUnwrapEnvelope then
  begin
    Result := AValue.ToJSON;
    Exit;
  end;

  if not (AValue is TJSONArray) then
    raise EJanusRESTResponseShape.Create(cRESTNOTANARRAY + AValue.ClassName);

  LArray := TJSONArray(AValue);
  if LArray.Count = 0 then
    raise EJanusRESTResponseShape.Create(cRESTEMPTYARRAY);

  Result := LArray.Items[0].ToJSON;
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
