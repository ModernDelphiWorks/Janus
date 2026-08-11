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

{ @abstract(Janus Framework - the insert answer is parsed PAIR by PAIR, so a
  COMPOSITE primary key arrives whole. Issue #300.)

  WHAT WAS WRONG

  The server emits the whole primary key inside ONE JSON object - see
  Janus.Server.Resource.pas, TAppResourceBase.ParseInsert, which walks
  LPrimaryKey.Columns appending `"name":value,` into a single string and then
  formats that string into the SINGLE object cRESOURCEINSERT reserves inside
  its `params` array. One object, N pairs.

  TSessionRestFul<M>.Insert used to read that answer with the object as the
  unit: `with FResultParams.Add as TParam do` sat OUTSIDE the pair loop, so ONE
  TParam was created per OBJECT and its Name and Value were OVERWRITTEN once per
  pair. The surviving param was the LAST pair; every earlier column of the key
  was discarded with no exception and no log.

  WHO READS THAT LIST - THE POPULATION, ENUMERATED

  `git grep -l ResultParams` over the whole repository, run at d4d38f7, returns
  TEN files. Only TWO of them READ the contents of the list this parser fills:

    Janus.RestDataSet.Adapter.pas:241-246 - TRESTDataSetAdapter<M>.ApplyInserter,
      the ONE production consumer;
    this fixture's own TParamsProbe<M>.Render, added by #300.

  The other eight do not read it:

    Janus.Session.Abstract.pas          owns the field, exposes the accessor
    Janus.Session.RESTful.pas           the writer - this parser
    Janus.Server.RestObjectSet.Session  an FResultParams of its OWN, on the
                                        SERVER side; a different list that
                                        never meets this one
    Janus.Tests.RESTfulDriver.dpr       project reference
    Janus.Tests.RESTfulDriver.dproj     project reference
    Test.Janus.AutoInc.Distribution     a comment
    Test.Janus.Rest.ReReadAfterInsert   a clause NAME
    Test.Janus.Rest.CompositeKeyReReadGate  prose only

  So "two readers" only adds up if the probe this issue added is counted. In
  Source/ there is exactly ONE, and it does not depend on one-param-per-object:
  it iterates 0..Count-1, calls FindField on each param name and skips the nil.
  More params simply mean more columns found.

  That one consumer stamps the dataset from ResultParams - so a REST entity
  with a composite key came back from an insert with one key column filled and
  the rest still on the AutoInc placeholder, and any later UPDATE or DELETE
  aimed at a key nobody has.

  WHAT THE REPAIR WIDENS, DECLARED

  The same class of change as the empty-object one declared at
  AnEmptyParamsObject, and a bigger one. ApplyInserter's guard is
  FindField <> nil, not "is this a key column". Before the repair one params
  OBJECT yielded one TParam, so at most ONE column of the row could be written
  per object; now EVERY pair is written, key column or not.

  Measured at 0f13601 with a throwaway probe over TCkRoot and NO child adapter
  - so the #297 re-read cannot fire and write over the row - driving one params
  object carrying the three pairs "tag":"fromserver", "ck1":7 and "ck2":9, in
  that order:

    with the repair        : GetCount 0, tag=fromserver, ck1=7,  ck2=9
    with the hunk reverted : GetCount 0, tag=root,       ck1=-1, ck2=9

  Three writes where there was one, and one of the three lands on a column that
  is not part of the key. What keeps that narrow today is that the SERVER walks
  LPrimaryKey.Columns only (Janus.Server.Resource.pas:304-307). That bound
  lives in the server and is written down nowhere on the client side, which is
  why it is written down here.

  WHY THE ASSERTION IS THE WHOLE LIST AND NOT THE COUNT

  The count alone goes green with the WRONG param: an object carrying the two
  pairs "k1":10 and "k2":20 produced ONE param before the fix and the fixed
  parser must produce TWO, but a fixture that only counted would also accept
  two params both named k2. So every clause
  renders the ENTIRE list - `name=value` per param, in order, joined by '|' -
  and compares it for exact equality. Order is part of the assertion because the
  server writes the key columns in mapping order and the consumer stamps them in
  the order it receives.

  AreEqual is called with ignoreCase = FALSE on every clause. DUnitX defaults
  that flag to True (Assert.fIgnoreCaseDefault) and a COLUMN NAME is not
  case noise - issue #293.

  AND THAT CLAIM USED TO BE HALF TRUE, WHICH IS WORSE THAN FALSE

  A flag that says "case matters" is only worth what the CORPUS lets it catch.
  Every column name this fixture drove was lower case - k1, k2, cmk1..cmk7,
  and ck1, ck2, tag next door - so the flags could only ever catch a defect
  that RAISED the case. Measured at 3ba57dd, on the one line that builds the
  name:

    Name := UpperCase(...)  killed 7 clauses
    Name := LowerCase(...)  killed NONE - 102 total, 0 failed

  Not a defect of the repair: TFields.FindField and TParams.ParamByName are
  both case-insensitive, so production would not notice either. It is the
  DECLARED CONTRACT being stronger than the fixture guarding it, which is the
  thing this whole issue is about.

  MixedCaseColumnNames_EachNameArrivesVerbatim closes it with one answer
  spelling one column K1 and the other k2, so a mutation in either direction
  has to break one of the two. Re-measured with that clause in place:
  LowerCase now fails 1 - and that 1 is this clause, nothing else - while
  UpperCase fails 8 instead of 7.

  THE PARSER DOES NOT CONSULT THE MAPPING, AND THAT IS MEASURED

  Insert reads the answer with System.JSON and never asks the explorer anything,
  so the entity behind the probe is not load-bearing for the parse. Rather than
  assert that from reading, TheSameAnswerParsesTheSameThroughAnUnrelatedEntity
  drives the SAME body through two entities whose keys have nothing in common -
  TKeyOnly, whose key IS the two Integer columns k1 and k2, and TStrMaster,
  whose key is one String column of another name entirely - and requires the
  same rendering out of both.

  That is also why the MIXED-TYPE clause carries seven pairs of seven types in
  the ANSWER while the entity behind it stays TKeyOnly. TCompMaster is the
  repository entity that owns seven columns of seven types, and it cannot be
  the probe: it declares cmk3 as TGUID, and TJanusJson.ObjectToJsonString -
  which Insert calls on the way OUT, before any answer exists - raises
  `Erro no SetValue() da propriedade [cmk3]` on it. Measured on top of 03595a6:
  with TCompMaster as the probe entity two clauses of this fixture came back
  ERRORED, not failed. That is a defect of the JSON layer, not of this parser, and it is
  reported rather than repaired here.

  WHAT THIS FIXTURE DOES NOT FIX, AND MEASURES ANYWAY

  ParseInsert writes the value with VarToStr and NO quoting, so a key column of
  a textual type produces a body that is not JSON at all. That is a defect of
  the SERVER contract, out of scope for #300, which the issue explicitly parks.
  ServerWritesTextualKeyValuesUnquotedAndTheWholeAnswerIsThenLost pins what the
  client does with such a body today, so the day the server is fixed this clause
  is the one that says so.

  ANCHORS INTO THE SUITE ARE BY METHOD, NEVER BY `file:line` - a clause anchor
  must not rot the day a line moves. Citations INTO SOURCE are by `file:line`,
  and each was re-read at the commit named beside it.
}

unit Test.Janus.Rest.ResultParamsCompositeKey;

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
  Janus.RestDataSet.Adapter,
  Janus.Session.RESTful,
  Test.Janus.RestConnection.Double,
  Test.Janus.Model.KeyOnly,
  Test.Janus.Model.RestLazyKeys;

type
  /// <summary> Drives TSessionRestFul&lt;M&gt;.Insert against a canned answer
  ///  and renders the resulting ResultParams as one comparable string.
  ///
  ///  The session owns ResultParams and frees it, so the list cannot outlive
  ///  the session - the rendering happens while the session is still alive and
  ///  the STRING is what leaves. An empty list renders as '' and a single
  ///  nameless param renders as '=', which keeps those two apart.
  ///
  ///  WHAT THIS RENDERING CANNOT SEE, AND IT IS A BLIND SPOT THIS PROBE MADE.
  ///  Render calls VarToStr on the value, so a param carrying the INTEGER 10
  ///  and a param carrying the STRING '10' render identically and nothing in
  ///  the suite can tell them apart. Measured at 3ba57dd: replacing the
  ///  parser's `Value := ...JsonValue.Value` with
  ///  `Value := VarToStr(...JsonValue.Value)` survives at 102/0/0.
  ///
  ///  That survivor is not the parser's - it is the price of comparing whole
  ///  lists as ONE string, which is what buys every other clause here its
  ///  precision about NAMES and ORDER. It is written down because the next
  ///  probe that renders through VarToStr will inherit the same blind spot
  ///  without noticing. Closing it needs an assertion on VarType, not another
  ///  string comparison, and this issue does not need one: the one production
  ///  consumer assigns LParam.Value straight into a TField. </summary>
  TParamsProbe<M: class, constructor> = class
  public
    class function Render(const AAnswer: String): String;
  end;

  [TestFixture]
  TTestRestResultParamsCompositeKey = class
  public
    [Test]
    procedure CompositeKeyOfTwoIntegers_BothColumnsSurvive;
    [Test]
    procedure MixedCaseColumnNames_EachNameArrivesVerbatim;
    [Test]
    procedure CompositeKeyOfSevenMixedTypes_AllSevenSurviveInOrder;
    [Test]
    procedure SingleColumnKey_IsUnchanged;
    [Test]
    procedure OneObjectPerColumn_StillYieldsOneParamPerColumn;
    [Test]
    procedure TwoObjectsCarryingTwoPairsEach_YieldFourParams;
    [Test]
    procedure DuplicateNamesAliasOntoTheFirst_AnRtlPropertyOfTParams;
    [Test]
    procedure TheSameAnswerParsesTheSameThroughAnUnrelatedEntity;
    [Test]
    procedure AnAnswerWithNoParamsElement_YieldsNoParams;
    [Test]
    procedure AnEmptyParamsObject_ContributesNoParam;
    [Test]
    procedure ServerWritesTextualKeyValuesUnquotedAndTheWholeAnswerIsThenLost;
  end;

implementation

const
  /// The literal shape of Janus.Server.Resource.pas cRESOURCEINSERT. The
  /// constant is private to TAppResourceBase, so it is spelled here rather than
  /// imported; what matters to this fixture is the ONE-OBJECT-N-PAIRS shape,
  /// which is what ParseInsert builds.
  cINSERTANSWER =
    '{"result":"Resource keyonly insert command executed successfully", ' +
    '"params":[{%s}]}';

{ TParamsProbe<M> }

class function TParamsProbe<M>.Render(const AAnswer: String): String;
var
  LConnection: TRecordingRestConnection;
  LReference: IRESTConnection;
  LSession: TSessionRestFul<M>;
  LObject: M;
  LFor: Integer;
begin
  Result := '';
  LConnection := TRecordingRestConnection.Create;
  // The interface reference is what keeps the double alive; the object
  // variable is only there to reach the Response setter.
  LReference := LConnection;
  LConnection.Response := AAnswer;
  LSession := TSessionRestFul<M>.Create(LReference, nil);
  try
    LObject := M.Create;
    try
      LSession.Insert(LObject);
    finally
      LObject.Free;
    end;
    for LFor := 0 to LSession.ResultParams.Count - 1 do
    begin
      if LFor > 0 then
        Result := Result + '|';
      Result := Result + LSession.ResultParams.Items[LFor].Name + '=' +
                VarToStr(LSession.ResultParams.Items[LFor].Value);
    end;
  finally
    LSession.Free;
  end;
end;

{ TTestRestResultParamsCompositeKey }

procedure TTestRestResultParamsCompositeKey.CompositeKeyOfTwoIntegers_BothColumnsSurvive;
var
  LActual: String;
begin
  LActual := TParamsProbe<TKeyOnly>.Render(
    Format(cINSERTANSWER, ['"k1":10,"k2":20']));
  Assert.AreEqual('k1=10|k2=20', LActual, False,
    'the two columns of the composite key must arrive as TWO params, in the ' +
    'order the server wrote them - one param per PAIR, not one per OBJECT');
end;

procedure TTestRestResultParamsCompositeKey.MixedCaseColumnNames_EachNameArrivesVerbatim;
var
  LActual: String;
begin
  // THE CASE CLAUSE, AND IT IS DELIBERATELY MIXED. Every other answer in this
  // fixture spells its columns in lower case - k1, k2, cmk1..cmk7, ck1, ck2,
  // tag - so a corpus of lower-case names can only catch a mutation that
  // RAISES the case. Measured at 3ba57dd: UpperCase on the name killed 7
  // clauses, and LowerCase on the same line killed NONE, 102/0/0. The
  // ignoreCase = False flags were doing half the job they claim.
  //
  // ONE pair of each case is what closes it. K1 comes back K1 and k2 comes
  // back k2, so LowerCase breaks the first and UpperCase breaks the second,
  // and neither can pass by being a no-op on this corpus.
  //
  // The two names differ by more than case on purpose. TParams.FindParam
  // (Data.DB.pas:11311-11321) matches with AnsiSameText, so K1 and k1 would
  // be one param wearing two slots - the aliasing pinned by
  // DuplicateNamesAliasOntoTheFirst_AnRtlPropertyOfTParams, which would
  // confound this clause instead of measuring it.
  LActual := TParamsProbe<TKeyOnly>.Render(
    Format(cINSERTANSWER, ['"K1":10,"k2":20']));
  Assert.AreEqual('K1=10|k2=20', LActual, False,
    'a column name arrives VERBATIM, in the case the server wrote it - and ' +
    'that is a claim about BOTH directions, which is why one name is upper ' +
    'and the other lower');
end;

procedure TTestRestResultParamsCompositeKey.CompositeKeyOfSevenMixedTypes_AllSevenSurviveInOrder;
var
  LActual: String;
begin
  // Seven columns of seven types - the shape TCompMaster carries, spelled with
  // its own column names, driven through TKeyOnly because TCompMaster cannot
  // be serialized on the way out (see the unit header). Textual values are
  // quoted here because that is what a well-formed body looks like; what the
  // SERVER writes today is the subject of the last clause of this fixture.
  LActual := TParamsProbe<TKeyOnly>.Render(
    Format(cINSERTANSWER, ['"cmk1":10,' +
                           '"cmk2":"AB C",' +
                           '"cmk3":"{7B7B7B7B-1111-2222-3333-444444444444}",' +
                           '"cmk4":"2026-08-11",' +
                           '"cmk5":1234.56,' +
                           '"cmk6":"2026-08-11T09:08:07",' +
                           '"cmk7":"09:08:07"']));
  Assert.AreEqual('cmk1=10|' +
                  'cmk2=AB C|' +
                  'cmk3={7B7B7B7B-1111-2222-3333-444444444444}|' +
                  'cmk4=2026-08-11|' +
                  'cmk5=1234.56|' +
                  'cmk6=2026-08-11T09:08:07|' +
                  'cmk7=09:08:07', LActual, False,
    'a composite key of MIXED types must arrive whole: seven pairs in, seven ' +
    'params out, each keeping its own name and its own value');
end;

procedure TTestRestResultParamsCompositeKey.SingleColumnKey_IsUnchanged;
var
  LActual: String;
begin
  LActual := TParamsProbe<TKeyOnly>.Render(Format(cINSERTANSWER, ['"k1":777']));
  Assert.AreEqual('k1=777', LActual, False,
    'the single-column key is the shape every shipped REST test drives - it ' +
    'must come out exactly as before');
end;

procedure TTestRestResultParamsCompositeKey.OneObjectPerColumn_StillYieldsOneParamPerColumn;
var
  LActual: String;
begin
  // The alternative contract the issue parks - one object per column. The
  // parser must read it too, and the outer loop is what does it.
  LActual := TParamsProbe<TKeyOnly>.Render(
    '{"result":"ok","params":[{"k1":10},{"k2":20}]}');
  Assert.AreEqual('k1=10|k2=20', LActual, False,
    'one pair per object is the other shape the answer can take, and the ' +
    'OUTER loop is what reads it');
end;

procedure TTestRestResultParamsCompositeKey.TwoObjectsCarryingTwoPairsEach_YieldFourParams;
var
  LActual: String;
begin
  // Both loops at once: dropping either one leaves two params instead of four,
  // and the rendering names which two were lost. The four names are DISTINCT
  // on purpose - see DuplicateNamesAliasOntoTheFirst_AnRtlPropertyOfTParams.
  LActual := TParamsProbe<TKeyOnly>.Render(
    '{"result":"ok","params":[{"k1":10,"k2":20},{"k3":30,"k4":40}]}');
  Assert.AreEqual('k1=10|k2=20|k3=30|k4=40', LActual, False,
    'the objects are walked in order and each object contributes all of its ' +
    'pairs - neither loop may swallow the other');
end;

procedure TTestRestResultParamsCompositeKey.DuplicateNamesAliasOntoTheFirst_AnRtlPropertyOfTParams;
var
  LActual: String;
begin
  // NOT a property of this parser and NOT changed by #300. TParams.GetItem
  // (Data.DB.pas:11219-11223) returns Item.ParamRef; TParam.ParamRef
  // (Data.DB.pas:11589-11595) resolves a named param to
  // TParams(Collection).ParamByName(Name), which is FindParam
  // (Data.DB.pas:11311-11321) returning the FIRST param of that name; and
  // TParams.Update (Data.DB.pas:11214-11215), which runs on every Add, walks
  // Items[i] - GetItem again - and clears FParamRef. TParam.SetAsVariant
  // (Data.DB.pas:12580-12581) writes THROUGH ParamRef as well.
  //
  // THOSE FIVE ARE CITED AS THE ROUTINES ON THE PATH, NOT AS A DERIVATION.
  // Each was re-read in Studio 37 and says what is written above. Walking
  // them by hand does NOT visibly produce the table below, and nothing here
  // claims it does - what follows is a MEASURED RULE, and it is stated as one.
  //
  // WHAT IS MEASURED. This body was originally written into the clause above
  // expecting k1=10|k2=20|k1=30|k2=40, and it came back as
  // k1=10|k2=20|k1=10|k2=40 - re-measured at 0f13601, where this clause is
  // green and the whole RESTfulDriver suite closes 102/0. It is load-bearing:
  // with the parser hunk reverted at that same commit it dies as k2=20|k2=40.
  //
  // AND THE ASYMMETRY IS POSITIONAL, NOT PER-COLUMN. The second k2 keeps its
  // 40 while the second k1 loses its 30, which no reading of ParamRef alone
  // explains - so it was measured, at 0f13601, with a throwaway console
  // program driving TParams through the very same calls this loop makes:
  //
  //   k1,k2,k1,k2       -> k1=10|k2=20|k1=10|k2=40   slots 0 1 0 3
  //   k1,k2,k1,k2,k3    -> k1=10|k2=20|k1=10|k2=20|k3=50   slots 0 1 0 1 4
  //   k1,k2,k1          -> k1=10|k2=20|k1=30         slots 0 1 2
  //
  // A duplicated slot keeps the value written into it until the NEXT Add; from
  // then on it resolves to the first slot of its name and the value it was
  // given stops being reachable. The LAST slot is never re-pointed, because no
  // Add follows it - which is the whole of the asymmetry. So "the second value
  // is simply not there to be found" is FALSE: it is written, and it is still
  // readable when it happens to be the last pair. The exact ordering inside
  // TParams.Update was NOT instrumented; what is stated here is the observed
  // behaviour, not a claim about the RTL's internal sequence.
  //
  // It costs nothing today: the answer ParseInsert builds is ONE object whose
  // pairs are the columns of one primary key, and a key has no repeated column.
  LActual := TParamsProbe<TKeyOnly>.Render(
    '{"result":"ok","params":[{"k1":10,"k2":20},{"k1":30,"k2":40}]}');
  Assert.AreEqual('k1=10|k2=20|k1=10|k2=40', LActual, False,
    'four slots, but the two repeated names alias onto the first param of ' +
    'each name - an RTL property of TParams, measured, not this parser');
end;

procedure TTestRestResultParamsCompositeKey.TheSameAnswerParsesTheSameThroughAnUnrelatedEntity;
const
  cBODY = '{"result":"ok","params":[{"k1":10,"k2":20}]}';
var
  LThroughKeyOnly: String;
  LThroughStrMaster: String;
begin
  LThroughKeyOnly := TParamsProbe<TKeyOnly>.Render(cBODY);
  LThroughStrMaster := TParamsProbe<TStrMaster>.Render(cBODY);
  Assert.AreEqual('k1=10|k2=20', LThroughKeyOnly, False,
    'TKeyOnly - the entity whose key IS k1;k2');
  Assert.AreEqual(LThroughKeyOnly, LThroughStrMaster, False,
    'the parser reads the ANSWER, never the mapping: an entity with a ' +
    'single-column STRING key and column names of its own must parse the same ' +
    'body into the same params');
end;

procedure TTestRestResultParamsCompositeKey.AnAnswerWithNoParamsElement_YieldsNoParams;
var
  LActual: String;
begin
  LActual := TParamsProbe<TKeyOnly>.Render(
    '{"result":"Resource keyonly insert command executed successfully"}');
  Assert.AreEqual('', LActual, False,
    'no "params" element means no params - the early Exit, which the ' +
    'consumer reads as Count = 0');
end;

procedure TTestRestResultParamsCompositeKey.AnEmptyParamsObject_ContributesNoParam;
var
  LActual: String;
begin
  // A BEHAVIOUR CHANGE, DECLARED. With the object as the unit of iteration an
  // empty object still produced one nameless param, so ResultParams.Count came
  // out 1 and TRESTDataSetAdapter<M>.ApplyInserter entered the block its
  // `if FSession.ResultParams.Count > 0` guards for an answer that named
  // nothing. With the PAIR as the unit it produces none and that block is
  // skipped.
  //
  // AND THAT BLOCK IS BIGGER THAN THE STAMPING LOOP. In the shape this branch
  // leaves behind, the guard is Janus.RestDataSet.Adapter.pas:239 and what it
  // wraps runs to :298 - three things, not one: the stamping loop at :241-247,
  // SetAutoIncValueChilds at :249, and the #297 stale-bookmark gate at
  // :295-297. Skipping on `{}` skips all three, not just the stamping.
  //
  // MEASURED: this clause is green at 0f13601 alongside the whole 102/0 suite,
  // so nothing in the shipped suite notices the wider skip. REASONED, and
  // labelled as such: the nameless param the old parser produced named no
  // column, and no field carries an empty FieldName, so FindField('') could
  // only answer nil and the loop could only write nothing - which leaves the
  // other two members of the block with nothing new to act on. That argument
  // was NOT put to a measurement of its own. ParseInsert cannot emit `{}`
  // anyway - it raises when the entity has no primary key - so this is a
  // degenerate body, not a shape of the shipped contract.
  LActual := TParamsProbe<TKeyOnly>.Render('{"result":"ok","params":[{}]}');
  Assert.AreEqual('', LActual, False,
    'an object with no pairs contributes no param - a param with no name ' +
    'names no column and only made the consumer believe an answer arrived');
end;

procedure TTestRestResultParamsCompositeKey.ServerWritesTextualKeyValuesUnquotedAndTheWholeAnswerIsThenLost;
var
  LActual: String;
begin
  // NOT FIXED BY #300, and pinned so it cannot rot silently: ParseInsert
  // appends VarToStr(value) with no quoting, so a String, Guid, Date or Time
  // key column yields a body that ParseJSONValue rejects outright. The client
  // then Exits at the nil check and loses the WHOLE key, not merely all but
  // the last column.
  LActual := TParamsProbe<TKeyOnly>.Render(
    Format(cINSERTANSWER, ['"k1":10,"k2":AB C']));
  Assert.AreEqual('', LActual, False,
    'a body the server can really produce for a textual key column is not ' +
    'JSON, and the client answers it with silence - a SERVER-side defect ' +
    'this issue parks, measured here so it is not forgotten');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRestResultParamsCompositeKey);

end.
