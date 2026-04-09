program JanusSmoke;

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ENDIF}
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  /// Models
  MetaDbDiff.Mapping.Register,
  Model.Atendimento in '..\..\Examples\Delphi\Data\Object Lazy\Model.Atendimento.pas',
  Model.Exame       in '..\..\Examples\Delphi\Data\Object Lazy\Model.Exame.pas',
  Model.Procedimento in '..\..\Examples\Delphi\Data\Object Lazy\Model.Procedimento.pas',
  Model.Setor       in '..\..\Examples\Delphi\Data\Object Lazy\Model.Setor.pas',
  Janus.Model.Client in '..\..\Examples\Delphi\Data\Models\Janus.Model.Client.pas',
  Janus.Model.Detail in '..\..\Examples\Delphi\Data\Models\Janus.Model.Detail.pas',
  Janus.Model.Lookup in '..\..\Examples\Delphi\Data\Models\Janus.Model.Lookup.pas',
  Janus.Model.Master in '..\..\Examples\Delphi\Data\Models\Janus.Model.Master.pas',
  Janus.DML.Generator.SQLite in '..\..\Source\Core\Janus.DML.Generator.SQLite.pas',
  /// Tests
  TestMappingCache   in 'Tests\TestMappingCache.pas',
  TestRttiSingleton  in 'Tests\TestRttiSingleton.pas',
  TestNullable       in 'Tests\TestNullable.pas',
  TestSmokeLazyLoading in 'Tests\TestSmokeLazyLoading.pas',
  TestLazyMapping    in 'Tests\TestLazyMapping.pas',
  TestLazyProxy      in 'Tests\TestLazyProxy.pas',
  TestDataSetLazyProxy in 'Tests\TestDataSetLazyProxy.pas',
  TestRestLazyProxy  in 'Tests\TestRestLazyProxy.pas',
  TestLazyProxyMultiplicity in 'Tests\TestLazyProxyMultiplicity.pas',
  TestGetDictionary  in 'Tests\TestGetDictionary.pas',
  TestQueryCache     in 'Tests\TestQueryCache.pas',
  TestDataSetAutoLazy in 'Tests\TestDataSetAutoLazy.pas',
  /// Advanced Tests — SPRINT-14
  TestCriteriaAdvanced in 'Tests\TestCriteriaAdvanced.pas',
  TestMiddlewarePipeline in 'Tests\TestMiddlewarePipeline.pas',
  TestDMLGenerator in 'Tests\TestDMLGenerator.pas',
  TestFluentSQLIntegration in 'Tests\TestFluentSQLIntegration.pas';

const
  EXIT_SUCCESS = 0;
  EXIT_FAILURE = 1;

var
  LRunner: ITestRunner;
  LResults: IRunResults;
  LLogger: ITestLogger;
  LNunitLogger: ITestLogger;
begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
  Exit;
{$ENDIF}
  try
    // Check command line options
    TDUnitX.CheckCommandLine;
    // Create the test runner
    LRunner := TDUnitX.CreateRunner;
    // Add loggers
    LLogger := TDUnitXConsoleLogger.Create(True);
    LRunner.AddLogger(LLogger);
    // Generate NUnit compatible XML
    LNunitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    LRunner.AddLogger(LNunitLogger);
    LRunner.FailsOnNoAsserts := False;
    // Run tests
    LResults := LRunner.Execute;
    // Report results
    if not LResults.AllPassed then
      System.ExitCode := EXIT_FAILURE
    else
      System.ExitCode := EXIT_SUCCESS;
    {$IFNDEF CI}
    if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
    begin
      System.Write('Done.. press <Enter> key to quit.');
      System.Readln;
    end;
    {$ENDIF}
  except
    on E: Exception do
      System.Writeln(E.ClassName, ': ', E.Message);
  end;
end.
