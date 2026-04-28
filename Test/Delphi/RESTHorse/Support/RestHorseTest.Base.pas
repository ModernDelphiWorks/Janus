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

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit RestHorseTest.Base;

interface

uses
  SysUtils,
  Classes,
  IOUtils,
  SyncObjs,
  DUnitX.TestFramework,
  // DataEngine
  DataEngine.FactoryInterfaces,
  DataEngine.FactoryConnection,
  // FireDAC
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  // Janus
  MetaDbDiff.Mapping.Register,
  Janus.Server.Horse,
  // Horse
  Horse;

const
  cTEST_DB_PATH = 'janus_rest_horse_test.db';

type
  TRestHorseTestBase = class
  private
    FDConnection: TFDConnection;
    FConnection: IDBConnection;
    FHorseDConnection: TFDConnection;
    FHorseConnection: IDBConnection;
    FServer: TRESTServerHorse;
    FPort: Integer;
    FServerThread: TThread;
    procedure _StartHorse;
    procedure _StopHorse;
    procedure _CreateSchema;
    procedure _RegisterTestEntities;
  protected
    FPrefix: String;
    property Connection: IDBConnection read FConnection;
    property Port: Integer read FPort;
    function BuildResourceURL(const AResource: String): String;
    // Executes all pending DDL/DML against the test database
    procedure ExecuteSQL(const ASQL: String);
    // Resets the test database to a known clean state
    procedure ResetDatabase;
    // Inserts seed data for tests
    procedure SeedCustomers;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
  end;

implementation

uses
  DataEngine.FactoryFireDAC,
  Horse.Core.RouterTree,
  RestHorseTest.Models;

{ TRestHorseTestBase }

procedure TRestHorseTestBase._RegisterTestEntities;
begin
  TRegisterClass.RegisterEntity(TCustomerTest);
  TRegisterClass.RegisterEntity(TOrderTest);
  TRegisterClass.RegisterEntity(TProductTest);
  TRegisterClass.RegisterEntity(TCustomerOrderSummary);
  TRegisterClass.RegisterEntity(TGrantGETOnly);
  TRegisterClass.RegisterEntity(TGrantGETAndPOST);
  TRegisterClass.RegisterEntity(TGrantFullAllow);
  TRegisterClass.RegisterEntity(TGrantReadOnlyWithPOST);
end;

procedure TRestHorseTestBase._CreateSchema;
const
  LDDL_CUSTOMER =
    'CREATE TABLE IF NOT EXISTS customer_test (' +
    '  id      INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  name    VARCHAR(100) NOT NULL,' +
    '  email   VARCHAR(200),' +
    '  active  INTEGER DEFAULT 1' +
    ')';
  LDDL_ORDER =
    'CREATE TABLE IF NOT EXISTS order_test (' +
    '  id          INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  customer_id INTEGER NOT NULL,' +
    '  description VARCHAR(200),' +
    '  total       REAL DEFAULT 0' +
    ')';
  LDDL_PRODUCT =
    'CREATE TABLE IF NOT EXISTS product_test (' +
    '  id    INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  name  VARCHAR(100) NOT NULL,' +
    '  price REAL DEFAULT 0' +
    ')';
  LDDL_GRANT_GET_ONLY =
    'CREATE TABLE IF NOT EXISTS grant_get_only_test (' +
    '  id   INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  name VARCHAR(100) NOT NULL' +
    ')';
  LDDL_GRANT_GET_POST =
    'CREATE TABLE IF NOT EXISTS grant_get_post_test (' +
    '  id   INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  name VARCHAR(100) NOT NULL' +
    ')';
  LDDL_GRANT_FULL_ALLOW =
    'CREATE TABLE IF NOT EXISTS grant_full_allow_test (' +
    '  id   INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  name VARCHAR(100) NOT NULL' +
    ')';
  LDDL_GRANT_READONLY_POST =
    'CREATE TABLE IF NOT EXISTS grant_readonly_post_test (' +
    '  id   INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  name VARCHAR(100) NOT NULL' +
    ')';
begin
  FConnection.ExecuteDirect('DROP TABLE IF EXISTS order_test');
  FConnection.ExecuteDirect('DROP TABLE IF EXISTS customer_test');
  FConnection.ExecuteDirect('DROP TABLE IF EXISTS product_test');
  FConnection.ExecuteDirect('DROP TABLE IF EXISTS grant_get_only_test');
  FConnection.ExecuteDirect('DROP TABLE IF EXISTS grant_get_post_test');
  FConnection.ExecuteDirect('DROP TABLE IF EXISTS grant_full_allow_test');
  FConnection.ExecuteDirect('DROP TABLE IF EXISTS grant_readonly_post_test');
  FConnection.ExecuteDirect(LDDL_CUSTOMER);
  FConnection.ExecuteDirect(LDDL_ORDER);
  FConnection.ExecuteDirect(LDDL_PRODUCT);
  FConnection.ExecuteDirect(LDDL_GRANT_GET_ONLY);
  FConnection.ExecuteDirect(LDDL_GRANT_GET_POST);
  FConnection.ExecuteDirect(LDDL_GRANT_FULL_ALLOW);
  FConnection.ExecuteDirect(LDDL_GRANT_READONLY_POST);
end;

procedure TRestHorseTestBase.ResetDatabase;
begin
  FConnection.ExecuteDirect('DELETE FROM order_test');
  FConnection.ExecuteDirect('DELETE FROM customer_test');
  FConnection.ExecuteDirect('DELETE FROM product_test');
end;

procedure TRestHorseTestBase.SeedCustomers;
begin
  FConnection.ExecuteDirect(
    'INSERT INTO customer_test (name, email, active) VALUES (''Alice'', ''alice@test.com'', 1)');
  FConnection.ExecuteDirect(
    'INSERT INTO customer_test (name, email, active) VALUES (''Bob'', ''bob@test.com'', 1)');
  FConnection.ExecuteDirect(
    'INSERT INTO customer_test (name, email, active) VALUES (''Carol'', ''carol@test.com'', 0)');
end;

procedure TRestHorseTestBase.ExecuteSQL(const ASQL: String);
begin
  FConnection.ExecuteDirect(ASQL);
end;

function TRestHorseTestBase.BuildResourceURL(const AResource: String): String;
begin
  if FPrefix <> '' then
    Result := Format('http://127.0.0.1:%d/%s/%s', [FPort, FPrefix, AResource])
  else
    Result := Format('http://127.0.0.1:%d/%s', [FPort, AResource]);
end;

procedure TRestHorseTestBase._StartHorse;
begin
  FPort := 9890 + Random(100);
  FServer := TRESTServerHorse.Create(nil, FHorseConnection, FPrefix);
  FServerThread := TThread.CreateAnonymousThread(
    procedure
    begin
      THorse.Listen(FPort);
    end);
  FServerThread.FreeOnTerminate := False;
  FServerThread.Start;
  Sleep(200);
end;

procedure TRestHorseTestBase._StopHorse;
begin
  THorse.StopListen;
  if Assigned(FServerThread) then
  begin
    FServerThread.Terminate;
    FServerThread.WaitFor;
    FreeAndNil(FServerThread);
  end;
  FreeAndNil(FServer);
end;

procedure TRestHorseTestBase.SetupFixture;
begin
  Randomize;
  FDConnection := TFDConnection.Create(nil);
  FDConnection.Params.DriverID := 'SQLite';
  FDConnection.Params.Database := cTEST_DB_PATH;
  FDConnection.Params.Values['OpenMode'] := 'CreateUTF8';
  FDConnection.Connected := True;
  FConnection := TFactoryFireDAC.Create(FDConnection, dnSQLite);
  FHorseDConnection := TFDConnection.Create(nil);
  FHorseDConnection.Params.DriverID := 'SQLite';
  FHorseDConnection.Params.Database := cTEST_DB_PATH;
  FHorseDConnection.Params.Values['OpenMode'] := 'CreateUTF8';
  FHorseDConnection.ResourceOptions.SilentMode := True;
  FHorseDConnection.Connected := True;
  FHorseConnection := TFactoryFireDAC.Create(FHorseDConnection, dnSQLite);
  _RegisterTestEntities;
  _StartHorse;
end;

procedure TRestHorseTestBase.TearDownFixture;
var
  LOldRoutes: THorseRouterTree;
  LNewRoutes: THorseRouterTree;
begin
  _StopHorse;
  LOldRoutes := THorse.Routes;
  LNewRoutes := THorseRouterTree.Create;
  THorse.Routes := LNewRoutes;
  LOldRoutes.Free;
  FHorseConnection := nil;
  FHorseDConnection.Connected := False;
  FreeAndNil(FHorseDConnection);
  FConnection := nil;
  FDConnection.Connected := False;
  FreeAndNil(FDConnection);
  if TFile.Exists(cTEST_DB_PATH) then
    TFile.Delete(cTEST_DB_PATH);
end;

procedure TRestHorseTestBase.Setup;
begin
  _CreateSchema;
end;

procedure TRestHorseTestBase.TearDown;
begin
end;

end.
