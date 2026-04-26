program JanusLiveBindings;

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
  /// LiveBindings Tests — ESP-004 / R22.1
  Tests.Janus.LiveBindings.R221 in 'Tests\Tests.Janus.LiveBindings.R221.pas',
  /// LiveBindings Tests — ESP-004 / R22.2
  Tests.Janus.LiveBindings.R222 in 'Tests\Tests.Janus.LiveBindings.R222.pas',
  /// LiveBindings Tests — ESP-002 / R22.3
  Tests.Janus.LiveBindings.R223 in 'Tests\Tests.Janus.LiveBindings.R223.pas',
  /// LiveBindings Tests — ESP-002 / R22.4
  Tests.Janus.LiveBindings.R224 in 'Tests\Tests.Janus.LiveBindings.R224.pas';

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
  System.ExitCode := EXIT_FAILURE;
  try
    LRunStartTime := Now;
    TDUnitX.CheckCommandLine;
    LXmlOutputFile := TDUnitX.Options.XMLOutputFile;
    if LXmlOutputFile <> '' then
    begin
      LXmlOutputFile := TPath.GetFullPath(LXmlOutputFile);
      LXmlDir := TPath.GetDirectoryName(LXmlOutputFile);
      if (LXmlDir <> '') and (not TDirectory.Exists(LXmlDir)) then
        TDirectory.CreateDirectory(LXmlDir);
      if LXmlDir <> '' then
      begin
        LProbeFile := TPath.Combine(LXmlDir, '.janus_livebindings_write_probe.tmp');
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
    LRunner := TDUnitX.CreateRunner;
    LLogger := TDUnitXConsoleLogger.Create(True);
    LRunner.AddLogger(LLogger);
    if LXmlOutputFile <> '' then
      LNunitLogger := TDUnitXXMLNUnitFileLogger.Create(LXmlOutputFile)
    else
      LNunitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    LRunner.AddLogger(LNunitLogger);
    LRunner.FailsOnNoAsserts := False;
    LResults := LRunner.Execute;
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
        System.Writeln('EVIDENCE ERROR: XML artifact is stale.');
        System.ExitCode := EXIT_FAILURE;
        Exit;
      end;
    end;
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
      System.Writeln(E.ClassName, ': ', E.Message);
      System.ExitCode := EXIT_FAILURE;
    end;
  end;
end.
