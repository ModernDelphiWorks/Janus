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

{ @abstract(Reusable DUnitX runner for Janus test executors.)
  Encapsulates the canonical bootstrap used by every test .dpr:
  TDUnitX.CheckCommandLine, XML output directory creation, optional
  write-probe, runner + console + NUnit XML logger wiring, optional
  artifact freshness validation, fail-closed exit code policy and
  exception handling. AProbeFileName='' skips the write-probe;
  AValidateFreshness=False skips the freshness check (parity flags
  for executors that never had those gates). }
unit Janus.Test.Runner;

interface

uses
  System.Classes,
  System.SysUtils,
  System.IOUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit;

type
  TJanusTestRunner = class
  public
    class function Execute(const AProbeFileName: string;
      const AValidateFreshness: Boolean): Integer;
  end;

implementation

const
  EXIT_SUCCESS = 0;
  EXIT_FAILURE = 1;

class function TJanusTestRunner.Execute(const AProbeFileName: string;
  const AValidateFreshness: Boolean): Integer;
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
  Result := EXIT_FAILURE;
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
      if (LXmlDir <> '') and (AProbeFileName <> '') then
      begin
        LProbeFile := TPath.Combine(LXmlDir, AProbeFileName);
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
    if AValidateFreshness and (LXmlOutputFile <> '') then
    begin
      if not TFile.Exists(LXmlOutputFile) then
      begin
        System.Writeln('EVIDENCE ERROR: XML artifact was not generated: ' + LXmlOutputFile);
        Result := EXIT_FAILURE;
        Exit;
      end;
      if TFile.GetLastWriteTime(LXmlOutputFile) < LRunStartTime then
      begin
        System.Writeln('EVIDENCE ERROR: XML artifact is stale — timestamp predates run start. Possible reuse of prior execution artifact.');
        Result := EXIT_FAILURE;
        Exit;
      end;
    end;
    if not LResults.AllPassed then
      Result := EXIT_FAILURE
    else
      Result := EXIT_SUCCESS;
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
      Result := EXIT_FAILURE;
    end;
  end;
end;

end.
