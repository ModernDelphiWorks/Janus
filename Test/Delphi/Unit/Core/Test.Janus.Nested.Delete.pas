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

{ @abstract(Janus Framework - clearing the nested datasets of a row being deleted.)

  WHAT IS UNDER TEST

  TDataSetAdapter<M>.DoBeforeDelete - the BeforeDelete handler the adapter
  installs on its own dataset in TDataSetBaseAdapter<M>.SetDataSetEvents. Among
  other things it empties every dataset registered in the row's
  TDataSet.NestedDataSets list, the structure that carries the ftDataSet columns
  ("Recurso usado em banco NoSQL", says the shipped comment).

  THE DEFECT THIS SUITE PINS

  That clearing loop was a `repeat LDataSet.Delete until LDataSet.Eof` with no
  guard on the dataset being empty. TDataSet.Delete opens with
  `if FRecordCount = 0 then DatabaseError(SDataSetEmpty, Self)`, so on a nested
  dataset that carries no row the FIRST Delete raises EDatabaseError - a
  `repeat` body always runs once. Deleting an owner row whose nested dataset
  happens to be empty therefore failed, which is the ordinary case: a parent
  with no children at all.

  This is the OPPOSITE family from the one #207 swept. #207 fixed loops that
  never terminate; this one terminates violently on the first iteration.

  WHY IT SURVIVED

  Measured, not guessed: before this unit, `ftDataSet` appeared in exactly ONE
  [Column] declaration in the whole repository -
  Examples\Delphi\NoSQL\MongoDB\Models\Janus.Model.Client - and that example is
  in no test project and in no build gate. Without an ftDataSet column
  TBind.SetInternalInitFieldDefsObjectClass never reaches
  _CreateFieldsNestedDataSet, nothing ever touches TDataSetField.NestedDataSet,
  and TDataSet.NestedDataSets stays empty - so the `for` around the loop
  iterated zero times and the body was unreachable. The suite was not tolerating
  the raise; it was never getting near it.

  WHAT THE GUARD MUST NOT BREAK

  Skipping an empty nested dataset must not turn into skipping the clearing.
  NestedPopulated_DoBeforeDelete_ClearsEveryNestedRow drives the same shipped
  method over a nested dataset with rows in it and measures that they are gone.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Nested.Delete;

interface

uses
  DB,
  Classes,
  SysUtils,
  Variants,
  Generics.Collections,
  DBClient,
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
  Janus.DataSet.ClientDataSet,
  Test.Janus.Model.Nested,
  Test.Janus.Cursor.Double;

type
  /// <summary> Reads TDataSet.NestedDataSets, which is protected. The shipped
  ///  code reaches it through a cracker of its own (TDataSetHack, declared in
  ///  Janus.DataSet.Adapter), so the fixture observes exactly the list the
  ///  method under test walks. </summary>
  TDataSetPeek = class(TDataSet)
  end;

  /// <summary> Classic protected-access descendant. DoBeforeDelete is protected
  ///  and its production trigger is TDataSet.Delete on the owner row, which also
  ///  destroys that row - so a measurement of what the handler did to the nested
  ///  dataset has to call the handler on its own. Both routes are exercised
  ///  here: this one, and the shipped BeforeDelete wiring. </summary>
  TNestedDeleteCrack<M: class, constructor> = class(TClientDataSetAdapter<M>)
  public
    class procedure BeforeDelete(const AAdapter: TClientDataSetAdapter<M>;
      const ADataSet: TDataSet);
  end;

  [TestFixture]
  TTestNestedDelete = class
  private
    FConn: IDBConnection;
    FCds: TClientDataSet;
    FAdapter: TClientDataSetAdapter<TNestedParent>;
    procedure BuildAdapter;
    procedure AddOwnerRow(const AKey: Integer; const ATag: String);
    procedure AddNestedRows(const ACount: Integer);
    function Nested: TDataSet;
    function NestedCount: Integer;
    function CaptureBeforeDelete: String;
    function CaptureOwnerDelete: String;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// The premise the whole fixture rests on: the ftDataSet column really did
    /// register a dataset in NestedDataSets, and with no child rows written
    /// that dataset is open and empty. Without this, every test below would
    /// pass over a `for` loop that never iterates.
    [Test]
    procedure Premise_TheOwnerRegistersOneNestedDataSetAndItIsEmpty;

    /// The RTL contract behind the defect, measured on a plain dataset instead
    /// of quoted from Data.DB: Delete on an empty dataset raises.
    [Test]
    procedure Premise_DeleteOnAnEmptyDataSetRaisesEDatabaseError;

    /// The defect itself, on the shipped method.
    [Test]
    procedure NestedEmpty_DoBeforeDelete_DoesNotRaise;
    /// ...and through the production route, TDataSet.Delete on the owner row.
    [Test]
    procedure NestedEmpty_DeletingTheOwnerRow_DoesNotRaise;
    /// ...and the owner row really went away, so "does not raise" is not
    /// "silently did nothing".
    [Test]
    procedure NestedEmpty_DeletingTheOwnerRow_RemovesIt;

    /// The guard must skip an EMPTY nested dataset, never a populated one.
    [Test]
    procedure NestedPopulated_DoBeforeDelete_ClearsEveryNestedRow;
    [Test]
    procedure NestedPopulated_DeletingTheOwnerRow_DoesNotRaise;
  end;

implementation

const
  cOWNERKEY   = 'pkey';
  cOWNERTAG   = 'ptag';
  cNESTED     = 'items';
  cNESTEDKEY  = 'citem';
  cNESTEDTAG  = 'ctag';
  cNESTEDROWS = 3;

{ TNestedDeleteCrack<M> }

class procedure TNestedDeleteCrack<M>.BeforeDelete(
  const AAdapter: TClientDataSetAdapter<M>; const ADataSet: TDataSet);
begin
  TNestedDeleteCrack<M>(AAdapter).DoBeforeDelete(ADataSet);
end;

{ TTestNestedDelete }

procedure TTestNestedDelete.Setup;
begin
  // The connection is only needed to build the adapter's session; no test here
  // opens a cursor. Zero rows keeps the double completely inert.
  FConn := TRowsConnection.Create(dnSQLite, 0,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add(cOWNERKEY, ftInteger);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName(cOWNERKEY).AsInteger := AIndex;
    end,
    'nested');
end;

procedure TTestNestedDelete.TearDown;
begin
  // Detach the ORM handlers before letting the dataset close: a teardown that
  // fires an adapter event over freed memory is a crash, not a test result.
  if FCds <> nil then
  begin
    FCds.BeforeScroll := nil;
    FCds.AfterScroll := nil;
    FCds.BeforeClose := nil;
    FCds.BeforeOpen := nil;
    FCds.AfterOpen := nil;
    FCds.AfterClose := nil;
    FCds.BeforeDelete := nil;
    FCds.AfterDelete := nil;
    FCds.BeforeInsert := nil;
    FCds.AfterInsert := nil;
    FCds.BeforeEdit := nil;
    FCds.AfterEdit := nil;
    FCds.BeforePost := nil;
    FCds.AfterPost := nil;
    FCds.OnNewRecord := nil;
  end;
  FreeAndNil(FCds);
  FreeAndNil(FAdapter);
  FConn := nil;
end;

/// The adapter's own constructor builds the field defs from the mapping and
/// calls CreateDataSet, so the nested dataset is produced by the SHIPPED path
/// (TBind.SetInternalInitFieldDefsObjectClass -> _CreateFieldsNestedDataSet),
/// not assembled by the fixture.
procedure TTestNestedDelete.BuildAdapter;
begin
  FCds := TClientDataSet.Create(nil);
  FAdapter := TClientDataSetAdapter<TNestedParent>.Create(FConn, FCds, -1, nil);
end;

procedure TTestNestedDelete.AddOwnerRow(const AKey: Integer;
  const ATag: String);
begin
  FCds.Append;
  FCds.FieldByName(cOWNERKEY).AsInteger := AKey;
  FCds.FieldByName(cOWNERTAG).AsString := ATag;
  FCds.Post;
end;

procedure TTestNestedDelete.AddNestedRows(const ACount: Integer);
var
  LNested: TDataSet;
  LFor: Integer;
begin
  LNested := Nested;
  for LFor := 1 to ACount do
  begin
    LNested.Append;
    LNested.FieldByName(cNESTEDKEY).AsInteger := LFor;
    LNested.FieldByName(cNESTEDTAG).AsString := 'row' + IntToStr(LFor);
    LNested.Post;
  end;
  // Writing into a nested dataset puts its owner into dsEdit (TDataSet.
  // CheckParentState). Leave the owner in dsBrowse so the measurement starts
  // from the state the production BeforeDelete sees.
  if FCds.State in [dsEdit, dsInsert] then
    FCds.Post;
end;

function TTestNestedDelete.Nested: TDataSet;
begin
  Result := (FCds.FieldByName(cNESTED) as TDataSetField).NestedDataSet;
end;

function TTestNestedDelete.NestedCount: Integer;
begin
  Result := Nested.RecordCount;
end;

function TTestNestedDelete.CaptureBeforeDelete: String;
begin
  Result := '';
  try
    TNestedDeleteCrack<TNestedParent>.BeforeDelete(FAdapter, FCds);
  except
    on E: Exception do
      Result := E.ClassName + ': ' + E.Message;
  end;
end;

function TTestNestedDelete.CaptureOwnerDelete: String;
begin
  Result := '';
  try
    FCds.Delete;
  except
    on E: Exception do
      Result := E.ClassName + ': ' + E.Message;
  end;
end;

procedure TTestNestedDelete.Premise_TheOwnerRegistersOneNestedDataSetAndItIsEmpty;
var
  LNested: TDataSet;
begin
  BuildAdapter;
  AddOwnerRow(1, 'owner');
  Assert.AreEqual(1, TDataSetPeek(FCds).NestedDataSets.Count,
    'the ftDataSet column must have registered exactly one nested dataset, ' +
    'otherwise the loop under test never iterates and this fixture is blind');
  LNested := Nested;
  Assert.IsTrue(TDataSetPeek(FCds).NestedDataSets[0] = LNested,
    'the registered dataset must be the one behind the ftDataSet field');
  Assert.IsTrue(LNested.Active,
    'an inactive nested dataset would fail on First, which is a different ' +
    'defect from the one under test');
  Assert.IsTrue(LNested.IsEmpty,
    'no child row was written, so the nested dataset must be empty - that is ' +
    'the state nobody exercised');
  Assert.AreEqual(0, LNested.RecordCount, 'and it must hold no record');
end;

procedure TTestNestedDelete.Premise_DeleteOnAnEmptyDataSetRaisesEDatabaseError;
var
  LPlain: TClientDataSet;
  LMessage: String;
begin
  LPlain := TClientDataSet.Create(nil);
  try
    LPlain.FieldDefs.Add(cNESTEDKEY, ftInteger);
    LPlain.CreateDataSet;
    Assert.IsTrue(LPlain.IsEmpty, 'the probe must start empty');
    LMessage := '';
    try
      LPlain.Delete;
    except
      on E: Exception do
        LMessage := E.ClassName + ': ' + E.Message;
    end;
    Assert.IsFalse(LMessage = '',
      'Delete on an empty dataset must raise - if it did not, the loop under ' +
      'test would have needed no guard at all');
    Assert.Contains(LowerCase(LMessage), 'empty dataset',
      'and the RTL must be the one refusing, by the message it ships');
    Assert.Contains(LMessage, 'EDatabaseError',
      'raised as EDatabaseError, the class the issue reports');
  finally
    LPlain.Free;
  end;
end;

procedure TTestNestedDelete.NestedEmpty_DoBeforeDelete_DoesNotRaise;
var
  LMessage: String;
begin
  BuildAdapter;
  AddOwnerRow(1, 'owner');
  Assert.IsTrue(Nested.IsEmpty, 'premise: the nested dataset carries no row');
  LMessage := CaptureBeforeDelete;
  Assert.IsTrue(LMessage = '',
    'clearing an already empty nested dataset must be a no-op, got ' + LMessage);
end;

procedure TTestNestedDelete.NestedEmpty_DeletingTheOwnerRow_DoesNotRaise;
var
  LMessage: String;
begin
  BuildAdapter;
  AddOwnerRow(1, 'owner');
  Assert.IsTrue(Nested.IsEmpty, 'premise: the nested dataset carries no row');
  // The production route: TDataSet.Delete fires the BeforeDelete the adapter
  // installed in TDataSetBaseAdapter<M>.SetDataSetEvents.
  LMessage := CaptureOwnerDelete;
  Assert.IsTrue(LMessage = '',
    'deleting an owner row with no children must work, got ' + LMessage);
end;

procedure TTestNestedDelete.NestedEmpty_DeletingTheOwnerRow_RemovesIt;
begin
  BuildAdapter;
  AddOwnerRow(1, 'owner');
  Assert.AreEqual(1, FCds.RecordCount, 'premise: one owner row');
  FCds.Delete;
  Assert.AreEqual(0, FCds.RecordCount,
    'the row must be gone - a guard that swallowed the delete would leave it');
end;

procedure TTestNestedDelete.NestedPopulated_DoBeforeDelete_ClearsEveryNestedRow;
var
  LMessage: String;
begin
  BuildAdapter;
  AddOwnerRow(1, 'owner');
  AddNestedRows(cNESTEDROWS);
  Assert.AreEqual(cNESTEDROWS, NestedCount,
    'premise: the nested dataset must really carry rows, otherwise this test ' +
    'is the empty case again and proves nothing about the clearing');
  LMessage := CaptureBeforeDelete;
  Assert.IsTrue(LMessage = '',
    'clearing a populated nested dataset must not raise, got ' + LMessage);
  Assert.AreEqual(0, NestedCount,
    'every nested row must have been deleted - the guard skips an EMPTY ' +
    'nested dataset, never a populated one');
end;

procedure TTestNestedDelete.NestedPopulated_DeletingTheOwnerRow_DoesNotRaise;
var
  LMessage: String;
begin
  BuildAdapter;
  AddOwnerRow(1, 'owner');
  AddNestedRows(cNESTEDROWS);
  Assert.AreEqual(cNESTEDROWS, NestedCount, 'premise: nested rows present');
  LMessage := CaptureOwnerDelete;
  Assert.IsTrue(LMessage = '',
    'deleting an owner row that has children must work, got ' + LMessage);
  Assert.AreEqual(0, FCds.RecordCount, 'and the owner row must be gone');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestNestedDelete);

end.
