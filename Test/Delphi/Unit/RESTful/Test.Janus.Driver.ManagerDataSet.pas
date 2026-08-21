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

{ @abstract(Janus Framework - TManagerDataSet under DRIVERRESTFUL.)

  WHAT IS UNDER TEST

  Janus.Manager.DataSet, compiled with DRIVERRESTFUL ON. The unit names the
  symbol EIGHT times - counted, not estimated - and they are not all the same
  kind of thing:

    RUN by this fixture
      * the IMDConnection alias  - IRESTConnection instead of IDBConnection
      * TManagerDataSet.AddAdapter<T>(ADataSet; APageSize)
                                 - builds TRESTFDMemTableAdapter<T>
      * TManagerDataSet.AddAdapter<T, M>(ADataSet)
                                 - builds the CHILD REST adapter bound to the
                                   master REST adapter

    COMPILED by this fixture, not separately asserted
      * the uses clause          - Janus.RestDataSet.FDMemTable instead of
                                   Janus.DataSet.FDMemTable
      * the uses clause          - Janus.RestFactory.Interfaces instead of
                                   DataEngine.FactoryInterfaces
      * the two IFNDEF DRIVERRESTFUL blocks that REMOVE NextPacket<T>,
                                   GetAutoNextPacket<T> and
                                   SetAutoNextPacket<T> - declaration and
                                   bodies. See the frontier note below.

    NOT REACHED AT ALL, in any configuration Janus.inc can produce
      * the uses clause          - Janus.RestDataSet.ClientDataSet. It sits
                                   inside IFDEF USECLIENTDATASET, and Janus.inc
                                   leaves USECLIENTDATASET commented out while
                                   defining USEFDMEMTABLE unconditionally.

  WHY THIS FIXTURE HAD TO EXIST

  Measured on the base this was written against: no test binary produced
  Janus.Manager.DataSet.dcu at all. Not the REST branch - the WHOLE UNIT. The
  four test projects never name it, in either branch, so all eight sites above
  were compiled by nothing. Test.Janus.MasterDetail.Link reaches the REST
  adapters, but it does so by CONSTRUCTING them directly and by cracking a
  protected method, precisely because the supported entry point - this manager -
  was out of reach.

  WHAT `SUPPORTED ENTRY POINT` MEANS HERE

  The shape the Examples use is
      oManager := TManagerDataSet.Create(RESTClientHorse1.AsConnection);
      oManager.AddAdapter<TMaster>(FDMemTable1);
      oManager.AddAdapter<TDetail, TMaster>(FDMemTable2);
      oManager.OpenWhere<TMaster>('...');
  and that is the shape below, with the HTTP connection replaced by
  Test.Janus.RestConnection.Double. No cracker, no direct construction of an
  adapter: the master-detail link is observed exactly where a user would meet
  it.

  WHAT IT DOES NOT COVER

  1) The ClientDataSet half of the REST family. Janus.inc defines USEFDMEMTABLE
     unconditionally, so TManagerDataSet can only ever select
     TRESTFDMemTableAdapter; TRESTClientDataSetAdapter is reachable from the
     manager only in a combination Janus.inc cannot currently produce. That
     half stays where Test.Janus.MasterDetail.Link left it: covered by direct
     construction.

  2) The ABSENCE of NextPacket<T>/GetAutoNextPacket<T>/SetAutoNextPacket<T> is
     a COMPILE-time property, and it is checked only by the compiler: this
     build declares the class without them, and any call would not compile.
     There is no runtime assertion for it and there is no honest one to write -
     all three are generic methods, and Delphi emits no RTTI for generic
     methods, so an RTTI sweep for their absence would pass whether they were
     there or not. Declared, not covered.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Driver.ManagerDataSet;

interface

{$IFNDEF DRIVERRESTFUL}
  {$MESSAGE FATAL 'This unit only makes sense with DRIVERRESTFUL defined. It belongs to Janus.Tests.RESTfulDriver, whose .dproj carries the directive. If this fires, the configuration this suite exists to protect has been switched off.'}
{$ENDIF}

uses
  DB,
  Rtti,
  Classes,
  SysUtils,
  TypInfo,
  Generics.Collections,
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
  Janus.RestDataSet.FDMemTable,
  Janus.Manager.DataSet,
  Test.Janus.RestConnection.Double,
  Test.Janus.Model.AsymKey;

type
  [TestFixture]
  TTestDriverManagerDataSet = class
  private
    FConn: IRESTConnection;
    FRecorder: TRecordingRestConnection;
    FManager: TManagerDataSet;
    FMasterMem: TFDMemTable;
    FChildMem: TFDMemTable;
    procedure BuildMasterOnly;
    procedure BuildMasterDetail;
    procedure MapNames(out AMasterColumn, AChildColumn: string);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// The alias itself. Under DRIVERRESTFUL, TManagerDataSet.Create takes an
    /// IRESTConnection; under the other branch the very same declaration takes
    /// an IDBConnection and this assignment would not compile.
    [Test]
    procedure Alias_TheManagerTakesARestConnection;

    /// AddAdapter<T> must actually register the class. The method exits
    /// silently on several paths, so `no exception raised` proves nothing -
    /// the dataset has to come back out.
    [Test]
    procedure AddAdapter_RegistersTheClassAndKeepsTheDataSet;

    /// The adapter the manager built is the REST one and not the DB one: it
    /// answers an Open by going to IRESTConnection.Execute. A non-REST adapter
    /// would have gone to a driver that this manager never received.
    [Test]
    procedure AddAdapter_TheAdapterItBuiltTalksToTheRestConnection;

    /// The master-detail link, installed through the manager and observed on
    /// the child dataset. This is the same defect family as the swap fixed in
    /// TRESTClientDataSetAdapter<M>.FilterDataSetChilds, measured this time on
    /// the variant the shipped configuration actually selects.
    [Test]
    procedure MasterDetail_TheManagerInstallsMasterKeyAndChildForeignKey;

    /// ...and the installed link resolves to real field objects on both ends.
    [Test]
    procedure MasterDetail_TheInstalledLinkResolvesBothEnds;

    /// The child adapter must have been registered under the CHILD class.
    /// AddAdapter<T, M> exits silently when the master is unknown, which would
    /// leave the pair half-built and the test above vacuous.
    [Test]
    procedure MasterDetail_TheChildIsRegisteredUnderItsOwnClass;

    /// The class the manager actually put in its repository, read back by
    /// RTTI. Behaviour can be argued about; the class name cannot: it is
    /// TRESTFDMemTableAdapter under this directive and TFDMemTableAdapter
    /// under the other one.
    [Test]
    procedure Selection_TheRepositoryHoldsTheRestAdapterClass;
  end;

implementation

const
  cMASTERKEY = 'mkey';
  cCHILDKEY  = 'cparent';

{ TTestDriverManagerDataSet }

procedure TTestDriverManagerDataSet.Setup;
begin
  FRecorder := TRecordingRestConnection.Create;
  FConn := FRecorder;
  FManager := TManagerDataSet.Create(FConn);
end;

procedure TTestDriverManagerDataSet.TearDown;
begin
  // The child memtable points at a TDataSource owned by the MASTER adapter,
  // and the manager owns both adapters. Detach before anything is freed.
  if FChildMem <> nil then
    FChildMem.MasterSource := nil;
  FreeAndNil(FManager);
  FreeAndNil(FChildMem);
  FreeAndNil(FMasterMem);
  FConn := nil;
  FRecorder := nil;
end;

procedure TTestDriverManagerDataSet.BuildMasterOnly;
begin
  FMasterMem := TFDMemTable.Create(nil);
  FManager.AddAdapter<TAsymMaster>(FMasterMem);
end;

procedure TTestDriverManagerDataSet.BuildMasterDetail;
begin
  BuildMasterOnly;
  FChildMem := TFDMemTable.Create(nil);
  FManager.AddAdapter<TAsymChild, TAsymMaster>(FChildMem);
end;

procedure TTestDriverManagerDataSet.MapNames(out AMasterColumn,
  AChildColumn: string);
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

procedure TTestDriverManagerDataSet.Alias_TheManagerTakesARestConnection;
var
  LLocal: TManagerDataSet;
begin
  // The assignment is the assertion: IMDConnection has to BE IRESTConnection.
  LLocal := TManagerDataSet.Create(FConn);
  try
    Assert.IsNotNull(LLocal,
      'TManagerDataSet.Create(IRESTConnection) must produce a manager');
  finally
    LLocal.Free;
  end;
end;

procedure TTestDriverManagerDataSet.AddAdapter_RegistersTheClassAndKeepsTheDataSet;
begin
  BuildMasterOnly;
  Assert.IsTrue(FManager.DataSet<TAsymMaster> = FMasterMem,
    'AddAdapter<T> must register the class - it exits silently when it does ' +
    'not, and DataSet<T> does not come back nil either: Resolver<T> returns ' +
    'nil and DataSet<T> reads FOrmDataSet off it, raising EAccessViolation on ' +
    'address 0000000C - measured in THIS build, and 0x0C is FOrmDataSet''s own ' +
    'offset');
end;

procedure TTestDriverManagerDataSet.AddAdapter_TheAdapterItBuiltTalksToTheRestConnection;
begin
  BuildMasterOnly;
  Assert.AreEqual(0, FRecorder.CallCount,
    'building the adapter must not talk to the server by itself');
  FManager.OpenWhere<TAsymMaster>('1 = 1');
  Assert.IsTrue(FRecorder.CallCount > 0,
    'the adapter the manager built must resolve an Open through ' +
    'IRESTConnection.Execute - if it does not, the manager selected the ' +
    'non-REST adapter and the directive is not doing anything');
  Assert.AreEqual(Ord(TRESTRequestMethodType.rtGET),
    Ord(FRecorder.LastCall.RequestMethod),
    'an Open is a GET');
end;

procedure TTestDriverManagerDataSet.MasterDetail_TheManagerInstallsMasterKeyAndChildForeignKey;
var
  LMasterColumn: string;
  LChildColumn: string;
begin
  MapNames(LMasterColumn, LChildColumn);
  Assert.AreNotEqual(LMasterColumn, LChildColumn,
    'the two ends must be spelled differently, otherwise a swapped wiring ' +
    'and a correct one produce the same string and this test proves nothing');
  BuildMasterDetail;
  FManager.OpenWhere<TAsymMaster>('1 = 1');
  Assert.IsTrue(FChildMem.MasterSource <> nil,
    'the child must have been attached to the master source');
  Assert.AreEqual(cMASTERKEY, FChildMem.MasterFields,
    'MasterFields must carry the MASTER column');
  Assert.AreEqual(cCHILDKEY, FChildMem.IndexFieldNames,
    'IndexFieldNames must carry the CHILD column');
end;

procedure TTestDriverManagerDataSet.MasterDetail_TheInstalledLinkResolvesBothEnds;
var
  LMasterFields: TList<TField>;
  LDetailFields: TList<TField>;
begin
  BuildMasterDetail;
  FManager.OpenWhere<TAsymMaster>('1 = 1');
  LMasterFields := TList<TField>.Create;
  LDetailFields := TList<TField>.Create;
  try
    // Not the strings this time: the FIELD OBJECTS the VCL resolves from the
    // link the manager installed. A MasterFields naming a column the master
    // has not got raises right here.
    FChildMem.GetDetailLinkFields(LMasterFields, LDetailFields);
    Assert.AreEqual(1, LMasterFields.Count, 'one master field expected');
    Assert.AreEqual(1, LDetailFields.Count, 'one detail field expected');
    Assert.IsTrue(LMasterFields[0].DataSet = FMasterMem,
      'the master end must resolve inside the MASTER dataset');
    Assert.AreEqual(cMASTERKEY, LMasterFields[0].FieldName,
      'and it must be the master key');
    Assert.IsTrue(LDetailFields[0].DataSet = FChildMem,
      'the detail end must resolve inside the CHILD dataset');
    Assert.AreEqual(cCHILDKEY, LDetailFields[0].FieldName,
      'and it must be the child foreign key');
  finally
    LDetailFields.Free;
    LMasterFields.Free;
  end;
end;

procedure TTestDriverManagerDataSet.MasterDetail_TheChildIsRegisteredUnderItsOwnClass;
begin
  BuildMasterDetail;
  Assert.IsTrue(FManager.DataSet<TAsymChild> = FChildMem,
    'AddAdapter<T, M> exits silently when the master is not registered; if ' +
    'that happened the pair is half-built and every master-detail assertion ' +
    'above is vacuous');
end;

procedure TTestDriverManagerDataSet.Selection_TheRepositoryHoldsTheRestAdapterClass;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LField: TRttiField;
  LRepository: TDictionary<string, TObject>;
  LPair: TPair<string, TObject>;
  LNames: string;
begin
  BuildMasterOnly;
  LNames := '';
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(TManagerDataSet);
    Assert.IsNotNull(LType, 'TManagerDataSet must be visible to RTTI');
    LField := LType.GetField('FRepository');
    Assert.IsNotNull(LField,
      'FRepository must be readable through RTTI, otherwise this test is ' +
      'blind and would pass on any adapter class whatsoever');
    LRepository := TDictionary<string, TObject>(LField.GetValue(FManager).AsObject);
    Assert.IsNotNull(LRepository, 'the manager must own a repository');
    Assert.AreEqual(1, LRepository.Count,
      'exactly one adapter was added, so exactly one must be in there');
    for LPair in LRepository do
      LNames := LNames + LPair.Value.ClassName + ' ';
  finally
    LContext.Free;
  end;
  // TFDMemTableAdapter is a SUFFIX of TRESTFDMemTableAdapter, so the prefix is
  // what separates the two branches - a Pos() on the shorter name would match
  // both and prove nothing.
  Assert.IsTrue(Pos('TRESTFDMemTableAdapter', LNames) = 1,
    'AddAdapter<T> must build TRESTFDMemTableAdapter under DRIVERRESTFUL; ' +
    'the non-REST branch would leave TFDMemTableAdapter here. Found: ' + LNames);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDriverManagerDataSet);

end.
