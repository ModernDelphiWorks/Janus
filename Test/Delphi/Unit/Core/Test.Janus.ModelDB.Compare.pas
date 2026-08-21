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

{ THE EMBEDDED COMPARATOR'S SAFETY DEFAULT - issue #341, Level 2.

  Janus.ModelDB.Compare is one unit, one class, one statement of behaviour:
  TModelDbCompare adds NOTHING to TModelDatabaseCompare except the line

      Policy := TComparePolicy.JanusOrmProfile;

  in its constructor. That line is a product decision recorded at length in the
  unit header - Janus grows a customer's schema alongside a growing set of
  decorated classes, and growing a schema must never DROP or ALTER anything.
  Its parent's default is the opposite: FullProfile, every mutation allowed.

  DELETE THAT ONE LINE AND NOTHING BREAKS. The class still compiles, still
  constructs, still builds a database - and silently starts emitting DROP TABLE
  and ALTER COLUMN against a customer's data. The compile-coverage census
  measured this unit at 0 of 7 test projects, so until now nothing anywhere
  would have noticed.

  The pertinence control is the PARENT: Policy_TheParentDefaultIsTheOpposite
  constructs TModelDatabaseCompare from the same double and asserts it DOES
  allow DropTable. Without it, "the subclass restricts the policy" would pass
  just as well if the restriction had moved into the parent - and the unit
  under test would be dead weight while the clause stayed green. }

unit Test.Janus.ModelDB.Compare;

interface

uses
  SysUtils,
  DUnitX.TestFramework,
  DataEngine.FactoryInterfaces,
  MetaDbDiff.Compare.Options,
  MetaDbDiff.Database.ModelCompare,
  /// MEASURED, NOT GUESSED: without these two the constructor dies with
  /// MetaDbDiff's own registry message - "O driver SQLite nao esta registrado,
  /// adicione a unit ..." (MetaDbDiff.DDL.Register.pas, TDDLRegister.GetDriver).
  /// The comparator resolves a DDL generator and a metadata reader per dialect
  /// exactly like Janus.Driver.Register does, and neither registry is seeded by
  /// anything but the presence of the dialect's unit.
  MetaDbDiff.DDL.Generator.SQLite,
  MetaDbDiff.Metadata.SQLite,
  /// The unit under test.
  Janus.ModelDB.Compare,
  /// TFakeConnection: the existing IDBConnection double.
  Test.Janus.DML.Generator.SQLite;

type
  /// TModelDatabaseCompare.Create refuses a connection that does not connect.
  /// The shared double answers IsConnected = False by design (every generator
  /// test wants a connection that answers nothing), so this descendant says
  /// yes to exactly that one question and inherits the other forty answers.
  TConnectedFakeConnection = class(TFakeConnection, IDBConnection)
  public
    function IsConnected: Boolean;
  end;

  [TestFixture]
  TTestJanusModelDbCompare = class
  private
    FConnection: IDBConnection;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Policy_TheSubclassRestrictsItToAdditiveGrowth;
    [Test]
    procedure Policy_ItRefusesEveryDestructiveOperation;
    [Test]
    procedure Policy_TheParentDefaultIsTheOpposite;
  end;

implementation

{$WARN SYMBOL_DEPRECATED OFF}
{ TModelDbCompare carries a `deprecated` marker pointing consumers at
  TModelDatabaseCompare. It is still SHIPPED and still the class the two
  Examples construct, so it is still worth a clause - and the marker would
  otherwise fill this build's log with W1000 for a deliberate reference. }

{ TConnectedFakeConnection }

function TConnectedFakeConnection.IsConnected: Boolean;
begin
  Result := True;
end;

{ TTestJanusModelDbCompare }

procedure TTestJanusModelDbCompare.Setup;
begin
  FConnection := TConnectedFakeConnection.Create(dnSQLite);
end;

procedure TTestJanusModelDbCompare.TearDown;
begin
  FConnection := nil;
end;

procedure TTestJanusModelDbCompare.Policy_TheSubclassRestrictsItToAdditiveGrowth;
var
  LCompare: TModelDbCompare;
begin
  LCompare := TModelDbCompare.Create(FConnection);
  try
    Assert.IsTrue(LCompare.Policy.Allows(TDDLOperation.CreateTable),
      'The embedded comparator must still be able to CREATE a missing table');
    Assert.IsTrue(LCompare.Policy.Allows(TDDLOperation.CreateColumn),
      'and a missing column');
    Assert.IsTrue(LCompare.Policy.Allows(TDDLOperation.CreatePrimaryKey),
      'and a missing primary key');
    Assert.IsTrue(LCompare.Policy.Allows(TDDLOperation.CreateForeignKey),
      'and a missing foreign key');
  finally
    LCompare.Free;
  end;
end;

{ The half that protects a customer's data. Each of these is a mutation
  FullProfile allows and JanusOrmProfile does not. }
procedure TTestJanusModelDbCompare.Policy_ItRefusesEveryDestructiveOperation;
var
  LCompare: TModelDbCompare;
begin
  LCompare := TModelDbCompare.Create(FConnection);
  try
    Assert.IsFalse(LCompare.Policy.Allows(TDDLOperation.DropTable),
      'The embedded comparator must NEVER drop a table: it grows a schema ' +
      'beside a growing model, and a table it does not recognise is a table ' +
      'it must leave alone');
    Assert.IsFalse(LCompare.Policy.Allows(TDDLOperation.DropColumn),
      'nor drop a column');
    Assert.IsFalse(LCompare.Policy.Allows(TDDLOperation.AlterColumn),
      'nor alter one - a widening it gets wrong is a truncation');
    Assert.IsFalse(LCompare.Policy.Allows(TDDLOperation.RebuildColumn),
      'nor rebuild one, which is the drop/copy/rename sequence under a name ' +
      'that does not say drop');
    Assert.IsFalse(LCompare.Policy.Allows(TDDLOperation.DropPrimaryKey),
      'nor drop a primary key');
    Assert.IsFalse(LCompare.Policy.Allows(TDDLOperation.DropForeignKey),
      'nor drop a foreign key');
    Assert.IsFalse(LCompare.Policy.Allows(TDDLOperation.DropView),
      'nor drop a view');
    Assert.IsFalse(LCompare.Policy.Allows(TDDLOperation.DropTrigger),
      'nor drop a trigger');
  finally
    LCompare.Free;
  end;
end;

{ PERTINENCE CONTROL. The restriction has to be THIS UNIT'S doing. If the
  parent were already restricted, both clauses above would be green with
  Janus.ModelDB.Compare deleted, and the coverage this fixture claims would be
  a fiction. }
procedure TTestJanusModelDbCompare.Policy_TheParentDefaultIsTheOpposite;
var
  LParent: TModelDatabaseCompare;
begin
  LParent := TModelDatabaseCompare.Create(FConnection);
  try
    Assert.IsTrue(LParent.Policy.Allows(TDDLOperation.DropTable),
      'Positive control: the PARENT defaults to FullProfile and DOES allow ' +
      'DROP TABLE. If this ever fails, the restriction moved upstream and the ' +
      'two clauses above stopped measuring TModelDbCompare');
    Assert.IsTrue(LParent.Policy.Allows(TDDLOperation.AlterColumn),
      'Positive control: the parent allows ALTER COLUMN too');
  finally
    LParent.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestJanusModelDbCompare);

end.
