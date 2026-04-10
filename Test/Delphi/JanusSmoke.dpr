program JanusSmoke;

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}
{$STRONGLINKTYPES ON}

uses
  System.Classes,
  System.SysUtils,
  System.IOUtils,
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
  TestObjectSetLazyProxy in 'Tests\TestObjectSetLazyProxy.pas',
  TestLazyMapping    in 'Tests\TestLazyMapping.pas',
  TestLazyProxy      in 'Tests\TestLazyProxy.pas',
  TestDataSetLazyProxy in 'Tests\TestDataSetLazyProxy.pas',
  TestRestLazyProxy  in 'Tests\TestRestLazyProxy.pas',
  TestLazyProxyMultiplicity in 'Tests\TestLazyProxyMultiplicity.pas',
  TestLazyWrapper    in 'Tests\TestLazyWrapper.pas',
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
  LXmlOutputFile: string;
  LXmlDir: string;
  LProbeFile: string;
  LProbeStream: TFileStream;
  LRunStartTime: TDateTime;
begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
  Exit;
{$ENDIF}
  // Fail-closed by default; set EXIT_SUCCESS only after all checks pass.
  System.ExitCode := EXIT_FAILURE;
  try
    // Record run start time for artifact freshness validation
    LRunStartTime := Now;
    // Check command line options
    TDUnitX.CheckCommandLine;
    // Pre-create XML output directory to prevent EInOutError on relative paths
    // (S2: relative-path directory handling fix)
    LXmlOutputFile := TDUnitX.Options.XMLOutputFile;
    if LXmlOutputFile <> '' then
    begin
      LXmlOutputFile := TPath.GetFullPath(LXmlOutputFile);
      LXmlDir := TPath.GetDirectoryName(LXmlOutputFile);
      if (LXmlDir <> '') and (not TDirectory.Exists(LXmlDir)) then
        TDirectory.CreateDirectory(LXmlDir);
      // Probe writability early to avoid false-positive runs when logger output path
      // is invalid or not writable.
      if LXmlDir <> '' then
      begin
        LProbeFile := TPath.Combine(LXmlDir, '.janus_smoke_write_probe.tmp');
        LProbeStream := nil;
        try
          LProbeStream := TFileStream.Create(LProbeFile, fmCreate);
        finally
          FreeAndNil(LProbeStream);
          if TFile.Exists(LProbeFile) then
            TFile.Delete(LProbeFile);
        end;
      end;
    end;
    // Create the test runner
    LRunner := TDUnitX.CreateRunner;
    // Add loggers
    LLogger := TDUnitXConsoleLogger.Create(True);
    LRunner.AddLogger(LLogger);
    // Generate NUnit compatible XML
    if LXmlOutputFile <> '' then
      LNunitLogger := TDUnitXXMLNUnitFileLogger.Create(LXmlOutputFile)
    else
      LNunitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    LRunner.AddLogger(LNunitLogger);
    LRunner.FailsOnNoAsserts := False;
    // Run tests
    LResults := LRunner.Execute;
    // S3: Artifact freshness validation — artifact must exist and timestamp must
    // be newer than run start time; stale or missing artifact is treated as failure.
    if LXmlOutputFile <> '' then
    begin
      if not TFile.Exists(LXmlOutputFile) then
      begin
        System.Writeln('EVIDENCE ERROR: XML artifact was not generated: ' + LXmlOutputFile);
        System.ExitCode := EXIT_FAILURE;
        Exit;
      end;
      if TFile.GetLastWriteTime(LXmlOutputFile) < LRunStartTime then
      begin
        System.Writeln('EVIDENCE ERROR: XML artifact is stale — timestamp predates run start. Possible reuse of prior execution artifact.');
        System.ExitCode := EXIT_FAILURE;
        Exit;
      end;
    end;
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
    begin
      // S3: Ensure exceptions during setup or execution yield EXIT_FAILURE,
      // not the default ExitCode=0 (which was the false-positive source).
      System.Writeln(E.ClassName, ': ', E.Message);
      System.ExitCode := EXIT_FAILURE;
    end;
  end;
end.
