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

  The one consumer is TRESTDataSetAdapter<M>.ApplyInserter, which stamps the
  dataset from ResultParams - so a REST entity with a composite key came back
  from an insert with one key column filled and the rest still on the AutoInc
  placeholder, and any later UPDATE or DELETE aimed at a key nobody has.

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

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
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
  ///  nameless param renders as '=', which keeps those two apart. </summary>
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
  // (Data.DB.pas:11219-11223) returns Item.ParamRef, and TParam.ParamRef
  // (Data.DB.pas:11589-11595) resolves a named param to
  // TParams(Collection).ParamByName(Name) - the FIRST param of that name. So
  // two params sharing a name are one param wearing two slots, on write and on
  // read alike, and the second value is simply not there to be found.
  //
  // MEASURED, not reasoned: this body was originally written into the clause
  // above expecting k1=10|k2=20|k1=30|k2=40, and it came back as
  // k1=10|k2=20|k1=10|k2=40. It is pinned here so the next reader does not
  // mistake the aliasing for a parser defect.
  // ANCHOR REMOVED - PENDING RE-MEASUREMENT. The commit this rendering was
  // stamped with was orphaned by a rebase and is not reachable from this
  // branch; its post-rebase twin carries a DIFFERENT tree and does not stand
  // in for it. The figure is unanchored until measured again at this HEAD.
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
  // out 1 and TRESTDataSetAdapter<M>.ApplyInserter entered its stamping block
  // for an answer that named nothing. With the PAIR as the unit it produces
  // none and the block is skipped. ParseInsert cannot emit `{}` - it raises
  // when the entity has no primary key - so this is a degenerate body, not a
  // shape of the shipped contract.
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
