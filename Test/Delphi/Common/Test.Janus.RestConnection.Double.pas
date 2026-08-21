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

{ @abstract(Janus Framework - a RECORDING IRESTConnection double.)

  WHAT IT IS FOR

  Every REST client path in the framework ends at IRESTConnection.Execute.
  A test that wants to drive those paths has exactly two choices: a live HTTP
  server, or a double. This is the double. It never opens a socket, it answers
  every Execute with a canned body, and it REMEMBERS what it was asked - the
  resource, the sub-resource, the verb and whatever the caller pushed through
  AddBodyParam/AddQueryParam/AddParam from inside the Execute callback.

  WHY RECORDING AND NOT INERT

  Test.Janus.MasterDetail.Link already carries an INERT double: it counts calls
  and returns '[]'. That is enough when the thing under test is the wiring the
  adapter installs afterwards. It is NOT enough for the methods that only exist
  when DRIVERRESTFUL is defined - TSessionRestFul<M>.Find(AMethodName, AParams)
  and its callers - because the whole point of those methods is WHERE they put
  the method name and the parameters. A double that does not remember cannot
  tell a correct placement from a swapped one.

  THE CANNED BODY IS NOT ARBITRARY

  It defaults to '[]' and must never default to ''. TSessionRestFul<M>.Find
  indexes the answer (LJSON[1]) before parsing it, and these test projects
  compile with range checking on, so an empty answer would fail as a range
  error inside the framework instead of as the assertion the test wrote.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.RestConnection.Double;

interface

uses
  Classes,
  SysUtils,
  Generics.Collections,
  Janus.Client.Methods,
  Janus.RestFactory.Interfaces;

type
  /// <summary> What the double raises when it is told to fail instead of
  ///  answering. It stands for EVERY way a real Execute can raise before it
  ///  ever produces a body: the server is down, the socket times out, the
  ///  status is 500 and the concrete client turns that into
  ///  EJanusRESTException. What the caller under test must see is THIS class
  ///  and THIS message - anything else means the failure was swallowed or
  ///  replaced on the way out. Issue #313. </summary>
  ERestConnectionFailure = class(Exception);

  /// <summary> One recorded call to IRESTConnection.Execute. </summary>
  TRestCallRecord = record
    Resource: string;
    SubResource: string;
    RequestMethod: TRESTRequestMethodType;
    BodyParams: string;
    QueryParams: string;
    Params: string;
  end;

  /// <summary> An IRESTConnection that never leaves the process and keeps a
  ///  transcript of everything it was asked to do. </summary>
  TRecordingRestConnection = class(TInterfacedObject, IRESTConnection)
  private
    FCalls: TList<TRestCallRecord>;
    FResponse: string;
    FPendingBody: string;
    FPendingQuery: string;
    FPendingParams: string;
    FServerUse: Boolean;
    FExecuteError: string;
    function DoExecute(const AResource, ASubResource: string;
      const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc): string;
    function GetCallCount: Integer;
    function GetLastCall: TRestCallRecord;
  public
    constructor Create;
    destructor Destroy; override;
    // IRESTConnection
    function GetBaseURL: string;
    function GetFullURL: string;
    function GetUsername: string;
    function GetPassword: string;
    function GetMethodGET: string;
    function GetMethodGETId: string;
    function GetMethodGETWhere: string;
    function GetMethodPOST: string;
    function GetMethodPUT: string;
    function GetMethodDELETE: string;
    function GetMethodGETNextPacket: string;
    function GetMethodGETNextPacketWhere: string;
    function GetMethodToken: string;
    function GetServerUse: Boolean;
    procedure SetCommandMonitor(AMonitor: ICommandMonitor);
    procedure SetClassNotServerUse(const Value: Boolean);
    function CommandMonitor: ICommandMonitor;
    function Execute(const AResource, ASubResource: string;
      const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc = nil): string; overload;
    function Execute(const AResource: string;
      const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc = nil): string; overload;
    procedure AddParam(AValue: string);
    procedure AddQueryParam(AValue: string);
    procedure AddBodyParam(AValue: string);
    // transcript
    property CallCount: Integer read GetCallCount;
    property LastCall: TRestCallRecord read GetLastCall;
    property Response: string read FResponse write FResponse;
    /// <summary> Set it and Execute RAISES ERestConnectionFailure with this
    ///  text instead of returning a body - AFTER the call has been recorded,
    ///  so the transcript still proves the path reached the connection. Left
    ///  empty (the default) the double behaves exactly as before.
    ///
    ///  This is the only way a test can drive the failure branch of a caller
    ///  that has a try/finally around Execute: no canned BODY can do it,
    ///  because a body means Execute returned. Issue #313. </summary>
    property ExecuteError: string read FExecuteError write FExecuteError;
  end;

implementation

const
  cEMPTYJSONARRAY = '[]';

{ TRecordingRestConnection }

constructor TRecordingRestConnection.Create;
begin
  inherited Create;
  FCalls := TList<TRestCallRecord>.Create;
  FResponse := cEMPTYJSONARRAY;
  FServerUse := False;
end;

destructor TRecordingRestConnection.Destroy;
begin
  FCalls.Free;
  inherited;
end;

function TRecordingRestConnection.GetCallCount: Integer;
begin
  Result := FCalls.Count;
end;

function TRecordingRestConnection.GetLastCall: TRestCallRecord;
begin
  if FCalls.Count = 0 then
    raise Exception.Create('no call was recorded - the path under test never ' +
      'reached IRESTConnection.Execute');
  Result := FCalls[FCalls.Count - 1];
end;

function TRecordingRestConnection.DoExecute(const AResource,
  ASubResource: string; const ARequestMethod: TRESTRequestMethodType;
  const AParams: TProc): string;
var
  LRecord: TRestCallRecord;
begin
  FPendingBody := '';
  FPendingQuery := '';
  FPendingParams := '';
  // The framework pushes body/query/params from INSIDE this callback, so the
  // transcript can only be closed after it has run.
  if Assigned(AParams) then
    AParams();
  LRecord.Resource := AResource;
  LRecord.SubResource := ASubResource;
  LRecord.RequestMethod := ARequestMethod;
  LRecord.BodyParams := FPendingBody;
  LRecord.QueryParams := FPendingQuery;
  LRecord.Params := FPendingParams;
  FCalls.Add(LRecord);
  // RECORD FIRST, THEN FAIL. A failing Execute that left no trace would be
  // indistinguishable from a caller that never called it at all.
  if Length(FExecuteError) > 0 then
    raise ERestConnectionFailure.Create(FExecuteError);
  Result := FResponse;
end;

function TRecordingRestConnection.Execute(const AResource, ASubResource: string;
  const ARequestMethod: TRESTRequestMethodType; const AParams: TProc): string;
begin
  Result := DoExecute(AResource, ASubResource, ARequestMethod, AParams);
end;

function TRecordingRestConnection.Execute(const AResource: string;
  const ARequestMethod: TRESTRequestMethodType; const AParams: TProc): string;
begin
  Result := DoExecute(AResource, '', ARequestMethod, AParams);
end;

procedure TRecordingRestConnection.AddBodyParam(AValue: string);
begin
  FPendingBody := FPendingBody + AValue;
end;

procedure TRecordingRestConnection.AddQueryParam(AValue: string);
begin
  FPendingQuery := FPendingQuery + AValue;
end;

procedure TRecordingRestConnection.AddParam(AValue: string);
begin
  FPendingParams := FPendingParams + AValue;
end;

function TRecordingRestConnection.CommandMonitor: ICommandMonitor;
begin
  Result := nil;
end;

procedure TRecordingRestConnection.SetCommandMonitor(AMonitor: ICommandMonitor);
begin
end;

procedure TRecordingRestConnection.SetClassNotServerUse(const Value: Boolean);
begin
end;

function TRecordingRestConnection.GetBaseURL: string;
begin
  Result := 'http://recorded.local';
end;

function TRecordingRestConnection.GetFullURL: string;
begin
  Result := 'http://recorded.local';
end;

function TRecordingRestConnection.GetUsername: string;
begin
  Result := '';
end;

function TRecordingRestConnection.GetPassword: string;
begin
  Result := '';
end;

function TRecordingRestConnection.GetMethodGET: string;
begin
  Result := '';
end;

function TRecordingRestConnection.GetMethodGETId: string;
begin
  Result := '';
end;

function TRecordingRestConnection.GetMethodGETWhere: string;
begin
  Result := '';
end;

function TRecordingRestConnection.GetMethodPOST: string;
begin
  Result := '';
end;

function TRecordingRestConnection.GetMethodPUT: string;
begin
  Result := '';
end;

function TRecordingRestConnection.GetMethodDELETE: string;
begin
  Result := '';
end;

function TRecordingRestConnection.GetMethodGETNextPacket: string;
begin
  Result := '';
end;

function TRecordingRestConnection.GetMethodGETNextPacketWhere: string;
begin
  Result := '';
end;

function TRecordingRestConnection.GetMethodToken: string;
begin
  Result := '';
end;

function TRecordingRestConnection.GetServerUse: Boolean;
begin
  Result := FServerUse;
end;

end.
