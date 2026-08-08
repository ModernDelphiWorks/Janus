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

{
  WiRL pin
  --------
  Written against delphi-blocks/WiRL @ aac8562c810b98fef590f3035f56bdf9ea3bad76
  (2026-07-13). The pin and what moved are registered in
  docs-src/docs/janus/user/guides/restful.md.

  Three client units this driver used to depend on no longer exist upstream:
  WiRL.Client.Resource.JSON, WiRL.Client.SubResource[.JSON] and
  WiRL.Client.Token. Their capabilities are reached now as follows.

  - Resource/SubResource pair -> a single TWiRLClientResource whose Resource
    property carries the whole path. TWiRLClientCustomResource.GetPath still
    builds engine/app/resource (WiRL.Client.CustomResource.pas:266-281), so
    the URL shape is unchanged.
  - Positional path params -> WiRL replaced PathParamsValues with named
    placeholder substitution (WiRL.Client.CustomResource.pas:284-301, with the
    old positional logic left commented out at :294-297). Janus feeds
    positional segments, so they are appended to the resource path here.
  - TWiRLClientToken -> the token round trip moved to the server side auth
    resources (WiRL.Core.Auth.Resource.pas:70-130), which answer a
    TWiRLLoginResponse carrying the access_token property (:31-40). The client
    performs that POST itself and then sends an Authorization Bearer header,
    which is the idiom the WiRL demo uses
    (Demos/03.Authorization/Client.Form.Main.pas:138-176).
  - TWiRLClient no longer exposes Request/Response; each call answers an
    IWiRLResponse (WiRL.http.Client.Interfaces.pas:113-163), so the status
    code is captured per call.
}

unit Janus.Client.WiRL;

interface

uses
  DB,
  JSON,
  SysUtils,
  StrUtils,
  Classes,
  Generics.Collections,
  Janus.Client,
  Janus.Client.Base,
  Janus.Client.Methods,
  Janus.Client.RestException,

  WiRL.Client.CustomResource,
  WiRL.Client.Resource,
  WiRL.Client.Application,
  WiRL.http.Client,
  WiRL.http.Client.Indy,
  WiRL.http.Client.Interfaces,
  WiRL.http.Accept.MediaType,
  WiRL.http.Headers,
  WiRL.http.URL,
  WiRL.Core.Classes,
  WiRL.Core.Utils;

type
  TRESTClientWiRL = class(TJanusClient)
  private
    FRESTClient: TWiRLClient;
    FRESTClientApp: TWiRLClientApplication;
    FRESTResource: TWiRLClientResource;
    FAccessToken: string;
    procedure SetProxyParamsClientValue;
    procedure SetProxyParamsBodyValue(var AParams: string);
    procedure SetAuthenticatorTypeValues;
    procedure SetParamValues;
    function AcquireAccessToken: string;
    function DoRequest(const AResource, ASubResource, AHttpMethod,
      ABody: string): string;
    function DoGET(const AResource, ASubResource: string): string;
    function DoPOST(const AResource, ASubResource: string): string;
    function DoPUT(const AResource, ASubResource: string): string;
    function DoDELETE(const AResource, ASubResource: string): string;
    function RemoveContextServerUse(const Value: string): string;
  protected
    procedure DoAfterCommand; override;
    procedure SetBaseURL; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function Execute(const AResource, ASubResource: string;
      const ARequestMethod: TRESTRequestMethodType;
      const AParamsProc: TProc = nil): string; overload;
    function Execute(const AURL: string;
      const ARequestMethod: TRESTRequestMethodType;
      const AParamsProc: TProc = nil): string; overload;
  published
    property APIContext;
    property RESTContext;
    property MethodToken;
    property JanusServerUse;
  end;

implementation

uses
  Janus.Client.RestWiRL.Factory;

{ TRESTClientWiRL }

constructor TRESTClientWiRL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FRESTFactory := TRESTFactoryWiRL.Create(Self);
  FRESTClient := TWiRLClient.Create(Self);
  FRESTClientApp := TWiRLClientApplication.Create(Self);
  FRESTClientApp.Client := FRESTClient;
  FRESTResource := TWiRLClientResource.Create(Self);
  FRESTResource.Application := FRESTClientApp;
  FAPIContext := 'app';
  FRESTContext := 'rest';
  /// <summary> Monta a URL base </summary>
  SetBaseURL;
end;

destructor TRESTClientWiRL.Destroy;
begin
  FRESTResource.Free;
  FRESTClientApp.Free;
  FRESTClient.Free;
  inherited;
end;

procedure TRESTClientWiRL.DoAfterCommand;
begin
  /// <summary> FStatusCode ja foi alimentado por DoRequest, pois o
  ///   TWiRLClient nao expoe mais uma propriedade Response. </summary>
  inherited;
end;

function TRESTClientWiRL.DoRequest(const AResource, ASubResource, AHttpMethod,
  ABody: string): string;
var
  LResponse: IWiRLResponse;
  LContent: string;
begin
  Result := '';
  LContent := '';
  FRequestMethod := AHttpMethod;
  /// <summary> Define valores dos parametros </summary>
  SetParamValues;
  try
    if AHttpMethod = 'POST' then
      LResponse := FRESTResource.Post<string, IWiRLResponse>(ABody)
    else
    if AHttpMethod = 'PUT' then
      LResponse := FRESTResource.Put<string, IWiRLResponse>(ABody)
    else
    if AHttpMethod = 'DELETE' then
      LResponse := FRESTResource.Delete<IWiRLResponse>
    else
      LResponse := FRESTResource.Get<IWiRLResponse>;
    FStatusCode := LResponse.StatusCode;
    Result := LResponse.ContentText;
  except
    on E: Exception do
    begin
      if E is EWiRLClientProtocolException then
      begin
        FStatusCode := EWiRLClientProtocolException(E).StatusCode;
        LContent := EWiRLClientProtocolException(E).ResponseText;
      end
      else
        FStatusCode := 0;
      if Assigned(FErrorCommand) then
        FErrorCommand(GetFullURL,
                      AResource,
                      ASubResource,
                      FRequestMethod,
                      E.Message,
                      FStatusCode)
      else
        raise EJanusRESTException
                .Create(GetFullURL,
                        AResource,
                        ASubResource,
                        FRequestMethod,
                        LContent,
                        E.Message,
                        FStatusCode);
    end;
  end;
end;

function TRESTClientWiRL.DoDELETE(const AResource, ASubResource: string): string;
begin
  Result := DoRequest(AResource, ASubResource, 'DELETE', '');
end;

function TRESTClientWiRL.DoGET(const AResource, ASubResource: string): string;
begin
  Result := DoRequest(AResource, ASubResource, 'GET', '');
end;

function TRESTClientWiRL.DoPOST(const AResource, ASubResource: string): string;
var
  LParams: string;
begin
  /// <summary> Define valores dos parametros </summary>
  SetProxyParamsBodyValue(LParams);
  Result := DoRequest(AResource, ASubResource, 'POST', LParams);
end;

function TRESTClientWiRL.DoPUT(const AResource, ASubResource: string): string;
var
  LParams: string;
begin
  /// <summary> Define valores dos parametros </summary>
  SetProxyParamsBodyValue(LParams);
  Result := DoRequest(AResource, ASubResource, 'PUT', LParams);
end;

function TRESTClientWiRL.Execute(const AURL: string;
  const ARequestMethod: TRESTRequestMethodType;
  const AParamsProc: TProc): string;

  procedure SetURLValue;
  begin
    FRESTClient.WiRLEngineURL := GetBaseURL;
    FRESTClientApp.AppName := '';
    FRESTResource.Resource := '';
    FRESTResource.PathParams.Clear;
    FRESTResource.QueryParams.Clear;
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

function TRESTClientWiRL.Execute(const AResource, ASubResource: string;
  const ARequestMethod: TRESTRequestMethodType;
  const AParamsProc: TProc): string;

  procedure SetURLValue;
  begin
    FRESTClientApp.AppName := FAPIContext;
    // Trata a URL Base caso o componente esteja para usar o servidor,
    // mas a classe nao.
    if (FServerUse) and (FClassNotServerUse) then
      FRESTClientApp.AppName := RemoveContextServerUse(FRESTClientApp.AppName);

    FRESTClient.WiRLEngineURL := GetBaseURL;
    // O WiRL nao tem mais o par Resource/SubResource: o caminho inteiro vai
    // na propriedade Resource e GetPath o combina com engine e app.
    FRESTResource.Resource := TWiRLURL.CombinePath([AResource, ASubResource]);
    FRESTResource.PathParams.Clear;
    FRESTResource.QueryParams.Clear;
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

function TRESTClientWiRL.RemoveContextServerUse(
  const Value: string): string;
begin
  Result := ReplaceStr(Value, '/Janus', '');
end;

function TRESTClientWiRL.AcquireAccessToken: string;
var
  LTokenResource: TWiRLClientResource;
  LResponse: IWiRLResponse;
  LJSON: TJSONValue;
  LToken: TJSONValue;
begin
  /// <summary> Sucessor do extinto TWiRLClientToken: faz o POST de login no
  ///   resource de autenticacao do WiRL e devolve o "access_token" do
  ///   TWiRLLoginResponse. </summary>
  Result := '';
  if Length(FMethodToken) = 0 then
    Exit;
  LTokenResource := TWiRLClientResource.Create(nil);
  try
    LTokenResource.Application := FRESTClientApp;
    LTokenResource.Resource := FMethodToken;
    LTokenResource.Accept := TMediaType.APPLICATION_JSON;
    LTokenResource.Headers.Authorization :=
      TBasicAuth.Create(FAuthenticator.Username, FAuthenticator.Password);
    LResponse := LTokenResource.Post<string, IWiRLResponse>('');
    if LResponse.StatusCode >= 400 then
      Exit;
    LJSON := TJSONObject.ParseJSONValue(LResponse.ContentText);
    if LJSON = nil then
      Exit;
    try
      if LJSON is TJSONObject then
      begin
        LToken := TJSONObject(LJSON).GetValue('access_token');
        if LToken <> nil then
          Result := LToken.Value;
      end;
    finally
      LJSON.Free;
    end;
  finally
    LTokenResource.Free;
  end;
end;

procedure TRESTClientWiRL.SetAuthenticatorTypeValues;
begin
  case FAuthenticator.AuthenticatorType of
    atNoAuth:
      begin
        FRESTResource.Headers.Authorization := '';
        Exit;
      end;
    atBasicAuth:
      begin
        FRESTResource.Headers.Authorization :=
          TBasicAuth.Create(FAuthenticator.Username, FAuthenticator.Password);
        Exit;
      end;
    atBearerToken,
    atOAuth1,
    atOAuth2:
      begin
        if Length(FAuthenticator.Token) > 0 then
        begin
          FRESTResource.Headers.Authorization :=
            TBearerAuth.Create(FAuthenticator.Token);
          Exit;
        end;
      end;
  end;
  /// <summary> Sem token explicito: obtem um com as credenciais e o
  ///   reaproveita nas chamadas seguintes. </summary>
  if (Length(FAccessToken) = 0) and (Length(FAuthenticator.Username) > 0) then
    FAccessToken := AcquireAccessToken;
  if Length(FAccessToken) > 0 then
    FRESTResource.Headers.Authorization := TBearerAuth.Create(FAccessToken);
end;

procedure TRESTClientWiRL.SetBaseURL;
begin
  inherited;
  FBaseURL := FBaseURL + FRESTContext;
end;

procedure TRESTClientWiRL.SetParamValues;
var
  LFor: Integer;
begin
  /// <summary> Params
  ///   O WiRL trocou PathParamsValues posicional por substituicao nomeada
  ///   de {name}; os segmentos posicionais do Janus vao no proprio caminho.
  /// </summary>
  for LFor := 0 to FParams.Count -1 do
    FRESTResource.Resource := TWiRLURL.CombinePath([FRESTResource.Resource,
                                                    FParams.Items[LFor].AsString]);
  /// <summary> Query Params </summary>
  for LFor := 0 to FQueryParams.Count -1 do
    FRESTResource.QueryParams.Add(FQueryParams.Items[LFor].AsString);
end;

procedure TRESTClientWiRL.SetProxyParamsBodyValue(var AParams: string);
var
  LFor: Integer;
begin
  if FBodyParams.Count = 0 then
    raise Exception.Create('N'#$00E3'o foi passado o par'#$00E2'metro com os dados do insert!');

  for LFor := 0 to FBodyParams.Count -1 do
    AParams := AParams + FBodyParams.Items[LFor].AsString;
end;

procedure TRESTClientWiRL.SetProxyParamsClientValue;
begin
  FRESTClient.ProxyParams.BasicAuthentication := FProxyParams.BasicAuthentication;
  FRESTClient.ProxyParams.ProxyServer := FProxyParams.ProxyServer;
  FRESTClient.ProxyParams.ProxyPort := FProxyParams.ProxyPort;
  FRESTClient.ProxyParams.ProxyUsername := FProxyParams.ProxyUsername;
  FRESTClient.ProxyParams.ProxyPassword := FProxyParams.ProxyPassword;
end;

end.
