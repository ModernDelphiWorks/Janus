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

{ @abstract(Janus Framework - the WiRL client-driver test configuration.)

  WHY THIS PROJECT EXISTS

  Nothing compiled the WiRL client path. Not one of the six .dproj files under
  Test\Delphi referenced Janus.Client.WiRL, Janus.Client.RestDriver.WiRL or
  Janus.Client.RestWiRL.Factory; the only other candidate is
  Examples\Delphi\RESTful\RESTFul via Driver\WiRL\Client, whose search path
  does not carry WiRL at all - it relies on the units being on the IDE's
  global library path.

  That is how #213 could sit in the tree: TRESTDriverWiRL shipped with three
  empty method bodies - GetMethodToken, GetUsername and GetPassword - each
  silently answering ''. No compiler read the unit and no test ran it.

  WHAT THIS PROJECT ADDS TO THE SUITE

    Janus.Client.WiRL              TRESTClientWiRL - construction, SetBaseURL,
                                   AcquireAccessToken and AccessToken
    Janus.Client.RestDriver.WiRL   TRESTDriverWiRL - every getter
    Janus.Client.RestWiRL.Factory  TRESTFactoryWiRL.Create

  EXTERNAL DEPENDENCY

  WiRL does not live beside the Janus checkout. It is expected at the path in
  the WIRLDIR property of the .dproj; override it on the command line
  (/p:WIRLDIR=<path>) or with an environment variable of the same name. The
  pin this code was written against is recorded at the top of
  Source\RESTful\Client\Janus.Client.WiRL.pas.

  DELIBERATELY NOT A CI GATE

  For exactly the reason .github\workflows\tests.yml already states about
  Janus.Tests.RESTMARS: the third party is not vendored here and is not a
  sibling checkout, so the runner cannot build it. This project is run by a
  developer locally. That is strictly better than the previous state - where
  NO machine compiled these units - but it is not cover.

  BUILDING IT

  The .dproj declares its own DCC_DcuOutput, exactly like the other six, so the
  projects do not collide. Do NOT pass /p:DCC_DcuOutput - a global property
  beats the project and puts the collision back.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

program Janus.Tests.RESTWiRL;

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
  /// The units this project exists to compile
  Janus.Client.WiRL,
  Janus.Client.RestDriver.WiRL,
  Janus.Client.RestWiRL.Factory,
  /// Tests
  Test.Janus.Driver.WiRLClientChain in 'Unit\RESTful\Test.Janus.Driver.WiRLClientChain.pas',
  Test.Janus.Driver.WiRLTokenAcquire in 'Unit\RESTful\Test.Janus.Driver.WiRLTokenAcquire.pas';

begin
  Randomize;
  TJanusTestBootstrap.RegisterFireDACSilent;
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
  Exit;
{$ENDIF}
  System.ExitCode := TJanusTestRunner.Execute('.janus_restwirl_write_probe.tmp', True);
end.
