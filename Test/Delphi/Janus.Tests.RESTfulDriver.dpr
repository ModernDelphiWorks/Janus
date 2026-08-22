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

{ @abstract(Janus Framework - the DRIVERRESTFUL test configuration.)

  WHY THIS PROJECT EXISTS

  Janus.inc ships the DRIVERRESTFUL define COMMENTED OUT. Every REST adapter
  the framework builds is selected inside IFDEF DRIVERRESTFUL blocks, and
  none of the other four test projects define it, so the whole ON branch was
  compiled by nothing. This project is that branch: the directive is carried by
  Janus.Tests.RESTfulDriver.dproj (DCC_Define), exactly the way every RESTful
  Example under Examples\Delphi\RESTful carries it.

  WHAT THE DIRECTIVE PULLS IN THAT NOTHING ELSE COMPILES

    Janus.Manager.DataSet      - eight conditional sites; no .dcu from any of
                                 the four existing test binaries, in EITHER
                                 branch
    Janus.Manager.ObjectSet    - five conditional sites; likewise
    Janus.RestObjectSet.Adapter- one conditional site; likewise
    Janus.Client.Base / Janus.Client / Janus.Client.Horse /
    Janus.Client.RestDriver.Horse / Janus.Client.RestHorse.Factory /
    Janus.Client.RestException / Janus.Client.Consts
                               - the concrete Horse client chain; likewise

  THE DIRECTIVE CANNOT BE DROPPED SILENTLY

  Each of the three test units under Unit\RESTful\Test.Janus.Driver.* opens
  with an IFNDEF DRIVERRESTFUL / MESSAGE FATAL pair. Removing the define from
  the .dproj does not produce a smaller green suite - it produces a build
  error.

  AND ONE THING HERE IS NOT ABOUT THE DIRECTIVE AT ALL

  Janus.Client.DataSnap and Janus.Client.WS are in the uses below, and NOT
  because DRIVERRESTFUL selects them - they are unconditional. They are here
  because a compile tripwire at 0546a51 showed that NO test project read either
  of them: inside Source the two client families are reachable from nothing but
  each other. An earlier version of this paragraph said "in either branch of any
  define" - only Debug/Win32 was ever built, here or by the review, so that
  generalisation was not measured and is withdrawn. The positive control - the same
  tripwire in Janus.Client.Horse - failed this project and only this one, so the
  probe was not blind. Three shipped Examples DO name them - JanusFireDAC.dpr
  under Examples\Delphi\Datasnap\Client, and the two forms under
  Examples\Delphi\RESTful\RESTFul via Driver - but those are standalone
  programs the suite never builds. This project is where they were brought in,
  because it is already the one that exists to compile a concrete client chain.
  Issue #323.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

program Janus.Tests.RESTfulDriver;

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}
{$STRONGLINKTYPES ON}

uses
  System.Classes,
  System.SysUtils,
  System.IOUtils,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ENDIF}
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  Janus.Test.Runner in 'Common\Janus.Test.Runner.pas',
  /// Models
  MetaDbDiff.Mapping.Register,
  Test.Janus.Model.AsymKey in 'Common\Test.Janus.Model.AsymKey.pas',
  /// The three level model with a to-ONE root - issue #312 needs that shape
  Test.Janus.Model.AsymTree in 'Common\Test.Janus.Model.AsymTree.pas',
  Test.Janus.Model.AutoIncTree in 'Common\Test.Janus.Model.AutoIncTree.pas',
  /// A root whose key comes from the CLIENT over a child whose key comes from
  /// the SERVER - the only shape in the repository that reaches the third door
  /// of ApplyInserter, where ExistSequence answers False. Issue #305.
  Test.Janus.Model.ClientKeyRoot in 'Common\Test.Janus.Model.ClientKeyRoot.pas',
  /// The canonical COMPOSITE PRIMARY KEY entity - both columns are the key.
  /// Issue #300.
  Test.Janus.Model.KeyOnly in 'Common\Test.Janus.Model.KeyOnly.pas',
  /// A COMPOSITE AUTOINC key over a cascading child - the only shape in which
  /// the #297 gate can be partially satisfied. Issue #300.
  Test.Janus.Model.CompositeAutoInc in 'Common\Test.Janus.Model.CompositeAutoInc.pas',
  /// String key and composite key - the two association shapes the REST lazy
  /// filter had no model for. Issue #251.
  Test.Janus.Model.RestLazyKeys in 'Common\Test.Janus.Model.RestLazyKeys.pas',
  /// A key declared NotInc and with NO [Sequence] - the one entity family in
  /// the test tree for which ExistSequence answers False. Issue #301.
  Test.Janus.Model.NotIncKey in 'Common\Test.Janus.Model.NotIncKey.pas',
  /// A flat entity that COUNTS ITS OWN DESTRUCTIONS - how the leak of an object
  /// the session builds, hands over and the caller then drops is observed, the
  /// dataset being blind to it. Issue #328.
  Test.Janus.Model.OpenIdRow in 'Common\Test.Janus.Model.OpenIdRow.pas',
  /// A GENERATED key whose property is a Nullable - the shape all eight models
  /// under Examples\Delphi\Data\Varios Niveis de Dados carry, and the one the
  /// #301 reader had no arm for. Issue #317.
  Test.Janus.Model.NullableKey in 'Common\Test.Janus.Model.NullableKey.pas',
  /// Doubles
  Test.Janus.RestConnection.Double in 'Common\Test.Janus.RestConnection.Double.pas',
  /// Tests - the DRIVERRESTFUL branch
  Test.Janus.Driver.ManagerDataSet in 'Unit\RESTful\Test.Janus.Driver.ManagerDataSet.pas',
  Test.Janus.Driver.ManagerObjectSet in 'Unit\RESTful\Test.Janus.Driver.ManagerObjectSet.pas',
  Test.Janus.Driver.HorseClientChain in 'Unit\RESTful\Test.Janus.Driver.HorseClientChain.pas',
  /// The one-resource Execute overload, and the ARGUMENT ORDER it hands down -
  /// which only the Horse chain can observe. Issue #211.
  Test.Janus.Driver.HorseExecuteOverload in 'Unit\RESTful\Test.Janus.Driver.HorseExecuteOverload.pas',
  /// Clearing the child datasets from wherever the cursor is - issue #222
  Test.Janus.Rest.ClearChilds in 'Unit\RESTful\Test.Janus.Rest.ClearChilds.pas',
  /// The cascade guard that decides WHICH child gets cleared - issue #235
  Test.Janus.Rest.CascadeGuard in 'Unit\RESTful\Test.Janus.Rest.CascadeGuard.pas',
  /// The lazy load and the lazy unload of the REST family - issue #251
  Test.Janus.Rest.Lazy in 'Unit\RESTful\Test.Janus.Rest.Lazy.pas',
  /// The same LoadLazy over the other concrete adapter of the family, whose
  /// OpenWhereInternal is a separate override - issue #251
  Test.Janus.Rest.Lazy.Cds in 'Unit\RESTful\Test.Janus.Rest.Lazy.Cds.pas',
  /// The client re-reads the aggregate it has just inserted, because the insert
  /// answer names the ROOT key and nothing below it - issue #297
  Test.Janus.Rest.ReReadAfterInsert in 'Unit\RESTful\Test.Janus.Rest.ReReadAfterInsert.pas',
  /// A COMPOSITE primary key lost every column but the last on the way back
  /// from an insert, because the answer was parsed one param per OBJECT
  /// instead of one per PAIR - issue #300
  Test.Janus.Rest.ResultParamsCompositeKey in 'Unit\RESTful\Test.Janus.Rest.ResultParamsCompositeKey.pas',
  /// What that repair does to the gate the #297 re-read stands behind - the
  /// only place where more params changes WHEN a round trip is bought
  Test.Janus.Rest.CompositeKeyReReadGate in 'Unit\RESTful\Test.Janus.Rest.CompositeKeyReReadGate.pas',
  /// The OBJECT half of the same family: the insert answer carries the key the
  /// server generated, and TRESTObjectSetAdapter never read it - issue #301
  /// Whether the client reconciles the key of EVERY row the insert wrote - issue #312
  Test.Janus.Rest.GraphInsertEntities in 'Unit\RESTful\Test.Janus.Rest.GraphInsertEntities.pas',
  Test.Janus.Rest.ObjectSetInsertKey in 'Unit\RESTful\Test.Janus.Rest.ObjectSetInsertKey.pas',
  /// What Insert does when the happy path does NOT happen: a connection that
  /// raises instead of answering, whose finally then freed a local that was
  /// never assigned - issue #313; and an answer whose `params` is valid JSON of
  /// the wrong shape, which the two hard casts turned into a raw EInvalidCast -
  /// issue #315
  Test.Janus.Rest.InsertAnswerRobustness in 'Unit\RESTful\Test.Janus.Rest.InsertAnswerRobustness.pas',
  /// "Open by id" over the REST ClientDataSet family: the answered row has to
  /// reach the dataset and the object it arrived in has to be released - the
  /// method discarded the result of Find and used a local it never assigned -
  /// issue #328
  Test.Janus.Rest.OpenIdPopulates in 'Unit\RESTful\Test.Janus.Rest.OpenIdPopulates.pas',
  /// The DataSnap and WS client chains. Measured with a compile tripwire at
  /// 0546a51: NO test project read either of them, and the positive control
  /// - the same tripwire in Janus.Client.Horse - failed this project and only
  /// this one. They are named here so the repair of issue #323 is compiled at
  /// all, and the fixture below drives both of them over a live loan server.
  Janus.Client.DataSnap,
  Janus.Client.WS,
  /// The shape of the answer the six sites read, and what Execute does with
  /// it - the WS one dropped it on the floor - issue #323
  Test.Janus.Client.ResponseShape in 'Unit\RESTful\Test.Janus.Client.ResponseShape.pas',
  /// WHICH VERB the DataSnap client puts on the wire, which server method that
  /// verb reaches, and what its PUT answers. The POST/PUT swap is a
  /// COMPENSATION for Embarcadero's own inverted prefix rule - HTTP PUT
  /// reaches accept* and HTTP POST reaches update* - and this fixture pins it,
  /// so the next reader does not "straighten" it and thereby swap insert with
  /// update against every DataSnap server. It also closes the half of #338
  /// that IS a defect: DoPUT never assigned Result. And it closes the reader's
  /// half of the complaint where the reader meets it - the 'Method : ' line of
  /// EJanusRESTException now reads 'POST (wire: PUT)' WHERE the label and the
  /// wire diverge, and plain where they do not, with the events still carrying
  /// the operation unannotated - issue #338
  Test.Janus.Client.DataSnapVerb in 'Unit\RESTful\Test.Janus.Client.DataSnapVerb.pas',
  /// The same two questions asked of the OTHER client family, whose answers
  /// are different ones. TRESTClientWS speaks plain REST - its constructor
  /// leaves the API context EMPTY, so no prefix dispatcher stands in front of
  /// it and its verbs go out STRAIGHT. #338 measured, and this fixture
  /// re-measured, that nothing pinned them: swapping the verb of DoPOST or of
  /// DoPUT killed ZERO clauses, because the #323 stub answers every verb
  /// alike. It also closes the half of #338 deliberately left open on this
  /// side - TRESTClientWS.DoPUT never assigned Result either, and Execute
  /// called it as a statement - against the contract measured on THIS class,
  /// which has two arms where the DataSnap one has one
  Test.Janus.Client.WSVerb in 'Unit\RESTful\Test.Janus.Client.WSVerb.pas',
  /// The half of the #301 reader a Nullable key never reached: a `Nullable<T>`
  /// property is tkRecord, so the case fell off its end and the object came out
  /// of an insert still holding the AutoInc placeholder - which the cascade
  /// then handed down. Includes the two questions #317 left open: a TEXTUAL key
  /// generated by a sequence, and the SCOPE of the arm - issue #317
  Test.Janus.Rest.NullableKeyReconciliation in 'Unit\RESTful\Test.Janus.Rest.NullableKeyReconciliation.pas';

begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
  Exit;
{$ENDIF}
  System.ExitCode := TJanusTestRunner.Execute('.janus_restful_write_probe.tmp', True);
end.
