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

{ @abstract(Janus Framework - the cascade guard of DeleteDataSetChilds.)

  WHAT IS UNDER TEST

  TRESTDataSetAdapter<M>.DeleteDataSetChilds walks every child adapter
  registered under the master and, for each one, every association the master
  declares. What decides whether that child's dataset is emptied is one guard
  with two conditions:

      A - the association carries TCascadeAction.CascadeDelete
      B - the association's ClassNameRef is this child's class name

  THE DEFECT THIS SUITE PINS

  The guard was `if not A and not B then Continue`. By De Morgan the child is
  emptied when A OR B holds, so two unrelated things clear data:

    * B alone - the association names the child but does NOT carry
      CascadeDelete. The child is wiped by a cascade the model switched off.
    * A alone - some OTHER association of the same master carries
      CascadeDelete. Because the child loop is the outer loop, that one flag
      empties EVERY child registered, including children no association names.

  Both need A and B together, which is what the fix asks for.

  WHY THE MODEL IS Test.Janus.Model.AutoIncTree

  It is the only model in the tree that already declares an association
  WITHOUT CascadeDelete next to one that has it:

      TAitRoot.mids   -> TAitMid        CascadeAutoInc/Insert/Update/Delete
      TAitRoot.others -> TAitNoCascade  CascadeInsert/Update  (no Delete)

  Premise_TheRootHasOneCascadingAndOneNonCascadingAssociation measures both
  from the mapping rather than trusting the declaration, because the whole
  suite is meaningless if `others` ever gains CascadeDelete.

  TAitMid serves the second shape: its single association points at TAitLeaf,
  so a TAitNoCascade adapter registered under it is a child that NO
  association of that master names - the pure leg-A case.

  WHY IT LIVES IN Janus.Tests.RESTfulDriver

  Same reason Test.Janus.Rest.ClearChilds does: outside Test\Delphi the only
  code that builds a TRESTClientDataSetAdapter or a TRESTFDMemTableAdapter is
  TManagerDataSet.AddAdapter<T>, and both overloads select them inside an
  IFDEF DRIVERRESTFUL block. This project is the configuration where the
  cascade is reachable at all.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Rest.CascadeGuard;

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
  MetaDbDiff.Mapping.Classes,
  MetaDbDiff.Mapping.Explorer,
  MetaDbDiff.Types.Mapping,
  Janus.RestFactory.Interfaces,
  Janus.RestDataSet.ClientDataSet,
  Janus.RestDataSet.FDMemTable,
  Test.Janus.Model.AutoIncTree,
  Test.Janus.RestConnection.Double;

type
  /// <summary> Classic cracker descendants. DeleteDataSetChilds and
  ///  FMasterObject are both protected, and the production trigger for the
  ///  cascade destroys the master row as well - so measuring what it did to
  ///  each child needs the handler called on its own. Both routes are
  ///  exercised here: this one, and the shipped BeforeDelete wiring. </summary>
  TRestCdsCascadeCrack<M: class, constructor> = class(TRESTClientDataSetAdapter<M>)
  public
    class procedure ClearChilds(const AAdapter: TRESTClientDataSetAdapter<M>);
    class function RegisteredChilds(
      const AAdapter: TRESTClientDataSetAdapter<M>): string;
  end;

  TRestMemCascadeCrack<M: class, constructor> = class(TRESTFDMemTableAdapter<M>)
  public
    class procedure ClearChilds(const AAdapter: TRESTFDMemTableAdapter<M>);
  end;

  [TestFixture]
  TTestRestCascadeGuard = class
  private
    FConn: IRESTConnection;
    FRootCds: TClientDataSet;
    FMidCds: TClientDataSet;
    FOtherCds: TClientDataSet;
    FRootMem: TFDMemTable;
    FMidMem: TFDMemTable;
    FOtherMem: TFDMemTable;
    FCdsRoot: TRESTClientDataSetAdapter<TAitRoot>;
    FCdsMid: TRESTClientDataSetAdapter<TAitMid>;
    FCdsOther: TRESTClientDataSetAdapter<TAitNoCascade>;
    FMemRoot: TRESTFDMemTableAdapter<TAitRoot>;
    FMemMid: TRESTFDMemTableAdapter<TAitMid>;
    FMemOther: TRESTFDMemTableAdapter<TAitNoCascade>;
    /// Root as master, with BOTH children registered under it - the shape a
    /// model with a cascading and a non-cascading association really has.
    procedure BuildCdsTrio;
    procedure BuildMemTrio;
    /// Mid as master, with the TAitNoCascade adapter registered under it.
    /// Mid's only association points at TAitLeaf, so this child is one that
    /// NO association of the master names.
    procedure BuildCdsUnrelatedPair;
    procedure AddRootRow(const ADataSet: TDataSet);
    procedure AddMidRows(const ADataSet: TDataSet; const ACount: Integer);
    procedure AddOtherRows(const ADataSet: TDataSet; const ACount: Integer);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// The premises every measurement below rests on. If the model ever
    /// changes under them these go red first and say why.
    [Test]
    procedure Premise_TheRootHasOneCascadingAndOneNonCascadingAssociation;
    [Test]
    procedure Premise_BothChildrenAreRegisteredUnderTheRoot;
    [Test]
    procedure Premise_TheMidNamesTheLeafAndNotTheNoCascadeChild;

    /// LOAD-BEARING - leg B on its own. The association names the child and
    /// does NOT carry CascadeDelete, so the child must be left alone.
    [Test]
    procedure NoCascadeDelete_TheChildMustSurvive;
    /// LOAD-BEARING - the same, on the TFDMemTable family Janus.inc ships
    /// selected.
    [Test]
    procedure NoCascadeDelete_FDMemTable_TheChildMustSurvive;
    /// LOAD-BEARING - leg A on its own. A child that no association of this
    /// master names must not be emptied because a sibling association happens
    /// to cascade.
    [Test]
    procedure UnrelatedChild_ACascadingSiblingMustNotClearIt;
    /// LOAD-BEARING, through the production route: TDataSet.Delete on the
    /// master row fires the BeforeDelete the adapter installed.
    [Test]
    procedure DeletingTheRootRow_ClearsTheCascadingChildOnly;

    /// THE OTHER DIRECTION. The legitimate cascade must keep working - a
    /// guard tightened past the point of usefulness would empty nothing and
    /// leave every measurement above green. This one is the witness against
    /// trading one defect for the other.
    [Test]
    procedure CascadeDelete_TheNamedChildIsStillCleared;
  end;

implementation

const
  cROOTKEY  = 'root_id';
  cROOTTAG  = 'tag';
  cMIDKEY   = 'mid_id';
  cMIDTAG   = 'tag';
  cOTHERKEY = 'other_id';
  cMIDROWS   = 3;
  cOTHERROWS = 4;

{ TRestCdsCascadeCrack<M> }

class procedure TRestCdsCascadeCrack<M>.ClearChilds(
  const AAdapter: TRESTClientDataSetAdapter<M>);
begin
  TRestCdsCascadeCrack<M>(AAdapter).DeleteDataSetChilds;
end;

class function TRestCdsCascadeCrack<M>.RegisteredChilds(
  const AAdapter: TRESTClientDataSetAdapter<M>): string;
var
  LKeys: TStringList;
begin
  LKeys := TStringList.Create;
  try
    LKeys.Sorted := True;
    LKeys.AddStrings(TRestCdsCascadeCrack<M>(AAdapter).FMasterObject.Keys.ToArray);
    Result := LKeys.CommaText;
  finally
    LKeys.Free;
  end;
end;

{ TRestMemCascadeCrack<M> }

class procedure TRestMemCascadeCrack<M>.ClearChilds(
  const AAdapter: TRESTFDMemTableAdapter<M>);
begin
  TRestMemCascadeCrack<M>(AAdapter).DeleteDataSetChilds;
end;

{ TTestRestCascadeGuard }

procedure TTestRestCascadeGuard.Setup;
begin
  FConn := TRecordingRestConnection.Create;
end;

procedure TTestRestCascadeGuard.TearDown;
begin
  if FMidCds <> nil then
    FMidCds.MasterSource := nil;
  if FOtherCds <> nil then
    FOtherCds.MasterSource := nil;
  if FMidMem <> nil then
    FMidMem.MasterSource := nil;
  if FOtherMem <> nil then
    FOtherMem.MasterSource := nil;
  FreeAndNil(FCdsOther);
  FreeAndNil(FCdsMid);
  FreeAndNil(FCdsRoot);
  FreeAndNil(FMemOther);
  FreeAndNil(FMemMid);
  FreeAndNil(FMemRoot);
  FreeAndNil(FOtherCds);
  FreeAndNil(FMidCds);
  FreeAndNil(FRootCds);
  FreeAndNil(FOtherMem);
  FreeAndNil(FMidMem);
  FreeAndNil(FRootMem);
  FConn := nil;
end;

/// Passing the master adapter as AMasterObject is what registers the child in
/// the master's FMasterObject - the dictionary the cascade walks. Registration
/// is keyed by the child's class name and asks nothing about cascade, which is
/// why a non-cascading child gets in at all.
procedure TTestRestCascadeGuard.BuildCdsTrio;
begin
  FRootCds := TClientDataSet.Create(nil);
  FCdsRoot := TRESTClientDataSetAdapter<TAitRoot>.Create(FConn, FRootCds, -1, nil);
  FMidCds := TClientDataSet.Create(nil);
  FCdsMid := TRESTClientDataSetAdapter<TAitMid>.Create(FConn, FMidCds, -1, FCdsRoot);
  FOtherCds := TClientDataSet.Create(nil);
  FCdsOther := TRESTClientDataSetAdapter<TAitNoCascade>.Create(FConn, FOtherCds,
                 -1, FCdsRoot);
end;

procedure TTestRestCascadeGuard.BuildMemTrio;
begin
  FRootMem := TFDMemTable.Create(nil);
  FMemRoot := TRESTFDMemTableAdapter<TAitRoot>.Create(FConn, FRootMem, -1, nil);
  FMidMem := TFDMemTable.Create(nil);
  FMemMid := TRESTFDMemTableAdapter<TAitMid>.Create(FConn, FMidMem, -1, FMemRoot);
  FOtherMem := TFDMemTable.Create(nil);
  FMemOther := TRESTFDMemTableAdapter<TAitNoCascade>.Create(FConn, FOtherMem,
                 -1, FMemRoot);
end;

procedure TTestRestCascadeGuard.BuildCdsUnrelatedPair;
begin
  FMidCds := TClientDataSet.Create(nil);
  FCdsMid := TRESTClientDataSetAdapter<TAitMid>.Create(FConn, FMidCds, -1, nil);
  FOtherCds := TClientDataSet.Create(nil);
  FCdsOther := TRESTClientDataSetAdapter<TAitNoCascade>.Create(FConn, FOtherCds,
                 -1, FCdsMid);
end;

procedure TTestRestCascadeGuard.AddRootRow(const ADataSet: TDataSet);
begin
  ADataSet.Append;
  ADataSet.FieldByName(cROOTKEY).AsInteger := 1;
  ADataSet.FieldByName(cROOTTAG).AsString := 'root';
  ADataSet.Post;
end;

procedure TTestRestCascadeGuard.AddMidRows(const ADataSet: TDataSet;
  const ACount: Integer);
var
  LFor: Integer;
begin
  for LFor := 1 to ACount do
  begin
    ADataSet.Append;
    ADataSet.FieldByName(cMIDKEY).AsInteger := LFor;
    ADataSet.FieldByName(cROOTKEY).AsInteger := 1;
    ADataSet.FieldByName(cMIDTAG).AsString := 'mid' + IntToStr(LFor);
    ADataSet.Post;
  end;
end;

procedure TTestRestCascadeGuard.AddOtherRows(const ADataSet: TDataSet;
  const ACount: Integer);
var
  LFor: Integer;
begin
  for LFor := 1 to ACount do
  begin
    ADataSet.Append;
    ADataSet.FieldByName(cOTHERKEY).AsInteger := LFor;
    ADataSet.FieldByName(cROOTKEY).AsInteger := 1;
    ADataSet.Post;
  end;
end;

procedure TTestRestCascadeGuard.Premise_TheRootHasOneCascadingAndOneNonCascadingAssociation;
var
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LFoundMid: Boolean;
  LFoundOther: Boolean;
begin
  LAssociations := TMappingExplorer.GetMappingAssociation(TAitRoot);
  Assert.IsNotNull(LAssociations,
    'TAitRoot must expose its associations - the cascade exits early without ' +
    'them and the guard under test is never reached');
  LFoundMid := False;
  LFoundOther := False;
  for LAssociation in LAssociations do
  begin
    if LAssociation.ClassNameRef = TAitMid.ClassName then
    begin
      LFoundMid := True;
      Assert.IsTrue(TCascadeAction.CascadeDelete in LAssociation.CascadeActions,
        'the association to TAitMid must carry CascadeDelete - it is the ' +
        'legitimate cascade every measurement here is contrasted against');
    end;
    if LAssociation.ClassNameRef = TAitNoCascade.ClassName then
    begin
      LFoundOther := True;
      Assert.IsFalse(TCascadeAction.CascadeDelete in LAssociation.CascadeActions,
        'the association to TAitNoCascade must NOT carry CascadeDelete - if ' +
        'it ever gains it, every no-cascade measurement below is decorative');
    end;
  end;
  Assert.IsTrue(LFoundMid, 'no association from TAitRoot to TAitMid');
  Assert.IsTrue(LFoundOther, 'no association from TAitRoot to TAitNoCascade');
end;

procedure TTestRestCascadeGuard.Premise_BothChildrenAreRegisteredUnderTheRoot;
begin
  BuildCdsTrio;
  Assert.AreEqual('TAitMid,TAitNoCascade',
    TRestCdsCascadeCrack<TAitRoot>.RegisteredChilds(FCdsRoot),
    'both adapters must be registered under the root - registration is what ' +
    'puts the non-cascading child in front of the guard in the first place');
end;

procedure TTestRestCascadeGuard.Premise_TheMidNamesTheLeafAndNotTheNoCascadeChild;
var
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
begin
  LAssociations := TMappingExplorer.GetMappingAssociation(TAitMid);
  Assert.IsNotNull(LAssociations, 'TAitMid must expose its association');
  for LAssociation in LAssociations do
  begin
    Assert.AreNotEqual(TAitNoCascade.ClassName, LAssociation.ClassNameRef,
      'no association of TAitMid may name TAitNoCascade - that is what makes ' +
      'the child registered under it an UNRELATED one');
    if LAssociation.ClassNameRef = TAitLeaf.ClassName then
      Assert.IsTrue(TCascadeAction.CascadeDelete in LAssociation.CascadeActions,
        'and the association it does declare must cascade, otherwise leg A ' +
        'never fires and the measurement proves nothing');
  end;
end;

procedure TTestRestCascadeGuard.NoCascadeDelete_TheChildMustSurvive;
begin
  BuildCdsTrio;
  AddRootRow(FRootCds);
  AddMidRows(FMidCds, cMIDROWS);
  AddOtherRows(FOtherCds, cOTHERROWS);
  Assert.AreEqual(cOTHERROWS, FOtherCds.RecordCount, 'premise: rows present');
  TRestCdsCascadeCrack<TAitRoot>.ClearChilds(FCdsRoot);
  Assert.AreEqual(cOTHERROWS, FOtherCds.RecordCount,
    'the association to TAitNoCascade does not carry CascadeDelete, so its ' +
    'rows must all still be here - with the two-legged guard the class-name ' +
    'match alone emptied them');
end;

procedure TTestRestCascadeGuard.NoCascadeDelete_FDMemTable_TheChildMustSurvive;
begin
  BuildMemTrio;
  AddRootRow(FRootMem);
  AddMidRows(FMidMem, cMIDROWS);
  AddOtherRows(FOtherMem, cOTHERROWS);
  Assert.AreEqual(cOTHERROWS, FOtherMem.RecordCount, 'premise: rows present');
  TRestMemCascadeCrack<TAitRoot>.ClearChilds(FMemRoot);
  Assert.AreEqual(cOTHERROWS, FOtherMem.RecordCount,
    'the same guard, inherited by the FDMemTable adapter, must leave the ' +
    'non-cascading child alone - this is the family Janus.inc ships selected');
end;

procedure TTestRestCascadeGuard.UnrelatedChild_ACascadingSiblingMustNotClearIt;
begin
  BuildCdsUnrelatedPair;
  AddMidRows(FMidCds, 1);
  AddOtherRows(FOtherCds, cOTHERROWS);
  Assert.AreEqual(cOTHERROWS, FOtherCds.RecordCount, 'premise: rows present');
  TRestCdsCascadeCrack<TAitMid>.ClearChilds(FCdsMid);
  Assert.AreEqual(cOTHERROWS, FOtherCds.RecordCount,
    'no association of TAitMid names TAitNoCascade, so nothing about this ' +
    'child may be decided by the CascadeDelete its TAitLeaf association ' +
    'carries - with the two-legged guard that one flag emptied every child');
end;

procedure TTestRestCascadeGuard.DeletingTheRootRow_ClearsTheCascadingChildOnly;
begin
  BuildCdsTrio;
  AddRootRow(FRootCds);
  AddMidRows(FMidCds, cMIDROWS);
  AddOtherRows(FOtherCds, cOTHERROWS);
  // The production route: TDataSet.Delete on the master fires the BeforeDelete
  // the adapter installed, and that is what calls the cascade.
  FRootCds.Delete;
  Assert.AreEqual(0, FRootCds.RecordCount, 'the master row must be gone');
  Assert.AreEqual(0, FMidCds.RecordCount,
    'and the child its model marked CascadeDelete with it');
  Assert.AreEqual(cOTHERROWS, FOtherCds.RecordCount,
    'but not the child its model did NOT mark - on the shipped route this is ' +
    'a delete of rows the caller never asked to delete');
end;

procedure TTestRestCascadeGuard.CascadeDelete_TheNamedChildIsStillCleared;
begin
  BuildCdsTrio;
  AddRootRow(FRootCds);
  AddMidRows(FMidCds, cMIDROWS);
  AddOtherRows(FOtherCds, cOTHERROWS);
  Assert.AreEqual(cMIDROWS, FMidCds.RecordCount, 'premise: rows present');
  TRestCdsCascadeCrack<TAitRoot>.ClearChilds(FCdsRoot);
  Assert.AreEqual(0, FMidCds.RecordCount,
    'the association to TAitMid carries CascadeDelete and names it, so the ' +
    'cascade must still empty it - a guard tightened too far would leave ' +
    'these rows behind and every no-cascade test above would stay green');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRestCascadeGuard);

end.
