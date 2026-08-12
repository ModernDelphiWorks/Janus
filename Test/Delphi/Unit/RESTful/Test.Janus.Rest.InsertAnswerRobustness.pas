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

{ @abstract(Janus Framework - TSessionRestFul<M>.Insert survives a FAILING call
  and a MALFORMED answer. Issues #313 and #315.)

  TWO DEFECTS, ONE METHOD. Both live in TSessionRestFul<M>.Insert and both are
  about what the method does when the happy path does not happen. They share a
  fixture because they share a method: splitting them would put two fronts on
  the same file.

  ============================================================================
  #313 - THE FINALLY FREED A POINTER THAT WAS NEVER ASSIGNED
  ============================================================================

  LParamsObject is a local of an UNMANAGED type, so Delphi does not zero it on
  entry. Its first assignment sat INSIDE the try, after FConnection.Execute,
  and the finally read it unconditionally through `if LParamsObject <> nil`.
  When Execute raised - server down, timeout, 500 turned into
  EJanusRESTException by the concrete client - the finally ran with whatever
  the previous stack frame had left in that slot. The nil test does not help:
  stack garbage is rarely zero.

  The damage is not the AV by itself. It is that the AV REPLACES the network
  error while that error is unwinding, so the caller is told "access violation"
  instead of "the server answered 500".

  THE POPULATION, RE-ENUMERATED AT ea0208f - AND THE ISSUE'S COUNT WAS WRONG

  Issue #313 says "eight finally sites that free a local, seven of them right".
  Re-counted at ea0208f over the whole unit: there are THIRTEEN try/finally
  blocks, and only FIVE of them free anything:

    :153-154  LObject.Free      - created at :115, BEFORE the try of :116
    :445-447  LParamsObject     - assigned at :386, INSIDE the try of :376
    :493-495  LObjectList.Free  - assigned at :479-482, before the try of :487
    :647-649  LObjectList.Free  - assigned and nil-tested at :632-634, before
                                  the inner try of :635
    :690-691  LJSONArray.Free   - created at :669, before the try of :670

  So the population is FIVE, not eight, and the ratio is four right to one
  wrong, not seven to one. The QUALITATIVE claim the issue rests on does hold
  and is the only part that matters: Insert is the ONLY site in this unit whose
  freed local is assigned inside the guarded block.

  WHAT THE ISSUE LEFT UNMEASURED - AND MEASURING IT KNOCKED THE ISSUE DOWN

  #313 says in so many words that the AV was never driven, only read off the
  initialisation rule. It was driven here, and THE AV DOES NOT HAPPEN AT
  ea0208f. That is the honest result and it is written at the top rather than
  buried.

  How it was driven. ExecuteRaises_TheNetworkErrorIsWhatReachesTheCaller cannot
  just call Insert and hope, because whether the slot holds garbage depends on
  what ran before it; a runner that happened to leave zeros there would report
  a false green. So _ScribbleOverTheFrame writes $CD over 64KB of stack at
  exactly the depth Insert is about to occupy, with nothing running in between,
  and only then is Insert called with a connection that raises.

  Measured at ea0208f, Studio 37.0, Debug/Win32, RESTfulDriver, with a throwaway
  diagnostic that published the slot's VALUE and its ADDRESS out of Insert:

    slot on entry to Insert   00000000
    address of that slot      012FF3E4
    scribbled range           012EF408 .. 012FF407

  The address is inside the scribbled range, so the scribble is not missing it:
  something zeroes the slot BETWEEN the scribble returning and the first
  statement of Insert, and the only thing that runs in that window is Insert's
  own prologue. Widening the scribble from 2KB to 64KB changed nothing, which
  is the second thing ruling coverage out.

  WHY the prologue clears it here is NOT DETERMINED, and no explanation is
  offered in its place. Three hand-written shapes carrying the SAME local list -
  four Strings, three unmanaged object references, two Integers, the first
  assignment inside the try - were compiled with the same dcc32 37.0 and NONE
  of them is cleared:

    a plain routine                                    slot = CDCDCDCD
    a routine holding an anonymous method that
      captures two of its own locals                   slot = CDCDCDCD
    a method of a generic class, instantiated          slot = CDCDCDCD

  All three die with "EAccessViolation ... Read of address CDCDCDCD" while an
  Exception carrying 'boom' is unwinding - the network error replaced by an
  access violation, exactly the damage #313 describes. So neither the local
  list, nor the closure, nor the generic instantiation is what makes the real
  Insert different, and guessing which of the remaining differences it is would
  be the invention this fixture is written to avoid.

  What that leaves is the only thing that matters for the decision: the class of
  defect is real and demonstrable, and whether it fires in THIS method is
  decided by codegen nobody controls.

  So the finally is one codegen decision away from the AV, and codegen is not a
  contract. What IS a contract is the compiler saying so out loud: dcc32 emits,
  building this very project at ea0208f,

    Janus.Session.RESTful.pas(446): warning W1036: Variable 'LParamsObject'
    might not have been initialized

  446 is the finally. The one-line repair makes that warning disappear, and
  that appearance/disappearance is the before-and-after this repair is measured
  by - because NO RUNTIME CLAUSE GOES RED FOR #313 AT THIS COMMIT, and pretending
  one did would be the whole point of the exercise thrown away.
  ExecuteRaises_TheNetworkErrorIsWhatReachesTheCaller is kept as the guard that
  goes red the day the prologue stops clearing the frame.

  ============================================================================
  #315 - TWO HARD CASTS, AND A NIL GUARD THAT ONLY COVERED ONE SHAPE
  ============================================================================

  `Values['params'] as TJSONArray` followed by `if ... = nil then Exit` reads
  like a guarded cast and is not one. `nil as TJSONArray` is nil, so the guard
  does catch the ABSENT key - and nothing else, because when the key is present
  with the wrong type the `as` raises before the guard is ever evaluated. Same
  for `Items[LFor] as TJSONObject` one loop down.

  THE FORMS, MEASURED AT ea0208f BEFORE ANY REPAIR. The bodies are spelled in
  words rather than in JSON because a curly brace inside a curly-brace comment
  closes it early - which happened once while writing this file, and a build
  that dies leaves the PREVIOUS exe on disk to report a false green.

    params is an OBJECT             EInvalidCast escapes Insert
    params is a STRING              EInvalidCast escapes Insert
    params is a NUMBER              EInvalidCast escapes Insert
    params is NULL                  EInvalidCast escapes Insert  <- not in #315
    params is an ARRAY OF NUMBERS   EInvalidCast escapes Insert, from the
                                    SECOND cast, one loop below the first

  The null form is the one the issue missed, and it is the likeliest of the
  five in the field: a server that has no key to report and says so explicitly
  writes null, not an absent key. TJSONNull is a TJSONValue like any other, so
  it reaches the cast and dies there.

  EXIT OR A NAMED EXCEPTION - DECIDED BY WHAT THE HOUSE ALREADY ANSWERS

  The issue leaves the choice open. It is not open: the same method answers the
  same question twice already, and one method below it the answer is written
  out with its reasoning. Every line number below was re-read at ea0208f, the
  tree this repair was written against:

    :387-388  the body does not parse into an object -> silent Exit
    :391-392  `params` is absent                     -> silent Exit
    :636-645  RefreshRecord, issue #297: "NENHUMA LINHA E UMA RESPOSTA, e nao
              um erro ... a excecao passaria a interromper a gravacao DEPOIS de
              o servidor ja ter escrito"

  That last one is decisive and it is about THIS moment in the lifecycle. By
  the time the answer is parsed the server HAS ALREADY INSERTED THE ROW. An
  exception here does not prevent anything; it aborts the client after the
  write, exactly the outcome #297 refused. `params` is the server's echo of the
  generated key: useful when present, and its absence is already a supported
  answer. A malformed `params` carries no more information than an absent one,
  so it gets the same answer - Exit, list left empty, consumer writes nothing.

  Two different answers to one question inside one framework is a defect on its
  own, so the repair does not invent a third.

  WHY `Continue` AND NOT `Exit` ON THE ITEM CAST

  The array is a list of independent objects - the parser already accepts one
  object per column as well as one object with N pairs. A non-object element
  says nothing about its siblings, so it is skipped and the well-formed ones
  are still read. ParamsArrayMixesObjectsAndNonObjects_TheGoodOnesStillArrive
  is what holds that apart from Exit, and the mutation table below says it
  earns its place: Continue -> Exit and Continue -> Break each kill it, and it
  alone.

  WHAT THIS REPAIR DOES NOT COVER - REPORTED, NOT WIDENED

  An answer that is not a JSON OBJECT at the top level never reaches line 390.
  TJanusJson.JSONStringToJSONObject (Source/Core/Janus.Json.pas:250-252) is
  itself `JSONStringToJSONValue(AJson) as TJSONObject`, so a body that is a
  top-level ARRAY raises EInvalidCast one layer BELOW this method, inside the
  parser. Measured at ea0208f. That file is the #314 front and is deliberately
  untouched here; no clause in this fixture pins its behaviour, because pinning
  it would make this fixture fail the day #314 repairs it.

  The sibling hard casts on response JSON outside this method were enumerated
  at ea0208f and are reported with the issue, not repaired here:
  Janus.Client.DataSnap.pas:145,178,212 and Janus.Client.WS.pas:143,177,212,
  all six of the form `(FRESTRequest.Response.JSONValue as TJSONArray).Items[0]`
  - which, unlike this method, ALSO indexes Items[0] without checking Count.

  ============================================================================
  MUTATION - EVERY FIGURE MEASURED, EVERY SURVIVOR DECLARED
  ============================================================================

  Measured on bfa1414, Janus.Tests.RESTfulDriver Debug/Win32, 130 clauses.
  Every mutation carries a MESSAGE WARN 'S313MUT' directive on the line it
  changes, and is listed only after dcc32 echoed that line number back. The
  directive is spelled here WITHOUT its braces on purpose: it is a directive,
  not a comment, and pasting it whole into a curly-brace comment closes the
  comment at its own closing brace. That kills the build, and a build that dies
  leaves the PREVIOUS exe on disk to report a green that was never run. The exe is deleted before each build for the same
  reason.

    what was mutated                              echoed at   killed

    #313, the repair itself
      LParamsObject := nil  ->  removed             :400       NONE  <- see below
    #315, the params guard
      guard reverted to `as TJSONArray` + nil test  :443       4
      `is TJSONArray`  ->  `is TJSONValue`          :443       3
      `if not (... is TJSONArray)` -> `if (...)`    :443       40
    #315, the item guard
      guard reverted to `as TJSONObject`            :492       3
      `is TJSONObject` ->  `is TJSONValue`          :492       3
      Continue  ->  Exit                            :493       1
      Continue  ->  Break                           :493       1
      `if not (... is TJSONObject)` -> `if (...)`   :492       36
    both #315 guards reverted at once               :443,:493  7

  Neither #315 guard is covered by the other: reverting the first kills four
  and reverting the second kills three, disjointly, and reverting both kills
  exactly those seven. That is what rules out the "it is identical to its
  sibling" reading, which is what a single combined mutation would have left
  open.

  Both directions are covered on both guards - weakened (`is TJSONValue`) and
  inverted (`if not` dropped) - and on the Continue, which dies to Exit and to
  Break alike.

  THE ONE SURVIVOR, AND IT IS NOT LEFT OPEN

  Removing `LParamsObject := nil` - the whole of the #313 repair - leaves the
  suite at 130/0/0. That is not a mutation that failed to apply: dcc32 echoed
  the marker at :400. It is the same result the header explains at length -
  Insert's prologue clears its own frame, so no runtime clause can see the
  difference at this commit.

  It is not left as an open survivor either, because the mutation IS killed,
  one level up from the runtime. Measured at the same commit, same project:

    with the repair       no W1036 for Janus.Session.RESTful.pas at all
    repair removed        Janus.Session.RESTful.pas(506): warning W1036:
                          Variable 'LParamsObject' might not have been
                          initialized

  506 is the finally. The compiler is the oracle for this one, and it answers
  both ways.

  WHICH CLAUSE CAUGHT WHICH, WHERE IT IS NOT OBVIOUS

  ParamsIsAnObject_IsReadAsNoParams dies to the reverted guard but NOT to
  `is TJSONValue`, and the reason is worth a line so nobody reads it as a hole:
  under that mutation a params OBJECT passes the guard and is then cast
  unchecked, and TJSONArray(aTJSONObject).Items[0] lands on the pair list, whose
  elements are TJSONPair and therefore fail `is TJSONObject` one loop down. The
  answer comes out empty by a second wrong turn rather than by the right rule.
  The other three clauses of that group do kill it.

  ANCHORS INTO THE SUITE ARE BY METHOD, NEVER BY `file:line`. Citations INTO
  SOURCE are by `file:line`, each re-read at the commit named beside it.
}

unit Test.Janus.Rest.InsertAnswerRobustness;

interface

uses
  DB,
  Classes,
  SysUtils,
  Variants,
  Generics.Collections,
  DUnitX.TestFramework,
  Janus.Client.Methods,
  Janus.RestFactory.Interfaces,
  Janus.Session.RESTful,
  Test.Janus.RestConnection.Double,
  Test.Janus.Model.KeyOnly,
  Test.Janus.Rest.ResultParamsCompositeKey;

type
  /// <summary> Drives TSessionRestFul&lt;M&gt;.Insert against a connection that
  ///  RAISES instead of answering, and renders whatever escapes as
  ///  `ClassName: Message`.
  ///
  ///  The rendering is a string on purpose: the thing under test is WHICH
  ///  exception survives the finally, and a class-only assertion would go green
  ///  on an EAccessViolation that happened to be re-raised as the right
  ///  class - which cannot happen, but the message costs nothing and pins the
  ///  identity as well as the type.
  ///
  ///  NOT GENERIC, unlike TParamsProbe next door, and for a compiler reason
  ///  worth writing down: a method of a parameterized type declared in the
  ///  INTERFACE section may not call a symbol local to the IMPLEMENTATION
  ///  section (E2506), and the frame dirtier this probe needs is exactly such
  ///  a symbol. The entity is not load-bearing here anyway - Insert reads the
  ///  answer with System.JSON and never consults the mapping, which
  ///  TheSameAnswerParsesTheSameThroughAnUnrelatedEntity already measures
  ///  next door. </summary>
  TInsertFailureProbe = class
  public
    class function WhatEscapes(const AError, AResponse: String;
      const AScribble: Boolean): String;
    class function CallsRecorded(const AError: String): Integer;
  end;

  [TestFixture]
  TTestRestInsertAnswerRobustness = class
  public
    // ---- issue #313 -------------------------------------------------------
    [Test]
    procedure ExecuteRaises_TheNetworkErrorIsWhatReachesTheCaller;
    [Test]
    procedure ExecuteRaises_TheTranscriptStillProvesThePostWasAttempted;
    [Test]
    procedure ExecuteSucceeds_NothingAboutTheHappyPathChanged;
    // ---- issue #315 -------------------------------------------------------
    [Test]
    procedure ParamsIsAnObject_IsReadAsNoParams;
    [Test]
    procedure ParamsIsAString_IsReadAsNoParams;
    [Test]
    procedure ParamsIsANumber_IsReadAsNoParams;
    [Test]
    procedure ParamsIsNull_IsReadAsNoParams;
    [Test]
    procedure ParamsIsAnArrayOfNumbers_IsReadAsNoParams;
    [Test]
    procedure ParamsArrayMixesObjectsAndNonObjects_TheGoodOnesStillArrive;
    [Test]
    procedure ParamsIsAnArrayOfArrays_IsReadAsNoParams;
    // ---- the two answers the guard must NOT have changed -------------------
    [Test]
    procedure ParamsIsAbsent_StillYieldsNoParams;
    [Test]
    procedure ParamsIsWellFormed_StillYieldsEveryPair;
  end;

implementation

const
  /// The shape Janus.Server.Resource.pas builds - one object, N pairs.
  cWELLFORMED = '{"result":"ok","params":[{"k1":10,"k2":20}]}';

var
  /// Keeps _ScribbleOverTheFrame from being optimised away. A local buffer
  /// that is written and never read is dead code the compiler may drop, and a
  /// scribble that did not happen would make the #313 clause a false green.
  GStackWitness: Byte = 0;

{ the frame dirtier }

/// <summary> Writes $CD over 64KB of stack at exactly the depth Insert is
///  about to occupy, so that a local Insert never assigns would be read as
///  $CDCDCDCD instead of whatever the previous caller happened to leave.
///
///  64KB and not 2KB because the size was MEASURED rather than guessed: with
///  the diagnostic in place the slot's address came back at 012FF3E4 inside a
///  scribbled range of 012EF408..012FF407, which is what proves the region is
///  covered and the zero that is read there is NOT a miss. </summary>
procedure _ScribbleOverTheFrame;
var
  LTrash: array[0..65535] of Byte;
begin
  FillChar(LTrash, SizeOf(LTrash), $CD);
  GStackWitness := LTrash[SizeOf(LTrash) - 1];
end;

{ TInsertFailureProbe }

class function TInsertFailureProbe.WhatEscapes(const AError, AResponse: String;
  const AScribble: Boolean): String;
var
  LConnection: TRecordingRestConnection;
  LReference: IRESTConnection;
  LSession: TSessionRestFul<TKeyOnly>;
  LObject: TKeyOnly;
begin
  LConnection := TRecordingRestConnection.Create;
  LReference := LConnection;
  LConnection.ExecuteError := AError;
  LConnection.Response := AResponse;
  LSession := TSessionRestFul<TKeyOnly>.Create(LReference, nil);
  try
    LObject := TKeyOnly.Create;
    try
      // NOTHING MAY RUN BETWEEN THE SCRIBBLE AND THE CALL. The point is that
      // Insert's frame lands on the bytes just dirtied, and any call in
      // between would clean the top of that region back out.
      if AScribble then
        _ScribbleOverTheFrame;
      try
        LSession.Insert(LObject);
        Result := '<nothing was raised>';
      except
        on E: Exception do
          Result := E.ClassName + ': ' + E.Message;
      end;
    finally
      LObject.Free;
    end;
  finally
    LSession.Free;
  end;
end;

class function TInsertFailureProbe.CallsRecorded(const AError: String): Integer;
var
  LConnection: TRecordingRestConnection;
  LReference: IRESTConnection;
  LSession: TSessionRestFul<TKeyOnly>;
  LObject: TKeyOnly;
begin
  LConnection := TRecordingRestConnection.Create;
  LReference := LConnection;
  LConnection.ExecuteError := AError;
  LSession := TSessionRestFul<TKeyOnly>.Create(LReference, nil);
  try
    LObject := TKeyOnly.Create;
    try
      try
        LSession.Insert(LObject);
      except
        on E: Exception do
          ; // swallowed here on purpose - the transcript is what is asserted
      end;
    finally
      LObject.Free;
    end;
    Result := LConnection.CallCount;
  finally
    LSession.Free;
  end;
end;

{ TTestRestInsertAnswerRobustness }

procedure TTestRestInsertAnswerRobustness.ExecuteRaises_TheNetworkErrorIsWhatReachesTheCaller;
var
  LActual: String;
begin
  // THE CLAUSE #313 SAID IT DID NOT WRITE, AND IT DOES NOT GO RED. Read the
  // header: the frame is dirtied on purpose and the slot is STILL zero, because
  // Insert's own prologue clears it. This clause is therefore a GUARD, not a
  // demonstration - it is what goes red the day the prologue stops clearing,
  // which is the only thing standing between this method and the AV today.
  LActual := TInsertFailureProbe.WhatEscapes(
    'the server refused the connection', cWELLFORMED, True);
  Assert.AreEqual('ERestConnectionFailure: the server refused the connection',
    LActual, False,
    'the failure the CONNECTION raised must be the failure the caller sees - ' +
    'a finally that frees an unassigned local replaces a diagnosable network ' +
    'error with an access violation');
end;

procedure TTestRestInsertAnswerRobustness.ExecuteRaises_TheTranscriptStillProvesThePostWasAttempted;
begin
  // A CONTROL, not a second assertion of the same thing. If Insert had failed
  // before ever reaching Execute the clause above would go green for the wrong
  // reason - no call, no garbage, no finally worth testing.
  Assert.AreEqual(1, TInsertFailureProbe.CallsRecorded('boom'),
    'the probe must actually reach IRESTConnection.Execute, otherwise the ' +
    'failure clause proves nothing about the finally');
end;

procedure TTestRestInsertAnswerRobustness.ExecuteSucceeds_NothingAboutTheHappyPathChanged;
var
  LActual: String;
begin
  // The same probe with no error set: initialising the local must not change
  // what a successful insert does. The body has to be a JSON OBJECT - the
  // double's own default is '[]' and that raises EInvalidCast one layer BELOW
  // this method, in TJanusJson.JSONStringToJSONObject, which is the #314 front
  // and nothing to do with either repair here. That is how the layer-below
  // behaviour written up in the header was measured, incidentally: this clause
  // caught it before it was set right.
  LActual := TInsertFailureProbe.WhatEscapes('', cWELLFORMED, True);
  Assert.AreEqual('<nothing was raised>', LActual, False,
    'an insert whose connection answers normally must still raise nothing');
end;

procedure TTestRestInsertAnswerRobustness.ParamsIsAnObject_IsReadAsNoParams;
begin
  Assert.AreEqual('', TParamsProbe<TKeyOnly>.Render(
    '{"result":"ok","params":{"k1":10}}'), False,
    'a params of the wrong TYPE carries no more information than an absent ' +
    'one and must be answered the same way - not with a raw EInvalidCast');
end;

procedure TTestRestInsertAnswerRobustness.ParamsIsAString_IsReadAsNoParams;
begin
  Assert.AreEqual('', TParamsProbe<TKeyOnly>.Render(
    '{"result":"ok","params":"x"}'), False,
    'a textual params must be read as no params');
end;

procedure TTestRestInsertAnswerRobustness.ParamsIsANumber_IsReadAsNoParams;
begin
  Assert.AreEqual('', TParamsProbe<TKeyOnly>.Render(
    '{"result":"ok","params":7}'), False,
    'a numeric params must be read as no params');
end;

procedure TTestRestInsertAnswerRobustness.ParamsIsNull_IsReadAsNoParams;
begin
  // THE FORM ISSUE #315 DID NOT LIST, and the likeliest of them all: a server
  // with no key to report writes null rather than dropping the key. TJSONNull
  // is a TJSONValue, so it reaches the cast and dies there.
  Assert.AreEqual('', TParamsProbe<TKeyOnly>.Render(
    '{"result":"ok","params":null}'), False,
    'an explicit null params must be read as no params, exactly like an ' +
    'absent one');
end;

procedure TTestRestInsertAnswerRobustness.ParamsIsAnArrayOfNumbers_IsReadAsNoParams;
begin
  Assert.AreEqual('', TParamsProbe<TKeyOnly>.Render(
    '{"result":"ok","params":[10,20]}'), False,
    'an array whose elements are not objects must yield no params - this is ' +
    'the SECOND cast, one loop below the first');
end;

procedure TTestRestInsertAnswerRobustness.ParamsArrayMixesObjectsAndNonObjects_TheGoodOnesStillArrive;
begin
  // WHAT HOLDS `Continue` APART FROM `Exit` ON THE ITEM CAST. The elements are
  // independent - the parser already accepts one object per column - so a bad
  // element says nothing about its siblings. With Exit the answer would be
  // '' and with Continue it is k1=7|k2=8, and the two good objects sit on
  // BOTH SIDES of the bad ones so neither a leading nor a trailing skip can
  // be mistaken for the whole rule.
  Assert.AreEqual('k1=7|k2=8', TParamsProbe<TKeyOnly>.Render(
    '{"result":"ok","params":[10,{"k1":7},"x",{"k2":8},null]}'), False,
    'a malformed element must be skipped, not abort the whole answer - the ' +
    'well-formed siblings still name real columns');
end;

procedure TTestRestInsertAnswerRobustness.ParamsIsAnArrayOfArrays_IsReadAsNoParams;
begin
  Assert.AreEqual('', TParamsProbe<TKeyOnly>.Render(
    '{"result":"ok","params":[["k1",10]]}'), False,
    'a nested ARRAY is not an object either, and TJSONArray is the one type ' +
    'a sloppy guard is most likely to let through');
end;

procedure TTestRestInsertAnswerRobustness.ParamsIsAbsent_StillYieldsNoParams;
begin
  // THE ANSWER THE OLD GUARD DID COVER. It must keep behaving identically:
  // the repair replaces the nil test, it does not narrow it.
  Assert.AreEqual('', TParamsProbe<TKeyOnly>.Render('{"result":"ok"}'), False,
    'an answer with no params element must still yield no params');
end;

procedure TTestRestInsertAnswerRobustness.ParamsIsWellFormed_StillYieldsEveryPair;
begin
  Assert.AreEqual('k1=10|k2=20', TParamsProbe<TKeyOnly>.Render(cWELLFORMED),
    False,
    'the happy path is unchanged - every pair of the one params object still ' +
    'becomes its own param, in order');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRestInsertAnswerRobustness);

end.
