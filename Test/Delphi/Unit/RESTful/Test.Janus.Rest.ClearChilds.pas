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

{ @abstract(Janus Framework - clearing the child datasets of a REST master row.)

  WHAT IS UNDER TEST

  TRESTDataSetAdapter<M>.DeleteDataSetChilds - the cascade the REST adapter
  runs from DoBeforeDelete. For every child adapter registered under the master
  it walks the association mapping and empties the child's dataset.

  THE DEFECT THIS SUITE PINS

  The clearing loop was `while not LDataSet.Eof do LDataSet.Delete` with no
  First before it, so it starts wherever the previous caller left the child
  cursor. When that place is Eof the loop body never runs and the child rows
  are all still there after a cascade that reported success - no exception, no
  return value, nothing for the caller to test.

  Measured on the shipped RTL (Test.Janus.Bind.ClearNested carries the trace):
  Delete makes the FOLLOWING row current and, on the last row, falls back onto
  the new last with Eof still False - so from ANY row inside the dataset the
  loop turns round and empties it. Eof on entry is the single state that keeps
  rows, and there it keeps every one of them. The rows "behind the cursor" do
  NOT survive; that part of the report does not hold up against measurement.

  Eof with rows present is reachable and is not the same thing as an empty
  dataset: Premise_TheChildCanSitAtEofWithItsRowsStillThere measures that Next
  on the last row raises Eof while every row is still there, which is also the
  state any `while not Eof do ... Next` walk terminates in.

  THE SIBLING THAT WAS ALREADY RIGHT

  TRESTDataSetAdapter<M>.RefreshRecordInternal clears the very same child
  datasets with the very same loop and DOES call First first, inside the same
  DisableControls/EnableControls frame. That method is the shape this fix
  copies, and Sibling_RefreshRecordInternal_AlreadyClearsFromEof measures that
  it never had the defect.

  WHY IT LIVES IN Janus.Tests.RESTfulDriver

  The method is not itself inside an IFDEF - the unit compiles wherever it is
  used, and Janus.Tests.Units compiles it too. What DRIVERRESTFUL gates is
  REACHABILITY. Measured over the whole tree: outside Test\Delphi the only code
  that constructs a TRESTClientDataSetAdapter or a TRESTFDMemTableAdapter is
  TManagerDataSet.AddAdapter<T> - both overloads - and in both the selection
  sits inside an IFDEF DRIVERRESTFUL block. This project is the configuration
  where the cascade can be reached at all, so it is where its regression lives.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Rest.ClearChilds;

interface

uses
  DB,
  Classes,
  SysUtils,
  Variants,
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
  Test.Janus.Model.AsymKey,
  Test.Janus.RestConnection.Double;

type
  /// <summary> Classic cracker descendants. DeleteDataSetChilds is protected
  ///  and its production trigger is TDataSet.Delete on the MASTER row, which
  ///  also destroys that row - so measuring what the cascade did to the child
  ///  needs the handler called on its own. Both routes are exercised here:
  ///  this one, and the shipped BeforeDelete wiring. </summary>
  TRestCdsClearCrack<M: class, constructor> = class(TRESTClientDataSetAdapter<M>)
  public
    class procedure ClearChilds(const AAdapter: TRESTClientDataSetAdapter<M>);
    class procedure RefreshRecord(const AAdapter: TRESTClientDataSetAdapter<M>;
      const AObject: TObject);
  end;

  TRestMemClearCrack<M: class, constructor> = class(TRESTFDMemTableAdapter<M>)
  public
    class procedure ClearChilds(const AAdapter: TRESTFDMemTableAdapter<M>);
  end;

  [TestFixture]
  TTestRestClearChilds = class
  private
    FConn: IRESTConnection;
    FMasterCds: TClientDataSet;
    FChildCds: TClientDataSet;
    FMasterMem: TFDMemTable;
    FChildMem: TFDMemTable;
    FCdsMaster: TRESTClientDataSetAdapter<TAsymMaster>;
    FCdsChild: TRESTClientDataSetAdapter<TAsymChild>;
    FMemMaster: TRESTFDMemTableAdapter<TAsymMaster>;
    FMemChild: TRESTFDMemTableAdapter<TAsymChild>;
    procedure BuildCdsPair;
    procedure BuildMemPair;
    procedure AddMasterRow(const ADataSet: TDataSet);
    procedure AddChildRows(const ADataSet: TDataSet; const ACount: Integer);
    /// Parks the cursor past the last row - Next on the last row is what sets
    /// Eof, and the rows stay where they are.
    procedure ParkAtEof(const ADataSet: TDataSet);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// The premises the measurements rest on: the child adapter really is
    /// registered under the master, the association the cascade reads really
    /// carries CascadeDelete, and the child cursor really can sit at Eof with
    /// its rows still present.
    [Test]
    procedure Premise_TheChildIsRegisteredAndTheAssociationCascades;
    [Test]
    procedure Premise_TheChildCanSitAtEofWithItsRowsStillThere;

    /// CONTROL. Cursor on the first child row - the buggy loop and the fixed
    /// loop clear the same rows, so this is green either way. It is here to
    /// document how the defect stayed invisible.
    [Test]
    procedure CursorOnFirstRow_DeleteDataSetChilds_ClearsTheChild;

    /// LOAD-BEARING, TClientDataSet family.
    [Test]
    procedure CursorAtEof_DeleteDataSetChilds_ClearsTheChild;
    /// LOAD-BEARING, TFDMemTable family - the one Janus.inc ships selected.
    [Test]
    procedure CursorAtEof_FDMemTable_DeleteDataSetChilds_ClearsTheChild;
    /// LOAD-BEARING, through the production route: TDataSet.Delete on the
    /// master row, which fires the BeforeDelete the adapter installed.
    [Test]
    procedure CursorAtEof_DeletingTheMasterRow_ClearsTheChild;

    /// The sibling that already called First. It must stay green before AND
    /// after the fix - if it ever goes red, the fix moved something it should
    /// not have touched.
    [Test]
    procedure Sibling_RefreshRecordInternal_AlreadyClearsFromEof;
  end;

implementation

const
  cMASTERKEY = 'mkey';
  cMASTERTAG = 'mtag';
  cCHILDKEY  = 'ckey';
  cCHILDFK   = 'cparent';
  cCHILDTAG  = 'ctag';
  cCHILDROWS = 4;

{ TRestCdsClearCrack<M> }

class procedure TRestCdsClearCrack<M>.ClearChilds(
  const AAdapter: TRESTClientDataSetAdapter<M>);
begin
  TRestCdsClearCrack<M>(AAdapter).DeleteDataSetChilds;
end;

class procedure TRestCdsClearCrack<M>.RefreshRecord(
  const AAdapter: TRESTClientDataSetAdapter<M>; const AObject: TObject);
begin
  TRestCdsClearCrack<M>(AAdapter).RefreshRecordInternal(AObject);
end;

{ TRestMemClearCrack<M> }

class procedure TRestMemClearCrack<M>.ClearChilds(
  const AAdapter: TRESTFDMemTableAdapter<M>);
begin
  TRestMemClearCrack<M>(AAdapter).DeleteDataSetChilds;
end;

{ TTestRestClearChilds }

procedure TTestRestClearChilds.Setup;
begin
  FConn := TRecordingRestConnection.Create;
end;

procedure TTestRestClearChilds.TearDown;
begin
  if FChildCds <> nil then
    FChildCds.MasterSource := nil;
  if FChildMem <> nil then
    FChildMem.MasterSource := nil;
  FreeAndNil(FCdsChild);
  FreeAndNil(FCdsMaster);
  FreeAndNil(FMemChild);
  FreeAndNil(FMemMaster);
  FreeAndNil(FChildCds);
  FreeAndNil(FMasterCds);
  FreeAndNil(FChildMem);
  FreeAndNil(FMasterMem);
  FConn := nil;
end;

/// Both adapters build their own dataset from the mapping and call
/// CreateDataSet, and passing the master adapter as AMasterObject is what
/// registers the child in the master's FMasterObject - the dictionary the
/// cascade walks.
procedure TTestRestClearChilds.BuildCdsPair;
begin
  FMasterCds := TClientDataSet.Create(nil);
  FCdsMaster := TRESTClientDataSetAdapter<TAsymMaster>.Create(FConn,
                  FMasterCds, -1, nil);
  FChildCds := TClientDataSet.Create(nil);
  FCdsChild := TRESTClientDataSetAdapter<TAsymChild>.Create(FConn, FChildCds,
                 -1, FCdsMaster);
end;

procedure TTestRestClearChilds.BuildMemPair;
begin
  FMasterMem := TFDMemTable.Create(nil);
  FMemMaster := TRESTFDMemTableAdapter<TAsymMaster>.Create(FConn, FMasterMem,
                  -1, nil);
  FChildMem := TFDMemTable.Create(nil);
  FMemChild := TRESTFDMemTableAdapter<TAsymChild>.Create(FConn, FChildMem, -1,
                 FMemMaster);
end;

procedure TTestRestClearChilds.AddMasterRow(const ADataSet: TDataSet);
begin
  ADataSet.Append;
  ADataSet.FieldByName(cMASTERKEY).AsInteger := 1;
  ADataSet.FieldByName(cMASTERTAG).AsString := 'master';
  ADataSet.Post;
end;

procedure TTestRestClearChilds.AddChildRows(const ADataSet: TDataSet;
  const ACount: Integer);
var
  LFor: Integer;
begin
  for LFor := 1 to ACount do
  begin
    ADataSet.Append;
    ADataSet.FieldByName(cCHILDKEY).AsInteger := LFor;
    ADataSet.FieldByName(cCHILDFK).AsInteger := 1;
    ADataSet.FieldByName(cCHILDTAG).AsString := 'child' + IntToStr(LFor);
    ADataSet.Post;
  end;
end;

procedure TTestRestClearChilds.ParkAtEof(const ADataSet: TDataSet);
begin
  ADataSet.Last;
  ADataSet.Next;
end;

procedure TTestRestClearChilds.Premise_TheChildIsRegisteredAndTheAssociationCascades;
var
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LFound: Boolean;
begin
  BuildCdsPair;
  AddMasterRow(FMasterCds);
  AddChildRows(FChildCds, cCHILDROWS);
  Assert.AreEqual(cCHILDROWS, FChildCds.RecordCount,
    'the child dataset must really carry rows, otherwise every measurement ' +
    'below is clearing an empty dataset and proves nothing');
  LAssociations := TMappingExplorer.GetMappingAssociation(TAsymMaster);
  Assert.IsNotNull(LAssociations,
    'TAsymMaster must expose its association - the cascade exits early ' +
    'without it and the loop under test is never reached');
  LFound := False;
  for LAssociation in LAssociations do
  begin
    if LAssociation.ClassNameRef <> TAsymChild.ClassName then
      Continue;
    LFound := True;
    Assert.IsTrue(TCascadeAction.CascadeDelete in LAssociation.CascadeActions,
      'and it must carry CascadeDelete, which is what makes the cascade act ' +
      'on this child at all');
  end;
  Assert.IsTrue(LFound, 'no association from TAsymMaster to TAsymChild');
end;

procedure TTestRestClearChilds.Premise_TheChildCanSitAtEofWithItsRowsStillThere;
begin
  BuildCdsPair;
  AddMasterRow(FMasterCds);
  AddChildRows(FChildCds, cCHILDROWS);
  ParkAtEof(FChildCds);
  Assert.IsTrue(FChildCds.Eof,
    'Next on the last row must set Eof - if it did not, the state the defect ' +
    'lives in would be unreachable and this fixture decorative');
  Assert.AreEqual(cCHILDROWS, FChildCds.RecordCount,
    'and the rows must still be there: Eof with rows, not Eof because the ' +
    'dataset emptied itself');
end;

procedure TTestRestClearChilds.CursorOnFirstRow_DeleteDataSetChilds_ClearsTheChild;
begin
  BuildCdsPair;
  AddMasterRow(FMasterCds);
  AddChildRows(FChildCds, cCHILDROWS);
  FChildCds.First;
  Assert.AreEqual(1, FChildCds.RecNo, 'premise: cursor on the first row');
  TRestCdsClearCrack<TAsymMaster>.ClearChilds(FCdsMaster);
  Assert.AreEqual(0, FChildCds.RecordCount,
    'the cascade must have emptied the child dataset');
end;

procedure TTestRestClearChilds.CursorAtEof_DeleteDataSetChilds_ClearsTheChild;
begin
  BuildCdsPair;
  AddMasterRow(FMasterCds);
  AddChildRows(FChildCds, cCHILDROWS);
  ParkAtEof(FChildCds);
  Assert.IsTrue(FChildCds.Eof, 'premise: the child cursor is at Eof');
  TRestCdsClearCrack<TAsymMaster>.ClearChilds(FCdsMaster);
  Assert.AreEqual(0, FChildCds.RecordCount,
    'the cascade must have emptied the child dataset - without the First the ' +
    'loop is Eof on entry, deletes nothing, and all four rows are still here');
end;

procedure TTestRestClearChilds.CursorAtEof_FDMemTable_DeleteDataSetChilds_ClearsTheChild;
begin
  BuildMemPair;
  AddMasterRow(FMasterMem);
  AddChildRows(FChildMem, cCHILDROWS);
  ParkAtEof(FChildMem);
  Assert.IsTrue(FChildMem.Eof, 'premise: the child cursor is at Eof');
  Assert.AreEqual(cCHILDROWS, FChildMem.RecordCount, 'premise: rows present');
  TRestMemClearCrack<TAsymMaster>.ClearChilds(FMemMaster);
  Assert.AreEqual(0, FChildMem.RecordCount,
    'the same cascade, inherited by the FDMemTable adapter, must empty the ' +
    'child dataset - this is the family Janus.inc ships selected');
end;

procedure TTestRestClearChilds.CursorAtEof_DeletingTheMasterRow_ClearsTheChild;
begin
  BuildCdsPair;
  AddMasterRow(FMasterCds);
  AddChildRows(FChildCds, cCHILDROWS);
  ParkAtEof(FChildCds);
  Assert.IsTrue(FChildCds.Eof, 'premise: the child cursor is at Eof');
  // The production route: TDataSet.Delete on the master fires the
  // BeforeDelete the adapter installed, and that is what calls the cascade.
  FMasterCds.Delete;
  Assert.AreEqual(0, FMasterCds.RecordCount, 'the master row must be gone');
  Assert.AreEqual(0, FChildCds.RecordCount,
    'and its children with it - without the First they outlive their master');
end;

procedure TTestRestClearChilds.Sibling_RefreshRecordInternal_AlreadyClearsFromEof;
var
  LObject: TAsymMaster;
begin
  BuildCdsPair;
  AddMasterRow(FMasterCds);
  AddChildRows(FChildCds, cCHILDROWS);
  ParkAtEof(FChildCds);
  Assert.IsTrue(FChildCds.Eof, 'premise: the child cursor is at Eof');
  LObject := TAsymMaster.Create;
  try
    LObject.mkey := 1;
    LObject.mtag := 'refreshed';
    // RefreshRecordInternal clears the same child datasets with the same loop
    // and already called First. It repopulates them from the object, whose
    // child list is empty here, so the measurement is the clearing alone.
    TRestCdsClearCrack<TAsymMaster>.RefreshRecord(FCdsMaster, LObject);
    Assert.AreEqual(0, FChildCds.RecordCount,
      'the sibling that already had its First must clear from Eof too - it ' +
      'is the shape the fix copies, so it has to be green on both sides of it');
  finally
    LObject.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRestClearChilds);

end.
