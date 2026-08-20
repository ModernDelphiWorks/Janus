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

{$INCLUDE ..\..\Janus.inc}

unit Janus.Client.DataSnap;

interface

uses
  DB,
  SysUtils,
  StrUtils,
  Classes,
  Janus.Client,
  Janus.Client.Base,
  Janus.Client.Methods,
  Janus.Client.RestException,
  {$IFDEF DELPHI15_UP}
  JSON,
  {$ELSE}
  DBXJSON,
  {$ENDIF}
  REST.Client,
  REST.Types,
  IPPeerClient;

type
  TRESTClientDataSnap = class(TJanusClient)
  private
    FRESTResponse: TRESTResponse;
    FRESTRequest: TRESTRequest;
    FRESTClient: TRESTClient;
    procedure SetProxyParamsClientValue;
    procedure SetParamsBodyValue;
    procedure SetAuthenticatorTypeValues;
    procedure SetParamValues;
    function DoGET(const AResource, ASubResource: string): string;
    function DoPOST(const AResource, ASubResource: string): string;
    function DoPUT(const AResource, ASubResource: string): string;
    function DoDELETE(const AResource, ASubResource: string): string;
    function RemoveContextServerUse(const Value: string): string;
  protected
    procedure DoAfterCommand; override;
    procedure SetBaseURL; override;
    procedure SetServerUse(const Value: Boolean); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AddQueryParam(AValue: string); override;
    function Execute(const AResource, ASubResource: string;
      const ARequestMethod: TRESTRequestMethodType;
      const AParamsProc: TProc = nil): string; overload;
    function Execute(const AURL: string;
      const ARequestMethod: TRESTRequestMethodType;
      const AParamsProc: TProc = nil): string; overload;
  published
    property APIContext;
    property RESTContext;
    property JanusServerUse;
  end;

implementation

uses
  Janus.Client.RestDataSnap.Factory;

{ TRESTClientDataSnap }

procedure TRESTClientDataSnap.AddQueryParam(AValue: string);
var
  LPos: Integer;
begin
  LPos := Pos('=', AValue);
  if LPos = 0 then
    Exit;

  with FQueryParams.Add as TParam do
  begin
    Name := Copy(AValue, 1, LPos -1);
    DataType := ftString;
    ParamType := ptInput;
    Value := Copy(AValue, LPos +1, MaxInt);
  end;
end;

constructor TRESTClientDataSnap.Create(AOwner: TComponent);
begin
  inherited;
  FRESTFactory := TRESTFactoryDatasnap.Create(Self);
  FRESTClient := TRESTClient.Create(Self);
  FRESTRequest := TRESTRequest.Create(Self);
  FRESTResponse := TRESTResponse.Create(Self);
  FRESTRequest.Client := FRESTClient;
  FRESTRequest.Response := FRESTResponse;
  FRESTResponse.RootElement := 'result';
  FAPIContext := 'datasnap';
  FRESTContext := '';
  /// <summary> Monta a URL base </summary>
  SetBaseURL;
end;

destructor TRESTClientDataSnap.Destroy;
begin
  FRESTClient.Free;
  FRESTResponse.Free;
  FRESTRequest.Free;
  inherited;
end;

procedure TRESTClientDataSnap.DoAfterCommand;
begin
  FStatusCode := FRESTRequest.Response.StatusCode;
  inherited;
end;

function TRESTClientDataSnap.DoDELETE(const AResource, ASubResource: string): string;
begin
  FRequestMethod := 'DELETE';
  FRESTRequest.Method := TRESTRequestMethod.rmDELETE;
  // Define valores dos parametros
  SetParamValues;
  // DELETE
  try
    FRESTRequest.Execute;
    // ISSUE #323 - was (JSONValue as TJSONArray).Items[0], two unguarded steps
    // whose three failing shapes escaped as three different untyped errors.
    // TJanusClient.ResponsePayload carries the rule and the measurements; it
    // raises INSIDE this try on purpose, so the handler below is what reports
    // it, with the server body still attached.
    Result := ResponsePayload(FRESTRequest.Response.JSONValue,
                              Length(FRESTResponse.RootElement) > 0);
  except
    on E: Exception do
    begin
      if Assigned(FErrorCommand) then
        FErrorCommand(GetBaseURL,
                      AResource,
                      ASubResource,
                      FRequestMethod,
                      E.Message,
                      FRESTRequest.Response.StatusCode)
      else
        raise EJanusRESTException
                .Create(FRESTClient.BaseURL,
                        AResource,
                        ASubResource,
                        FRequestMethod,
                        FRESTRequest.Response.Content,
                        E.Message,
                        FRESTRequest.Response.StatusCode);
    end;
  end;
end;

function TRESTClientDataSnap.DoGET(const AResource, ASubResource: string): string;
begin
  FRequestMethod := 'GET';
  FRESTRequest.Method := TRESTRequestMethod.rmGET;
  // Define valores dos parametros
  SetParamValues;
  // DELETE
  try
    FRESTRequest.Execute;
    // ISSUE #323 - was (JSONValue as TJSONArray).Items[0], two unguarded steps
    // whose three failing shapes escaped as three different untyped errors.
    // TJanusClient.ResponsePayload carries the rule and the measurements; it
    // raises INSIDE this try on purpose, so the handler below is what reports
    // it, with the server body still attached.
    Result := ResponsePayload(FRESTRequest.Response.JSONValue,
                              Length(FRESTResponse.RootElement) > 0)
  except
    on E: Exception do
    begin
      if Assigned(FErrorCommand) then
        FErrorCommand(GetBaseURL,
                      AResource,
                      ASubResource,
                      FRequestMethod,
                      E.Message,
                      FRESTRequest.Response.StatusCode)
      else
        raise EJanusRESTException
                .Create(FRESTClient.BaseURL,
                        AResource,
                        ASubResource,
                        FRequestMethod,
                        FRESTRequest.Response.Content,
                        E.Message,
                        FRESTRequest.Response.StatusCode);
    end;
  end;

end;

function TRESTClientDataSnap.DoPOST(const AResource, ASubResource: string): string;
begin
  FRequestMethod := 'POST';
  // ISSUE #338 - THE VERB IS CROSSED ON PURPOSE. DO NOT "STRAIGHTEN" IT.
  // DataSnap dispatches by METHOD NAME PREFIX, and its own table is the one
  // that is inverted: Studio 37.0, Datasnap.DSService.pas,
  // TDSRESTService.SetMethodNameWithPrefix, reached from ProcessREST, maps
  // 'PUT' -> 'accept', 'POST' -> 'update', 'DELETE' -> 'cancel'. So an INSERT
  // has to travel as HTTP PUT to reach acceptapp, which is the method that
  // inserts - see Janus.Server.Resource.DataSnap, and acceptmaster in the
  // shipped example server. Sending rmPOST here would reach updateapp and turn
  // every insert into an update against a real server. Both transports land on
  // that table: TDSRESTServer over Indy and TDSHTTPWebDispatcher over
  // WebBroker. TRESTClientWS maps 'POST' -> rmPOST and is NOT a counterexample
  // - it speaks plain REST, which has no prefix dispatch to compensate.
  // Pinned by TTestClientDataSnapVerb.
  FRESTRequest.Method := TRESTRequestMethod.rmPUT;
  // Define valores dos parametros
  SetParamsBodyValue;
  // POST
  try
    FRESTRequest.Execute;
    // ISSUE #323 - was (JSONValue as TJSONArray).Items[0], two unguarded steps
    // whose three failing shapes escaped as three different untyped errors.
    // TJanusClient.ResponsePayload carries the rule and the measurements; it
    // raises INSIDE this try on purpose, so the handler below is what reports
    // it, with the server body still attached.
    Result := ResponsePayload(FRESTRequest.Response.JSONValue,
                              Length(FRESTResponse.RootElement) > 0);
  except
    on E: Exception do
    begin
      if Assigned(FErrorCommand) then
        FErrorCommand(GetBaseURL,
                      AResource,
                      ASubResource,
                      FRequestMethod,
                      E.Message,
                      FRESTRequest.Response.StatusCode)
      else
        raise EJanusRESTException
                .Create(FRESTClient.BaseURL,
                        AResource,
                        ASubResource,
                        FRequestMethod,
                        FRESTRequest.Response.Content,
                        E.Message,
                        FRESTRequest.Response.StatusCode);
    end;
  end;
end;

function TRESTClientDataSnap.DoPUT(const AResource, ASubResource: string): string;
begin
  FRequestMethod := 'PUT';
  // ISSUE #338 - CROSSED ON PURPOSE, the mirror of the note in DoPOST above.
  // 'POST' -> 'update' in the DataSnap prefix table, so an UPDATE has to
  // travel as HTTP POST to reach updateapp. Sending rmPUT here would reach
  // acceptapp and turn every update into an insert.
  FRESTRequest.Method := TRESTRequestMethod.rmPOST;
  // Define valores dos parametros
  SetParamsBodyValue;
  // PUT
  try
    FRESTRequest.Execute;
    // ISSUE #338 - THIS ASSIGNMENT WAS ABSENT, AND EVERY PUT ANSWERED ''.
    // The method executed the request and returned without ever touching
    // Result, so the server's answer was read and discarded - and nothing
    // warned, because the except below terminates the function. The contract
    // it now meets is the one DoGET, DoPOST and DoDELETE OF THIS SAME CLASS
    // already met, measured on this class rather than borrowed from
    // TRESTClientWS - whose DoPUT had the identical hole, and which #338 left
    // open ON PURPOSE rather than repair by analogy.
    //
    // THAT HOLE IS NOW CLOSED TOO, AND NOT BY ANALOGY EITHER. The #338
    // follow-up measured the contract on the WS class in its own right and
    // found a DIFFERENT one: TRESTClientWS leaves RootElement EMPTY and
    // publishes it as a writable property, so the unwrap flag is genuinely
    // variable there and its DoPUT had to be pinned in BOTH arms. Here it is
    // constant-True - this class's constructor sets 'result' and nothing can
    // reach it from outside - which is why one arm was enough. The two repairs
    // agree in shape and rest on separate measurements; neither is evidence
    // about the other.
    //
    // Joining that contract means joining its failure half: ResponsePayload
    // raises INSIDE this try for a nil, non-array or empty answer, so a PUT
    // that used to swallow a malformed body silently now reports it through
    // the handler below, with the server body still attached. That widening is
    // the point - a DataSnap error answers a body with no 'result' key, which
    // is exactly the shape this used to discard.
    Result := ResponsePayload(FRESTRequest.Response.JSONValue,
                              Length(FRESTResponse.RootElement) > 0);
  except
    on E: Exception do
    begin
      if Assigned(FErrorCommand) then
        FErrorCommand(GetBaseURL,
                      AResource,
                      ASubResource,
                      FRequestMethod,
                      E.Message,
                      FRESTRequest.Response.StatusCode)
      else
        raise EJanusRESTException
                .Create(FRESTClient.BaseURL,
                        AResource,
                        ASubResource,
                        FRequestMethod,
                        FRESTRequest.Response.Content,
                        E.Message,
                        FRESTRequest.Response.StatusCode);
    end;
  end;
end;

function TRESTClientDataSnap.Execute(const AURL: string;
  const ARequestMethod: TRESTRequestMethodType;
  const AParamsProc: TProc): string;
var
  LFor: Integer;

  procedure SetURLValue;
  begin
    FRESTClient.BaseURL := AURL;
    FRESTRequest.Params.Clear;
    FRESTRequest.ResetToDefaults;
    FRESTRequest.Resource := '';
    FRESTRequest.ResourceSuffix := '';
  end;

begin
  Result := '';
  // Executa a procedure de adicao dos parametros
  if Assigned(AParamsProc) then
    AParamsProc();
  // Define valor da URL
  SetURLValue;
  // Define dados do proxy
  SetProxyParamsClientValue;
  // Define valores de autenticacao
  SetAuthenticatorTypeValues;

  for LFor := 0 to FParams.Count -1 do
    if FParams.Items[LFor].AsString = 'None' then
      FParams.Items[LFor].AsString := '';
  try
    // DoBeforeCommand
    DoBeforeCommand;

    case ARequestMethod of
      TRESTRequestMethodType.rtPOST:
        begin
          Result := DoPOST('', '');
        end;
      TRESTRequestMethodType.rtPUT:
        begin
          Result := DoPUT('', '');
        end;
      TRESTRequestMethodType.rtGET:
        begin
          Result := DoGET('', '');
        end;
      TRESTRequestMethodType.rtDELETE:
        begin
          Result := DoDELETE('', '');
        end;
      TRESTRequestMethodType.rtPATCH: ;
    end;
    // Passao JSON para a VAR que podera ser manipulada no evento AfterCommand
    FResponseString := Result;
    // DoAfterCommand
    DoAfterCommand;
    // Pega de volta o JSON manipulado ou nao no evento AfterCommand
    Result := FResponseString;
  finally
    FResponseString := '';
    FParams.Clear;
    FQueryParams.Clear;
    FBodyParams.Clear;
  end;
end;

function TRESTClientDataSnap.Execute(const AResource, ASubResource: string;
      const ARequestMethod: TRESTRequestMethodType;
      const AParamsProc: TProc = nil): string;
var
  LFor: Integer;

  procedure SetURLValue;
  begin
    FRESTClient.BaseURL := GetBaseURL;
    // Trata a URL Base caso o componente esteja para usar o servidor,
    // mas a classe nao.
    if (FServerUse) and (FClassNotServerUse) then
      FRESTClient.BaseURL := RemoveContextServerUse(FRESTClient.BaseURL);

    FRESTRequest.Params.Clear;
    FRESTRequest.ResetToDefaults;
    FRESTRequest.Resource := AResource;
    FRESTRequest.ResourceSuffix := ASubResource;
  end;

begin
  Result := '';
  // Executa a procedure de adicao dos parametros
  if Assigned(AParamsProc) then
    AParamsProc();
  // Define valor da URL
  SetURLValue;
  // Define dados do proxy
  SetProxyParamsClientValue;
  // Define valores de autenticacao
  SetAuthenticatorTypeValues;

  for LFor := 0 to FParams.Count -1 do
    if FParams.Items[LFor].AsString = 'None' then
      FParams.Items[LFor].AsString := '';
  try
    // DoBeforeCommand
    DoBeforeCommand;

    case ARequestMethod of
      TRESTRequestMethodType.rtPOST:
        begin
          Result := DoPOST(AResource, ASubResource);
        end;
      TRESTRequestMethodType.rtPUT:
        begin
          Result := DoPUT(AResource, ASubResource);
        end;
      TRESTRequestMethodType.rtGET:
        begin
          Result := DoGET(AResource, ASubResource);
        end;
      TRESTRequestMethodType.rtDELETE:
        begin
          Result := DoDELETE(AResource, ASubResource);
        end;
      TRESTRequestMethodType.rtPATCH: ;
    end;
    // Passao JSON para a VAR que podera ser manipulada no evento AfterCommand
    FResponseString := Result;
    // DoAfterCommand
    DoAfterCommand;
    // Pega de volta o JSON manipulado ou nao no evento AfterCommand
    Result := FResponseString;
  finally
    FResponseString := '';
    FParams.Clear;
    FQueryParams.Clear;
    FBodyParams.Clear;
  end;
end;

function TRESTClientDataSnap.RemoveContextServerUse(
  const Value: string): string;
begin
  Result := ReplaceStr(Value, '/Janus/app', '');
end;

procedure TRESTClientDataSnap.SetAuthenticatorTypeValues;
begin
  case FAuthenticator.AuthenticatorType of
    atNoAuth:;
    atBasicAuth:;
    atBearerToken,
    atOAuth1,
    atOAuth2:
      begin
        if Length(FAuthenticator.Token) > 0 then
        begin
          FRESTClient.AddAuthParameter('Authorization', 'Bearer ' + FAuthenticator.Token, TRESTRequestParameterKind.pkHTTPHEADER);
          Exit;
        end;
      end;
  end;
  FRESTClient.AddAuthParameter('username', FAuthenticator.Username, TRESTRequestParameterKind.pkHTTPHEADER);
  FRESTClient.AddAuthParameter('password', FAuthenticator.Password, TRESTRequestParameterKind.pkHTTPHEADER);
end;

procedure TRESTClientDataSnap.SetBaseURL;
begin
  inherited;
  FBaseURL := FBaseURL + FAPIContext;
  if Length(FRESTContext) > 0 then
    FBaseURL := FBaseURL + '/' + FRESTContext;
end;

procedure TRESTClientDataSnap.SetParamValues;
var
  LFor: Integer;
begin
  /// <summary> Params </summary>
  for LFor := 0 to FParams.Count -1 do
  begin
    FRESTRequest.ResourceSuffix := FRESTRequest.ResourceSuffix + '/{' +
                                   FParams.Items[LFor].Name + '}';
    FRESTRequest.Params.AddUrlSegment(FParams.Items[LFor].Name,
                                      FParams.Items[LFor].AsString);
  end;
  /// <summary> Query Params </summary>
  for LFor := 0 to FQueryParams.Count -1 do
    FRESTRequest.AddParameter(FQueryParams.Items[LFor].Name,
                              FQueryParams.Items[LFor].AsString);
end;

procedure TRESTClientDataSnap.SetParamsBodyValue;
var
  LFor: Integer;
begin
  if FBodyParams.Count = 0 then
    raise Exception.Create('N'#$00E3'o foi passado o par'#$00E2'metro com os dados do insert!');

  for LFor := 0 to FBodyParams.Count -1 do
    FRESTRequest.Body.Add(FBodyParams.Items[LFor].AsString, ContentTypeFromString('application/json'));
end;

procedure TRESTClientDataSnap.SetProxyParamsClientValue;
begin
  FRESTClient.ProxyServer := FProxyParams.ProxyServer;
  FRESTClient.ProxyPort := FProxyParams.ProxyPort;
  FRESTClient.ProxyUsername := FProxyParams.ProxyUsername;
  FRESTClient.ProxyPassword := FProxyParams.ProxyPassword;
end;

procedure TRESTClientDataSnap.SetServerUse(const Value: Boolean);
begin
  if FServerUse = Value then
    Exit;

  FServerUse := Value;
  FRESTContext := RemoveContextServerUse(FRESTContext);
  if FServerUse then
    FRESTContext := FRESTContext + '/Janus/app';
  SetBaseURL;
end;

end.
