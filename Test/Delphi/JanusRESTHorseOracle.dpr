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
  Janus.Test.Bootstrap in 'Common\Janus.Test.Bootstrap.pas',
  Janus.Test.Runner in 'Common\Janus.Test.Runner.pas',
  // Oracle DML generator — registers factory with TDriverRegister
  Janus.DML.Generator.Oracle,
  // Entity registration support
  MetaDbDiff.Mapping.Register,
  // Oracle test infrastructure
  RestHorseOracleTest.Base in 'RESTOracle\Support\RestHorseOracleTest.Base.pas',
  // Oracle auto-view test fixture
  Test.Janus.REST.Oracle.AutoView in 'RESTOracle\Test.Janus.REST.Oracle.AutoView.pas';

begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
  Exit;
{$ENDIF}
  TJanusTestBootstrap.RegisterFireDACSilent;
  System.ExitCode := TJanusTestRunner.Execute('', False);
end.
