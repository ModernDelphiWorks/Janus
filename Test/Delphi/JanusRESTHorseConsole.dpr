program JanusRESTHorseConsole;

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Net.HTTPClient,
  Net.URLClient,
  // FireDAC silent wait-cursor — required when TFDConnection is used from
  // non-VCL threads. Registers a null GUI provider so FireDAC does not
  // invoke VCL cursor callbacks that AV outside the main thread.
  FireDAC.ConsoleUI.Wait,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  // SQLite DML generator — registers the SQLite factory with TDriverRegister
  Janus.DML.Generator.SQLite,
  // DataEngine
  DataEngine.FactoryInterfaces,
  DataEngine.FactoryConnection,
  DataEngine.FactoryFireDAC,
  // Janus
  MetaDbDiff.Mapping.Register,
  Janus.Server.Horse,
  // Horse
  Horse,
  Horse.Core.RouterTree,
  // Console models
  JanusRESTHorseConsole.Models in 'Tests\JanusRESTHorseConsole.Models.pas';

const
  cDB_PATH         = 'janus_rest_console_test.db';
  cAPI_PREFIX      = 'api/Janus';
  cTIMEOUT_MS      = 2000;
  cVERBNOTALLOWED  = 'not allowed for';
  cREADONLY_MSG    = 'read-only (RESTReadOnly)';
  cSCENARIOS_TOTAL = 12;
  EXIT_SUCCESS     = 0;
  EXIT_FAILURE     = 1;

var
  GPort: Integer;
  GPassCount: Integer;
  GFailCount: Integer;

procedure _Assert(const AScenario: String; const ACondition: Boolean;
  const AReason: String = '');
begin
  if ACondition then
  begin
    Writeln('[PASS] ' + AScenario);
    Inc(GPassCount);
  end
  else
  begin
    if AReason <> '' then
      Writeln('[FAIL] ' + AScenario + ' -- ' + AReason)
    else
      Writeln('[FAIL] ' + AScenario);
    Inc(GFailCount);
  end;
end;

function _URL(const AResource: String): String;
begin
  Result := Format('http://127.0.0.1:%d/%s/%s', [GPort, cAPI_PREFIX, AResource]);
end;

function _Get(const AURL: String): String;
var
  LClient: THTTPClient;
begin
  LClient := THTTPClient.Create;
  try
    LClient.ConnectionTimeout := cTIMEOUT_MS;
    LClient.ResponseTimeout := cTIMEOUT_MS;
    Result := LClient.Get(AURL).ContentAsString(TEncoding.UTF8);
  finally
    LClient.Free;
  end;
end;

function _Post(const AURL: String; const ABody: String): String;
var
  LClient: THTTPClient;
  LStream: TStringStream;
begin
  LClient := THTTPClient.Create;
  try
    LClient.ConnectionTimeout := cTIMEOUT_MS;
    LClient.ResponseTimeout := cTIMEOUT_MS;
    LStream := TStringStream.Create(ABody, TEncoding.UTF8);
    try
      Result := LClient.Post(AURL, LStream, nil,
        [TNameValuePair.Create('Content-Type', 'application/json')])
        .ContentAsString(TEncoding.UTF8);
    finally
      LStream.Free;
    end;
  finally
    LClient.Free;
  end;
end;

function _Put(const AURL: String; const ABody: String): String;
var
  LClient: THTTPClient;
  LStream: TStringStream;
begin
  LClient := THTTPClient.Create;
  try
    LClient.ConnectionTimeout := cTIMEOUT_MS;
    LClient.ResponseTimeout := cTIMEOUT_MS;
    LStream := TStringStream.Create(ABody, TEncoding.UTF8);
    try
      Result := LClient.Put(AURL, LStream, nil,
        [TNameValuePair.Create('Content-Type', 'application/json')])
        .ContentAsString(TEncoding.UTF8);
    finally
      LStream.Free;
    end;
  finally
    LClient.Free;
  end;
end;

function _Delete(const AURL: String): String;
var
  LClient: THTTPClient;
begin
  LClient := THTTPClient.Create;
  try
    LClient.ConnectionTimeout := cTIMEOUT_MS;
    LClient.ResponseTimeout := cTIMEOUT_MS;
    Result := LClient.Delete(AURL).ContentAsString(TEncoding.UTF8);
  finally
    LClient.Free;
  end;
end;

procedure _CreateSchema(const AConn: IDBConnection);
begin
  AConn.ExecuteDirect('DROP TABLE IF EXISTS demo_product');
  AConn.ExecuteDirect('DROP TABLE IF EXISTS demo_readonly');
  AConn.ExecuteDirect('DROP TABLE IF EXISTS demo_get_only');
  AConn.ExecuteDirect('DROP TABLE IF EXISTS demo_get_post');
  AConn.ExecuteDirect(
    'CREATE TABLE demo_product (' +
    '  id    INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  name  VARCHAR(100) NOT NULL,' +
    '  price REAL DEFAULT 0)');
  AConn.ExecuteDirect(
    'CREATE TABLE demo_readonly (' +
    '  id   INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  name VARCHAR(100) NOT NULL)');
  AConn.ExecuteDirect(
    'CREATE TABLE demo_get_only (' +
    '  id   INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  name VARCHAR(100) NOT NULL)');
  AConn.ExecuteDirect(
    'CREATE TABLE demo_get_post (' +
    '  id   INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  name VARCHAR(100) NOT NULL)');
  AConn.ExecuteDirect('INSERT INTO demo_readonly (name) VALUES (''ReadOnlySeed'')');
  AConn.ExecuteDirect('INSERT INTO demo_get_only (name) VALUES (''GetOnlySeed'')');
  AConn.ExecuteDirect('INSERT INTO demo_get_post (name) VALUES (''GetPostSeed'')');
end;

procedure _RegisterModels;
begin
  TRegisterClass.RegisterEntity(TDemoProduct);
  TRegisterClass.RegisterEntity(TDemoReadOnly);
  TRegisterClass.RegisterEntity(TDemoGetOnly);
  TRegisterClass.RegisterEntity(TDemoGetPost);
end;

function _StartServer(const AHorseConn: IDBConnection): TRESTServerHorse;
var
  LThread: TThread;
begin
  Result := TRESTServerHorse.Create(nil, AHorseConn, cAPI_PREFIX);
  LThread := TThread.CreateAnonymousThread(
    procedure
    begin
      THorse.Listen(GPort);
    end);
  LThread.FreeOnTerminate := True;
  LThread.Start;
  Sleep(200);
end;

procedure _RunDemoProductScenarios;
var
  LResult: String;
begin
  LResult := _Get(_URL('DemoProduct'));
  _Assert('GET DemoProduct list',
    not LResult.Contains(cVERBNOTALLOWED) and not LResult.Contains(cREADONLY_MSG));
  LResult := _Post(_URL('DemoProduct'), '{"name":"TestProduct","price":9.99}');
  _Assert('POST DemoProduct insert',
    not LResult.Contains(cVERBNOTALLOWED) and not LResult.Contains(cREADONLY_MSG));
  LResult := _Put(_URL('DemoProduct'), '{"id":1,"name":"UpdatedProduct","price":19.99}');
  _Assert('PUT DemoProduct update',
    not LResult.Contains(cVERBNOTALLOWED) and not LResult.Contains(cREADONLY_MSG));
  LResult := _Delete(_URL('DemoProduct(1)'));
  _Assert('DELETE DemoProduct',
    not LResult.Contains(cVERBNOTALLOWED) and not LResult.Contains(cREADONLY_MSG));
end;

procedure _RunDemoReadOnlyScenarios;
var
  LResult: String;
begin
  LResult := _Get(_URL('DemoReadOnly'));
  _Assert('GET DemoReadOnly (allowed)',
    not LResult.Contains(cVERBNOTALLOWED) and not LResult.Contains(cREADONLY_MSG));
  LResult := _Post(_URL('DemoReadOnly'), '{"name":"ShouldFail"}');
  _Assert('POST DemoReadOnly blocked (RESTReadOnly)', LResult.Contains(cREADONLY_MSG));
  LResult := _Put(_URL('DemoReadOnly'), '{"id":1,"name":"ShouldFail"}');
  _Assert('PUT DemoReadOnly blocked (RESTReadOnly)', LResult.Contains(cREADONLY_MSG));
end;

procedure _RunDemoGetOnlyScenarios;
var
  LResult: String;
begin
  LResult := _Get(_URL('DemoGetOnly'));
  _Assert('GET DemoGetOnly (allowed)',
    not LResult.Contains(cVERBNOTALLOWED) and not LResult.Contains(cREADONLY_MSG));
  LResult := _Post(_URL('DemoGetOnly'), '{"name":"ShouldFail"}');
  _Assert('POST DemoGetOnly blocked (RESTAllowGET)', LResult.Contains(cVERBNOTALLOWED));
end;

procedure _RunDemoGetPostScenarios;
var
  LResult: String;
begin
  LResult := _Get(_URL('DemoGetPost'));
  _Assert('GET DemoGetPost (allowed)',
    not LResult.Contains(cVERBNOTALLOWED) and not LResult.Contains(cREADONLY_MSG));
  LResult := _Post(_URL('DemoGetPost'), '{"name":"GetPostInsert"}');
  _Assert('POST DemoGetPost insert (allowed)',
    not LResult.Contains(cVERBNOTALLOWED) and not LResult.Contains(cREADONLY_MSG));
  LResult := _Delete(_URL('DemoGetPost(1)'));
  _Assert('DELETE DemoGetPost blocked (RESTAllowGET+POST)', LResult.Contains(cVERBNOTALLOWED));
end;

procedure RunTests;
begin
  Writeln('=== JanusRESTHorseConsole Self-Test ===');
  Writeln(Format('Server: http://127.0.0.1:%d/%s', [GPort, cAPI_PREFIX]));
  Writeln('');
  _RunDemoProductScenarios;
  _RunDemoReadOnlyScenarios;
  _RunDemoGetOnlyScenarios;
  _RunDemoGetPostScenarios;
  Writeln('');
  Writeln(Format('Result: %d/%d passed', [GPassCount, cSCENARIOS_TOTAL]));
end;

var
  LFDConn: TFDConnection;
  LConnection: IDBConnection;
  LHorseFDConn: TFDConnection;
  LHorseConn: IDBConnection;
  LServer: TRESTServerHorse;
  LOldRoutes: THorseRouterTree;
  LNewRoutes: THorseRouterTree;
begin
  IsMultiThread := True;
  FDManager.SilentMode := True;
  Randomize;
  GPort := 9200 + Random(100);
  GPassCount := 0;
  GFailCount := 0;
  System.ExitCode := EXIT_FAILURE;
  try
    LFDConn := TFDConnection.Create(nil);
    LFDConn.Params.DriverID := 'SQLite';
    LFDConn.Params.Database := cDB_PATH;
    LFDConn.Params.Values['OpenMode'] := 'CreateUTF8';
    LFDConn.Connected := True;
    LConnection := TFactoryFireDAC.Create(LFDConn, dnSQLite);
    LHorseFDConn := TFDConnection.Create(nil);
    LHorseFDConn.Params.DriverID := 'SQLite';
    LHorseFDConn.Params.Database := cDB_PATH;
    LHorseFDConn.Params.Values['OpenMode'] := 'CreateUTF8';
    LHorseFDConn.ResourceOptions.SilentMode := True;
    LHorseFDConn.Connected := True;
    LHorseConn := TFactoryFireDAC.Create(LHorseFDConn, dnSQLite);
    _CreateSchema(LConnection);
    _RegisterModels;
    LServer := _StartServer(LHorseConn);
    try
      RunTests;
      if GFailCount = 0 then
        System.ExitCode := EXIT_SUCCESS;
      Writeln('Server still running — press ENTER to exit');
      Readln;
    finally
      THorse.StopListen;
      LOldRoutes := THorse.Routes;
      LNewRoutes := THorseRouterTree.Create;
      THorse.Routes := LNewRoutes;
      LOldRoutes.Free;
      FreeAndNil(LServer);
    end;
    LHorseConn := nil;
    LHorseFDConn.Connected := False;
    FreeAndNil(LHorseFDConn);
    LConnection := nil;
    LFDConn.Connected := False;
    FreeAndNil(LFDConn);
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      System.ExitCode := EXIT_FAILURE;
    end;
  end;
  if TFile.Exists(cDB_PATH) then
    TFile.Delete(cDB_PATH);
end.
