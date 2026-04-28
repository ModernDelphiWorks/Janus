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

program Janus.Tests.LiveBindings;

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
  Test.Janus.LiveBindings.Base       in 'LiveBindings\Test.Janus.LiveBindings.Base.pas',
  Test.Janus.LiveBindings.DataSet    in 'LiveBindings\Test.Janus.LiveBindings.DataSet.pas',
  Test.Janus.LiveBindings.GridColumn in 'LiveBindings\Test.Janus.LiveBindings.GridColumn.pas';

begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
  Exit;
{$ENDIF}
  System.ExitCode := TJanusTestRunner.Execute('.janus_livebindings_write_probe.tmp', True);
end.
