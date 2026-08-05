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

program Janus.Tests.RESTHorse;

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
  /// Three levels with every key column spelled once — issue #225
  Test.Janus.Model.AsymTree in 'Common\Test.Janus.Model.AsymTree.pas',
  /// Test Infrastructure
  RestHorseTest.Models in 'RESTHorse\Support\RestHorseTest.Models.pas',
  RestHorseTest.Base   in 'RESTHorse\Support\RestHorseTest.Base.pas',
  /// Integration Test Suites — ESP-002
  Test.Janus.REST.Horse.Integration in 'RESTHorse\Test.Janus.REST.Horse.Integration.pas',
  Test.Janus.REST.Horse.ReadOnly         in 'RESTHorse\Test.Janus.REST.Horse.ReadOnly.pas',
  Test.Janus.REST.Horse.JoinView         in 'RESTHorse\Test.Janus.REST.Horse.JoinView.pas',
  /// Integration Test Suites — ESP-006
  Test.Janus.REST.Horse.Driver      in 'RESTHorse\Test.Janus.REST.Horse.Driver.pas',
  /// Integration Test Suites — R20 method-level grant (#137)
  Test.Janus.REST.Horse.MethodGrant      in 'RESTHorse\Test.Janus.REST.Horse.MethodGrant.pas',
  /// Whose primary key the server side cascade propagates — issue #225
  Test.Janus.Server.RestObjectSet.AutoInc in 'RESTHorse\Test.Janus.Server.RestObjectSet.AutoInc.pas',
  /// Whether the update leg of that cascade propagates at all — issue #239
  Test.Janus.Server.RestObjectSet.CascadeUpdate in 'RESTHorse\Test.Janus.Server.RestObjectSet.CascadeUpdate.pas',
  /// The same question on the LIST leg, where N children are inserted — issue #242
  Test.Janus.Server.RestObjectSet.CascadeUpdateList in 'RESTHorse\Test.Janus.Server.RestObjectSet.CascadeUpdateList.pas',
  /// Whether the MASTER key reaches a child added on update — issue #242
  Test.Janus.Server.RestObjectSet.UpdateMasterKey in 'RESTHorse\Test.Janus.Server.RestObjectSet.UpdateMasterKey.pas',
  /// Key-only entity, no updatable column — issue #240
  Test.Janus.Model.KeyOnly in 'Common\Test.Janus.Model.KeyOnly.pas',
  /// The ORDER the server side cascade deletes a tree in — issue #240
  Test.Janus.Server.RestObjectSet.CascadeDelete in 'RESTHorse\Test.Janus.Server.RestObjectSet.CascadeDelete.pas',
  /// A single-object association that is nil — issue #240
  Test.Janus.Server.RestObjectSet.NilBranch in 'RESTHorse\Test.Janus.Server.RestObjectSet.NilBranch.pas',
  /// The ExistSequence guard around the cascade propagation — issue #240
  Test.Janus.Server.RestObjectSet.SuppliedKey in 'RESTHorse\Test.Janus.Server.RestObjectSet.SuppliedKey.pas',
  /// A key-only Update on the server side — issue #240
  Test.Janus.Server.RestObjectSet.NoOpUpdate in 'RESTHorse\Test.Janus.Server.RestObjectSet.NoOpUpdate.pas';

begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
  Exit;
{$ENDIF}
  TJanusTestBootstrap.RegisterFireDACSilent;
  System.ExitCode := TJanusTestRunner.Execute('.janus_rest_horse_write_probe.tmp', True);
end.
