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

{ @abstract(Janus Framework - master-detail wiring of the REST client family.)

  WHAT IS UNDER TEST

  TRESTClientDataSetAdapter<M>.FilterDataSetChilds and
  TRESTFDMemTableAdapter<M>._FilterDataSetChilds - the two methods that install
  the master-detail link on every child dataset after the master is opened.
  Both feed two VCL properties of the CHILD dataset from the [Association]
  mapping: MasterFields and IndexFieldNames.

  THE DEFECT THIS SUITE PINS

  The two variants fed the two properties from OPPOSITE ends of the mapping.
  TRESTFDMemTableAdapter<M>._FilterDataSetChilds sends ColumnsName (the
  master's column) to MasterFields and ColumnsNameRef (the child's column) to
  IndexFieldNames - and still does, unchanged, because that is the correct
  way round. TRESTClientDataSetAdapter<M>.FilterDataSetChilds sent them the
  other way round, and is what this suite made fail and then fixed. Which of
  the two is right is not a matter of taste: the VCL fixes the meaning of both
  properties, measured here by
  Semantics_TheVCLResolvesMasterFieldsAgainstTheMaster.

  WHY IT SURVIVED

  NOT because the two ends usually share a name by luck. Measured over the
  whole tree at the time this suite was written: 43 [Association] declarations,
  31 with both ends spelled the same and 11 with them spelled differently
  (Orion.Model.Empresa, Orion.Model.Contato, Orion.Model.Estado and one
  Janus.Model.Detail, all under Examples\Delphi). Name symmetry was never the
  cover.

  It survived because NOTHING reached the method. Outside this unit, the only
  place in the repository that constructs a TRESTClientDataSetAdapter is
  TManagerDataSet.AddAdapter<T> (both overloads), and there the class is
  selected only when DRIVERRESTFUL is defined AND USEFDMEMTABLE is not -
  Janus.inc ships DRIVERRESTFUL commented out and USEFDMEMTABLE on, so that
  branch is not even compiled. No test and no Example instantiated either REST
  adapter. This fixture constructs them directly, which is why it can reach
  code the conditional compilation keeps out of every shipped configuration.

  WHY THE FIXTURE NEEDS ASYMMETRIC KEYS

  Every other master-detail fixture in the suite links a column to a column of
  the SAME name (aitroot.root_id -> aitmid.root_id, Master.id -> Detail.id).
  With identical names the two wirings produce byte-identical strings, so a
  test written on them would pass with the swap in place and prove nothing.
  Test.Janus.Model.AsymKey removes that cover: mdmaster.mkey -> mdchild.cparent,
  so exactly one wiring can resolve.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.MasterDetail.Link;

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
  Janus.Client.Methods,
  Janus.RestFactory.Interfaces,
  Janus.RestDataSet.ClientDataSet,
  Janus.RestDataSet.FDMemTable,
  Test.Janus.Model.AsymKey;

type
  /// <summary> An IRESTConnection that never leaves the process. The adapters
  ///  only need it to build their session and to answer one GET; the answer is
  ///  an empty JSON array, so no row ever arrives and the only thing the test
  ///  observes is the WIRING the adapter installs afterwards. </summary>
  TInertRestConnection = class(TInterfacedObject, IRESTConnection)
  private
    FExecuteCount: Integer;
  public
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
    property ExecuteCount: Integer read FExecuteCount;
  end;

  /// <summary> Classic cracker descendant. OpenWhereInternal is protected and
  ///  FilterDataSetChilds is private, so this is the only way a test can make
  ///  the SHIPPED FilterDataSetChilds run - it is called from inside
  ///  OpenWhereInternal when the adapter owns no master of its own. </summary>
  TRestCdsCrack<M: class, constructor> = class(TRESTClientDataSetAdapter<M>)
  public
    class procedure OpenWhere(const AAdapter: TRESTClientDataSetAdapter<M>);
  end;

  TRestMemCrack<M: class, constructor> = class(TRESTFDMemTableAdapter<M>)
  public
    class procedure OpenWhere(const AAdapter: TRESTFDMemTableAdapter<M>);
  end;

  [TestFixture]
  TTestMasterDetailLink = class
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
    procedure MapNames(out AMasterColumn, AChildColumn: String);
    procedure PlainCds(out AMaster, AChild: TClientDataSet;
      out ASource: TDataSource);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// The mapping itself: which end of the association is the master's
    /// column and which is the child's. Everything below rests on this.
    [Test]
    procedure Premise_TheAssociationEndsAreNamedDifferently;

    /// The VCL contract, measured on a live pair instead of quoted from a
    /// manual: MasterFields is resolved against the MASTER dataset and
    /// IndexFieldNames against the DETAIL one.
    [Test]
    procedure Semantics_TheVCLResolvesMasterFieldsAgainstTheMaster;

    /// Order A - what TRESTFDMemTableAdapter<M>._FilterDataSetChilds sends:
    /// IndexFieldNames := ColumnsNameRef, MasterFields := ColumnsName.
    [Test]
    procedure Order_ChildIndexMasterKey_LinksAndRangesTheChild;
    /// Order B - what TRESTClientDataSetAdapter<M>.FilterDataSetChilds sent:
    /// IndexFieldNames := ColumnsName, MasterFields := ColumnsNameRef.
    [Test]
    procedure Order_MasterIndexChildKey_RaisesFieldNotFound;

    /// The SHIPPED ClientDataSet method, driven for real.
    [Test]
    procedure RestClientDataSet_InstallsMasterKeyAndChildForeignKey;
    /// The SHIPPED FDMemTable method, driven for real.
    [Test]
    procedure RestFDMemTable_InstallsMasterKeyAndChildForeignKey;
    /// ...and the link the shipped method installed resolves, field object by
    /// field object, to the two datasets it is supposed to join.
    [Test]
    procedure RestClientDataSet_TheInstalledLinkResolvesBothEnds;
  end;

implementation

const
  cEMPTYJSON = '[]';
  cMASTERKEY = 'mkey';
  cCHILDKEY  = 'cparent';

{ TInertRestConnection }

function TInertRestConnection.GetBaseURL: String;
begin
  Result := 'http://inert.local';
end;

function TInertRestConnection.GetFullURL: String;
begin
  Result := 'http://inert.local';
end;

function TInertRestConnection.GetUsername: String;
begin
  Result := '';
end;

function TInertRestConnection.GetPassword: String;
begin
  Result := '';
end;

function TInertRestConnection.GetMethodGET: String;
begin
  Result := '';
end;

function TInertRestConnection.GetMethodGETId: String;
begin
  Result := '';
end;

function TInertRestConnection.GetMethodGETWhere: String;
begin
  Result := '';
end;

function TInertRestConnection.GetMethodPOST: String;
begin
  Result := '';
end;

function TInertRestConnection.GetMethodPUT: String;
begin
  Result := '';
end;

function TInertRestConnection.GetMethodDELETE: String;
begin
  Result := '';
end;

function TInertRestConnection.GetMethodGETNextPacket: String;
begin
  Result := '';
end;

function TInertRestConnection.GetMethodGETNextPacketWhere: String;
begin
  Result := '';
end;

function TInertRestConnection.GetMethodToken: String;
begin
  Result := '';
end;

function TInertRestConnection.GetServerUse: Boolean;
begin
  Result := False;
end;

procedure TInertRestConnection.SetCommandMonitor(AMonitor: ICommandMonitor);
begin
end;

procedure TInertRestConnection.SetClassNotServerUse(const Value: Boolean);
begin
end;

function TInertRestConnection.CommandMonitor: ICommandMonitor;
begin
  Result := nil;
end;

function TInertRestConnection.Execute(const AResource, ASubResource: String;
  const ARequestMethod: TRESTRequestMethodType; const AParams: TProc): String;
begin
  Inc(FExecuteCount);
  if Assigned(AParams) then
    AParams();
  Result := cEMPTYJSON;
end;

function TInertRestConnection.Execute(const AResource: String;
  const ARequestMethod: TRESTRequestMethodType; const AParams: TProc): String;
begin
  Inc(FExecuteCount);
  if Assigned(AParams) then
    AParams();
  Result := cEMPTYJSON;
end;

procedure TInertRestConnection.AddParam(AValue: String);
begin
end;

procedure TInertRestConnection.AddQueryParam(AValue: String);
begin
end;

procedure TInertRestConnection.AddBodyParam(AValue: String);
begin
end;

{ TRestCdsCrack<M> }

class procedure TRestCdsCrack<M>.OpenWhere(
  const AAdapter: TRESTClientDataSetAdapter<M>);
begin
  TRestCdsCrack<M>(AAdapter).OpenWhereInternal('1 = 1');
end;

{ TRestMemCrack<M> }

class procedure TRestMemCrack<M>.OpenWhere(
  const AAdapter: TRESTFDMemTableAdapter<M>);
begin
  TRestMemCrack<M>(AAdapter).OpenWhereInternal('1 = 1');
end;

{ TTestMasterDetailLink }

procedure TTestMasterDetailLink.Setup;
begin
  FConn := TInertRestConnection.Create;
end;

procedure TTestMasterDetailLink.TearDown;
begin
  // Detach first: a dataset freed while another still points at its
  // TDataSource is a crash, not a test result.
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

procedure TTestMasterDetailLink.BuildCdsPair;
begin
  FMasterCds := TClientDataSet.Create(nil);
  FCdsMaster := TRESTClientDataSetAdapter<TAsymMaster>.Create(FConn,
                  FMasterCds, -1, nil);
  FChildCds := TClientDataSet.Create(nil);
  FCdsChild := TRESTClientDataSetAdapter<TAsymChild>.Create(FConn, FChildCds,
                 -1, FCdsMaster);
end;

procedure TTestMasterDetailLink.BuildMemPair;
begin
  FMasterMem := TFDMemTable.Create(nil);
  FMemMaster := TRESTFDMemTableAdapter<TAsymMaster>.Create(FConn, FMasterMem,
                  -1, nil);
  FChildMem := TFDMemTable.Create(nil);
  FMemChild := TRESTFDMemTableAdapter<TAsymChild>.Create(FConn, FChildMem, -1,
                 FMemMaster);
end;

procedure TTestMasterDetailLink.MapNames(out AMasterColumn,
  AChildColumn: String);
var
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
begin
  AMasterColumn := '';
  AChildColumn := '';
  LAssociations := TMappingExplorer.GetMappingAssociation(TAsymMaster);
  Assert.IsNotNull(LAssociations,
    'TAsymMaster must expose its association, otherwise this fixture is blind');
  for LAssociation in LAssociations do
  begin
    if LAssociation.ClassNameRef <> TAsymChild.ClassName then
      Continue;
    AMasterColumn := LAssociation.ColumnsName[0];
    AChildColumn := LAssociation.ColumnsNameRef[0];
    Exit;
  end;
  Assert.Fail('no association from TAsymMaster to TAsymChild');
end;

/// <summary> A master-detail pair built by hand, with no adapter anywhere, so
///  a test can install ONE wiring order and observe nothing but that order. </summary>
procedure TTestMasterDetailLink.PlainCds(out AMaster, AChild: TClientDataSet;
  out ASource: TDataSource);
begin
  AMaster := TClientDataSet.Create(nil);
  AMaster.FieldDefs.Add(cMASTERKEY, ftInteger);
  AMaster.FieldDefs.Add('mtag', ftString, 20);
  AMaster.CreateDataSet;

  AChild := TClientDataSet.Create(nil);
  AChild.FieldDefs.Add('ckey', ftInteger);
  AChild.FieldDefs.Add(cCHILDKEY, ftInteger);
  AChild.CreateDataSet;

  ASource := TDataSource.Create(nil);
  ASource.DataSet := AMaster;
end;

procedure TTestMasterDetailLink.Premise_TheAssociationEndsAreNamedDifferently;
var
  LMasterColumn: String;
  LChildColumn: String;
begin
  MapNames(LMasterColumn, LChildColumn);
  Assert.AreEqual(cMASTERKEY, LMasterColumn,
    'ColumnsName must be the column declared on the MASTER entity');
  Assert.AreEqual(cCHILDKEY, LChildColumn,
    'ColumnsNameRef must be the column of the REFERENCED (child) table');
  Assert.AreNotEqual(LMasterColumn, LChildColumn,
    'if the two ends shared a name this whole fixture would pass with the ' +
    'wiring swapped, which is exactly how the defect survived');
end;

procedure TTestMasterDetailLink.Semantics_TheVCLResolvesMasterFieldsAgainstTheMaster;
var
  LMaster: TClientDataSet;
  LChild: TClientDataSet;
  LSource: TDataSource;
  LMasterFields: TList<TField>;
  LDetailFields: TList<TField>;
begin
  PlainCds(LMaster, LChild, LSource);
  LMasterFields := TList<TField>.Create;
  LDetailFields := TList<TField>.Create;
  try
    LChild.MasterSource := LSource;
    LChild.IndexFieldNames := cCHILDKEY;
    LChild.MasterFields := cMASTERKEY;
    // TDataSet.GetDetailLinkFields is public and is what the VCL itself uses
    // to report the two ends of a live link.
    LChild.GetDetailLinkFields(LMasterFields, LDetailFields);
    Assert.AreEqual(1, LMasterFields.Count, 'one master field expected');
    Assert.AreEqual(1, LDetailFields.Count, 'one detail field expected');
    Assert.AreEqual(cMASTERKEY, LMasterFields[0].FieldName,
      'MasterFields names a column of the MASTER');
    Assert.IsTrue(LMasterFields[0].DataSet = LMaster,
      'and the VCL resolved it against the MASTER dataset');
    Assert.AreEqual(cCHILDKEY, LDetailFields[0].FieldName,
      'IndexFieldNames names a column of the DETAIL');
    Assert.IsTrue(LDetailFields[0].DataSet = LChild,
      'and the VCL resolved it against the DETAIL dataset');
  finally
    LChild.MasterSource := nil;
    LDetailFields.Free;
    LMasterFields.Free;
    LSource.Free;
    LChild.Free;
    LMaster.Free;
  end;
end;

procedure TTestMasterDetailLink.Order_ChildIndexMasterKey_LinksAndRangesTheChild;
var
  LMaster: TClientDataSet;
  LChild: TClientDataSet;
  LSource: TDataSource;
  LMasterColumn: String;
  LChildColumn: String;
begin
  MapNames(LMasterColumn, LChildColumn);
  PlainCds(LMaster, LChild, LSource);
  try
    LMaster.AppendRecord([1, 'A']);
    LMaster.AppendRecord([2, 'B']);
    LChild.AppendRecord([10, 1]);
    LChild.AppendRecord([11, 1]);
    LChild.AppendRecord([12, 2]);

    LChild.MasterSource := LSource;
    // The order TRESTFDMemTableAdapter<M>._FilterDataSetChilds installs.
    LChild.IndexFieldNames := LChildColumn;
    LChild.MasterFields := LMasterColumn;

    LMaster.First;
    Assert.AreEqual(2, LChild.RecordCount,
      'master row 1 owns two child rows');
    LMaster.Next;
    Assert.AreEqual(1, LChild.RecordCount,
      'master row 2 owns one child row');
  finally
    LChild.MasterSource := nil;
    LSource.Free;
    LChild.Free;
    LMaster.Free;
  end;
end;

procedure TTestMasterDetailLink.Order_MasterIndexChildKey_RaisesFieldNotFound;
var
  LMaster: TClientDataSet;
  LChild: TClientDataSet;
  LSource: TDataSource;
  LMasterColumn: String;
  LChildColumn: String;
  LMessage: String;
begin
  MapNames(LMasterColumn, LChildColumn);
  PlainCds(LMaster, LChild, LSource);
  try
    LMaster.AppendRecord([1, 'A']);
    LChild.AppendRecord([10, 1]);
    LChild.MasterSource := LSource;
    LMessage := '';
    try
      // The order TRESTClientDataSetAdapter<M>.FilterDataSetChilds used to
      // install: the MASTER column handed to the CHILD's own index.
      LChild.IndexFieldNames := LMasterColumn;
      LChild.MasterFields := LChildColumn;
    except
      on E: Exception do
        LMessage := E.ClassName + ': ' + E.Message;
    end;
    Assert.IsFalse(LMessage = '',
      'the swapped order must not be silently accepted');
    Assert.Contains(LowerCase(LMessage), LowerCase(LMasterColumn),
      'the failure must name the MASTER column that the child does not have');
  finally
    LChild.MasterSource := nil;
    LSource.Free;
    LChild.Free;
    LMaster.Free;
  end;
end;

procedure TTestMasterDetailLink.RestClientDataSet_InstallsMasterKeyAndChildForeignKey;
begin
  BuildCdsPair;
  // Runs the SHIPPED FilterDataSetChilds by way of the shipped
  // TRESTClientDataSetAdapter<M>.OpenWhereInternal.
  TRestCdsCrack<TAsymMaster>.OpenWhere(FCdsMaster);
  Assert.IsTrue(FChildCds.MasterSource <> nil,
    'the child must have been attached to the master source');
  Assert.AreEqual(cMASTERKEY, FChildCds.MasterFields,
    'MasterFields must carry the MASTER column');
  Assert.AreEqual(cCHILDKEY, FChildCds.IndexFieldNames,
    'IndexFieldNames must carry the CHILD column');
end;

procedure TTestMasterDetailLink.RestFDMemTable_InstallsMasterKeyAndChildForeignKey;
begin
  BuildMemPair;
  TRestMemCrack<TAsymMaster>.OpenWhere(FMemMaster);
  Assert.IsTrue(FChildMem.MasterSource <> nil,
    'the child must have been attached to the master source');
  Assert.AreEqual(cMASTERKEY, FChildMem.MasterFields,
    'MasterFields must carry the MASTER column');
  Assert.AreEqual(cCHILDKEY, FChildMem.IndexFieldNames,
    'IndexFieldNames must carry the CHILD column');
end;

procedure TTestMasterDetailLink.RestClientDataSet_TheInstalledLinkResolvesBothEnds;
var
  LMasterFields: TList<TField>;
  LDetailFields: TList<TField>;
begin
  BuildCdsPair;
  TRestCdsCrack<TAsymMaster>.OpenWhere(FCdsMaster);
  LMasterFields := TList<TField>.Create;
  LDetailFields := TList<TField>.Create;
  try
    // Not the strings this time: the FIELD OBJECTS the VCL itself resolves
    // from the link the shipped method installed. A MasterFields naming a
    // column the master has not got would raise right here.
    FChildCds.GetDetailLinkFields(LMasterFields, LDetailFields);
    Assert.AreEqual(1, LMasterFields.Count, 'one master field expected');
    Assert.AreEqual(1, LDetailFields.Count, 'one detail field expected');
    Assert.IsTrue(LMasterFields[0].DataSet = FMasterCds,
      'the master end must resolve inside the MASTER dataset');
    Assert.AreEqual(cMASTERKEY, LMasterFields[0].FieldName,
      'and it must be the master key');
    Assert.IsTrue(LDetailFields[0].DataSet = FChildCds,
      'the detail end must resolve inside the CHILD dataset');
    Assert.AreEqual(cCHILDKEY, LDetailFields[0].FieldName,
      'and it must be the child foreign key');
  finally
    LDetailFields.Free;
    LMasterFields.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestMasterDetailLink);

end.
