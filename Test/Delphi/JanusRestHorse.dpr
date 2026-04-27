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

program JanusRestHorse;

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
  Janus.Test.Bootstrap in 'Common\Janus.Test.Bootstrap.pas',
  Janus.Test.Runner in 'Common\Janus.Test.Runner.pas',
  /// DML generator registration — this unit's initialization block registers
  /// the SQLite factory with TDriverRegister. Without it, TCommandSelecter's
  /// construction path hits an unregistered driver and AVs deep in the
  /// TDictionary miss path.
  Janus.DML.Generator.SQLite,
  /// Models
  MetaDbDiff.Mapping.Register,
  /// Test Infrastructure
  RestHorseTest.Models in 'Tests\RestHorseTest.Models.pas',
  RestHorseTest.Base   in 'Tests\RestHorseTest.Base.pas',
  /// Integration Test Suites — ESP-002
  TestJanusRESTHorseIntegration in 'Tests\TestJanusRESTHorseIntegration.pas',
  TestJanusRESTReadOnly         in 'Tests\TestJanusRESTReadOnly.pas',
  TestJanusRESTJoinView         in 'Tests\TestJanusRESTJoinView.pas',
  /// Integration Test Suites — ESP-006
  TestJanusRESTHorseDriver      in 'Tests\TestJanusRESTHorseDriver.pas',
  /// Integration Test Suites — R20 method-level grant (#137)
  TestJanusRESTMethodGrant      in 'Tests\TestJanusRESTMethodGrant.pas';

begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
  Exit;
{$ENDIF}
  TJanusTestBootstrap.RegisterFireDACSilent;
  System.ExitCode := TJanusTestRunner.Execute('.janus_rest_horse_write_probe.tmp', True);
end.
