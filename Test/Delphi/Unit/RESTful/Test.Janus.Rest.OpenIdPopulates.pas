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

{ @abstract(Janus Framework - "open by id" over the REST ClientDataSet family:
  the row the server answered has to reach the dataset, and the object it
  arrived in has to be released. Issue #328.)

  WHAT WAS WRONG

  TRESTClientDataSetAdapter<M>.OpenIDInternal declared a local M, called
  FSession.Find and DISCARDED the returned reference, then tested, used and
  freed the local that had never been assigned. Three consequences, and the
  clauses below are one per consequence:

    1. the row never reaches the dataset - "open by id" empties the dataset,
       buys a round trip, and leaves nothing behind;
    2. the object the session built is never freed - it leaks, once per call;
    3. the `<> nil` test and the `Free` run on whatever the previous call left
       on the stack at that address.

  WHY (3) IS NOT ASSERTED HERE, AND WHERE IT IS MEASURED INSTEAD

  Consequence (3) is a property of the CODE GENERATED for this method, not of
  any state a test can set up, and a test that drove it would have to free a
  pointer it does not own. It was measured by reading the binary, which is the
  same instrument that closed the equivalent question in issue #313.

  Measured on b66b04b, Janus.Tests.Units.exe built Debug/Win32 with
  DCC_MapFile=3, over ALL FIVE instantiations of
  TRESTClientDataSetAdapter<>.OpenIDInternal the linker kept (TAitMid,
  TAitRoot, TAsymChild, TAsymMaster, TKeyOnly). The frame is identical in all
  five:

    push ebp / mov ebp,esp / add esp,-14h
    xor ecx,ecx / mov [ebp-14h],ecx    <- the ONLY slot the prologue zeroes,
                                          and it is the UnicodeString temp for
                                          AID.ToString, zeroed because it is a
                                          MANAGED type
    mov [ebp-10h],edx                  <- AID
    mov [ebp-4],eax                    <- Self
    ...
    mov [ebp-0Ch],eax                  <- where the DISCARDED Find result went
    cmp [ebp-8],0                      <- LObject: never written by this method
    ...
    mov eax,[ebp-8] / call TObject.Free

  So the answer for THIS method is the opposite of the one #313 measured for
  TSessionRestFul<M>.Insert: there the prologue zeroed the whole local area
  and the stale free could not happen; here the prologue zeroes one slot and
  LObject is not it. The contrast is visible inside this very same method
  group - OpenSQLInternal, whose local IS assigned, uses [ebp-8] too and
  writes it (`mov [ebp-8],eax`) before the same `cmp [ebp-8],0`.

  WHY NO CLAUSE DRIVES "Find RETURNED nil"

  Because nothing can reach it from here. TSessionRestFul<M>.Find(const AID:
  String) ends in TJanusJson.JsonToObject<M>, which is TJsonBuilder
  .JsonToObject<T>: it does `Result := T.Create` and RAISES when the parse
  fails, freeing the instance on the way out. There is no path through it that
  answers nil - not for a malformed body, not for a body whose columns are all
  absent (an instance with default values comes back). Read in the JsonFlow
  the seven test projects actually compile against, `.modules\JsonFlow` at
  65a1e91, Source\Core\JsonFlow.Builders.pas, TJsonBuilder.JsonToObject<T>.

  The repair therefore KEEPS the `<> nil` guard, and mutating it to `if True`
  is a DECLARED SURVIVOR of this fixture. It survives on the wiring, not on
  the contract: FSession is declared TSessionAbstract<M>, whose Find(const
  AID: String) hands straight to FCommandExecutor.Find, and
  TSQLCommandExecutor<M>.Find answers `Result := nil` whenever the select
  does not bring back exactly one row. Only the session this class installs
  today - TSessionRestFul<M> - cannot answer nil. The sibling of the same
  family keeps the guard too: TRESTFDMemTableAdapter<M>.OpenIDInternal exits
  on nil, leaving the dataset empty and raising nothing. A clause here would
  be measuring the serialiser, not this adapter.

  HOW THE FIXTURE PINS THE SYMPTOM DOWN

  Because LObject held stack leftovers, what a caller SEES from the broken
  method depends on what ran just before it. A test whose red depended on that
  would be measuring the caller's history. ScrubbedOpenID therefore zeroes the
  stack region the callee is about to build its frame in, immediately before
  the call, so the broken method behaves as its most forgiving case - a silent
  no-op - every time. That makes the failure DETERMINISTIC and understates
  rather than overstates the defect. With the repair in place the scrub is
  inert: the local is assigned before it is read.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Rest.OpenIdPopulates;

interface

uses
  DB,
  Rtti,
  Classes,
  SysUtils,
  DBClient,
  DUnitX.TestFramework,
  Janus.RestFactory.Interfaces,
  Janus.RestDataSet.ClientDataSet,
  Test.Janus.Model.OpenIdRow,
  Test.Janus.RestConnection.Double;

type
  /// <summary> Classic cracker descendant: OpenIDInternal is protected, and
  ///  the production callers that reach it (TContainerDataSet.OpenID,
  ///  TManagerDataSet.OpenID) would drag a whole container in for nothing.
  /// </summary>
  ///  NOT generic on purpose: a class method of a parameterized type declared
  ///  in the interface section may not touch an implementation-local symbol,
  ///  and the scrub below has to be one - see _ZeroTheFrameBelow.
  TOpenIdCdsCrack = class(TRESTClientDataSetAdapter<TOpenIdRow>)
  public
    class procedure ScrubbedOpenID(
      const AAdapter: TRESTClientDataSetAdapter<TOpenIdRow>;
      const AID: TValue);
  end;

  [TestFixture]
  TTestRestOpenIdPopulates = class
  private
    FConn: IRESTConnection;
    FServer: TRecordingRestConnection;
    FCds: TClientDataSet;
    FAdapter: TRESTClientDataSetAdapter<TOpenIdRow>;
    procedure Build(const AResponse: String);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// PREMISE. Without this the two clauses below could both be green over a
    /// path that never went anywhere.
    [Test]
    procedure Premise_OpenByIdReallyAsksTheServerForThatId;
    /// LOAD-BEARING. Consequence 1: the answered row has to land in the
    /// dataset.
    [Test]
    procedure OpenId_TheRowTheServerAnsweredLandsInTheDataSet;
    /// LOAD-BEARING. Consequence 2: the object it arrived in has to be freed.
    [Test]
    procedure OpenId_TheObjectTheSessionBuiltIsReleased;
    /// LOAD-BEARING, against a repair that populates without emptying. Two
    /// opens in a row leave ONE row, and release BOTH objects.
    [Test]
    procedure OpenId_ASecondOpenReplacesTheRowInsteadOfAddingToIt;
  end;

implementation

const
  /// One row, the shape TSessionRestFul<M>.Find(const AID: String) expects: a
  /// single JSON OBJECT, not an array.
  cONEROW  = '{"oid":7,"tag":"from-server"}';
  cOTHERROW = '{"oid":9,"tag":"second-call"}';

/// <summary> Zeroes the stack that the NEXT call made from the same place
///  will build its frame on.
///
///  It has to be its own routine, and this is the whole trick: a local array
///  declared in ScrubbedOpenID would sit ABOVE the callee's frame and never
///  touch it. Called as a SIBLING of OpenIDInternal - same caller, same esp
///  at the call - this procedure's locals land on exactly the bytes
///  OpenIDInternal is about to use, [ebp-8] among them. 512 bytes is far more
///  than the 20 that method allocates.
///
///  Nothing may run between this returning and the call under test, or the
///  scrub is undone. That is why ScrubbedOpenID takes AID already boxed as
///  TValue and casts with a hard cast, which emits no code. </summary>
procedure _ZeroTheFrameBelow;
var
  LScrub: array[0..127] of NativeUInt;
  LFor: Integer;
begin
  for LFor := Low(LScrub) to High(LScrub) do
    LScrub[LFor] := 0;
  if LScrub[High(LScrub)] <> 0 then
    raise Exception.Create('unreachable - keeps the loop from being elided');
end;

{ TOpenIdCdsCrack }

class procedure TOpenIdCdsCrack.ScrubbedOpenID(
  const AAdapter: TRESTClientDataSetAdapter<TOpenIdRow>; const AID: TValue);
begin
  _ZeroTheFrameBelow;
  TOpenIdCdsCrack(AAdapter).OpenIDInternal(AID);
end;

{ TTestRestOpenIdPopulates }

procedure TTestRestOpenIdPopulates.Setup;
begin
  FServer := TRecordingRestConnection.Create;
  FConn := FServer;
  FCds := nil;
  FAdapter := nil;
  TOpenIdRow.DestroyCount := 0;
end;

procedure TTestRestOpenIdPopulates.TearDown;
begin
  FreeAndNil(FAdapter);
  FreeAndNil(FCds);
  FConn := nil;
  FServer := nil;
end;

procedure TTestRestOpenIdPopulates.Build(const AResponse: String);
begin
  FServer.Response := AResponse;
  FCds := TClientDataSet.Create(nil);
  FAdapter := TRESTClientDataSetAdapter<TOpenIdRow>.Create(FConn, FCds, -1, nil);
  // The constructor leaves the dataset open and may have appended nothing;
  // every clause below starts from a dataset that is open and empty, which is
  // also the state OpenIDInternal itself produces before it asks the server.
  TOpenIdRow.DestroyCount := 0;
end;

procedure TTestRestOpenIdPopulates.Premise_OpenByIdReallyAsksTheServerForThatId;
begin
  Build(cONEROW);

  TOpenIdCdsCrack.ScrubbedOpenID(FAdapter, TValue.From<Integer>(7));

  Assert.AreEqual(1, FServer.CallCount,
    'exactly one round trip - if this is 0 the two clauses below would be ' +
    'measuring a method that never left the process');
  Assert.AreEqual('openidrow', FServer.LastCall.Resource,
    'and it asked the resource this entity maps to');
  Assert.AreEqual('$value=7', FServer.LastCall.QueryParams,
    'carrying the id it was opened by - anything else and the row that came ' +
    'back would be someone else''s');
end;

procedure TTestRestOpenIdPopulates.OpenId_TheRowTheServerAnsweredLandsInTheDataSet;
begin
  Build(cONEROW);

  TOpenIdCdsCrack.ScrubbedOpenID(FAdapter, TValue.From<Integer>(7));

  Assert.IsTrue(FCds.Active,
    'the dataset has to be open, otherwise there is nothing to read');
  Assert.AreEqual(1, FCds.RecordCount,
    'THE WHOLE POINT OF "OPEN BY ID". 0 here is the defect of issue #328: ' +
    'the method empties the dataset, buys the round trip the premise above ' +
    'already proved, and then drops the answer');
  Assert.AreEqual(7, FCds.FieldByName('oid').AsInteger,
    'and the row is the one that was asked for');
  Assert.AreEqual('from-server', FCds.FieldByName('tag').AsString,
    'CARRYING THE SERVER PAYLOAD. A blank tag with RecordCount = 1 would ' +
    'mean an empty row was appended from somewhere else, not that the ' +
    'answer was populated');
end;

procedure TTestRestOpenIdPopulates.OpenId_TheObjectTheSessionBuiltIsReleased;
begin
  Build(cONEROW);

  TOpenIdCdsCrack.ScrubbedOpenID(FAdapter, TValue.From<Integer>(7));

  Assert.AreEqual(1, TOpenIdRow.DestroyCount,
    'THE LEAK. TSessionRestFul<M>.Find hands the caller an instance it built ' +
    'and does not keep - whoever called it owns it. 0 here means the ' +
    'reference was dropped without ever being released, once per call, which ' +
    'is what discarding the result of Find did');
end;

procedure TTestRestOpenIdPopulates.OpenId_ASecondOpenReplacesTheRowInsteadOfAddingToIt;
begin
  Build(cONEROW);
  TOpenIdCdsCrack.ScrubbedOpenID(FAdapter, TValue.From<Integer>(7));

  FServer.Response := cOTHERROW;
  TOpenIdCdsCrack.ScrubbedOpenID(FAdapter, TValue.From<Integer>(9));

  Assert.AreEqual(1, FCds.RecordCount,
    'ONE ROW, NOT TWO. "Open by id" is a replace, and the EmptyDataSet that ' +
    'stands before the round trip is what makes it one - a repair that ' +
    'populated without emptying would read 2 here and still satisfy every ' +
    'other clause of this fixture');
  Assert.AreEqual(9, FCds.FieldByName('oid').AsInteger,
    'and the row left standing is the SECOND one');
  Assert.AreEqual(2, TOpenIdRow.DestroyCount,
    'both instances released, one per call - a leak that only shows up from ' +
    'the second call on is still a leak');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRestOpenIdPopulates);

end.
