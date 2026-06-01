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

{
  @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
}

unit Test.Janus.Driver.Register;

interface

uses
  SysUtils,
  DUnitX.TestFramework,
  Janus.DML.Interfaces,
  Janus.Driver.Register,
  DataEngine.FactoryInterfaces;

type
  [TestFixture]
  TTestJanusDriverRegister = class
  strict private
    FCounterA: Integer;
    FCounterB: Integer;
    function _MakeCountingFactoryA: TDMLGeneratorFactory;
    function _MakeCountingFactoryB: TDMLGeneratorFactory;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure RegisterDriver_AddsToRegistry;
    [Test]
    procedure RegisterDriver_OverwritesExisting;
    [Test]
    procedure GetDriver_ReturnsInstanceFromRegisteredFactory;
    [Test]
    procedure GetDriver_RaisesWhenMissing;
    [Test]
    procedure GetDriver_InvokesFactoryEachCall;
    [Test]
    procedure Registry_PreservesProductionRegistrationsAfterTeardown;
  end;

implementation

const
  // Enum value never registered by production code in Janus.Tests.Unit.dpr
  // (no Janus.DML.Generator.DB2.pas exists). Used as the "missing" key.
  CMissingDriver: TDBEngineDriver = dnDB2;

  // Enum value used as scratch space for register/overwrite/invocation tests.
  // No Janus.DML.Generator.Informix.pas exists, so no production code registers it.
  CScratchDriver: TDBEngineDriver = dnInformix;

  // Enum value registered by Janus.DML.Generator.SQLite (already in dpr uses).
  // Used read-only to verify production registration is preserved.
  CProductionDriver: TDBEngineDriver = dnSQLite;

{ TTestJanusDriverRegister }

procedure TTestJanusDriverRegister.Setup;
begin
  FCounterA := 0;
  FCounterB := 0;
end;

procedure TTestJanusDriverRegister.TearDown;
begin
  // Scratch driver carries no production registration to restore. Production
  // entries (e.g. dnSQLite) are never overwritten, so they remain byte-equal.
end;

function TTestJanusDriverRegister._MakeCountingFactoryA: TDMLGeneratorFactory;
begin
  Result := function: IDMLGeneratorCommand
            begin
              Inc(FCounterA);
              Result := nil;
            end;
end;

function TTestJanusDriverRegister._MakeCountingFactoryB: TDMLGeneratorFactory;
begin
  Result := function: IDMLGeneratorCommand
            begin
              Inc(FCounterB);
              Result := nil;
            end;
end;

procedure TTestJanusDriverRegister.RegisterDriver_AddsToRegistry;
begin
  TDriverRegister.RegisterDriver(CScratchDriver, _MakeCountingFactoryA);

  TDriverRegister.GetDriver(CScratchDriver);

  Assert.AreEqual(1, FCounterA, 'Factory should be invoked exactly once');
end;

procedure TTestJanusDriverRegister.RegisterDriver_OverwritesExisting;
begin
  TDriverRegister.RegisterDriver(CScratchDriver, _MakeCountingFactoryA);
  TDriverRegister.RegisterDriver(CScratchDriver, _MakeCountingFactoryB);

  TDriverRegister.GetDriver(CScratchDriver);

  Assert.AreEqual(0, FCounterA, 'Factory A must not be invoked after overwrite');
  Assert.AreEqual(1, FCounterB, 'Factory B (latest registration) must be invoked');
end;

procedure TTestJanusDriverRegister.GetDriver_ReturnsInstanceFromRegisteredFactory;
var
  LResult: IDMLGeneratorCommand;
begin
  LResult := TDriverRegister.GetDriver(CProductionDriver);

  Assert.IsNotNull(LResult, 'Production-registered driver must yield a non-nil instance');
  Assert.IsTrue(Supports(LResult, IDMLGeneratorCommand),
    'Returned reference must implement IDMLGeneratorCommand');
end;

procedure TTestJanusDriverRegister.GetDriver_RaisesWhenMissing;
begin
  Assert.WillRaiseWithMessageRegex(
    procedure
    begin
      TDriverRegister.GetDriver(CMissingDriver);
    end,
    Exception,
    'n.o est. registrado',
    'GetDriver must raise with PT-BR contract message containing "não está registrado"');
end;

procedure TTestJanusDriverRegister.GetDriver_InvokesFactoryEachCall;
var
  LFor: Integer;
begin
  TDriverRegister.RegisterDriver(CScratchDriver, _MakeCountingFactoryA);

  for LFor := 1 to 3 do
    TDriverRegister.GetDriver(CScratchDriver);

  Assert.AreEqual(3, FCounterA, 'Factory must be invoked once per GetDriver call');
end;

procedure TTestJanusDriverRegister.Registry_PreservesProductionRegistrationsAfterTeardown;
var
  LBefore: IDMLGeneratorCommand;
  LAfter: IDMLGeneratorCommand;
begin
  LBefore := TDriverRegister.GetDriver(CProductionDriver);

  TDriverRegister.RegisterDriver(CScratchDriver, _MakeCountingFactoryA);
  TDriverRegister.RegisterDriver(CScratchDriver, _MakeCountingFactoryB);
  TDriverRegister.GetDriver(CScratchDriver);

  LAfter := TDriverRegister.GetDriver(CProductionDriver);

  Assert.IsNotNull(LBefore, 'Production driver must yield instance before mutation');
  Assert.IsNotNull(LAfter, 'Production driver must yield instance after mutation');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestJanusDriverRegister);

end.
