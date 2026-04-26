program JanusRESTHorseConsole;

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
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
  Janus.DML.Generator.SQLite,
  DataEngine.FactoryInterfaces,
  DataEngine.FactoryConnection,
  DataEngine.FactoryFireDAC,
  MetaDbDiff.Mapping.Register,
  Horse,
  Horse.Core.RouterTree,
  JanusRESTHorseConsole.Interfaces in 'Tests\JanusRESTHorseConsole.Interfaces.pas',
  JanusRESTHorseConsole.DataModule  in 'Tests\JanusRESTHorseConsole.DataModule.pas',
  JanusRESTHorseConsole.Provider    in 'Tests\JanusRESTHorseConsole.Provider.pas',
  JanusRESTHorseConsole.Models      in 'Tests\JanusRESTHorseConsole.Models.pas';

const
  cDB_PATH    = 'janus_rest_console_test.db';
  cAPI_PREFIX = 'api/Janus';

var
  GPort: Integer;

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

var
  LFDConn: TFDConnection;
  LConnection: IDBConnection;
  LProvider: IProvider;
  LThread: TThread;
  LOldRoutes: THorseRouterTree;
  LNewRoutes: THorseRouterTree;
begin
  IsMultiThread := True;
  FDManager.SilentMode := True;
  Randomize;
  GPort := 9200 + Random(100);
  LFDConn := TFDConnection.Create(nil);
  try
    LFDConn.Params.DriverID := 'SQLite';
    LFDConn.Params.Database := cDB_PATH;
    LFDConn.Params.Values['OpenMode'] := 'CreateUTF8';
    LFDConn.Connected := True;
    LConnection := TFactoryFireDAC.Create(LFDConn, dnSQLite);
    _CreateSchema(LConnection);
    LConnection := nil;
    LFDConn.Connected := False;
  finally
    FreeAndNil(LFDConn);
  end;
  _RegisterModels;
  LProvider := TProviderJanus.Create;
  LThread := TThread.CreateAnonymousThread(
    procedure
    begin
      THorse.Listen(GPort);
    end);
  LThread.FreeOnTerminate := True;
  LThread.Start;
  Sleep(200);
  Writeln('=== JanusRESTHorseConsole ===');
  Writeln(Format('Server running on http://127.0.0.1:%d/%s', [GPort, cAPI_PREFIX]));
  Writeln('Press ENTER to exit...');
  Readln;
  THorse.StopListen;
  LOldRoutes := THorse.Routes;
  LNewRoutes := THorseRouterTree.Create;
  THorse.Routes := LNewRoutes;
  LOldRoutes.Free;
  LProvider := nil;
  if TFile.Exists(cDB_PATH) then
    TFile.Delete(cDB_PATH);
end.
