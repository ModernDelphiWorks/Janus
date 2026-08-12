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

{ @abstract(Janus Framework - TManagerDataSet.AutoNextPacket<T>. Issue #332.)

  WHAT THE ISSUE SAID AND WHAT WAS MEASURED. AutoNextPacket<T> was declared
  `function ... : TManagerDataSet` and its body never assigned Result - it does
  one thing, `Resolver<T>.AutoNextPacket := AValue`, and returns whatever was
  in the return slot. dcc32 says so itself: on 0546a51 the basal build of
  Janus.Tests.Units and Janus.Tests.RESTfulDriver each echoed

    Janus.Manager.DataSet.pas(448): warning W1035: Return value of function
    'TManagerDataSet.AutoNextPacket<T:class,constructor>' might be undefined

  and after this commit neither does.

  THE ISSUE ALSO CALLED IT `THE ONLY W1035 IN THE TREE`, AND THAT IS FALSE AS
  A STATEMENT ABOUT THE TREE. It is true only of what the seven test projects
  compile. Enumerated, the same defect - a function whose body sets the
  resolver's flag and never assigns Result - exists in two more places:

    Components\Source\Janus.DB.Manager.ClientDataSet.pas
      function TManagerClientDataSet.AutoNextPacket<T>(...): TManagerClientDataSet;
    Components\Source\Janus.DB.Manager.FDMemTable.pas
      function TManagerFDMemTable.AutoNextPacket<T>(...): TManagerFDMemTable;

  Neither is a W1035 in any build because NO .dproj in the repository compiles
  Components\ - the seven test projects do not name it. They are left alone
  here: they are a different class each, reached through a different wrapper
  (Janus.Manager.ClientDataSet / Janus.Manager.FDMemTable, whose own
  AutoNextPacket<T> DOES assign Result from them), so turning them into
  procedures cascades into a surface no build in this repository covers. The
  fact is recorded rather than acted on.

  WHY A PROCEDURE AND NOT `Result := Self`. The three methods immediately
  around it in the implementation - ApplyUpdates<T>, Open<T>(String),
  Open<T>(Integer) - are all procedures with the same one-line shape, and the
  two methods in the class that DO return the manager (AddAdapter<T>,
  AddLookupField<T,M>) both open with `Result := Self` on their first line.
  AutoNextPacket had the signature of the second group and the body of the
  first. Making it a procedure turns a runtime landmine into a compile error
  for anyone who chained off it - and the measurement below says nobody in
  this repository did.

  WHO CHAINED OFF IT, ENUMERATED AND NOT SAMPLED. NOBODY. Every mention of the
  identifier `AutoNextPacket` in the whole repository was listed - Source\,
  Test\, Examples\, Components\, Projects\, .pas/.dpr/.inc/.dfm/.fmx - and not
  one of them calls THIS method. The mentions divide into exactly three groups:
  the property of the same name on TDataSetBaseAdapter and TContainerDataSet
  (a different member entirely); the two Components classes above; and their
  two wrappers, whose `Result := FManagerDataSet.AutoNextPacket<T>(AValue)`
  reads a field declared `TManagerClientDataSet` / `TManagerFDMemTable` - the
  Components classes, not TManagerDataSet. So the change breaks no consumer in
  the tree, and the seven test projects were rebuilt to prove it.

  WHAT WAS MEASURED BEFORE THE CHANGE, AND IT IS WORSE THAN `UNDEFINED`. A
  probe clause held the returned reference against the manager it was called
  on:

    LReturned := FManager.AutoNextPacket<TKeyOnly>(False);
    Assert.AreSame(FManager, LReturned)

  On 0546a51 it did not merely fail - it ERRORED, with

    Access violation at address 00000000 in module 'Janus.Tests.Units.exe'

  The return slot carried nil, so a consumer who wrote the fluent chain the
  signature invited would have taken an access violation on the very next
  call. That clause is GONE from this fixture, deliberately and not by
  oversight: after the repair the method has no return value, so the clause
  cannot be written at all. Its number is recorded here instead, which is the
  only place it can live. What survives is the side effect, below, and the
  side effect is the whole of what the method ever did.

  TWO VALUES, NOT ONE. The adapter constructor sets FAutoNextPacket := True,
  so a clause that only ever asked for True would pass against a body that had
  been deleted. Both clauses drive the flag to the value the constructor did
  NOT leave, and one of them drives it back.
}

unit Test.Janus.Manager.AutoNextPacket;

interface

uses
  DB,
  Classes,
  SysUtils,
  DUnitX.TestFramework,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Param,
  FireDAC.Stan.Error,
  FireDAC.DatS,
  FireDAC.Phys.Intf,
  FireDAC.DApt.Intf,
  FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,
  DataEngine.FactoryInterfaces,
  Janus.Manager.DataSet,
  Test.Janus.Cursor.Double,
  Test.Janus.Model.KeyOnly;

type
  {$IFDEF USECLIENTDATASET}
  TMemDataSet = TClientDataSet;
  {$ELSE}
  TMemDataSet = TFDMemTable;
  {$ENDIF}

  [TestFixture]
  TTestManagerAutoNextPacket = class
  private
    FConn: IDBConnection;
    FManager: TManagerDataSet;
    FMem: TMemDataSet;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// The constructor leaves the flag True, so THIS is the clause that can
    /// tell a live body from a deleted one: drive it to False and read it
    /// back through the manager's own getter.
    [Test]
    procedure AutoNextPacket_False_ReachesTheAdapter;
    /// ...and back, so the clause above cannot be green because the setter
    /// writes a constant. Same method, the other value.
    [Test]
    procedure AutoNextPacket_True_ReachesTheAdapter;
  end;

implementation

{ TTestManagerAutoNextPacket }

procedure TTestManagerAutoNextPacket.Setup;
begin
  FConn := TRowsConnection.Create(dnSQLite, 2,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add('k1', ftInteger);
      ADataSet.FieldDefs.Add('k2', ftInteger);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName('k1').AsInteger := 1;
      ADataSet.FieldByName('k2').AsInteger := AIndex;
    end,
    'manager-autonextpacket');
  FManager := TManagerDataSet.Create(FConn);
  FMem := TMemDataSet.Create(nil);
  FManager.AddAdapter<TKeyOnly>(FMem);
end;

procedure TTestManagerAutoNextPacket.TearDown;
begin
  FreeAndNil(FManager);
  FreeAndNil(FMem);
  FConn := nil;
end;

procedure TTestManagerAutoNextPacket.AutoNextPacket_False_ReachesTheAdapter;
begin
  // The premise, and it is asserted rather than assumed: the adapter is born
  // True. Without this line the clause below could not tell "the setter ran"
  // from "it was already False".
  Assert.IsTrue(FManager.GetAutoNextPacket<TKeyOnly>,
    'premise: TDataSetBaseAdapter<M> constructs with FAutoNextPacket := True');
  FManager.AutoNextPacket<TKeyOnly>(False);
  Assert.IsFalse(FManager.GetAutoNextPacket<TKeyOnly>,
    'ISSUE #332: the side effect is the whole of what AutoNextPacket<T> ever ' +
    'did, and it must survive the method losing its return value.');
end;

procedure TTestManagerAutoNextPacket.AutoNextPacket_True_ReachesTheAdapter;
begin
  FManager.AutoNextPacket<TKeyOnly>(False);
  Assert.IsFalse(FManager.GetAutoNextPacket<TKeyOnly>,
    'premise: driven off the constructor default first');
  FManager.AutoNextPacket<TKeyOnly>(True);
  Assert.IsTrue(FManager.GetAutoNextPacket<TKeyOnly>,
    'the SECOND value, so neither clause can be green against a body that ' +
    'writes a constant.');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestManagerAutoNextPacket);

end.
