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

{ @abstract(Janus Framework - the MARS server-driver test configuration.)

  WHY THIS PROJECT EXISTS

  Before it, NOTHING compiled Janus.Server.Resource.MARS.pas. Not one of the
  five .dproj files under Test\Delphi referenced it, and the only other
  candidate - Examples\Delphi\RESTful\RESTFul via Driver\MARS\Server -
  points its search path at Source\RESTful Components\Server, a directory that
  does not exist in this tree, so it cannot have built for as long as that path
  has been wrong.

  A unit no compiler reads is not merely untested, it is unverified at the
  level of syntax. That is not a theory: the MARS pair below shipped calling
  TMARSEngine.Applications, a property MARS has since commented out, and it
  took a hand-run of dcc32 on a single unit to find it.

  WHAT THIS PROJECT ADDS TO THE SUITE

    Janus.Server.Resource.MARS   the resource class, its attributes, and its
                                 registration into TMARSResourceRegistry
    Janus.Server.MARS            TRESTServerMARS and the engine setter
    Janus.Server.Resource        TAppResourceBase, on the MARS path through it

  EXTERNAL DEPENDENCY

  This project is the first under Test\Delphi to need a third-party framework
  that does not live beside the Janus checkout. MARS is expected at the path in
  the MARSDIR property below; override it on the command line
  (/p:MARSDIR=<path>) or with an environment variable of the same name.

  BUILDING IT

  The .dproj declares its own DCC_DcuOutput, exactly like the other five, so
  the projects do not collide. Do NOT pass /p:DCC_DcuOutput - a global property
  beats the project and puts the collision back.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

program Janus.Tests.RESTMARS;

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
  Janus.Test.Bootstrap in 'Common\Janus.Test.Bootstrap.pas',
  /// DML generator registration - this unit's initialization block registers
  /// the SQLite factory with TDriverRegister. Without it, the behavioural
  /// fixture's first real query AVs deep in the TDictionary miss path, the
  /// same way Janus.Tests.RESTHorse documents.
  Janus.DML.Generator.SQLite,
  /// Models - so the mapping repository is in a realistic, populated state.
  /// RestHorseTest.Models is reused rather than duplicated: it is a plain set
  /// of mapped entity classes with no Horse dependency, and the behavioural
  /// fixture queries its customer_test table through SQLite.
  MetaDbDiff.Mapping.Register,
  Test.Janus.Model.AsymKey in 'Common\Test.Janus.Model.AsymKey.pas',
  RestHorseTest.Models in 'RESTHorse\Support\RestHorseTest.Models.pas',
  /// The units this project exists to compile
  Janus.Server.Resource.MARS,
  Janus.Server.MARS,
  /// Tests
  Test.Janus.Server.Resource.MARS in 'Unit\RESTful\Test.Janus.Server.Resource.MARS.pas';

begin
  TJanusTestBootstrap.RegisterFireDACSilent;
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
  Exit;
{$ENDIF}
  System.ExitCode := TJanusTestRunner.Execute('.janus_restmars_write_probe.tmp', True);
end.
