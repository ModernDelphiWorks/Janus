unit TestBase;

// =============================================================================
// JANUS ORM -- FPCUnit Test Base Class
//
// Provides TJanusTestBase with SQLite setup/teardown for all test suites.
// Each test gets a fresh database file, created in SetUp and deleted in TearDown.
//
// SPRINT-09 — ESP-006-FPCTEST / ADR-010, ADR-011
// =============================================================================

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SysUtils, fpcunit,
  Janus.DLL.Interfaces,
  Janus.IncludeDll,
  Janus.Lazarus.Helper;

type
  TJanusTestBase = class(TTestCase)
  protected
    FConn: IJanusConnection;
    FDbFile: string;
    procedure SetUp; override;
    procedure TearDown; override;
  end;

implementation

procedure TJanusTestBase.SetUp;
var
  LFileStream: TFileStream;
begin
  FDbFile := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'janus_test_' + ClassName + '.db';
  if FileExists(FDbFile) then
    DeleteFile(FDbFile);

  // Some bridge builds expect the SQLite file to exist before opening.
  LFileStream := TFileStream.Create(FDbFile, fmCreate);
  LFileStream.Free;

  JanusRegisterModels;
  FConn := JanusConnectSQLiteStr(FDbFile);
  AssertNotNull('Connection must not be nil', FConn);
end;

procedure TJanusTestBase.TearDown;
begin
  FConn := nil;
  if FileExists(FDbFile) then
    DeleteFile(FDbFile);
end;

end.
