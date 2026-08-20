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
    // ISSUE #338 - THIS ASSIGNMENT WAS ABSENT, AND EVERY PUT ANSWERED ''.
    // The method executed the request and returned without ever touching
    // Result, so the server's answer was read and discarded - and nothing
    // warned, because the except below terminates the function.
    //
    // #338 repaired the identical hole in TRESTClientDataSnap.DoPUT and
    // deliberately left this one open, because "the sibling does it" is not an
    // argument this house accepts. So the contract was measured HERE, on this
    // class, and it is NOT the same contract: DoGET, DoPOST and DoDELETE OF
    // THIS CLASS all answer ResponsePayload under the expression below, and
    // the flag in it is genuinely VARIABLE here - RootElement is a published,
    // writable property of TRESTClientWS alone and the constructor leaves it
    // EMPTY - where TRESTClientDataSnap pins it to 'result' with no way in from
    // outside. So this expression has two live arms and its DataSnap
    // counterpart has one, and TTestClientWSVerb drives both.
    //
    // Joining that contract means joining its failure half: ResponsePayload
    // raises INSIDE this try for a nil, non-array or empty answer, so a PUT
    // that used to swallow a malformed body silently now reports it through the
    // handler below, with the server body still attached.
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
    // PUT WAS THE ONE ARM STILL LEFT AS A STATEMENT, AND IT NO LONGER IS.
    // The #323 repair assigned the other three and left this one, on the
    // measured ground that DoPUT read nothing from the response and never
    // assigned its own Result - so `Result := DoPUT(...)` was INERT here. That
    // ground was real while it lasted and it is now gone: DoPUT answers
    // ResponsePayload, so the assignment carries a payload, and dropping it
    // would reproduce on this one arm exactly the defect #323 removed from the
    // other three.
    //
    // AN EARLIER VERSION OF THIS COMMENT GAVE A FALSE REASON, and it sat in
    // Source holding up a design choice. It said assigning it "would add the
    // undefined-return warning that assigning an unassigned Result earns".
    // Re-measured at ea18be3 under #338, full rebuild with the DCU output
    // wiped so that every unit re-emits its warnings: writing
    // `Result := DoPUT(...)` here and building emits NO warning naming this
    // unit at all. That measurement is what made the assignment free to make,
    // and it is the half of the old note that survives its conclusion.
    //
    // THE INVENTORY CLAUSE THAT USED TO FOLLOW IT IS WITHDRAWN. It said "the
    // only W1035 in the entire build is Janus.Manager.DataSet's
    // AutoNextPacket". There is no W1035 in this build AT ALL: the census is
    // W1000 x12, W1010 x3, W1020 x100, W1036 x2, identical with and without
    // the experiment above, and the warning is suppressed nowhere - not in
    // Janus.inc, not in the .dproj.
    //
    // THE EXAMPLE DID NOT GO MISSING - ISSUE #332 REMOVED IT.
    // AutoNextPacket<T> genuinely did emit that W1035 while it was a function
    // whose body never assigned Result; #332 made it a procedure, so there is
    // no site left for the warning to come from. Test.Janus.Manager.
    // AutoNextPacket carries that measurement, and records besides that "the
    // only W1035 in the tree" was a false framing even when the warning still
    // existed: two more instances of the same defect sit under Components\,
    // which no test project compiles. This comment was therefore repeating a
    // count that had already been retired AND already been corrected in
    // another fixture - which is the whole hazard of quoting a census across
    // files instead of re-running it.
    //
    // W1035 remains a warning about a DEFINITION rather than about a call
    // site, and that is the point being made here. The counter-example was
    // already in the tree - TRESTClientDataSnap.DoPUT likewise never assigned
    // Result and WAS assigned at two sites, silently.
    //
    // ISSUE #338 HAS SINCE CLOSED THAT COUNTER-EXAMPLE, AND ONLY ON THAT SIDE.
    // TRESTClientDataSnap.DoPUT now answers ResponsePayload, like the three
    // other verbs of ITS class - so the sentence above is history, not a
    // description of the tree, and the silent-assignment point it made no
    // longer has that example to stand on. The W1035 measurement it rests on
    // is unaffected: that was about a call site earning no warning, which
    // remains true here.
    //
    // THIS SIDE WAS DELIBERATELY LEFT ALONE, AND IS NO LONGER. #338 repaired
    // the DataSnap client because the contract was measured on THAT class, and
    // refused to carry the repair across on the strength of the analogy alone -
    // "the sibling does it" is the argument this house does not accept. The
    // follow-up measured the contract HERE instead, and found a DIFFERENT one:
    // the root-element flag is variable on this class and constant on that one,
    // so this DoPUT's answer had to be pinned in BOTH arms where one was enough
    // there. See the note in DoPUT, and TTestClientWSVerb.
    //
    // Also measured under #338, by mutation with a compiler-echoed directive:
    // swapping the HTTP verb of TRESTClientWS.DoPOST killed NO test in the
    // suite, and the same was true of DoPUT. This family's verbs were pinned by
    // nothing - the #323 stub answers every verb identically, so verb identity
    // was invisible to it. Both were re-run at 0d21f2c and both confirmed,
    // 214 found / 214 passed each. TTestClientWSVerb now reads the verb off the
    // socket, and both die there.
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
