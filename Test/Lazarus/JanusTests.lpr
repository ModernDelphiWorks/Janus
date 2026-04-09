program JanusTests;

// =============================================================================
// JANUS ORM -- FPCUnit Test Runner
//
// Console test runner for all Janus DLL Bridge test suites.
// Registers: Strategy 1, Strategy 2, Criteria, Edge Cases.
//
// SPRINT-09 — ESP-006-FPCTEST
// =============================================================================

{$mode objfpc}{$H+}

uses
  Classes, SysUtils,
  fpcunit, testregistry, consoletestrunner,
  TestBase,
  TestJanusStrategy1,
  TestJanusStrategy2,
  TestJanusCriteria,
  TestJanusEdgeCases;

var
  LApp: TTestRunner;
begin
  LApp := TTestRunner.Create(nil);
  try
    LApp.Initialize;
    LApp.Run;
  finally
    LApp.Free;
  end;
end.
