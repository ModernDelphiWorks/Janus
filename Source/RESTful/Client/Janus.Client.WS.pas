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

unit Janus.Client.WS;

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
  TRESTClientWS = class(TJanusClient)
  private
    FRESTResponse: TRESTResponse;
    FRESTRequest: TRESTRequest;
    FRESTClient: TRESTClient;
    FRootElement: String;
    procedure SetProxyParamsClientValue;
    procedure SetParamsBodyValue;
    procedure SetAuthenticatorTypeValues;
    procedure SetParamValues;
    function DoGET(const AResource, ASubResource: String): String;
    function DoPOST(const AResource, ASubResource: String): String;
    function DoPUT(const AResource, ASubResource: String): String;
    function DoDELETE(const AResource, ASubResource: String): String;
    function GetRootElement: String;
    procedure SetRootElement(const Value: String);
  protected
    procedure DoAfterCommand; override;
    procedure SetBaseURL; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AddQueryParam(AValue: String); override;
    function Execute(const AResource, ASubResource: String;
      const ARequestMethod: TRESTRequestMethodType;
      const AParamsProc: TProc = nil): String;
  published
    property APIContext;
    property RESTContext;
    property RootElement: String read GetRootElement write SetRootElement;
  end;

implementation

uses
  Janus.Client.RestWS.Factory;

{ TRESTClientWS }

procedure TRESTClientWS.AddQueryParam(AValue: String);
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

constructor TRESTClientWS.Create(AOwner: TComponent);
begin
  inherited;
  FRESTFactory := TRESTFactoryWS.Create(Self);
  FRESTClient := TRESTClient.Create(Self);
  FRESTRequest := TRESTRequest.Create(Self);
  FRESTResponse := TRESTResponse.Create(Self);
  FRESTRequest.Client := FRESTClient;
  FRESTRequest.Response := FRESTResponse;
  FRESTResponse.RootElement := '';
  FAPIContext := '';
  FRESTContext := '';
  // Monta a URL base
  SetBaseURL;
end;

destructor TRESTClientWS.Destroy;
begin
  FRESTClient.Free;
  FRESTResponse.Free;
  FRESTRequest.Free;
  inherited;
end;

procedure TRESTClientWS.DoAfterCommand;
begin
  FStatusCode := FRESTRequest.Response.StatusCode;
  inherited;
end;

function TRESTClientWS.DoDELETE(const AResource, ASubResource: String): String;
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

function TRESTClientWS.DoGET(const AResource, ASubResource: String): String;
begin
  FRequestMethod := 'GET';
  FRESTRequest.Method := TRESTRequestMethod.rmGET;
  // Define valores dos parametros
  SetParamValues;
  // GET
  try
    FRESTRequest.Execute;
    // ISSUE #323 - THE BRANCH THAT ONLY THIS ONE OF THE SIX SITES HAD.
    // "Unwrap only when a root element was configured" was written here and
    // nowhere else, so DoPOST and DoDELETE unwrapped unconditionally - and the
    // constructor leaves RootElement EMPTY, which made unwrapping wrong by
    // default in the two of them. The rule was not invented for this repair; it
    // was taken FROM HERE into ResponsePayload, and the other five sites now
    // ask the same question this one already asked. The else arm went with it:
    // JSONValue is nil for an empty or non-JSON body, and ToJSON on nil is an
    // access violation.
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

function TRESTClientWS.DoPOST(const AResource, ASubResource: String): String;
begin
  FRequestMethod := 'POST';
  FRESTRequest.Method := TRESTRequestMethod.rmPOST;
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

function TRESTClientWS.DoPUT(const AResource, ASubResource: String): String;
begin
  FRequestMethod := 'PUT';
  FRESTRequest.Method := TRESTRequestMethod.rmPUT;
  // Define valores dos parametros
  SetParamsBodyValue;
  // PUT
  try
    FRESTRequest.Execute;
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

function TRESTClientWS.Execute(const AResource, ASubResource: String;
  const ARequestMethod: TRESTRequestMethodType;
  const AParamsProc: TProc): String;
var
  LFor: Integer;

  procedure SetURLValue;
  begin
    FRESTClient.BaseURL := GetBaseURL;
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

    // ISSUE #323 - THE ANSWER WAS READ AND THEN DROPPED ONE FRAME ABOVE IT.
    // These four were called as STATEMENTS. Result was set to '' at the top of
    // this method and never assigned again, so `FResponseString := Result`
    // below stored '' and this function ANSWERED '' TO EVERY REQUEST EVER MADE
    // THROUGH IT - the payload the Do* methods work to produce never reached
    // TRESTDriverWS.Execute, which does return what it is given. Nothing warns:
    // discarding a function result is legal Pascal, and Result IS assigned, so
    // there is no W1035 either. Same defect as issue #328's OpenIDInternal,
    // which discarded the result of Find; the sibling TRESTClientDataSnap.
    // Execute already assigned all four.
    //
    // PUT stays a statement, and that is not an oversight: TRESTClientWS.DoPUT
    // does not read the response and never assigns its own Result, so there is
    // no payload there to lose - assigning it would pin nothing and would add
    // the undefined-return warning that assigning an unassigned Result earns.
    case ARequestMethod of
      TRESTRequestMethodType.rtPOST:
        begin
          Result := DoPOST(AResource, ASubResource);
        end;
      TRESTRequestMethodType.rtPUT:
        begin
          DoPUT(AResource, ASubResource);
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

procedure TRESTClientWS.SetAuthenticatorTypeValues;
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

procedure TRESTClientWS.SetBaseURL;
begin
  inherited;
  FBaseURL := FBaseURL + FAPIContext;
  if Length(FRESTContext) > 0 then
    FBaseURL := FBaseURL + '/' + FRESTContext;
end;

procedure TRESTClientWS.SetParamValues;
var
  LFor: Integer;
begin
  // Params
  for LFor := 0 to FParams.Count -1 do
  begin
    FRESTRequest.ResourceSuffix := FRESTRequest.ResourceSuffix + '/{' +
                                   FParams.Items[LFor].Name + '}';
    FRESTRequest.Params.AddUrlSegment(FParams.Items[LFor].Name,
                                      FParams.Items[LFor].AsString);
  end;
  // Query Params
  for LFor := 0 to FQueryParams.Count -1 do
    FRESTRequest.AddParameter(FQueryParams.Items[LFor].Name,
                              FQueryParams.Items[LFor].AsString);
end;

procedure TRESTClientWS.SetParamsBodyValue;
var
  LFor: Integer;
begin
  if FBodyParams.Count = 0 then
    raise Exception.Create('N'#$00E3'o foi passado o par'#$00E2'metro com os dados do insert!');

  for LFor := 0 to FBodyParams.Count -1 do
    FRESTRequest.Body.Add(FBodyParams.Items[LFor].AsString, ContentTypeFromString('application/json'));
end;

procedure TRESTClientWS.SetProxyParamsClientValue;
begin
  FRESTClient.ProxyServer := FProxyParams.ProxyServer;
  FRESTClient.ProxyPort := FProxyParams.ProxyPort;
  FRESTClient.ProxyUsername := FProxyParams.ProxyUsername;
  FRESTClient.ProxyPassword := FProxyParams.ProxyPassword;
end;

function TRESTClientWS.GetRootElement: String;
begin
  Result := FRootElement;
end;

procedure TRESTClientWS.SetRootElement(const Value: String);
begin
  FRootElement := Value;
  FRESTResponse.RootElement := FRootElement;
end;

end.
