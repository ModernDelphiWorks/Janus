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

{ @abstract(Janus Framework - TSessionRestFul<M>.Insert survives a FAILING
  call. Issue #313.)

  WHAT THE METHOD DOES WHEN THE HAPPY PATH DOES NOT HAPPEN. The sibling half of
  that question - an answer whose `params` is valid JSON of the wrong shape -
  is issue #315 and lands in this same fixture in the next commit, because it
  lands in this same method.

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
  statement of Insert, and the only thing that runs there is Insert's own
  prologue. Insert declares four String locals, and the Win32 compiler clears
  the whole local area of such a frame rather than the managed slots alone.
  Widening the scribble from 2KB to 64KB changed nothing, which is what rules
  out coverage as the explanation.

  The class of defect is real all the same, and that was measured too rather
  than argued: the SAME local list written by hand as a plain routine outside a
  generic class is NOT cleared, and it dies with
  "EAccessViolation ... Read of address CDCDCDCD" while an Exception carrying
  'boom' was unwinding - the network error replaced by an access violation,
  exactly the damage #313 describes. Same commit, same compiler.

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
  Test.Janus.Model.KeyOnly;

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

initialization
  TDUnitX.RegisterTestFixture(TTestRestInsertAnswerRobustness);

end.
