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
  Janus.Test.Runner in 'Common\Janus.Test.Runner.pas',
  /// LiveBindings Tests — ESP-004 / R22.1
  Tests.Janus.LiveBindings.R221 in 'Tests\Tests.Janus.LiveBindings.R221.pas',
  /// LiveBindings Tests — ESP-004 / R22.2
  Tests.Janus.LiveBindings.R222 in 'Tests\Tests.Janus.LiveBindings.R222.pas',
  /// LiveBindings Tests — ESP-002 / R22.3
  Tests.Janus.LiveBindings.R223 in 'Tests\Tests.Janus.LiveBindings.R223.pas',
  /// LiveBindings Tests — ESP-002 / R22.4
  Tests.Janus.LiveBindings.R224 in 'Tests\Tests.Janus.LiveBindings.R224.pas';

begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
  Exit;
{$ENDIF}
  System.ExitCode := TJanusTestRunner.Execute('.janus_livebindings_write_probe.tmp', True);
end.
