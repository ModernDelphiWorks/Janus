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

{ @abstract(Janus Framework - what the #300 parser repair does to the gate the
  #297 re-read stands behind. Issue #300.)

  WHY THIS FIXTURE EXISTS

  Test.Janus.Rest.ResultParamsCompositeKey proves the parser in isolation: N
  pairs in, N params out. This one asks the question that only the ADAPTER can
  answer, because #297 landed a gate that READS the very columns #300 changed
  the number of.

  TRESTDataSetAdapter<M>.ApplyInserter stamps the row from ResultParams and then
  decides whether to buy a re-read GET:

      if _GraphBelowIsStale(Self) and not _RowKeyIsUngenerated(Self) then

  _RowKeyIsUngenerated walks the row's OWN primary key COLUMN BY COLUMN and
  answers True the moment ONE of them still carries the AutoInc placeholder. On
  a single-column key that is a yes/no about the whole answer, and every shipped
  clause of Test.Janus.Rest.ReReadAfterInsert drives exactly that. On a
  COMPOSITE key it is not: before #300 the client was left with the LAST key
  column stamped and every earlier one on the placeholder, which is precisely
  the state that makes _RowKeyIsUngenerated say True and the gate refuse.

  SO THE FIX DOES CHANGE WHEN THE RE-READ FIRES, AND HERE IS THE NUMBER

  Same model, same seed, same answer - one POST answer naming BOTH key columns
  of a composite AutoInc key, over a child that is still on its own placeholder:

    parser before #300 : ck1 = -1, ck2 = 9, GetCount = 0
    parser after  #300 : ck1 =  7, ck2 = 9, GetCount = 1

  That is not a regression of #297, it is #297 finally reaching a shape it could
  never reach: with the key incomplete there was nothing to ask BY, and the gate
  was right to refuse - Cost_WithoutResultParamsNoGetIsIssued says the same
  thing about the empty answer. What #300 removes is the case where the key
  IS complete on the wire and the client threw half of it away.

  THE COST IS BOUNDED THE SAME WAY IT ALREADY WAS

  One extra GET per inserted root, and only for a root that has a stale graph
  below it. CompositeKey_NoChildMeansNoGet drives the same root without a child
  adapter and requires zero GETs, so the new firing is the gate opening and not
  the guard disappearing.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Rest.CompositeKeyReReadGate;

interface

uses
  DB,
  Classes,
  SysUtils,
  Generics.Collections,
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
  Janus.Client.Methods,
  Janus.RestFactory.Interfaces,
  Janus.RestDataSet.FDMemTable,
  // The recording double and the ApplyUpdates cracker of the #297 fixture are
  // reused verbatim. A fourth double answering the same two verbs is how
  // doubles grow answers nobody asked for.
  Test.Janus.Rest.ReReadAfterInsert,
  Test.Janus.Model.CompositeAutoInc;

type
  [TestFixture]
  TTestRestCompositeKeyReReadGate = class
  private
    FRep: TReplayRestConnection;
    FConn: IRESTConnection;
    FRootMem: TFDMemTable;
    FChildMem: TFDMemTable;
    FRoot: TRESTFDMemTableAdapter<TCkRoot>;
    FChild: TRESTFDMemTableAdapter<TCkChild>;
    procedure BuildTree;
    procedure Seed;
    function KeyOf(const ADataSet: TDataSet; const AColumn: String): Integer;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure Premise_TheAnswerNamesBothColumnsOfTheCompositeKey;
    [Test]
    procedure CompositeKey_BothColumnsReachTheRootRow;
    [Test]
    procedure CompositeKey_TheGateOpensAndExactlyOneGetIsIssued;
    [Test]
    procedure CompositeKey_NoChildMeansNoGet;
    [Test]
    procedure CompositeKey_AnAnswerMissingOneKeyColumnKeepsTheGateShut;
  end;

implementation

const
  cPLACEHOLDER = -1;
  /// The two numbers the server generated for the two key columns. DIFFERENT
  /// from each other and from the placeholder, so a repair that copied one
  /// column over the other could not look green.
  cSRVK1 = 7;
  cSRVK2 = 9;
  /// The shape Janus.Server.Resource.pas cRESOURCEINSERT takes for a COMPOSITE
  /// key: ONE object, one pair per key column, because ParseInsert appends them
  /// all into the one object the constant reserves.
  cPOSTANSWER =
    '{"result":"Resource ckroot insert command executed successfully",' +
    '"params":[{"ck1":7,"ck2":9}]}';
  /// The same answer with ONE key column missing - the state the client used to
  /// be left in by the parser, now reachable only if the SERVER sends it.
  cPOSTHALFKEY =
    '{"result":"Resource ckroot insert command executed successfully",' +
    '"params":[{"ck2":9}]}';
  /// What the GET route answers: the root on its real key with its child.
  cGETANSWER =
    '[{"ck1":7,"ck2":9,"tag":"root","childs":[' +
      '{"cc_id":333,"ck1":7,"ck2":9,"tag":"child"}]}]';

{ TTestRestCompositeKeyReReadGate }

procedure TTestRestCompositeKeyReReadGate.Setup;
begin
  FRep := TReplayRestConnection.Create;
  FConn := FRep;
  FRep.PostAnswer := cPOSTANSWER;
  FRep.GetAnswer := cGETANSWER;
end;

procedure TTestRestCompositeKeyReReadGate.TearDown;
begin
  FreeAndNil(FChild);
  FreeAndNil(FChildMem);
  FreeAndNil(FRoot);
  FreeAndNil(FRootMem);
  FConn := nil;
  FRep := nil;
end;

procedure TTestRestCompositeKeyReReadGate.BuildTree;
begin
  FRootMem := TFDMemTable.Create(nil);
  FRoot := TRESTFDMemTableAdapter<TCkRoot>.Create(FConn, FRootMem, -1, nil);
  FChildMem := TFDMemTable.Create(nil);
  FChild := TRESTFDMemTableAdapter<TCkChild>.Create(FConn, FChildMem, -1, FRoot);
end;

procedure TTestRestCompositeKeyReReadGate.Seed;
begin
  FRootMem.Append;
  FRootMem.FieldByName('ck1').AsInteger := cPLACEHOLDER;
  FRootMem.FieldByName('ck2').AsInteger := cPLACEHOLDER;
  FRootMem.FieldByName('tag').AsString := 'root';
  FRootMem.Post;
  FChildMem.Append;
  FChildMem.FieldByName('cc_id').AsInteger := cPLACEHOLDER;
  FChildMem.FieldByName('ck1').AsInteger := cPLACEHOLDER;
  FChildMem.FieldByName('ck2').AsInteger := cPLACEHOLDER;
  FChildMem.FieldByName('tag').AsString := 'child';
  FChildMem.Post;
end;

function TTestRestCompositeKeyReReadGate.KeyOf(const ADataSet: TDataSet;
  const AColumn: String): Integer;
begin
  Result := MaxInt;
  if not ADataSet.Active then
    Exit;
  if ADataSet.IsEmpty then
    Exit(-99);
  ADataSet.First;
  Result := ADataSet.FieldByName(AColumn).AsInteger;
end;

procedure TTestRestCompositeKeyReReadGate
  .Premise_TheAnswerNamesBothColumnsOfTheCompositeKey;
begin
  BuildTree;
  Seed;
  TMemApply<TCkRoot>.Apply(FRoot);
  Assert.AreEqual(1, FRep.PostCount,
    'premise: the aggregate leaves in ONE POST, the way the shipped path ' +
    'sends it');
  Assert.IsTrue(Pos('"ck1":7', FRep.PostAnswer) > 0,
    'premise: the canned answer really names the FIRST key column - without ' +
    'it every clause below would be measuring the half-key case');
  Assert.IsTrue(Pos('"ck2":9', FRep.PostAnswer) > 0,
    'premise: and the second');
end;

procedure TTestRestCompositeKeyReReadGate.CompositeKey_BothColumnsReachTheRootRow;
begin
  BuildTree;
  Seed;
  TMemApply<TCkRoot>.Apply(FRoot);
  Assert.AreEqual(cSRVK1, KeyOf(FRootMem, 'ck1'),
    'the FIRST column of the composite key - the one the old parser threw ' +
    'away, leaving it on the placeholder');
  Assert.AreEqual(cSRVK2, KeyOf(FRootMem, 'ck2'),
    'the LAST column, which arrived even before #300');
end;

procedure TTestRestCompositeKeyReReadGate
  .CompositeKey_TheGateOpensAndExactlyOneGetIsIssued;
begin
  BuildTree;
  Seed;
  TMemApply<TCkRoot>.Apply(FRoot);
  Assert.AreEqual(1, FRep.GetCount,
    'THE INTERACTION WITH #297, measured: with the whole composite key ' +
    'stamped, _RowKeyIsUngenerated answers False and the re-read fires. ' +
    'Before #300 this number was 0, because ck1 stayed on the placeholder ' +
    'and the gate refused - correctly, since there was nothing to ask by');
end;

procedure TTestRestCompositeKeyReReadGate.CompositeKey_NoChildMeansNoGet;
begin
  // Same root, same answer, NO child adapter - so _GraphBelowIsStale has
  // nothing to find. The new firing must be the gate OPENING, not the guard
  // disappearing.
  FRootMem := TFDMemTable.Create(nil);
  FRoot := TRESTFDMemTableAdapter<TCkRoot>.Create(FConn, FRootMem, -1, nil);
  FRootMem.Append;
  FRootMem.FieldByName('ck1').AsInteger := cPLACEHOLDER;
  FRootMem.FieldByName('ck2').AsInteger := cPLACEHOLDER;
  FRootMem.FieldByName('tag').AsString := 'root';
  FRootMem.Post;
  TMemApply<TCkRoot>.Apply(FRoot);
  Assert.AreEqual(1, FRep.PostCount, 'the row was still inserted');
  Assert.AreEqual(0, FRep.GetCount,
    'a root with no child adapter has nothing stale below it and must not ' +
    'pay for a round trip, composite key or not');
end;

procedure TTestRestCompositeKeyReReadGate
  .CompositeKey_AnAnswerMissingOneKeyColumnKeepsTheGateShut;
begin
  // The other half of the interaction. #300 repairs the CLIENT; a server that
  // really sends a partial key still leaves a placeholder in the row, and the
  // gate must still refuse - a GET filtered on a placeholder can only answer
  // somebody else's row or nothing.
  FRep.PostAnswer := cPOSTHALFKEY;
  BuildTree;
  Seed;
  TMemApply<TCkRoot>.Apply(FRoot);
  Assert.AreEqual(cPLACEHOLDER, KeyOf(FRootMem, 'ck1'),
    'premise: the column the answer did not name is still the placeholder');
  Assert.AreEqual(cSRVK2, KeyOf(FRootMem, 'ck2'),
    'premise: the column it did name arrived');
  Assert.AreEqual(0, FRep.GetCount,
    'one placeholder anywhere in the row key is enough for ' +
    '_RowKeyIsUngenerated to keep the gate shut');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRestCompositeKeyReReadGate);

end.
