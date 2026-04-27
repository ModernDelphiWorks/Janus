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

program JanusRESTHorseOracle;

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}
{$STRONGLINKTYPES ON}

uses
  System.Classes,
  System.SysUtils,
  System.IOUtils,
  // FireDAC infrastructure
  FireDAC.ConsoleUI.Wait,
  FireDAC.Comp.Client,
  // Oracle driver registration — initialization registers the OCI factory
  FireDAC.Phys.Oracle,
  FireDAC.Phys.OracleDef,
  FireDAC.Stan.Def,
  FireDAC.Stan.Intf,
  FireDAC.Phys,
  FireDAC.Stan.Async,
  FireDAC.Comp.DataSet,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ENDIF}
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  // Oracle DML generator — registers factory with TDriverRegister
  Janus.DML.Generator.Oracle,
  // Entity registration support
  MetaDbDiff.Mapping.Register,
  // Oracle test infrastructure
  RestHorseOracleTest.Base in 'Tests\RestHorseOracleTest.Base.pas',
  // Oracle auto-view test fixture
  TestJanusRESTOracleAutoView in 'Tests\TestJanusRESTOracleAutoView.pas';

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
begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
  Exit;
{$ENDIF}
  System.ExitCode := EXIT_FAILURE;
  IsMultiThread := True;
  FDManager.SilentMode := True;
  try
    TDUnitX.CheckCommandLine;
    LXmlOutputFile := TDUnitX.Options.XMLOutputFile;
    if LXmlOutputFile <> '' then
    begin
      LXmlOutputFile := TPath.GetFullPath(LXmlOutputFile);
      LXmlDir := TPath.GetDirectoryName(LXmlOutputFile);
      if (LXmlDir <> '') and (not TDirectory.Exists(LXmlDir)) then
        TDirectory.CreateDirectory(LXmlDir);
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
