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

{ @abstract(Janus Framework - TManagerDataSet.AddAdapter<T, M> on the LOCAL
  branch, the one Janus.inc ships.)

  WHY THIS FIXTURE EXISTS

  AddAdapter<T, M> had exactly one fixture in the repository -
  Test.Janus.Driver.ManagerDataSet - and it belongs to Janus.Tests.RESTfulDriver,
  which compiles the unit with DRIVERRESTFUL DEFINED. The method's body selects
  its adapter inside nested IFDEFs, so that fixture measures the REST leg and
  only the REST leg. The leg every consumer gets from a stock Janus.inc -
  TFDMemTableAdapter<T>, no directive - was reached by nothing: measured on the
  base this was written against, Janus.Tests.Units named AddAdapter once, in
  Test.Janus.Reopen.Lazy.BuildManager, and that call is the SINGLE-parameter
  overload with no master at all.

  So this fixture is not a second opinion on the REST one. It is the first
  measurement of the branch the ORM actually ships, and it is written against
  the maintainer's rule that the client/server path is measured first and
  always.

  WHAT THE LOCAL LINK IS, CONCRETELY

  The REST adapters bind a child to its master with MasterSource/MasterFields
  on the dataset. The local family does not: TDataSetAdapter<M> has no such
  wiring. What AddAdapter<T, M> produces locally is an OBJECT link -
  TDataSetBaseAdapter<M>.SetMasterObject files the child adapter in the
  master adapter's FMasterObject dictionary under the child's class name, and
  points the child's FOwnerMasterObject back at the master. That dictionary is
  the whole mechanism: TDataSetAdapter<M>.OpenDataSetChilds returns on its
  first lines when FMasterObject.Count is zero, so a master that was never
  linked opens alone and no child is ever queried. Both ends of that link are
  asserted below, and then the consequence is asserted end to end.

  THE THREE SILENT EXITS

  AddAdapter<T, M> returns without a word on three conditions: T already
  registered, M not registered, and the master entry being nil. The first two
  are pinned below AS THEY SHIP. Nothing here argues they are right; whether
  they should raise is the maintainer's call, not this fixture's. What the
  fixture removes is the possibility of the behaviour changing by accident.

  One measurement is worth carrying into that decision, because it was not
  what this fixture expected. `Silent` describes the CALL, not the session.
  TManagerDataSet.DataSet<T> is `Result := Resolver<T>.FOrmDataSet` and
  TManagerDataSet.Resolver<T> returns nil for a class it never registered, so
  the next call a consumer makes on the detail dereferences nil - measured on
  Win32 as EAccessViolation, pinned by
  MasterMissing_TheNextCallOnTheDetailDereferencesNil. The silence lasts
  exactly one statement, and then the caller gets a fault with nothing in it
  naming the master it misspelled.

  THE THIRD EXIT IS NOT COVERED AND CANNOT HONESTLY BE

  `if LMaster = nil then Exit` needs a nil VALUE filed under a key the
  repository CONTAINS. FRepository is private, every Add to it in
  Janus.Manager.DataSet passes a freshly constructed adapter, and nothing in
  the public surface can store nil. Reaching it would mean writing nil into the
  dictionary through RTTI - a state the shipped code cannot produce - and the
  test would then be measuring the fixture. Declared, not covered.

  IT RUNS IN BOTH SHIPPED CONFIGURATIONS

  The dataset handed to AddAdapter and the adapter class name expected back
  both follow the directive Janus.inc selects, through TMemDataSet and
  cLOCALADAPTER below. Hard-coding TFDMemTable made every test here error
  with `Is not TClientDataSet type` under the ClientDataSet configuration -
  which reads as that configuration being broken, when what was broken was
  the fixture. Measured in both, see #223.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

{ The dataset choice lives in Janus.inc, so a fixture that has to follow it
  must read it. Without this include the IFDEFs below are simply false and
  the fixture silently hard-codes one half of the choice again. }
{$INCLUDE ..\..\..\..\Source\Janus.inc}

unit Test.Janus.Manager.AddAdapter;

interface

{$IFDEF DRIVERRESTFUL}
  {$MESSAGE FATAL 'This unit measures the NON-REST leg of TManagerDataSet.AddAdapter. With DRIVERRESTFUL defined it would silently assert the REST leg instead, which Test.Janus.Driver.ManagerDataSet already covers.'}
{$ENDIF}

uses
  DB,
  Rtti,
  Classes,
  SysUtils,
  Generics.Collections,
  DUnitX.TestFramework,
  {$IFDEF USECLIENTDATASET}
  DBClient,
  {$ENDIF}
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
  Janus.DataSet.Base.Adapter,
  Janus.DataSet.Consts,
  Janus.Manager.DataSet,
  Test.Janus.Cursor.Double,
  Test.Janus.Model.AsymKey,
  Test.Janus.Model.KeyOnly;

type
  /// <summary> The in-memory dataset THIS BUILD is configured to accept.
  ///  Janus.inc exposes that choice as one of two directives and
  ///  TManagerDataSet.ResolverDataSetType rejects anything else, so a fixture
  ///  that hard-coded one of them could only run in one of the two shipped
  ///  configurations - and in the other one every test here errored with
  ///  `Is not TClientDataSet type` before reaching a single assertion. Both
  ///  configurations are supported and both were run. </summary>
  {$IFDEF USECLIENTDATASET}
  TMemDataSet = TClientDataSet;
  {$ELSE}
  TMemDataSet = TFDMemTable;
  {$ENDIF}

  /// <summary> The usual protected-access descendant. FOwnerMasterObject and
  ///  FMasterObject are the two ends of the link AddAdapter<T, M> installs and
  ///  both are protected. The probe adds no field of its own, so it is the
  ///  same object seen through a wider door. </summary>
  TAdapterProbe<M: class, constructor> = class(TDataSetBaseAdapter<M>)
  public
    class function OwnerOf(const AAdapter: TObject): TObject;
    class function ChildCountOf(const AAdapter: TObject): Integer;
    class function ChildUnder(const AAdapter: TObject;
      const AKey: String): TObject;
    /// <summary> Reaches the protected SetMasterObject, which is the ONLY
    ///  writer of FOwnerMasterObject besides the `:= nil` of Destroy, and
    ///  therefore the only place the value can be refused. </summary>
    class procedure LinkTo(const AAdapter, AMaster: TObject);
    /// <summary> Reads the master's current entity THROUGH a cast typed with
    ///  the DETAIL's type argument - the exact shape of the two lines issue
    ///  #255 names. </summary>
    class function OwnerCurrentClassName(const AAdapter: TObject): String;
  end;

  /// <summary> NOT an adapter, and padded on purpose. The cast in
  ///  SetMasterObject reads FMasterObject at a fixed offset out of whatever it
  ///  is handed; with this object the offset lands inside the padding, which
  ///  Delphi zeroes on construction, so the misread yields nil instead of
  ///  arbitrary heap. That keeps the measurement of the UNGUARDED behaviour
  ///  deterministic - a nil dereference - instead of undefined. The size is
  ///  asserted against the adapter's InstanceSize in the test that uses it, so
  ///  the premise cannot rot in silence. </summary>
  TNotAnAdapter = class
  private
    FPad: array[0..63] of Pointer;
  end;

  [TestFixture]
  TTestManagerAddAdapter = class
  private
    FRows: TRowsConnection;
    FConn: IDBConnection;
    FManager: TManagerDataSet;
    FMasterMem: TMemDataSet;
    FChildMem: TMemDataSet;
    FSpareMem: TMemDataSet;
    function Repository: TDictionary<String, TObject>;
    function AdapterOf(const AClassName: String): TObject;
    procedure BuildMasterOnly;
    procedure BuildMasterDetail;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// EXTREME 1 - the master IS registered. Both ends of the object link the
    /// local branch depends on: the child adapter must point back at the
    /// master adapter, and it must be the very object filed under the MASTER
    /// class name, not a copy and not some other adapter.
    [Test]
    procedure MasterPresent_TheChildPointsAtTheAdapterFiledUnderTheMasterClass;

    /// ...and the other end of the same link: the master adapter must carry
    /// the child in its FMasterObject dictionary, keyed by the CHILD class
    /// name. TDataSetAdapter<M>.OpenDataSetChilds reads exactly that.
    [Test]
    procedure MasterPresent_TheMasterCarriesTheChildUnderTheChildClassName;

    /// The consequence, end to end and without touching a private field:
    /// opening the master must open the child, which can only happen through
    /// the link above. Asserted against the connection - a second cursor is
    /// handed out and the child dataset comes back active.
    [Test]
    procedure MasterPresent_OpeningTheMasterOpensTheChildThroughThatLink;

    /// The class the manager put in the repository for BOTH ends. Behaviour
    /// can be argued about, a class name cannot: without DRIVERRESTFUL the
    /// adapter is the LOCAL one for the configured dataset -
    /// TFDMemTableAdapter or TClientDataSetAdapter - and never its
    /// TREST... namesake.
    [Test]
    procedure Selection_BothEndsAreTheLocalAdapterClass;

    /// EXTREME 2 - the master is NOT registered. The shipped behaviour is a
    /// silent return: no exception, and nothing at all in the repository.
    [Test]
    procedure MasterMissing_ItExitsSilentlyAndRegistersNothing;

    /// ...and what the caller meets NEXT, which is the part worth knowing
    /// before anyone decides whether the silent exit is acceptable. It is not
    /// a nil dataset. TManagerDataSet.DataSet<T> is
    /// `Result := Resolver<T>.FOrmDataSet` and TManagerDataSet.Resolver<T>
    /// returns nil for a class it never registered, so the very next call a
    /// consumer would make dereferences nil. Measured, on Win32, as
    /// EAccessViolation. This asserts the consequence as it ships; it does not
    /// say the consequence is acceptable.
    [Test]
    procedure MasterMissing_TheNextCallOnTheDetailDereferencesNil;

    /// DEGENERATE - the detail is already registered. The second call must be
    /// a no-op, and `no-op` has to be proved on the DATASET: an overwrite
    /// would also raise nothing.
    [Test]
    procedure DetailTwice_TheSecondCallIsANoOpAndTheFirstDataSetSurvives;

    /// The issue that opened this work says the hard cast the method used to
    /// carry `works by coincidence of layout: the fields it touches sit at the
    /// same offsets in both instantiations`. This measures the layout claim
    /// directly - and it does NOT confirm `coincidence`. Every field of
    /// TDataSetBaseAdapter<M> is a pointer or a fixed-size scalar for every M
    /// the constraint `M: class, constructor` admits, so the offsets agree by
    /// construction and no instantiation with a different layout can be built
    /// to disprove it. What the cast really risked was never the offsets: it
    /// was the TYPE ARGUMENT, which drives RTTI lookups and object creation
    /// and is wrong regardless of where the fields sit.
    [Test]
    procedure Layout_EveryInstantiationOfTheBaseAdapterAgreesOnEveryOffset;

    /// ISSUE #255, THE HALF THAT BITES. SetMasterObject takes a TObject and
    /// hard-casts it, so nothing asked the value whether it was an adapter at
    /// all. Handed something else it read FMasterObject out of the middle of
    /// that object and called Add on the result. Measured, with the guard
    /// removed and this same padded intruder: `EAccessViolation|Access
    /// violation at address 014E23E2 in module 'Janus.Tests.Units.exe'
    /// (offset 9D23E2). Read of address 00000008` - the module address moves
    /// with the build, the `00000008` does not, and neither half names the
    /// detail or what was passed. This asserts the WHOLE replacement message,
    /// so a swap of the two names in the Format call is a failure and not a
    /// coincidence.
    [Test]
    procedure MasterNotAnAdapter_IsRefusedByNameInsteadOfFaulting;

    /// ...and the refusal must NOT be `AValue is TDataSetBaseAdapter<M>`,
    /// which is the obvious way to write it and is wrong: the master is by
    /// definition of ANOTHER instantiation, and two instantiations of one
    /// generic class are unrelated types. That naive guard turns every
    /// master-detail link in the framework into an exception; this test is
    /// what catches it.
    [Test]
    procedure Guard_TheMasterOfAnotherInstantiationIsStillAccepted;

    /// The mechanism the guard hangs on, pinned in BOTH directions. A rename
    /// cannot rot it in silence - the class the manager actually builds does
    /// NOT carry the base-adapter name itself, it is reached by walking
    /// ClassParent - and neither can the CONTENT of the string: the expected
    /// value is derived from the name Delphi really emits and compared with
    /// Source's own cBaseAdapterPrefix, not with a copy kept here. Shortening
    /// the constant to `TDataSetBase` still recognises every adapter and still
    /// passes 505 of 505 without that comparison (measured at b5a664c; the
    /// suite has grown since - re-run the mutation rather than scaling the
    /// number); the trailing `<` is the only thing separating `an
    /// instantiation of this template` from `any class whose name starts
    /// like that`.
    [Test]
    procedure Recognition_TheAncestorNameIsWhatTheGuardHangsOn;

    /// ISSUE #255, THE HALF THAT DOES NOT BITE, measured rather than assumed.
    /// The cast carries the DETAIL's type argument, and the question is
    /// whether that changes what comes back. It does not: FCurrentInternal is
    /// read as a reference and every question asked of it - ClassName,
    /// ClassType - is answered by the object's own VMT pointer, never by
    /// TypeInfo(M). Read through a cast that says TAsymChild, the object
    /// answers TAsymMaster. That is why _GetMasterValues hands
    /// GetMappingAssociation the master's real class.
    [Test]
    procedure Recovery_TheObjectBehindTheDetailTypedCastIsTheMasterEntity;

    /// WHERE the refusal sits, and it is not cosmetic. SetMasterObject removes
    /// the child from its current master BEFORE it would file it under the new
    /// one. A guard placed AFTER that block still refuses the bad value, still
    /// raises the same message, and still passes every other test in this
    /// unit - measured at b5a664c, 505 of 505 green with the raise moved
    /// down; the suite has grown since, so read the figure as the size of
    /// that run and re-run the mutation rather than scaling it - while
    /// leaving a call that FAILED having already unlinked the child: the
    /// master no longer lists it and FOwnerMasterObject still points at that
    /// master. This asserts the whole link is exactly what it was before the
    /// failed call, which is the only assertion that can tell the two
    /// placements apart.
    [Test]
    procedure Refusal_LeavesTheLegitimateLinkExactlyAsItWas;
  end;

implementation

const
  cMASTERCLASS = 'TAsymMaster';
  cCHILDCLASS  = 'TAsymChild';
  {$IFDEF USECLIENTDATASET}
  cLOCALADAPTER = 'TClientDataSetAdapter';
  {$ELSE}
  cLOCALADAPTER = 'TFDMemTableAdapter';
  {$ENDIF}

/// Turns a Boolean into a word, so an ordered signature string reads as a
/// sentence and a flipped answer is visible in the failure text instead of
/// hiding behind True/False.
function Yn(const AValue: Boolean): String;
begin
  if AValue then
    Result := 'yes'
  else
    Result := 'no';
end;

{ TAdapterProbe<M> }

class function TAdapterProbe<M>.OwnerOf(const AAdapter: TObject): TObject;
begin
  Result := TAdapterProbe<M>(AAdapter).FOwnerMasterObject;
end;

class function TAdapterProbe<M>.ChildCountOf(const AAdapter: TObject): Integer;
begin
  Result := TAdapterProbe<M>(AAdapter).FMasterObject.Count;
end;

class function TAdapterProbe<M>.ChildUnder(const AAdapter: TObject;
  const AKey: String): TObject;
var
  LChild: TDataSetBaseAdapter<M>;
begin
  Result := nil;
  if TAdapterProbe<M>(AAdapter).FMasterObject.TryGetValue(AKey, LChild) then
    Result := LChild;
end;

class procedure TAdapterProbe<M>.LinkTo(const AAdapter, AMaster: TObject);
begin
  TAdapterProbe<M>(AAdapter).SetMasterObject(AMaster);
end;

class function TAdapterProbe<M>.OwnerCurrentClassName(
  const AAdapter: TObject): String;
var
  LOwner: TObject;
begin
  LOwner := TAdapterProbe<M>(AAdapter).FOwnerMasterObject;
  if LOwner = nil then
    Exit('');
  Result := TAdapterProbe<M>(LOwner).FCurrentInternal.ClassName;
end;

{ TTestManagerAddAdapter }

/// A cursor wide enough for BOTH entities. Janus.Bind reads every field of the
/// TARGET dataset out of the cursor BY NAME, so a column the cursor has not got
/// is `Field <name> not found` the moment either side opens.
procedure TTestManagerAddAdapter.Setup;
begin
  FRows := TRowsConnection.Create(dnSQLite, 2,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add('mkey', ftInteger);
      ADataSet.FieldDefs.Add('mtag', ftString, 20);
      ADataSet.FieldDefs.Add('ckey', ftInteger);
      ADataSet.FieldDefs.Add('cparent', ftInteger);
      ADataSet.FieldDefs.Add('ctag', ftString, 20);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName('mkey').AsInteger := 1 + AIndex;
      ADataSet.FieldByName('mtag').AsString := 'M' + IntToStr(AIndex);
      ADataSet.FieldByName('ckey').AsInteger := 10 + AIndex;
      ADataSet.FieldByName('cparent').AsInteger := 1 + AIndex;
      ADataSet.FieldByName('ctag').AsString := 'C' + IntToStr(AIndex);
    end,
    'manager-addadapter');
  FConn := FRows;
  FManager := TManagerDataSet.Create(FConn);
end;

procedure TTestManagerAddAdapter.TearDown;
begin
  FreeAndNil(FManager);
  FreeAndNil(FSpareMem);
  FreeAndNil(FChildMem);
  FreeAndNil(FMasterMem);
  FConn := nil;
  FRows := nil;
end;

/// The manager keeps its adapters in a private dictionary. Reading it is the
/// only way to compare the object the child was given against the object the
/// repository holds for the master - which is the whole point of the first two
/// tests. RTTI, not a cracker: TManagerDataSet is not a class one can descend
/// usefully for this, the field is private and there is no accessor.
function TTestManagerAddAdapter.Repository: TDictionary<String, TObject>;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LField: TRttiField;
begin
  Result := nil;
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(TManagerDataSet);
    Assert.IsNotNull(LType, 'TManagerDataSet must be visible to RTTI');
    LField := LType.GetField('FRepository');
    Assert.IsNotNull(LField,
      'FRepository must be readable through RTTI, otherwise every assertion ' +
      'that reads it is blind and would pass on anything at all');
    Result := TDictionary<String, TObject>(LField.GetValue(FManager).AsObject);
  finally
    LContext.Free;
  end;
end;

function TTestManagerAddAdapter.AdapterOf(const AClassName: String): TObject;
begin
  if not Repository.TryGetValue(AClassName, Result) then
    Result := nil;
end;

procedure TTestManagerAddAdapter.BuildMasterOnly;
begin
  FMasterMem := TMemDataSet.Create(nil);
  FManager.AddAdapter<TAsymMaster>(FMasterMem);
end;

procedure TTestManagerAddAdapter.BuildMasterDetail;
begin
  BuildMasterOnly;
  FChildMem := TMemDataSet.Create(nil);
  FManager.AddAdapter<TAsymChild, TAsymMaster>(FChildMem);
end;

procedure TTestManagerAddAdapter.MasterPresent_TheChildPointsAtTheAdapterFiledUnderTheMasterClass;
var
  LMaster: TObject;
  LChild: TObject;
begin
  BuildMasterDetail;
  LMaster := AdapterOf(cMASTERCLASS);
  LChild := AdapterOf(cCHILDCLASS);
  Assert.IsNotNull(LMaster, 'the master adapter must be in the repository');
  Assert.IsNotNull(LChild,
    'the child adapter must be in the repository - AddAdapter<T, M> returns ' +
    'silently on three conditions and then every assertion below is vacuous');
  Assert.IsTrue(TAdapterProbe<TAsymChild>.OwnerOf(LChild) = LMaster,
    'the child must point back at THE master adapter the repository holds ' +
    'under the master class name. Handing the constructor anything else - nil ' +
    'included - leaves the pair unlinked and OpenDataSetChilds with nothing ' +
    'to iterate');
end;

procedure TTestManagerAddAdapter.MasterPresent_TheMasterCarriesTheChildUnderTheChildClassName;
var
  LMaster: TObject;
  LChild: TObject;
begin
  BuildMasterDetail;
  LMaster := AdapterOf(cMASTERCLASS);
  LChild := AdapterOf(cCHILDCLASS);
  Assert.IsNotNull(LMaster, 'the master adapter must be in the repository');
  Assert.IsNotNull(LChild, 'the child adapter must be in the repository');
  Assert.AreEqual(1, TAdapterProbe<TAsymMaster>.ChildCountOf(LMaster),
    'exactly one detail was added, so the master must carry exactly one');
  Assert.IsTrue(
    TAdapterProbe<TAsymMaster>.ChildUnder(LMaster, cCHILDCLASS) = LChild,
    'and it must be filed under the CHILD class name - that string is the key ' +
    'TDataSetAdapter<M>.OpenDataSetChilds and SelectAssociation look it up by');
end;

procedure TTestManagerAddAdapter.MasterPresent_OpeningTheMasterOpensTheChildThroughThatLink;
begin
  BuildMasterDetail;
  Assert.AreEqual(0, FRows.CreateCount,
    'building the adapters must not query anything by itself');
  FManager.OpenWhere<TAsymMaster>('1 = 1');
  Assert.IsTrue(FMasterMem.Active, 'the master must be open');
  Assert.IsTrue(FRows.CreateCount > 1,
    'opening a LINKED master must produce a SECOND cursor - the child query. ' +
    'With the link missing OpenDataSetChilds returns on FMasterObject.Count = ' +
    '0 and exactly one cursor is ever asked for');
  Assert.IsTrue(FChildMem.Active,
    'and the child dataset must have been opened by that query');
end;

procedure TTestManagerAddAdapter.Selection_BothEndsAreTheLocalAdapterClass;
var
  LMaster: TObject;
  LChild: TObject;
begin
  BuildMasterDetail;
  LMaster := AdapterOf(cMASTERCLASS);
  LChild := AdapterOf(cCHILDCLASS);
  Assert.IsNotNull(LMaster, 'the master adapter must be in the repository');
  Assert.IsNotNull(LChild, 'the child adapter must be in the repository');
  // Each local adapter name is a SUFFIX of its REST namesake -
  // TFDMemTableAdapter of TRESTFDMemTableAdapter, TClientDataSetAdapter of
  // TRESTClientDataSetAdapter - so the POSITION is what separates the
  // branches. A bare Pos() would match both and prove nothing.
  Assert.AreEqual(1, Pos(cLOCALADAPTER, LMaster.ClassName),
    'AddAdapter<T> must build ' + cLOCALADAPTER + ' without DRIVERRESTFUL. ' +
    'Found: ' + LMaster.ClassName);
  Assert.AreEqual(1, Pos(cLOCALADAPTER, LChild.ClassName),
    'AddAdapter<T, M> must build ' + cLOCALADAPTER + ' without DRIVERRESTFUL. ' +
    'Found: ' + LChild.ClassName);
end;

procedure TTestManagerAddAdapter.MasterMissing_ItExitsSilentlyAndRegistersNothing;
begin
  FChildMem := TMemDataSet.Create(nil);
  // No AddAdapter<TAsymMaster> anywhere above this line.
  Assert.WillNotRaiseAny(
    procedure
    begin
      FManager.AddAdapter<TAsymChild, TAsymMaster>(FChildMem);
    end,
    'the shipped behaviour is a silent return when the master is unknown. ' +
    'This asserts what SHIPS, not what ought to ship');
  Assert.AreEqual(0, Repository.Count,
    'and it must register nothing - a half-built pair would be worse than ' +
    'either outcome');
end;

procedure TTestManagerAddAdapter.MasterMissing_TheNextCallOnTheDetailDereferencesNil;
begin
  FChildMem := TMemDataSet.Create(nil);
  // No AddAdapter<TAsymMaster> anywhere above this line, so the call below
  // takes the `master not registered` exit.
  FManager.AddAdapter<TAsymChild, TAsymMaster>(FChildMem);
  Assert.WillRaise(
    procedure
    begin
      FManager.DataSet<TAsymChild>;
    end,
    EAccessViolation,
    'the silent exit is not silent for long: DataSet<T> reads FOrmDataSet off ' +
    'the nil TManagerDataSet.Resolver<T> returns. If this ever stops raising, ' +
    'somebody made the manager answer for an unregistered class and the ' +
    'silent exit changed shape');
end;

procedure TTestManagerAddAdapter.DetailTwice_TheSecondCallIsANoOpAndTheFirstDataSetSurvives;
begin
  BuildMasterDetail;
  FSpareMem := TMemDataSet.Create(nil);
  Assert.WillNotRaiseAny(
    procedure
    begin
      FManager.AddAdapter<TAsymChild, TAsymMaster>(FSpareMem);
    end,
    'registering the same detail twice returns silently');
  Assert.AreEqual(2, Repository.Count,
    'and adds nothing - two classes went in, two entries exist');
  Assert.IsTrue(FManager.DataSet<TAsymChild> = FChildMem,
    'the FIRST dataset must survive. Without this the test cannot tell a ' +
    'no-op from an overwrite: neither raises');
end;

procedure TTestManagerAddAdapter.Layout_EveryInstantiationOfTheBaseAdapterAgreesOnEveryOffset;
var
  LContext: TRttiContext;

  function Shape(const AClass: TClass): String;
  var
    LType: TRttiType;
    LField: TRttiField;
    LCount: Integer;
  begin
    Result := '';
    LCount := 0;
    LType := LContext.GetType(AClass);
    Assert.IsNotNull(LType, AClass.ClassName + ' must be visible to RTTI');
    for LField in LType.GetFields do
    begin
      Result := Result + LField.Name + '@' + IntToStr(LField.Offset) + ';';
      Inc(LCount);
    end;
    Assert.IsTrue(LCount > 0,
      'field RTTI must be emitted for ' + AClass.ClassName + ', otherwise ' +
      'this test compares two empty strings and passes on anything');
  end;

var
  LMasterShape: String;
  LChildShape: String;
  LThirdShape: String;
begin
  LContext := TRttiContext.Create;
  try
    LMasterShape := Shape(TDataSetBaseAdapter<TAsymMaster>);
    LChildShape := Shape(TDataSetBaseAdapter<TAsymChild>);
    // A third entity from an unrelated model, with a different field list and
    // a different key shape, so that agreement cannot be an artefact of two
    // near-identical entities.
    LThirdShape := Shape(TDataSetBaseAdapter<TKeyOnly>);
  finally
    LContext.Free;
  end;
  Assert.AreEqual(TDataSetBaseAdapter<TAsymMaster>.InstanceSize,
                  TDataSetBaseAdapter<TAsymChild>.InstanceSize,
    'two instantiations of the base adapter must occupy the same bytes');
  Assert.AreEqual(TDataSetBaseAdapter<TAsymMaster>.InstanceSize,
                  TDataSetBaseAdapter<TKeyOnly>.InstanceSize,
    'and so must a third one from an unrelated model');
  Assert.AreEqual(LMasterShape, LChildShape,
    'every field must sit at the same offset in both instantiations');
  Assert.AreEqual(LMasterShape, LThirdShape,
    'and in the third');
end;

procedure TTestManagerAddAdapter.MasterNotAnAdapter_IsRefusedByNameInsteadOfFaulting;
var
  LChild: TObject;
  LIntruder: TNotAnAdapter;
  LOutcome: String;
begin
  BuildMasterDetail;
  LChild := AdapterOf(cCHILDCLASS);
  Assert.IsNotNull(LChild, 'the child adapter must be in the repository');
  LIntruder := TNotAnAdapter.Create;
  try
    Assert.IsTrue(
      LIntruder.InstanceSize >= TDataSetBaseAdapter<TAsymChild>.InstanceSize,
      'the intruder must be at least as big as the adapter, otherwise the ' +
      'unguarded read this test describes would land PAST the object and the ' +
      'measurement quoted above would be undefined behaviour instead of a ' +
      'nil dereference. Intruder ' + IntToStr(LIntruder.InstanceSize) +
      ' bytes against adapter ' +
      IntToStr(TDataSetBaseAdapter<TAsymChild>.InstanceSize));
    LOutcome := '';
    try
      TAdapterProbe<TAsymChild>.LinkTo(LChild, LIntruder);
      LOutcome := 'nothing was raised';
    except
      on E: Exception do
        LOutcome := E.ClassName + '|' + E.Message;
    end;
    // Two DISTINCT names in a FIXED order. cCHILDCLASS is the detail entity,
    // TNotAnAdapter is what was handed in - transposing them in the Format
    // call changes this string.
    Assert.AreEqual(
      'Exception|' + Format(cMASTERNOTADAPTER, [cCHILDCLASS, 'TNotAnAdapter']),
      LOutcome,
      'SetMasterObject must refuse a non-adapter by NAME. Both names matter: ' +
      'the detail says which link broke, the intruder says what was passed');
  finally
    LIntruder.Free;
  end;
end;

procedure TTestManagerAddAdapter.Guard_TheMasterOfAnotherInstantiationIsStillAccepted;
var
  LMaster: TObject;
  LChild: TObject;
begin
  BuildMasterDetail;
  LMaster := AdapterOf(cMASTERCLASS);
  LChild := AdapterOf(cCHILDCLASS);
  Assert.IsNotNull(LMaster, 'the master adapter must be in the repository');
  Assert.IsNotNull(LChild, 'the child adapter must be in the repository');
  Assert.AreNotEqual(LMaster.ClassName, LChild.ClassName,
    'the premise of this test: the two ends are DIFFERENT instantiations of ' +
    'the same generic adapter. Master ' + LMaster.ClassName + ', child ' +
    LChild.ClassName);
  // Unlink and relink, so SetMasterObject really runs with a non-nil value
  // instead of taking its `already this master` exit.
  Assert.WillNotRaiseAny(
    procedure
    begin
      TAdapterProbe<TAsymChild>.LinkTo(LChild, nil);
      TAdapterProbe<TAsymChild>.LinkTo(LChild, LMaster);
    end,
    'a guard written as `AValue is TDataSetBaseAdapter<M>` compiles and ' +
    'refuses THIS - the only shape a master ever has - which would break ' +
    'every master-detail link in the framework');
  Assert.IsTrue(TAdapterProbe<TAsymChild>.OwnerOf(LChild) = LMaster,
    'and the link must be the one it was before: the child points at the ' +
    'master adapter');
  Assert.AreEqual(1, TAdapterProbe<TAsymMaster>.ChildCountOf(LMaster),
    'and the master carries exactly one child - not zero from the unlink and ' +
    'not two from a relink that forgot to remove');
end;

procedure TTestManagerAddAdapter.Recognition_TheAncestorNameIsWhatTheGuardHangsOn;
var
  LMaster: TObject;
  LChild: TObject;
  LIntruder: TNotAnAdapter;
  LClass: TClass;
  LChain: String;
  LAnswers: String;
  LEmitted: String;
  LHits: Integer;
begin
  BuildMasterDetail;
  LMaster := AdapterOf(cMASTERCLASS);
  LChild := AdapterOf(cCHILDCLASS);
  Assert.IsNotNull(LMaster, 'the master adapter must be in the repository');
  Assert.IsNotNull(LChild, 'the child adapter must be in the repository');

  // The predicate itself, asked four questions whose answers are NOT all the
  // same, in a fixed order and under distinct names. An inverted predicate
  // flips all four; one that stopped walking ClassParent flips only the two
  // built adapters; one that stopped testing for nil flips only the first.
  LIntruder := TNotAnAdapter.Create;
  try
    LAnswers := 'nil=' + Yn(_IsBaseAdapterInstance(nil)) +
                ';intruder=' + Yn(_IsBaseAdapterInstance(LIntruder)) +
                ';master=' + Yn(_IsBaseAdapterInstance(LMaster)) +
                ';child=' + Yn(_IsBaseAdapterInstance(LChild));
    Assert.AreEqual('nil=no;intruder=no;master=yes;child=yes', LAnswers,
      'the recognition SetMasterObject leans on. The two adapters are ' +
      'different instantiations of the same generic class and both must be ' +
      'recognised; nothing else may be');
  finally
    LIntruder.Free;
  end;

  // THE CONTENT OF THE CONSTANT, against the name the compiler really emits.
  // Everything above still passes with cBaseAdapterPrefix shortened to
  // `TDataSetBase` - every adapter is still recognised - so nothing above can
  // tell that the trailing `<` went missing. Deriving the expected value from
  // the emitted name can, and it reads Source's constant, not a copy kept
  // here: a copy would only ever agree with itself.
  LEmitted := TDataSetBaseAdapter<TAsymChild>.ClassName;
  Assert.IsTrue(Pos('<', LEmitted) > 0,
    'the premise: Delphi must emit the type argument in the class name, ' +
    'otherwise there is no `<` to anchor and this whole approach is void. ' +
    'Found: ' + LEmitted);
  Assert.AreEqual(Copy(LEmitted, 1, Pos('<', LEmitted)), cBaseAdapterPrefix,
    'cBaseAdapterPrefix must be the template name UP TO AND INCLUDING the ' +
    '`<`. That character is the only thing separating an instantiation of ' +
    'this template from any class whose name merely starts the same way, and ' +
    'dropping it changes no other assertion in this unit. Emitted: ' +
    LEmitted);

  Assert.AreNotEqual(1, Pos(cBaseAdapterPrefix, LChild.ClassName),
    'the class the manager builds is ' + cLOCALADAPTER + ', NOT the base ' +
    'adapter - so a guard that only looked at ClassName would refuse every ' +
    'real master. Found: ' + LChild.ClassName);
  LChain := '';
  LHits := 0;
  LClass := LChild.ClassType;
  while LClass <> nil do
  begin
    LChain := LChain + LClass.ClassName + ';';
    if Pos(cBaseAdapterPrefix, LClass.ClassName) = 1 then
      Inc(LHits);
    LClass := LClass.ClassParent;
  end;
  Assert.AreEqual(1, LHits,
    'walking ClassParent must meet `' + cBaseAdapterPrefix + '` exactly ' +
    'once. If a rename ever leaves that string behind, the guard silently ' +
    'stops recognising adapters and starts refusing them. Chain: ' + LChain);
end;

procedure TTestManagerAddAdapter.Recovery_TheObjectBehindTheDetailTypedCastIsTheMasterEntity;
begin
  BuildMasterDetail;
  Assert.AreEqual(cMASTERCLASS,
    TAdapterProbe<TAsymChild>.OwnerCurrentClassName(AdapterOf(cCHILDCLASS)),
    'the cast says TAsymChild and the object answers ' + cMASTERCLASS + '. ' +
    'That is the whole answer to `does the wrong type argument change what ' +
    'comes back` for these two sites: ClassName and ClassType read the ' +
    'instance VMT pointer, not TypeInfo(M)');
end;

procedure TTestManagerAddAdapter.Refusal_LeavesTheLegitimateLinkExactlyAsItWas;
var
  LMaster: TObject;
  LChild: TObject;
  LIntruder: TNotAnAdapter;
  LRaised: String;
  LBefore: String;
  LAfter: String;

  // The WHOLE link, both ends, in one ordered signature. Counting children
  // alone would not do: the unlink removes the entry AND leaves
  // FOwnerMasterObject pointing at the master, so only reading both ends
  // together tells a refusal that touched nothing from one that half-ran.
  function LinkShape: String;
  begin
    Result :=
      'children=' + IntToStr(TAdapterProbe<TAsymMaster>.ChildCountOf(LMaster)) +
      ';under-' + cCHILDCLASS + '=' +
        Yn(TAdapterProbe<TAsymMaster>.ChildUnder(LMaster, cCHILDCLASS) = LChild) +
      ';owner=' + Yn(TAdapterProbe<TAsymChild>.OwnerOf(LChild) = LMaster);
  end;

begin
  BuildMasterDetail;
  LMaster := AdapterOf(cMASTERCLASS);
  LChild := AdapterOf(cCHILDCLASS);
  Assert.IsNotNull(LMaster, 'the master adapter must be in the repository');
  Assert.IsNotNull(LChild, 'the child adapter must be in the repository');

  LBefore := LinkShape;
  Assert.AreEqual('children=1;under-' + cCHILDCLASS + '=yes;owner=yes', LBefore,
    'the premise: a whole, live link before anything is attempted. Without ' +
    'this the comparison below could pass on two equally broken states');

  LIntruder := TNotAnAdapter.Create;
  try
    LRaised := 'nothing was raised';
    try
      TAdapterProbe<TAsymChild>.LinkTo(LChild, LIntruder);
    except
      on E: Exception do
        LRaised := E.ClassName;
    end;
    Assert.AreEqual('Exception', LRaised,
      'the call must fail - if it stops failing this test is measuring ' +
      'nothing');
    LAfter := LinkShape;
  finally
    LIntruder.Free;
  end;

  Assert.AreEqual(LBefore, LAfter,
    'A CALL THAT FAILED MUST HAVE CHANGED NOTHING. SetMasterObject unlinks ' +
    'the child from its current master BEFORE it would file it under the new ' +
    'one, so a guard sitting after that block raises the very same message ' +
    'and still leaves the master without its child. Before: ' + LBefore +
    ' - after: ' + LAfter);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestManagerAddAdapter);

end.
