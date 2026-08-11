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

{ @abstract(Janus Framework - the DRIVERRESTFUL test configuration.)

  WHY THIS PROJECT EXISTS

  Janus.inc ships the DRIVERRESTFUL define COMMENTED OUT. Every REST adapter
  the framework builds is selected inside IFDEF DRIVERRESTFUL blocks, and
  none of the other four test projects define it, so the whole ON branch was
  compiled by nothing. This project is that branch: the directive is carried by
  Janus.Tests.RESTfulDriver.dproj (DCC_Define), exactly the way every RESTful
  Example under Examples\Delphi\RESTful carries it.

  WHAT THE DIRECTIVE PULLS IN THAT NOTHING ELSE COMPILES

    Janus.Manager.DataSet      - eight conditional sites; no .dcu from any of
                                 the four existing test binaries, in EITHER
                                 branch
    Janus.Manager.ObjectSet    - five conditional sites; likewise
    Janus.RestObjectSet.Adapter- one conditional site; likewise
    Janus.Client.Base / Janus.Client / Janus.Client.Horse /
    Janus.Client.RestDriver.Horse / Janus.Client.RestHorse.Factory /
    Janus.Client.RestException / Janus.Client.Consts
                               - the concrete Horse client chain; likewise

  THE DIRECTIVE CANNOT BE DROPPED SILENTLY

  Each of the three test units under Unit\RESTful\Test.Janus.Driver.* opens
  with an IFNDEF DRIVERRESTFUL / MESSAGE FATAL pair. Removing the define from
  the .dproj does not produce a smaller green suite - it produces a build
  error.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

program Janus.Tests.RESTfulDriver;

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
  /// Models
  MetaDbDiff.Mapping.Register,
  Test.Janus.Model.AsymKey in 'Common\Test.Janus.Model.AsymKey.pas',
  Test.Janus.Model.AutoIncTree in 'Common\Test.Janus.Model.AutoIncTree.pas',
  /// The canonical COMPOSITE PRIMARY KEY entity - both columns are the key.
  /// Issue #300.
  Test.Janus.Model.KeyOnly in 'Common\Test.Janus.Model.KeyOnly.pas',
  /// A COMPOSITE AUTOINC key over a cascading child - the only shape in which
  /// the #297 gate can be partially satisfied. Issue #300.
  Test.Janus.Model.CompositeAutoInc in 'Common\Test.Janus.Model.CompositeAutoInc.pas',
  /// String key and composite key - the two association shapes the REST lazy
  /// filter had no model for. Issue #251.
  Test.Janus.Model.RestLazyKeys in 'Common\Test.Janus.Model.RestLazyKeys.pas',
  /// A key declared NotInc and with NO [Sequence] - the one entity family in
  /// the test tree for which ExistSequence answers False. Issue #301.
  Test.Janus.Model.NotIncKey in 'Common\Test.Janus.Model.NotIncKey.pas',
  /// Doubles
  Test.Janus.RestConnection.Double in 'Common\Test.Janus.RestConnection.Double.pas',
  /// Tests - the DRIVERRESTFUL branch
  Test.Janus.Driver.ManagerDataSet in 'Unit\RESTful\Test.Janus.Driver.ManagerDataSet.pas',
  Test.Janus.Driver.ManagerObjectSet in 'Unit\RESTful\Test.Janus.Driver.ManagerObjectSet.pas',
  Test.Janus.Driver.HorseClientChain in 'Unit\RESTful\Test.Janus.Driver.HorseClientChain.pas',
  /// The one-resource Execute overload, and the ARGUMENT ORDER it hands down -
  /// which only the Horse chain can observe. Issue #211.
  Test.Janus.Driver.HorseExecuteOverload in 'Unit\RESTful\Test.Janus.Driver.HorseExecuteOverload.pas',
  /// Clearing the child datasets from wherever the cursor is - issue #222
  Test.Janus.Rest.ClearChilds in 'Unit\RESTful\Test.Janus.Rest.ClearChilds.pas',
  /// The cascade guard that decides WHICH child gets cleared - issue #235
  Test.Janus.Rest.CascadeGuard in 'Unit\RESTful\Test.Janus.Rest.CascadeGuard.pas',
  /// The lazy load and the lazy unload of the REST family - issue #251
  Test.Janus.Rest.Lazy in 'Unit\RESTful\Test.Janus.Rest.Lazy.pas',
  /// The same LoadLazy over the other concrete adapter of the family, whose
  /// OpenWhereInternal is a separate override - issue #251
  Test.Janus.Rest.Lazy.Cds in 'Unit\RESTful\Test.Janus.Rest.Lazy.Cds.pas',
  /// The client re-reads the aggregate it has just inserted, because the insert
  /// answer names the ROOT key and nothing below it - issue #297
  Test.Janus.Rest.ReReadAfterInsert in 'Unit\RESTful\Test.Janus.Rest.ReReadAfterInsert.pas',
  /// A COMPOSITE primary key lost every column but the last on the way back
  /// from an insert, because the answer was parsed one param per OBJECT
  /// instead of one per PAIR - issue #300
  Test.Janus.Rest.ResultParamsCompositeKey in 'Unit\RESTful\Test.Janus.Rest.ResultParamsCompositeKey.pas',
  /// What that repair does to the gate the #297 re-read stands behind - the
  /// only place where more params changes WHEN a round trip is bought
  Test.Janus.Rest.CompositeKeyReReadGate in 'Unit\RESTful\Test.Janus.Rest.CompositeKeyReReadGate.pas',
  /// The OBJECT half of the same family: the insert answer carries the key the
  /// server generated, and TRESTObjectSetAdapter never read it - issue #301
  Test.Janus.Rest.ObjectSetInsertKey in 'Unit\RESTful\Test.Janus.Rest.ObjectSetInsertKey.pas';

begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
  Exit;
{$ENDIF}
  System.ExitCode := TJanusTestRunner.Execute('.janus_restful_write_probe.tmp', True);
end.
