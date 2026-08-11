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

{ @abstract(Janus Framework - the REST client re-reads the aggregate it just
  inserted. Issue #297.)

  WHAT WAS WRONG

  TRESTDataSetAdapter<M>.ApplyInserter POSTs the whole aggregate in ONE call and
  then stamps the client from the answer. The answer - the shipped contract in
  Janus.Server.Resource.pas, cRESOURCEINSERT - names the ROOT's primary key and
  NOTHING ELSE. So after a save the client holds:

    aitroot.root_id  = the key the server generated          (stamped)
    aitmid.root_id   = the same key                          (cascade)
    aitmid.mid_id    = the AutoInc PLACEHOLDER               (never reconciled)
    aitleaf.mid_id   = the AutoInc PLACEHOLDER               (never reconciled)
    aitleaf.leaf_id  = the AutoInc PLACEHOLDER               (never reconciled)

  The SERVER is not wrong: Janus.Server.RestObjectSet repairs the placeholders it
  receives, level by level, before writing. What is wrong is the CLIENT, at
  levels two and three - the operator saves, sees keys that do not exist, and any
  UPDATE or DELETE issued from that screen aims at a row nobody has.

  WHAT THE REPAIR IS

  Re-read. After the POST the root DOES carry the server's key, and a GET on the
  route that already exists brings the whole graph back - the server's
  FillAssociation recurses and only skips Lazy associations. So the client asks
  once more and rewrites its own datasets from the answer. One extra GET per
  inserted root, no contract change, no new endpoint, and all THREE levels are
  reconciled instead of only the second.

  WHY THE FIXTURE ASSERTS ON THE CLIENT AND NOT ON "NOTHING RAISED"

  The double keeps every body it was handed and answers the POST and the GET
  DIFFERENTLY, so each clause can name the number that must appear on the client
  and where that number came from. `-1` is what the client had; 555 and 333 are
  what only the GET could have supplied.

  ONE COMMENT ELSEWHERE IS NOW FALSE AND IS NOT THIS BRANCH'S TO EDIT

  The doc comment over TDataSetBaseAdapter<M>._AutoIncKeyIsGenerated, in
  Janus.DataSet.Base.Adapter, still says of the REST family "nao ha nada depois
  ... e o neto FICA com o placeholder como chave estrangeira". After this issue
  there IS something after - ApplyInserter re-reads the aggregate - so the
  sentence needs its second half rewritten. That file is held by another branch
  while this one is being written, so the correction is reported instead of
  applied; the rest of that comment, which is about the guard refusing to
  PROPAGATE a placeholder, is unaffected and still exact.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Rest.ReReadAfterInsert;

interface

uses
  DB,
  Classes,
  SysUtils,
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
  Janus.Client.Methods,
  Janus.RestFactory.Interfaces,
  Janus.DataSet.Base.Adapter,
  Janus.DataSet.Fields,
  Janus.RestDataSet.ClientDataSet,
  Janus.RestDataSet.FDMemTable,
  Test.Janus.Model.AutoIncTree;

type
  /// <summary> An IRESTConnection that answers the POST and the GET with
  ///  DIFFERENT documents, and remembers both what it was handed and how many
  ///  times each verb was used.
  ///
  ///  WHY A THIRD DOUBLE. TRecordingRestConnection (Common\) has ONE canned
  ///  answer for every verb, which cannot express the thing under test here:
  ///  the POST answers the shipped insert contract - the root key and nothing
  ///  else - and the GET answers the graph. TCapturingRestConnection, in
  ///  Test.Janus.Grandchild.Read, answers '{}' to everything and belongs to
  ///  another fixture. This one is declared here for the same reason that one
  ///  was declared there: two fixtures editing one double is how doubles grow
  ///  answers nobody asked for. </summary>
  TReplayRestConnection = class(TInterfacedObject, IRESTConnection)
  private
    FBodies: TStringList;
    FQueries: TStringList;
    FPending: String;
    FPendingQuery: String;
    FPostCount: Integer;
    FGetCount: Integer;
    FPutCount: Integer;
    FDeleteCount: Integer;
    FPostAnswer: String;
    FPostAnswers: TStringList;
    FGetAnswer: String;
    FGetAnswers: TStringList;
    function DoExecute(const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc): String;
  public
    constructor Create;
    destructor Destroy; override;
    function GetBaseURL: String;
    function GetFullURL: String;
    function GetUsername: String;
    function GetPassword: String;
    function GetMethodGET: String;
    function GetMethodGETId: String;
    function GetMethodGETWhere: String;
    function GetMethodPOST: String;
    function GetMethodPUT: String;
    function GetMethodDELETE: String;
    function GetMethodGETNextPacket: String;
    function GetMethodGETNextPacketWhere: String;
    function GetMethodToken: String;
    function GetServerUse: Boolean;
    procedure SetCommandMonitor(AMonitor: ICommandMonitor);
    procedure SetClassNotServerUse(const Value: Boolean);
    function CommandMonitor: ICommandMonitor;
    function Execute(const AResource, ASubResource: String;
      const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc = nil): String; overload;
    function Execute(const AResource: String;
      const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc = nil): String; overload;
    procedure AddParam(AValue: String);
    procedure AddQueryParam(AValue: String);
    procedure AddBodyParam(AValue: String);
    property Bodies: TStringList read FBodies;
    property Queries: TStringList read FQueries;
    property PostCount: Integer read FPostCount;
    property GetCount: Integer read FGetCount;
    property PutCount: Integer read FPutCount;
    property DeleteCount: Integer read FDeleteCount;
    /// One answer per POST, consumed in order. Empty means "the same answer
    ///  every time" - which is fine for one root and a LIE for two, because two
    ///  roots that come back on the SAME primary key are not two roots.
    procedure QueuePostAnswer(const AAnswer: String);
    /// The same, per GET.
    procedure QueueGetAnswer(const AAnswer: String);
    property PostAnswer: String read FPostAnswer write FPostAnswer;
    property GetAnswer: String read FGetAnswer write FGetAnswer;
  end;

  /// <summary> Classic cracker descendants: ApplyUpdates is protected in both
  ///  concrete REST adapters, and the writing path is the only place the defect
  ///  lives. Same technique Test.Janus.Rest.CascadeGuard uses. </summary>
  TMemApply<M: class, constructor> = class(TRESTFDMemTableAdapter<M>)
  public
    class procedure Apply(const A: TRESTFDMemTableAdapter<M>);
  end;

  TCdsApply<M: class, constructor> = class(TRESTClientDataSetAdapter<M>)
  public
    class procedure Apply(const A: TRESTClientDataSetAdapter<M>);
  end;

  /// <summary> Reaches the event swap of the base adapter, which is what
  ///  decides HOW the re-read may be issued. See
  ///  Design_TheEventSwitchIsASwapAndNotACounter. </summary>
  TEventCrack<M: class, constructor> = class(TDataSetBaseAdapter<M>)
  public
    class procedure Off(const A: TDataSetBaseAdapter<M>);
    class procedure On_(const A: TDataSetBaseAdapter<M>);
  end;

  [TestFixture]
  TTestRestReReadAfterInsert = class
  private
    FRep: TReplayRestConnection;
    FConn: IRESTConnection;
    FRootMem: TFDMemTable;
    FMidMem: TFDMemTable;
    FLeafMem: TFDMemTable;
    FMemRoot: TRESTFDMemTableAdapter<TAitRoot>;
    FMemMid: TRESTFDMemTableAdapter<TAitMid>;
    FMemLeaf: TRESTFDMemTableAdapter<TAitLeaf>;
    FRootCds: TClientDataSet;
    FMidCds: TClientDataSet;
    FLeafCds: TClientDataSet;
    FCdsRoot: TRESTClientDataSetAdapter<TAitRoot>;
    FCdsMid: TRESTClientDataSetAdapter<TAitMid>;
    FCdsLeaf: TRESTClientDataSetAdapter<TAitLeaf>;
    FLoneMem: TFDMemTable;
    FLone: TRESTFDMemTableAdapter<TAitLeaf>;
    FOtherMem: TFDMemTable;
    FOther: TRESTFDMemTableAdapter<TAitNoCascade>;
    procedure BuildMemTree;
    procedure BuildCdsTree;
    procedure SeedRoot(const ADataSet: TDataSet; const ATag: String);
    procedure SeedMid(const ADataSet: TDataSet; const ATag: String);
    procedure SeedLeaf(const ADataSet: TDataSet; const ATag: String);
    procedure SeedTree(const ARoot, AMid, ALeaf: TDataSet);
    procedure RunMem;
    procedure RunCds;
    function KeyOf(const ADataSet: TDataSet; const AColumn: String): Integer;
    function AllQueries: String;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // -----------------------------------------------------------------------
    // Premises. If any of these is red every clause under it measures nothing.
    // -----------------------------------------------------------------------

    /// The aggregate really does leave in ONE POST, and the root really does
    /// take the key the answer named. Green before AND after the repair - it is
    /// the half that already worked.
    [Test]
    procedure Premise_OnePostCarriesTheWholeGraphAndTheRootTakesTheAnsweredKey;
    /// And what left on the wire really did carry the placeholder below the
    /// root - otherwise there would be nothing to reconcile.
    [Test]
    procedure Premise_ThePayloadCarriedThePlaceholderBelowTheRoot;

    // -----------------------------------------------------------------------
    // The defect, in the family that ships it. RED before the repair.
    // -----------------------------------------------------------------------

    /// The middle row's OWN key. Before: -1, the placeholder it was typed with.
    /// After: 555, a number that exists nowhere but in the GET answer.
    [Test]
    procedure ReRead_TheMidRowTakesTheKeyOnlyTheServerKnew;
    /// The grandchild's own key. Level three is the one the reorder option
    /// could never reach.
    [Test]
    procedure ReRead_TheLeafRowTakesTheKeyOnlyTheServerKnew;
    /// And the grandchild's FOREIGN key now points at the middle row the server
    /// actually wrote, instead of at the placeholder.
    [Test]
    procedure ReRead_TheLeafForeignKeyPointsAtTheMidTheServerWrote;
    /// The re-read asks for the row by the key the SERVER returned. Asking by
    /// the placeholder would answer nothing and reconcile nothing.
    [Test]
    procedure ReRead_TheGetAsksByTheKeyTheServerReturned;

    // -----------------------------------------------------------------------
    // The other REST family. Measured, not assumed, before and after.
    // -----------------------------------------------------------------------

    [Test]
    procedure Cds_TheMidRowTakesTheKeyOnlyTheServerKnew;
    [Test]
    procedure Cds_TheLeafRowTakesTheKeyOnlyTheServerKnew;
    [Test]
    procedure Cds_TheLeafForeignKeyPointsAtTheMidTheServerWrote;

    // -----------------------------------------------------------------------
    // What the extra GET costs, and where it must NOT happen.
    // -----------------------------------------------------------------------

    /// A root with no child adapter registered has nothing to reconcile, and
    /// pays nothing.
    [Test]
    procedure Cost_AnAggregateWithNoChildrenCostsNoGet;
    /// Exactly ONE GET for one inserted root - not one per level and not one
    /// per child row.
    [Test]
    procedure Cost_OneInsertedRootCostsExactlyOneGet;
    /// No `params` in the answer means the root's own key is unknown, so there
    /// is nothing to ask BY. The re-read must not fire on a placeholder.
    [Test]
    procedure Cost_WithoutResultParamsNoGetIsIssued;
    /// A child under an association the model did NOT mark CascadeAutoInc had
    /// no key generated for it by this insert, so a placeholder there is the
    /// consumer's own value and reconciles nothing. TAitRoot.others is the only
    /// association in the repository shaped to ask this.
    [Test]
    procedure Cost_APlaceholderUnderANonCascadeAssociationBuysNoGet;
    /// The middle row already carries a key the operator typed, and ONLY the
    /// grandchild is still on the placeholder. Level two answers "nothing wrong
    /// here" and the re-read must fire anyway - which is what makes the walk
    /// recursive instead of one level deep.
    [Test]
    procedure Cost_AStaleGrandchildAloneStillBuysTheGet;
    /// Every level already carries a key of its own. Nothing is stale, so there
    /// is nothing to ask about - the fifth and last case that pays nothing, and
    /// the only one that had no clause of its own.
    [Test]
    procedure Cost_AGraphThatAlreadyCarriesEveryKeyBuysNoGet;
    /// `params` came back, but named no column this row has - so the stamp
    /// wrote nothing and the root is STILL on the placeholder. Gating on
    /// "params arrived" instead of "the key arrived" sent the GET out as
    /// $filter=root_id=-1, a round trip that can only answer somebody else's
    /// row or nothing at all - and it contradicted the message of the clause
    /// right above it, which says the re-read must not fire on a placeholder.
    [Test]
    procedure Cost_ParamsThatNameNoColumnOfThisRowBuyNoGet;

    // -----------------------------------------------------------------------
    // An answer SHALLOWER than the graph the client is holding.
    // -----------------------------------------------------------------------

    /// The answer carries the middle level but not the grandchild - which is
    /// what the shipped server does whenever the association is Lazy, because
    /// TRESTObjectManager.FillAssociation skips exactly those. Applying it
    /// would empty a grandchild dataset the server had JUST written from the
    /// POST, and nothing would ever put those rows back.
    [Test]
    procedure Shallow_AnAnswerMissingTheGrandchildBranchIsRefused;
    /// The same one level up: the answer carries no children at all, while the
    /// client holds children that went out in that very POST.
    [Test]
    procedure Shallow_AnAnswerWithNoChildBranchAtAllIsRefused;
    /// The control that keeps the two above from being a blanket refusal: where
    /// the CLIENT holds nothing, an answer that carries nothing is not shallow -
    /// it agrees, and the levels that ARE there must still be reconciled.
    [Test]
    procedure Shallow_AnAnswerIsNotRefusedForALevelTheClientDoesNotHold;

    // -----------------------------------------------------------------------
    // The design constraint the repair had to obey.
    // -----------------------------------------------------------------------

    /// TWO roots saved in ONE ApplyUpdates are left alone, and that is a
    /// measurement and not a preference. RefreshRecordInternal empties the
    /// child datasets WHOLE, and deleting a middle row still fires its own
    /// CascadeDelete, which empties the grandchild dataset whole as well. With
    /// the re-read allowed to run over two roots, measured at 0a0161f over this
    /// same tree: two middle rows and two leaves went in and
    /// `roots=2 mids=1 leafs=1` came out - the second root's re-read took the
    /// first root's already reconciled children with it. That is WORSE than the
    /// defect, so in this case the client is left exactly as it was before this
    /// fix: placeholders below the root, and not one row lost.
    [Test]
    procedure MultiRoot_TwoRootsSavedTogetherAreLeftAloneAndKeepEveryRow;
    /// The server answers the re-read with NO row - the aggregate was deleted
    /// by somebody else between the POST and the GET, or the resource does not
    /// serve it. Before the guard this raised EArgumentOutOfRange out of
    /// TSessionRestFul<M>.RefreshRecord and aborted the save AFTER the server
    /// had already written.
    [Test]
    procedure Empty_AGetThatFindsNothingLeavesTheClientAsItWas;
    /// The answer is a document that is NOT this row. Rewriting the client from
    /// it would be silent data loss, and it stopped being hypothetical when the
    /// re-read started firing on its own after every insert.
    [Test]
    procedure Foreign_AnAnswerThatIsNotThisRowIsDiscarded;

    /// What a "shout at the end of ApplyInserter" would cost, measured instead
    /// of assumed. ApplyInserter is the FIRST of the three phases
    /// ApplyInternal runs inside one try, and ApplyUpdates clears
    /// FSession.DeleteList in its own finally whatever happened. So an
    /// exception raised at the end of the insert phase does not merely report -
    /// it drops the update and the delete the operator asked for in the same
    /// save, and the delete list is emptied on the way out, so nothing will
    /// re-send them. This clause pins that all three phases really do run in
    /// one call, which is the premise that makes the cost real.
    [Test]
    procedure Detector_AllThreePhasesRunInsideTheSameCall;

    /// TDataSetBaseAdapter<M>.RefreshRecord brackets its work with
    /// DisableDataSetEvents/EnableDataSetEvents, and that pair is a SWAP and
    /// not a counter: a second Disable finds the handlers already nil and
    /// stashes nothing, so the matching Enable puts the ORIGINAL handlers back
    /// while the outer caller still believes they are off. Inside ApplyInternal
    /// that would re-arm DoBeforePost before ApplyUpdater runs, and ApplyUpdater
    /// does not terminate with it armed - the load-bearing note on
    /// DisableDataSetEvents in both REST ApplyInternal overrides. This is why
    /// the re-read calls the SESSION entry point directly instead of the
    /// adapter's RefreshRecord wrapper.
    [Test]
    procedure Design_TheEventSwitchIsASwapAndNotACounter;
  end;

implementation

const
  cROOTKEY = 'root_id';
  cMIDKEY  = 'mid_id';
  cLEAFKEY = 'leaf_id';
  cOTHERKEY = 'other_id';
  cTAG     = 'tag';
  cPLACEHOLDER = -1;
  /// The three numbers the server generated. They are DIFFERENT from each other
  /// and from the placeholder on purpose: a repair that copied the root's key
  /// downwards would look green if they were equal.
  cSRVROOT = 777;
  cSRVMID  = 555;
  cSRVLEAF = 333;
  /// Distinct from every key above AND from the placeholder, so "the row is not
  /// there at all" can never be read as "the row is there with the wrong key".
  cNOROWATALL = -99;

  /// Verbatim shape of Janus.Server.Resource.pas cRESOURCEINSERT, filled the way
  /// TAppResourceBase.ParseInsert fills it: the ROOT primary key and nothing
  /// else.
  cPOSTANSWER =
    '{"result":"Resource aitroot insert command executed successfully",' +
    '"params":[{"root_id":777}]}';
  /// The same answer with the element the client gates on removed.
  cPOSTNOPARAMS =
    '{"result":"Resource aitroot insert command executed successfully"}';
  /// What the GET route already answers: the whole graph, because the server's
  /// FillAssociation recurses and only skips Lazy associations.
  cGETANSWER =
    '[{"root_id":777,"tag":"root","others":[],"mids":[' +
      '{"mid_id":555,"root_id":777,"tag":"mid","leafs":[' +
        '{"leaf_id":333,"mid_id":555,"root_id":777,"tag":"leaf"}]}]}]';

{ TReplayRestConnection }

constructor TReplayRestConnection.Create;
begin
  inherited Create;
  FBodies := TStringList.Create;
  FQueries := TStringList.Create;
  FPostAnswers := TStringList.Create;
  FGetAnswers := TStringList.Create;
  FPostAnswer := cPOSTANSWER;
  FGetAnswer := cGETANSWER;
end;

destructor TReplayRestConnection.Destroy;
begin
  FGetAnswers.Free;
  FPostAnswers.Free;
  FQueries.Free;
  FBodies.Free;
  inherited;
end;

/// The framework pushes body and query from INSIDE the callback, so the
/// transcript can only be closed after it has run. Running it is also what makes
/// the body observable at all.
function TReplayRestConnection.DoExecute(
  const ARequestMethod: TRESTRequestMethodType; const AParams: TProc): String;
begin
  FPending := '';
  FPendingQuery := '';
  if Assigned(AParams) then
    AParams();
  if FPending <> '' then
    FBodies.Add(FPending);
  if FPendingQuery <> '' then
    FQueries.Add(FPendingQuery);
  case ARequestMethod of
    TRESTRequestMethodType.rtPOST:
      begin
        Inc(FPostCount);
        if FPostCount <= FPostAnswers.Count then
          Result := FPostAnswers[FPostCount - 1]
        else
          Result := FPostAnswer;
      end;
    TRESTRequestMethodType.rtGET:
      begin
        Inc(FGetCount);
        if FGetCount <= FGetAnswers.Count then
          Result := FGetAnswers[FGetCount - 1]
        else
          Result := FGetAnswer;
      end;
    TRESTRequestMethodType.rtPUT:
      begin
        Inc(FPutCount);
        Result := '{}';
      end;
    TRESTRequestMethodType.rtDELETE:
      begin
        Inc(FDeleteCount);
        Result := '{}';
      end;
  else
    // An empty JSON OBJECT and never '': TSessionRestFul<M> indexes the answer
    // before parsing it and these projects compile with range checking on.
    Result := '{}';
  end;
end;

function TReplayRestConnection.Execute(const AResource, ASubResource: String;
  const ARequestMethod: TRESTRequestMethodType; const AParams: TProc): String;
begin
  Result := DoExecute(ARequestMethod, AParams);
end;

function TReplayRestConnection.Execute(const AResource: String;
  const ARequestMethod: TRESTRequestMethodType; const AParams: TProc): String;
begin
  Result := DoExecute(ARequestMethod, AParams);
end;

procedure TReplayRestConnection.QueuePostAnswer(const AAnswer: String);
begin
  FPostAnswers.Add(AAnswer);
end;

procedure TReplayRestConnection.QueueGetAnswer(const AAnswer: String);
begin
  FGetAnswers.Add(AAnswer);
end;

procedure TReplayRestConnection.AddBodyParam(AValue: String);
begin
  FPending := FPending + AValue;
end;

procedure TReplayRestConnection.AddQueryParam(AValue: String);
begin
  FPendingQuery := FPendingQuery + AValue;
end;

procedure TReplayRestConnection.AddParam(AValue: String);
begin
end;

function TReplayRestConnection.CommandMonitor: ICommandMonitor;
begin
  Result := nil;
end;

procedure TReplayRestConnection.SetCommandMonitor(AMonitor: ICommandMonitor);
begin
end;

procedure TReplayRestConnection.SetClassNotServerUse(const Value: Boolean);
begin
end;

function TReplayRestConnection.GetBaseURL: String;
begin
  Result := 'http://replayed.local';
end;

function TReplayRestConnection.GetFullURL: String;
begin
  Result := 'http://replayed.local';
end;

function TReplayRestConnection.GetUsername: String;
begin
  Result := '';
end;

function TReplayRestConnection.GetPassword: String;
begin
  Result := '';
end;

function TReplayRestConnection.GetMethodGET: String;
begin
  Result := '';
end;

function TReplayRestConnection.GetMethodGETId: String;
begin
  Result := '';
end;

function TReplayRestConnection.GetMethodGETWhere: String;
begin
  Result := '';
end;

function TReplayRestConnection.GetMethodPOST: String;
begin
  Result := '';
end;

function TReplayRestConnection.GetMethodPUT: String;
begin
  Result := '';
end;

function TReplayRestConnection.GetMethodDELETE: String;
begin
  Result := '';
end;

function TReplayRestConnection.GetMethodGETNextPacket: String;
begin
  Result := '';
end;

function TReplayRestConnection.GetMethodGETNextPacketWhere: String;
begin
  Result := '';
end;

function TReplayRestConnection.GetMethodToken: String;
begin
  Result := '';
end;

function TReplayRestConnection.GetServerUse: Boolean;
begin
  Result := False;
end;

{ TMemApply<M> }

class procedure TMemApply<M>.Apply(const A: TRESTFDMemTableAdapter<M>);
begin
  TMemApply<M>(A).ApplyUpdates(0);
end;

{ TCdsApply<M> }

class procedure TCdsApply<M>.Apply(const A: TRESTClientDataSetAdapter<M>);
begin
  TCdsApply<M>(A).ApplyUpdates(0);
end;

{ TEventCrack<M> }

class procedure TEventCrack<M>.Off(const A: TDataSetBaseAdapter<M>);
begin
  TEventCrack<M>(A).DisableDataSetEvents;
end;

class procedure TEventCrack<M>.On_(const A: TDataSetBaseAdapter<M>);
begin
  TEventCrack<M>(A).EnableDataSetEvents;
end;

{ TTestRestReReadAfterInsert }

procedure TTestRestReReadAfterInsert.Setup;
begin
  FRep := TReplayRestConnection.Create;
  FConn := FRep;
end;

procedure TTestRestReReadAfterInsert.TearDown;
begin
  FreeAndNil(FOther);
  FreeAndNil(FOtherMem);
  FreeAndNil(FLone);
  FreeAndNil(FLoneMem);
  FreeAndNil(FCdsLeaf);
  FreeAndNil(FCdsMid);
  FreeAndNil(FCdsRoot);
  FreeAndNil(FLeafCds);
  FreeAndNil(FMidCds);
  FreeAndNil(FRootCds);
  FreeAndNil(FMemLeaf);
  FreeAndNil(FMemMid);
  FreeAndNil(FMemRoot);
  FreeAndNil(FLeafMem);
  FreeAndNil(FMidMem);
  FreeAndNil(FRootMem);
  FConn := nil;
  FRep := nil;
end;

procedure TTestRestReReadAfterInsert.BuildMemTree;
begin
  FRootMem := TFDMemTable.Create(nil);
  FMemRoot := TRESTFDMemTableAdapter<TAitRoot>.Create(FConn, FRootMem, -1, nil);
  FMidMem := TFDMemTable.Create(nil);
  FMemMid := TRESTFDMemTableAdapter<TAitMid>.Create(FConn, FMidMem, -1, FMemRoot);
  FLeafMem := TFDMemTable.Create(nil);
  FMemLeaf := TRESTFDMemTableAdapter<TAitLeaf>.Create(FConn, FLeafMem, -1, FMemMid);
end;

procedure TTestRestReReadAfterInsert.BuildCdsTree;
begin
  FRootCds := TClientDataSet.Create(nil);
  FCdsRoot := TRESTClientDataSetAdapter<TAitRoot>.Create(FConn, FRootCds, -1, nil);
  FMidCds := TClientDataSet.Create(nil);
  FCdsMid := TRESTClientDataSetAdapter<TAitMid>.Create(FConn, FMidCds, -1, FCdsRoot);
  FLeafCds := TClientDataSet.Create(nil);
  FCdsLeaf := TRESTClientDataSetAdapter<TAitLeaf>.Create(FConn, FLeafCds, -1, FCdsMid);
end;

procedure TTestRestReReadAfterInsert.SeedRoot(const ADataSet: TDataSet;
  const ATag: String);
begin
  ADataSet.Append;
  ADataSet.FieldByName(cROOTKEY).AsInteger := cPLACEHOLDER;
  ADataSet.FieldByName(cTAG).AsString := ATag;
  ADataSet.Post;
end;

procedure TTestRestReReadAfterInsert.SeedMid(const ADataSet: TDataSet;
  const ATag: String);
begin
  ADataSet.Append;
  ADataSet.FieldByName(cMIDKEY).AsInteger := cPLACEHOLDER;
  ADataSet.FieldByName(cROOTKEY).AsInteger := cPLACEHOLDER;
  ADataSet.FieldByName(cTAG).AsString := ATag;
  ADataSet.Post;
end;

procedure TTestRestReReadAfterInsert.SeedLeaf(const ADataSet: TDataSet;
  const ATag: String);
begin
  ADataSet.Append;
  ADataSet.FieldByName(cLEAFKEY).AsInteger := cPLACEHOLDER;
  ADataSet.FieldByName(cMIDKEY).AsInteger := cPLACEHOLDER;
  ADataSet.FieldByName(cROOTKEY).AsInteger := cPLACEHOLDER;
  ADataSet.FieldByName(cTAG).AsString := ATag;
  ADataSet.Post;
end;

/// Every key at the AutoInc placeholder - the state a screen is in when the
/// operator typed a root, a middle row under it and a leaf under that, and
/// pressed save once.
procedure TTestRestReReadAfterInsert.SeedTree(const ARoot, AMid, ALeaf: TDataSet);
begin
  SeedRoot(ARoot, 'root');
  SeedMid(AMid, 'mid');
  SeedLeaf(ALeaf, 'leaf');
end;

procedure TTestRestReReadAfterInsert.RunMem;
begin
  BuildMemTree;
  SeedTree(FRootMem, FMidMem, FLeafMem);
  TMemApply<TAitRoot>.Apply(FMemRoot);
end;

procedure TTestRestReReadAfterInsert.RunCds;
begin
  BuildCdsTree;
  SeedTree(FRootCds, FMidCds, FLeafCds);
  TCdsApply<TAitRoot>.Apply(FCdsRoot);
end;

/// The value of ONE column on the FIRST row, read without moving anybody's
/// cursor by hand.
function TTestRestReReadAfterInsert.KeyOf(const ADataSet: TDataSet;
  const AColumn: String): Integer;
begin
  Result := MaxInt;
  if not ADataSet.Active then
    Exit;
  if ADataSet.IsEmpty then
    Exit(cNOROWATALL);
  ADataSet.First;
  Result := ADataSet.FieldByName(AColumn).AsInteger;
end;

function TTestRestReReadAfterInsert.AllQueries: String;
begin
  Result := FRep.Queries.Text;
end;

procedure TTestRestReReadAfterInsert
  .Premise_OnePostCarriesTheWholeGraphAndTheRootTakesTheAnsweredKey;
begin
  RunMem;
  Assert.AreEqual(1, FRep.PostCount,
    'the whole aggregate must leave in ONE POST - anything else and the ' +
    'clauses below are measuring a different path');
  Assert.IsTrue(Pos('"leafs"', FRep.Bodies.Text) > 0,
    'the POST body must carry all three levels: ' + FRep.Bodies.Text);
  Assert.AreEqual(cSRVROOT, KeyOf(FRootMem, cROOTKEY),
    'the root row takes the key the answer named - this half already worked');
end;

procedure TTestRestReReadAfterInsert
  .Premise_ThePayloadCarriedThePlaceholderBelowTheRoot;
begin
  RunMem;
  Assert.IsTrue(Pos('"mid_id":-1', FRep.Bodies.Text) > 0,
    'the middle row went out on the placeholder, which is what the server ' +
    'repairs on its side and the client never hears about: ' +
    FRep.Bodies.Text);
end;

procedure TTestRestReReadAfterInsert.ReRead_TheMidRowTakesTheKeyOnlyTheServerKnew;
begin
  RunMem;
  Assert.AreEqual(cSRVMID, KeyOf(FMidMem, cMIDKEY),
    'aitmid.mid_id must be the key the server generated. -1 means the client ' +
    'kept the placeholder it typed and the screen is showing a row that does ' +
    'not exist');
end;

procedure TTestRestReReadAfterInsert.ReRead_TheLeafRowTakesTheKeyOnlyTheServerKnew;
begin
  RunMem;
  Assert.AreEqual(cSRVLEAF, KeyOf(FLeafMem, cLEAFKEY),
    'aitleaf.leaf_id must be the key the server generated - level THREE, the ' +
    'one no reordering could ever reach');
end;

procedure TTestRestReReadAfterInsert
  .ReRead_TheLeafForeignKeyPointsAtTheMidTheServerWrote;
begin
  RunMem;
  Assert.AreEqual(cSRVMID, KeyOf(FLeafMem, cMIDKEY),
    'aitleaf.mid_id must name the middle row the server actually wrote');
end;

procedure TTestRestReReadAfterInsert.ReRead_TheGetAsksByTheKeyTheServerReturned;
begin
  RunMem;
  Assert.IsTrue(Pos('root_id=777', AllQueries) > 0,
    'the re-read must ask for the row by the key the SERVER returned; asking ' +
    'by the placeholder would answer nothing. Queries seen: ' + AllQueries);
end;

procedure TTestRestReReadAfterInsert.Cds_TheMidRowTakesTheKeyOnlyTheServerKnew;
begin
  RunCds;
  Assert.AreEqual(cSRVMID, KeyOf(FMidCds, cMIDKEY),
    'the two REST families converge - neither overrides ApplyInserter - and ' +
    'this clause is what keeps that a measurement');
end;

procedure TTestRestReReadAfterInsert.Cds_TheLeafRowTakesTheKeyOnlyTheServerKnew;
begin
  RunCds;
  Assert.AreEqual(cSRVLEAF, KeyOf(FLeafCds, cLEAFKEY),
    'the ClientDataSet family reaches level three too');
end;

procedure TTestRestReReadAfterInsert
  .Cds_TheLeafForeignKeyPointsAtTheMidTheServerWrote;
begin
  RunCds;
  Assert.AreEqual(cSRVMID, KeyOf(FLeafCds, cMIDKEY),
    'the ClientDataSet family reconciles the grandchild foreign key too');
end;

procedure TTestRestReReadAfterInsert.Cost_AnAggregateWithNoChildrenCostsNoGet;
begin
  FRep.PostAnswer :=
    '{"result":"ok","params":[{"leaf_id":333}]}';
  FLoneMem := TFDMemTable.Create(nil);
  FLone := TRESTFDMemTableAdapter<TAitLeaf>.Create(FConn, FLoneMem, -1, nil);
  SeedLeaf(FLoneMem, 'lone');
  TMemApply<TAitLeaf>.Apply(FLone);
  Assert.AreEqual(1, FRep.PostCount, 'the row was still inserted');
  Assert.AreEqual(0, FRep.GetCount,
    'an aggregate with no child adapter has nothing to reconcile and must ' +
    'not pay for a round trip');
end;

procedure TTestRestReReadAfterInsert.Cost_OneInsertedRootCostsExactlyOneGet;
begin
  RunMem;
  Assert.AreEqual(1, FRep.GetCount,
    'ONE extra GET per inserted root - not one per level and not one per ' +
    'child row');
end;

procedure TTestRestReReadAfterInsert.Cost_WithoutResultParamsNoGetIsIssued;
begin
  FRep.PostAnswer := cPOSTNOPARAMS;
  RunMem;
  Assert.AreEqual(cPLACEHOLDER, KeyOf(FRootMem, cROOTKEY),
    'premise of this clause: without params the root is not stamped either');
  Assert.AreEqual(0, FRep.GetCount,
    'with the root key unknown there is nothing to ask BY, so the re-read ' +
    'must not fire on a placeholder');
end;

procedure TTestRestReReadAfterInsert
  .Cost_APlaceholderUnderANonCascadeAssociationBuysNoGet;
begin
  FRootMem := TFDMemTable.Create(nil);
  FMemRoot := TRESTFDMemTableAdapter<TAitRoot>.Create(FConn, FRootMem, -1, nil);
  FOtherMem := TFDMemTable.Create(nil);
  FOther := TRESTFDMemTableAdapter<TAitNoCascade>.Create(FConn, FOtherMem, -1,
              FMemRoot);
  SeedRoot(FRootMem, 'root');
  FOtherMem.Append;
  FOtherMem.FieldByName(cOTHERKEY).AsInteger := cPLACEHOLDER;
  FOtherMem.FieldByName(cROOTKEY).AsInteger := cPLACEHOLDER;
  FOtherMem.Post;
  TMemApply<TAitRoot>.Apply(FMemRoot);
  Assert.AreEqual(1, FRep.PostCount, 'premise: the aggregate was sent');
  Assert.AreEqual(cPLACEHOLDER, KeyOf(FOtherMem, cOTHERKEY),
    'premise: the child really is sitting on the placeholder');
  Assert.AreEqual(0, FRep.GetCount,
    'TAitRoot.others carries CascadeInsert and CascadeUpdate but NOT ' +
    'CascadeAutoInc, so this insert generated no key for it and there is ' +
    'nothing to reconcile - paying for a round trip here would be paying for ' +
    'a value the consumer typed');
end;

procedure TTestRestReReadAfterInsert.Cost_AStaleGrandchildAloneStillBuysTheGet;
begin
  BuildMemTree;
  SeedRoot(FRootMem, 'root');
  // The middle row carries a key the OPERATOR typed. Level two is not stale.
  FMidMem.Append;
  FMidMem.FieldByName(cMIDKEY).AsInteger := cSRVMID;
  FMidMem.FieldByName(cROOTKEY).AsInteger := cPLACEHOLDER;
  FMidMem.FieldByName(cTAG).AsString := 'typed';
  FMidMem.Post;
  SeedLeaf(FLeafMem, 'leaf');
  TMemApply<TAitRoot>.Apply(FMemRoot);
  Assert.AreEqual(1, FRep.GetCount,
    'only the GRANDCHILD is on the placeholder here, so a walk that stopped ' +
    'at the first level would answer "nothing to do" and leave level three ' +
    'wrong forever');
  Assert.AreEqual(cSRVLEAF, KeyOf(FLeafMem, cLEAFKEY),
    'and the grandchild really was reconciled');
end;

procedure TTestRestReReadAfterInsert.Cost_AGraphThatAlreadyCarriesEveryKeyBuysNoGet;
begin
  BuildMemTree;
  SeedRoot(FRootMem, 'root');
  FMidMem.Append;
  FMidMem.FieldByName(cMIDKEY).AsInteger := cSRVMID;
  FMidMem.FieldByName(cROOTKEY).AsInteger := cPLACEHOLDER;
  FMidMem.FieldByName(cTAG).AsString := 'typed';
  FMidMem.Post;
  FLeafMem.Append;
  FLeafMem.FieldByName(cLEAFKEY).AsInteger := cSRVLEAF;
  FLeafMem.FieldByName(cMIDKEY).AsInteger := cSRVMID;
  FLeafMem.FieldByName(cROOTKEY).AsInteger := cPLACEHOLDER;
  FLeafMem.FieldByName(cTAG).AsString := 'typed';
  FLeafMem.Post;
  TMemApply<TAitRoot>.Apply(FMemRoot);
  Assert.AreEqual(1, FRep.PostCount, 'premise: the aggregate was sent');
  Assert.AreEqual(0, FRep.GetCount,
    'both levels below the root already carry a key of their own, so there is ' +
    'no divergence to reconcile and no round trip to pay for');
end;

procedure TTestRestReReadAfterInsert.Cost_ParamsThatNameNoColumnOfThisRowBuyNoGet;
begin
  // A well-formed answer that names a column this entity does not have. The
  // stamp loop skips it - FindField answers nil - so nothing is written and the
  // root comes out of ApplyInserter still on the placeholder.
  FRep.PostAnswer := '{"result":"ok","params":[{"nosuchcolumn":"9"}]}';
  RunMem;
  Assert.AreEqual(cPLACEHOLDER, KeyOf(FRootMem, cROOTKEY),
    'premise of this clause: nothing was stamped, so the root is still on the ' +
    'placeholder even though params did come back');
  Assert.AreEqual(0, FRep.GetCount,
    'the gate has to be "the root key arrived", not "an answer arrived": with ' +
    'the root still at -1 the only filter the re-read could build is ' +
    'root_id=-1');
end;

procedure TTestRestReReadAfterInsert
  .Shallow_AnAnswerMissingTheGrandchildBranchIsRefused;
begin
  // Exactly what the shipped server answers when `leafs` is Lazy: the middle
  // level is there, the grandchild branch is not.
  FRep.GetAnswer :=
    '[{"root_id":777,"tag":"root","others":[],"mids":[' +
      '{"mid_id":555,"root_id":777,"tag":"mid"}]}]';
  RunMem;
  Assert.AreEqual(1, FRep.GetCount, 'premise: the re-read really was issued');
  Assert.AreEqual(1, FLeafMem.RecordCount,
    'the grandchild row went out in the POST and the server wrote it. An ' +
    'answer that does not mention that level is not permission to delete it');
  Assert.AreEqual(1, FMidMem.RecordCount,
    'and the middle row is still there too');
  Assert.AreEqual(cPLACEHOLDER, KeyOf(FMidMem, cMIDKEY),
    'the answer was refused WHOLE rather than applied in part: a half-applied ' +
    'graph is a third state nobody can reason about');
end;

procedure TTestRestReReadAfterInsert
  .Shallow_AnAnswerWithNoChildBranchAtAllIsRefused;
begin
  FRep.GetAnswer := '[{"root_id":777,"tag":"root","others":[],"mids":[]}]';
  RunMem;
  Assert.AreEqual(1, FRep.GetCount, 'premise: the re-read really was issued');
  Assert.AreEqual(1, FMidMem.RecordCount,
    'the middle row went out in the POST and the server wrote it');
  Assert.AreEqual(1, FLeafMem.RecordCount,
    'and so did the grandchild - emptying the middle level takes it along ' +
    'through its own CascadeDelete, so this clause loses two rows if the ' +
    'refusal is missing');
end;

procedure TTestRestReReadAfterInsert
  .Shallow_AnAnswerIsNotRefusedForALevelTheClientDoesNotHold;
begin
  // Root and one middle row, no grandchild anywhere - not in the client, not
  // in the answer.
  BuildMemTree;
  SeedRoot(FRootMem, 'root');
  SeedMid(FMidMem, 'mid');
  FRep.GetAnswer :=
    '[{"root_id":777,"tag":"root","others":[],"mids":[' +
      '{"mid_id":555,"root_id":777,"tag":"mid"}]}]';
  TMemApply<TAitRoot>.Apply(FMemRoot);
  Assert.AreEqual(1, FRep.GetCount, 'premise: the re-read really was issued');
  Assert.AreEqual(cSRVMID, KeyOf(FMidMem, cMIDKEY),
    'the client holds no grandchild, so an answer with no grandchild branch ' +
    'agrees with it and must be applied - a refusal that fired here would ' +
    'turn the whole repair off for every two-level aggregate');
end;

procedure TTestRestReReadAfterInsert
  .MultiRoot_TwoRootsSavedTogetherAreLeftAloneAndKeepEveryRow;
begin
  // TWO ROOTS MEANS TWO KEYS. Answering both POSTs with the same primary key
  // would make the two roots indistinguishable, and any row loss measured over
  // that could be blamed on the double instead of on the code.
  FRep.QueuePostAnswer('{"result":"ok","params":[{"root_id":777}]}');
  FRep.QueuePostAnswer('{"result":"ok","params":[{"root_id":888}]}');
  FRep.QueueGetAnswer(
    '[{"root_id":777,"tag":"rootA","others":[],"mids":[' +
      '{"mid_id":555,"root_id":777,"tag":"midA","leafs":[' +
        '{"leaf_id":333,"mid_id":555,"root_id":777,"tag":"leafA"}]}]}]');
  FRep.QueueGetAnswer(
    '[{"root_id":888,"tag":"rootB","others":[],"mids":[' +
      '{"mid_id":666,"root_id":888,"tag":"midB","leafs":[' +
        '{"leaf_id":444,"mid_id":666,"root_id":888,"tag":"leafB"}]}]}]');
  BuildMemTree;
  SeedRoot(FRootMem, 'rootA');
  SeedMid(FMidMem, 'midA');
  SeedLeaf(FLeafMem, 'leafA');
  SeedRoot(FRootMem, 'rootB');
  SeedMid(FMidMem, 'midB');
  SeedLeaf(FLeafMem, 'leafB');
  TMemApply<TAitRoot>.Apply(FMemRoot);
  Assert.AreEqual(2, FRep.PostCount,
    'premise: both roots really were sent');
  Assert.AreEqual(0, FRep.GetCount,
    'no re-read fires when more than one root was saved in the same call - ' +
    'the second one would empty the first one child datasets');
  Assert.AreEqual(2, FMidMem.RecordCount,
    'both middle rows must survive. Allowing the re-read here measured ' +
    'mids=1 at 0a0161f: rows the operator typed simply disappeared');
  Assert.AreEqual(2, FLeafMem.RecordCount,
    'and both grandchild rows with them');
end;

procedure TTestRestReReadAfterInsert
  .Empty_AGetThatFindsNothingLeavesTheClientAsItWas;
begin
  FRep.GetAnswer := '[]';
  RunMem;
  Assert.AreEqual(1, FRep.GetCount, 'premise: the re-read really was issued');
  Assert.AreEqual(cSRVROOT, KeyOf(FRootMem, cROOTKEY),
    'the root keeps the key the POST answered');
  Assert.AreEqual(1, FMidMem.RecordCount,
    'and the child row the operator typed is still there - an answer with no ' +
    'row must not cost the client its own data, and must not raise: the ' +
    'server has already written by this point');
end;

procedure TTestRestReReadAfterInsert.Foreign_AnAnswerThatIsNotThisRowIsDiscarded;
begin
  // A well-formed aggregate, but for ANOTHER root.
  FRep.GetAnswer :=
    '[{"root_id":901,"tag":"someone else","others":[],"mids":[' +
      '{"mid_id":902,"root_id":901,"tag":"theirs","leafs":[]}]}]';
  RunMem;
  Assert.AreEqual(1, FRep.GetCount, 'premise: the re-read really was issued');
  Assert.AreEqual(cSRVROOT, KeyOf(FRootMem, cROOTKEY),
    'the client keeps ITS row - 901 would mean the answer overwrote a row it ' +
    'was never about');
  Assert.AreEqual(cPLACEHOLDER, KeyOf(FMidMem, cMIDKEY),
    'and its own child, still on the placeholder, rather than the stranger ' +
    'row 902');
end;

procedure TTestRestReReadAfterInsert.Detector_AllThreePhasesRunInsideTheSameCall;
begin
  BuildMemTree;
  // A row the operator DELETED. First, so that the cascade its removal fires
  // cannot take the rows the clauses below need.
  SeedRoot(FRootMem, 'gone');
  FRootMem.Delete;
  // A row the operator EDITED. Clearing the internal marker by hand is what
  // turns a row that was typed into a row that was LOADED and then changed -
  // DoBeforePost promotes -1 to dsEdit and leaves anything else alone.
  SeedRoot(FRootMem, 'kept');
  FRootMem.Edit;
  FRootMem.FieldByName(cInternalField).AsInteger := -1;
  FRootMem.FieldByName(cTAG).AsString := 'changed';
  FRootMem.Post;
  // And the row the operator INSERTED, with a child under it so that its graph
  // is the stale one this issue is about.
  SeedRoot(FRootMem, 'new');
  SeedMid(FMidMem, 'mid');
  TMemApply<TAitRoot>.Apply(FMemRoot);
  Assert.AreEqual(1, FRep.PostCount, 'the insert phase ran');
  Assert.AreEqual(1, FRep.PutCount,
    'the UPDATE phase ran in the same call - it is the first thing an ' +
    'exception raised at the end of the insert phase would take away');
  Assert.AreEqual(1, FRep.DeleteCount,
    'and so did the DELETE phase. Worse than skipped: ApplyUpdates clears ' +
    'FSession.DeleteList in its own finally whatever happened, so a row ' +
    'dropped here is gone from the client AND was never sent');
end;

procedure TTestRestReReadAfterInsert.Design_TheEventSwitchIsASwapAndNotACounter;
var
  LWasOff: Boolean;
begin
  BuildMemTree;
  TEventCrack<TAitRoot>.Off(FMemRoot);
  LWasOff := not Assigned(FRootMem.BeforePost);
  // The nested pair a call to RefreshRecord would add from inside ApplyInternal
  TEventCrack<TAitRoot>.Off(FMemRoot);
  TEventCrack<TAitRoot>.On_(FMemRoot);
  Assert.IsTrue(LWasOff,
    'premise: the first Disable really did unhook DoBeforePost');
  Assert.IsTrue(Assigned(FRootMem.BeforePost),
    'a nested Disable/Enable pair puts the ORIGINAL handler back while the ' +
    'outer caller still believes events are off. That is why the re-read may ' +
    'not go through the adapter RefreshRecord wrapper: inside ApplyInternal ' +
    'it would re-arm DoBeforePost and ApplyUpdater would not terminate');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRestReReadAfterInsert);

end.
