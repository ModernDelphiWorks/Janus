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

{ @abstract(Janus Framework - who owns the object the caller hands to the REST
  ObjectSet family. Issue #362.)

  WHAT WAS WRONG

  TRESTObjectSetAdapter<M>.Update wrapped the object it was given in a
  TObjectList<M> - whose OwnsObjects is True by default - and called Clear on
  that list in its `finally`. Clear on an owning list DESTROYS the items, and
  the single item here is THE CALLER'S OBJECT. So

    LObj := TSomething.Create;
    try
      LObjectSet.Update(LObj);   // LObj is destroyed in here
    finally
      LObj.Free;                 // double free
    end;

  - the obvious code - was wrong, and nothing in the signature said so.

  THE ENUMERATION THE ISSUE LEFT OPEN, ANSWERED BY EXECUTION

  Issue #362 measured Update alone and recorded Insert and Delete as NOT
  MEASURED. All three are driven below, each through the SAME instrument, and
  the answers are:

    Update  destroyed the caller's object   - the defect, repaired here
    Insert  did not                         - it never wraps; it hands the
                                              object straight to
                                              TSessionRestFul<M>.Insert
    Delete  did not                         - likewise, through
                                              TSessionRestFul<M>.Delete

  The Insert and Delete clauses are therefore CHARACTERISATION, not repair.
  They stay because the enumeration is the part of this issue that was open,
  and an enumeration nothing re-runs is a sentence, not a measurement: the day
  one of those two grows a list of its own, the clause is what says so.

  THE INSTRUMENT, AND THE RULE IT KEEPS

  A destruction ledger keyed by the instance ADDRESS -
  Test.Janus.Model.OwnedProbe. NO CLAUSE BELOW DEREFERENCES A POINTER THE
  LEDGER MIGHT HAVE ALREADY BURIED. Each clause asks the ledger first and only
  touches the object when the answer is zero. That discipline is what makes
  these clauses runnable against the DEFECTIVE source at all: read `LProbe.tag`
  unconditionally and the red run is a use-after-free whose numbers mean
  nothing.

  WHY THE REPAIR IS `OwnsObjects := False` AND NOT "STOP USING A LIST"

  Because the second one does not exist to be chosen. The only method on the
  RESTful session that puts a PUT on the wire is
  TSessionRestFul<M>.Update(const AObjectList: TObjectList<M>) - the list
  overload is the one and only override there. The single-object overload it
  inherits, TSessionAbstract<M>.Update(const AObject: M; const AKey: String),
  reaches FCommandExecutor and FModifiedFields.Items[AKey], and a RESTful
  session has neither: FCommandExecutor is assigned by
  TSessionObjectSet/TSessionDataSet and by nothing on the REST side. Measured -
  see the mutation table in the delivery note: routing Update through that
  overload takes the whole fixture from 6 passing clauses to an access
  violation, and NOT ONE PUT reaches the connection.

  So "do not use a list" means ADDING a single-object PUT to the shipped
  session class - a new method on a public generic, whose list overload the
  DataSet family still needs, since TRESTDataSetAdapter<M>.ApplyUpdater really
  does batch N objects. One line inside one method against a second way to
  spell the same round trip.

  WHAT MAY NOT REGRESS, AND THE POPULATION THAT SAYS IT CANNOT

  A list that stops owning its items must not start forgetting something it was
  right to free. The list in question is a LOCAL of one method, and its whole
  population is enumerable in the method body: it is created, ONE Add is
  performed - of the caller's argument - and it is cleared and freed. There is
  no other entrant.

  The neighbouring list that DOES legitimately own - LUpdateList in
  TRESTDataSetAdapter<M>.ApplyUpdater - is a different local in a different
  unit, and it is filled with objects that method creates itself (`M.Create`).
  It is deliberately NOT touched.

  AND THE OBJECT LEAK IS RULED OUT FROM THE OTHER SIDE by
  Update_TheLedgerSeesTheCallersOwnFree: after the call the caller performs the
  Free, and the ledger must have seen it. That clause is also the instrument's
  self-check - a ledger that recorded nothing would make every "0 destructions"
  clause here green while measuring nothing, and this is the one place that
  reddens if it does.

  WHAT NOTHING HERE CATCHES, SAID PLAINLY: A LEAK OF THE WRAPPER LIST ITSELF.
  Measured, not assumed - a mutation that removes LObjectList.Free outright,
  applied with a MESSAGE WARN directive the compiler echoed as W1054 on the
  header of Update, SURVIVES at 283/0/0 and leaves Tests Leaked at 0. DUnitX's leak
  counter is blind to it, which is the same finding Test.Janus.Metadata.Compare
  recorded for a different leak and a different suite. The ledger is an
  instrument for ENTITY instances and a TObjectList is not one; catching that
  would need a heap instrument, which is a different issue from this one.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Rest.ObjectSetOwnership;

interface

{$IFNDEF DRIVERRESTFUL}
  {$MESSAGE FATAL 'This unit only makes sense with DRIVERRESTFUL defined. It belongs to Janus.Tests.RESTfulDriver, whose .dproj carries the directive. TRESTObjectSetAdapter is selected by that directive and by nothing else.'}
{$ENDIF}

uses
  Classes,
  SysUtils,
  Generics.Collections,
  DUnitX.TestFramework,
  Janus.Client.Methods,
  Janus.RestFactory.Interfaces,
  Janus.RestObjectSet.Adapter,
  Test.Janus.RestConnection.Double,
  Test.Janus.Model.OwnedProbe;

type
  [TestFixture]
  TTestRestObjectSetOwnership = class
  private
    FConn: IRESTConnection;
    FRecorder: TRecordingRestConnection;
    FAdapter: TRESTObjectSetAdapter<TOwnedProbe>;
    /// Builds the probe FIRST and the adapter after it, then zeroes the
    /// ledger. The order is the instrument's safety: while the probe is alive
    /// nothing else can be allocated at its address, so the throwaway
    /// `M.Create` inside TSessionRestFul<M>.Create cannot be mistaken for it.
    function NewProbe: TOwnedProbe;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// THE DEFECT. After Update returns, the object the caller passed must
    /// still exist. A 1 here is TObjectList<M>.Clear destroying it.
    [Test]
    procedure Update_TheObjectTheCallerPassedIsNotDestroyed;

    /// THE INSTRUMENT'S OWN SELF-CHECK, and the clause the one above depends
    /// on for its meaning. A ledger that recorded NOTHING would make every
    /// "0 destructions" clause in this fixture green while measuring nothing
    /// at all. Here the caller's own Free is performed and the ledger is
    /// required to have seen it - so a broken ledger reddens HERE, which is
    /// what stops it from silently passing everywhere else.
    ///
    /// It also pins the ownership handover in the direction the repair could
    /// have got wrong: after Update the object is the CALLER'S to release, and
    /// releasing it must really release it.
    [Test]
    procedure Update_TheLedgerSeesTheCallersOwnFree;

    /// The object must still be USABLE, which is the thing the caller actually
    /// lost. Guarded: it asks the ledger before touching the object, so on the
    /// defective source this fails instead of reading dead memory.
    [Test]
    procedure Update_TheObjectIsStillReadableAfterTheCall;

    /// PREMISE. Update still has to do its job - one PUT, carrying this
    /// object's payload. Without this clause a repair that simply stopped
    /// calling the session would be green on every clause above.
    [Test]
    procedure Update_ThePayloadStillGoesOutAsASinglePut;

    /// THE ENUMERATION, second of three: Insert does not wrap and does not
    /// destroy. Driven through the full path - the probe carries a [Sequence],
    /// so ExistSequence is True and the answer reader runs.
    [Test]
    procedure Insert_TheObjectTheCallerPassedIsNotDestroyed;

    /// And Insert really did run, rather than exiting early: the key it left
    /// on the object is one only the answer could have supplied.
    [Test]
    procedure Insert_TheKeyTheAnswerNamedWasApplied;

    /// THE ENUMERATION, third of three: Delete does not wrap and does not
    /// destroy either.
    [Test]
    procedure Delete_TheObjectTheCallerPassedIsNotDestroyed;

    /// And Delete really did reach the connection.
    [Test]
    procedure Delete_TheRoundTripStillHappens;
  end;

implementation

const
  /// The AutoInc placeholder an unsaved row carries.
  cPLACEHOLDER = -1;

  /// The key only the insert answer can supply. Nothing in this fixture
  /// writes it.
  cSERVERKEY = 424;

  /// The shipped insert contract, naming this entity's primary key BY PROPERTY
  /// NAME - the document Janus.Server.Resource.pas builds.
  cINSERTANSWER =
    '{"result":"Resource ownedprobe insert command executed successfully", ' +
    '"params":[{"probe_id":424}]}';

  /// What the probe carries out on the wire.
  cTAG = 'ownership-probe';

{ TTestRestObjectSetOwnership }

procedure TTestRestObjectSetOwnership.Setup;
begin
  FRecorder := TRecordingRestConnection.Create;
  FConn := FRecorder;
  FRecorder.Response := cINSERTANSWER;
  FAdapter := nil;
end;

procedure TTestRestObjectSetOwnership.TearDown;
begin
  FreeAndNil(FAdapter);
  FConn := nil;
  FRecorder := nil;
  TOwnedProbe.ResetLedger;
end;

function TTestRestObjectSetOwnership.NewProbe: TOwnedProbe;
begin
  Result := TOwnedProbe.Create;
  Result.probe_id := cPLACEHOLDER;
  Result.tag := cTAG;
  // The adapter - and with it the session's own throwaway instance - is built
  // WHILE the probe is alive, and the ledger is zeroed afterwards. See the
  // doc comment over this method.
  FAdapter := TRESTObjectSetAdapter<TOwnedProbe>.Create(FConn);
  TOwnedProbe.ResetLedger;
end;

procedure TTestRestObjectSetOwnership.Update_TheObjectTheCallerPassedIsNotDestroyed;
var
  LProbe: TOwnedProbe;
  LAddress: Pointer;
  LDestructions: Integer;
begin
  LProbe := NewProbe;
  LAddress := Pointer(LProbe);

  FAdapter.Update(LProbe);

  LDestructions := TOwnedProbe.DestructionsOf(LAddress);
  // Release it ONLY if it is still ours to release. Freeing it after the
  // adapter already did is the double free this issue is about, and a fixture
  // must not commit the defect it is measuring.
  if LDestructions = 0 then
    LProbe.Free;

  Assert.AreEqual(0, LDestructions,
    'the object the caller passed must survive Update. 1 here is ' +
    'TObjectList<M>.Clear destroying the item of a list whose OwnsObjects was ' +
    'left at its default True - the caller is left with a dangling pointer ' +
    'and its own Free is a double free - issue #362');
end;

procedure TTestRestObjectSetOwnership.Update_TheLedgerSeesTheCallersOwnFree;
var
  LProbe: TOwnedProbe;
  LAddress: Pointer;
begin
  LProbe := NewProbe;
  LAddress := Pointer(LProbe);

  FAdapter.Update(LProbe);

  if TOwnedProbe.DestructionsOf(LAddress) <> 0 then
    Assert.Fail('Update destroyed the object, so the caller has nothing left ' +
      'to free and this clause cannot make its measurement - issue #362');

  LProbe.Free;

  Assert.AreEqual(1, TOwnedProbe.DestructionsOf(LAddress),
    'the ledger must have SEEN the caller''s own Free. 0 here means the ' +
    'instrument records nothing, and every "0 destructions" clause in this ' +
    'fixture would then be green while measuring nothing at all');
end;

procedure TTestRestObjectSetOwnership.Update_TheObjectIsStillReadableAfterTheCall;
var
  LProbe: TOwnedProbe;
  LAddress: Pointer;
begin
  LProbe := NewProbe;
  LAddress := Pointer(LProbe);

  FAdapter.Update(LProbe);

  if TOwnedProbe.DestructionsOf(LAddress) > 0 then
    Assert.Fail('Update destroyed the object the caller passed, so any read ' +
      'of it here would be a use-after-free. This clause deliberately refuses ' +
      'to perform that read - issue #362');

  Assert.AreEqual(cTAG, LProbe.tag,
    'the caller''s object must come out of Update carrying what it went in ' +
    'with, which is the thing a consumer actually loses when the adapter ' +
    'frees it');
  LProbe.Free;
end;

procedure TTestRestObjectSetOwnership.Update_ThePayloadStillGoesOutAsASinglePut;
var
  LProbe: TOwnedProbe;
  LAddress: Pointer;
begin
  LProbe := NewProbe;
  LAddress := Pointer(LProbe);

  FAdapter.Update(LProbe);

  if TOwnedProbe.DestructionsOf(LAddress) = 0 then
    LProbe.Free;

  Assert.AreEqual(1, FRecorder.CallCount,
    'exactly one round trip. 0 here would mean the ownership clauses above ' +
    'are green about a method that no longer talks to the server at all');
  Assert.AreEqual(Ord(TRESTRequestMethodType.rtPUT),
    Ord(FRecorder.LastCall.RequestMethod),
    'and it is a PUT');
  Assert.Contains(FRecorder.LastCall.BodyParams, cTAG,
    'carrying THIS object''s payload - which is how the body proves the ' +
    'object reached the serializer alive');
end;

procedure TTestRestObjectSetOwnership.Insert_TheObjectTheCallerPassedIsNotDestroyed;
var
  LProbe: TOwnedProbe;
  LAddress: Pointer;
  LDestructions: Integer;
begin
  LProbe := NewProbe;
  LAddress := Pointer(LProbe);

  FAdapter.Insert(LProbe);

  LDestructions := TOwnedProbe.DestructionsOf(LAddress);
  if LDestructions = 0 then
    LProbe.Free;

  Assert.AreEqual(0, LDestructions,
    'Insert hands the object straight to TSessionRestFul<M>.Insert and wraps ' +
    'nothing, so the caller keeps it. This is CHARACTERISATION - the answer ' +
    'issue #362 recorded as NOT MEASURED - and it is what will say so the day ' +
    'Insert grows a list of its own');
end;

procedure TTestRestObjectSetOwnership.Insert_TheKeyTheAnswerNamedWasApplied;
var
  LProbe: TOwnedProbe;
  LAddress: Pointer;
begin
  LProbe := NewProbe;
  LAddress := Pointer(LProbe);

  FAdapter.Insert(LProbe);

  if TOwnedProbe.DestructionsOf(LAddress) > 0 then
    Assert.Fail('Insert destroyed the object the caller passed - reading it ' +
      'here would be a use-after-free');

  Assert.AreEqual(cSERVERKEY, LProbe.probe_id,
    'the whole of Insert ran, gate included: this number exists only in the ' +
    'answer. The placeholder here would mean the clause above measured a ' +
    'method that exited at `if FSession.ExistSequence` and touched nothing');
  LProbe.Free;
end;

procedure TTestRestObjectSetOwnership.Delete_TheObjectTheCallerPassedIsNotDestroyed;
var
  LProbe: TOwnedProbe;
  LAddress: Pointer;
  LDestructions: Integer;
begin
  LProbe := NewProbe;
  LProbe.probe_id := 7;
  LAddress := Pointer(LProbe);

  FAdapter.Delete(LProbe);

  LDestructions := TOwnedProbe.DestructionsOf(LAddress);
  if LDestructions = 0 then
    LProbe.Free;

  Assert.AreEqual(0, LDestructions,
    'Delete hands the object to CascadeActionsExecute and then to ' +
    'TSessionRestFul<M>.Delete, neither of which wraps or frees it. ' +
    'CHARACTERISATION, for the same reason as the Insert clause - issue #362');
end;

procedure TTestRestObjectSetOwnership.Delete_TheRoundTripStillHappens;
var
  LProbe: TOwnedProbe;
  LAddress: Pointer;
begin
  LProbe := NewProbe;
  LProbe.probe_id := 7;
  LAddress := Pointer(LProbe);

  FAdapter.Delete(LProbe);

  if TOwnedProbe.DestructionsOf(LAddress) = 0 then
    LProbe.Free;

  Assert.AreEqual(1, FRecorder.CallCount,
    'exactly one round trip - the ownership clause above must not be green ' +
    'about a Delete that never left the process');
  Assert.AreEqual(Ord(TRESTRequestMethodType.rtDELETE),
    Ord(FRecorder.LastCall.RequestMethod),
    'and it is a DELETE');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRestObjectSetOwnership);

end.
