unit TestDMLGenerator;

interface

uses
  Classes,
  DB,
  Rtti,
  SysUtils,
  Generics.Collections,
  DUnitX.TestFramework,
  DataEngine.FactoryInterfaces,
  MetaDbDiff.Mapping.Classes,
  MetaDbDiff.Mapping.Explorer,
  Janus.Command.Inserter,
  Janus.Command.Updater,
  Janus.Command.Deleter,
  Janus.Command.Selecter,
  Janus.DML.Generator.SQLite,
  Janus.Model.Client,
  Janus.Model.Master,
  Janus.Model.Detail;

type
  TFakeConnection = class(TInterfacedObject, IDBConnection)
  private
    FDriver: TDBEngineDriver;
  public
    constructor Create(ADriver: TDBEngineDriver);
    procedure Connect;
    procedure Disconnect;
    procedure ExecuteDirect(const ASQL: String); overload;
    procedure ExecuteDirect(const ASQL: String; const AParams: TParams); overload;
    procedure ExecuteScript(const AScript: String);
    procedure AddScript(const AScript: String);
    procedure ExecuteScripts;
    procedure ApplyUpdates(const ADataSets: array of IDBDataSet);
    function IsConnected: Boolean;
    function CreateQuery: IDBQuery;
    function CreateDataSet(const ASQL: String = ''): IDBDataSet;
    function GetSQLScripts: String;
    function RowsAffected: UInt32;
    function GetDriver: TDBEngineDriver;
    function CommandMonitor: ICommandMonitor;
    function MonitorCallback: TMonitorProc;
    function Options: IOptions;
    procedure SetCommandMonitor(AMonitor: ICommandMonitor);
    function _GetTransaction(const AKey: String): TComponent;
    procedure StartTransaction;
    procedure Commit;
    procedure Rollback;
    procedure AddTransaction(const AKey: String; const ATransaction: TComponent);
    procedure UseTransaction(const AKey: String);
    function TransactionActive: TComponent;
    function InTransaction: Boolean;
  end;

  [TestFixture]
  TTestDMLGenerator = class
  private
    FConnection: IDBConnection;
    function CreateClient: Tclient;
    function CreateDetail: Tdetail;
    function FindAssociation(AClass: TClass; const AClassNameRef: String): TAssociationMapping;
  public
    [Setup]
    procedure Setup;
    [Test]
    procedure TestGenerateInsert_ClientTargetsMappedTable;
    [Test]
    procedure TestGenerateInsert_ClientIncludesMappedColumns;
    [Test]
    procedure TestGenerateInsert_ClientOmitsNullBlob;
    [Test]
    procedure TestGenerateInsert_ClientBuildsExpectedParamCount;
    [Test]
    procedure TestGenerateInsert_ClientBuildsPrimaryKeyParam;
    [Test]
    procedure TestGenerateInsert_ClientBuildsNameParam;
    [Test]
    procedure TestGenerateInsert_ClientPreservesBindPlaceholderWithoutQuotes;
    [Test]
    procedure TestGenerateUpdate_ClientTargetsMappedTable;
    [Test]
    procedure TestGenerateUpdate_ClientBuildsSetClause;
    [Test]
    procedure TestGenerateUpdate_ClientBuildsWhereClause;
    [Test]
    procedure TestGenerateUpdate_ClientPreservesBindPlaceholderWithoutQuotes;
    [Test]
    procedure TestGenerateUpdate_EmptyChangesReturnsEmptySql;
    [Test]
    procedure TestGenerateUpdate_ClientBuildsExpectedParamCount;
    [Test]
    procedure TestGenerateDelete_ClientTargetsMappedTable;
    [Test]
    procedure TestGenerateDelete_ClientBuildsPrimaryKeyParam;
    [Test]
    procedure TestGenerateSelectAll_ClientBuildsSelect;
    [Test]
    procedure TestGenerateSelectAll_ClientIncludesConfiguredOrderBy;
    [Test]
    procedure TestGenerateSelectId_ClientBuildsPrimaryKeyPredicate;
    [Test]
    procedure TestGenerateSelectWhere_PreservesPercentWildcard;
    [Test]
    procedure TestGenerateSelect_FirebirdWithWhere_ProducesCorrectSQL;
    [Test]
    procedure TestGenerateSelect_SQLiteWithPagination_ProducesLimitOffset;
    [Test]
    procedure TestGenerateSelect_FirebirdWithJoin_ProducesJoinClause;
    [Test]
    procedure TestGenerateSelect_SQLiteOrderBy_AppendsOrderByClause;
    [Test]
    procedure TestGenerateInsert_MultiColumn_PreservesAllPlaceholders;
    [Test]
    procedure TestGenerateUpdate_MultiField_AllPlaceholdersWithoutQuotes;
    [Test]
    procedure TestGenerateNextPacket_UsesSqlitePagination;
    [Test]
    procedure TestGenerateSelectOneToOne_UsesAssociationColumns;
    [Test]
    procedure TestGenerateSelectOneToMany_UsesAssociationColumns;
    [Test]
    procedure TestGenerateSelectAll_MasterIncludesJoinAndScope;
  end;

implementation

constructor TFakeConnection.Create(ADriver: TDBEngineDriver);
begin
  inherited Create;
  FDriver := ADriver;
end;

procedure TFakeConnection.AddScript(const AScript: String);
begin
end;

procedure TFakeConnection.AddTransaction(const AKey: String;
  const ATransaction: TComponent);
begin
end;

procedure TFakeConnection.ApplyUpdates(const ADataSets: array of IDBDataSet);
begin
end;

function TFakeConnection.CommandMonitor: ICommandMonitor;
begin
  Result := nil;
end;

procedure TFakeConnection.Commit;
begin
end;

procedure TFakeConnection.Connect;
begin
end;

function TFakeConnection.CreateDataSet(const ASQL: String): IDBDataSet;
begin
  Result := nil;
end;

function TFakeConnection.CreateQuery: IDBQuery;
begin
  Result := nil;
end;

procedure TFakeConnection.Disconnect;
begin
end;

procedure TFakeConnection.ExecuteDirect(const ASQL: String);
begin
end;

procedure TFakeConnection.ExecuteDirect(const ASQL: String; const AParams: TParams);
begin
end;

procedure TFakeConnection.ExecuteScript(const AScript: String);
begin
end;

procedure TFakeConnection.ExecuteScripts;
begin
end;

function TFakeConnection.GetDriver: TDBEngineDriver;
begin
  Result := FDriver;
end;

function TFakeConnection.GetSQLScripts: String;
begin
  Result := '';
end;

function TFakeConnection.InTransaction: Boolean;
begin
  Result := False;
end;

function TFakeConnection.IsConnected: Boolean;
begin
  Result := False;
end;

function TFakeConnection.MonitorCallback: TMonitorProc;
begin
  Result := nil;
end;

function TFakeConnection.Options: IOptions;
begin
  Result := nil;
end;

procedure TFakeConnection.Rollback;
begin
end;

function TFakeConnection.RowsAffected: UInt32;
begin
  Result := 0;
end;

procedure TFakeConnection.SetCommandMonitor(AMonitor: ICommandMonitor);
begin
end;

procedure TFakeConnection.StartTransaction;
begin
end;

function TFakeConnection.TransactionActive: TComponent;
begin
  Result := nil;
end;

procedure TFakeConnection.UseTransaction(const AKey: String);
begin
end;

function TFakeConnection._GetTransaction(const AKey: String): TComponent;
begin
  Result := nil;
end;

function TTestDMLGenerator.CreateClient: Tclient;
begin
  Result := Tclient.Create;
  Result.client_id := 1;
  Result.client_name := 'Acme';
end;

function TTestDMLGenerator.CreateDetail: Tdetail;
begin
  Result := Tdetail.Create;
  Result.detail_id := 10;
  Result.master_id := 1;
  Result.lookup_id := 3;
  Result.lookup_description := 'Item A';
  Result.price := 25.5;
end;

function TTestDMLGenerator.FindAssociation(AClass: TClass;
  const AClassNameRef: String): TAssociationMapping;
var
  LAssociation: TAssociationMapping;
  LAssociations: TAssociationMappingList;
begin
  Result := nil;
  LAssociations := TMappingExplorer.GetMappingAssociation(AClass);
  for LAssociation in LAssociations do
    if SameText(LAssociation.ClassNameRef, AClassNameRef) then
      Exit(LAssociation);
end;

procedure TTestDMLGenerator.Setup;
begin
  FConnection := TFakeConnection.Create(dnSQLite);
end;

procedure TTestDMLGenerator.TestGenerateInsert_ClientTargetsMappedTable;
var
  LClient: Tclient;
  LInserter: TCommandInserter;
  LSQL: String;
begin
  LClient := CreateClient;
  try
    LInserter := TCommandInserter.Create(FConnection, dnSQLite, LClient);
    try
      LSQL := LowerCase(LInserter.GenerateInsert(LClient));
      Assert.Contains(LSQL, 'insert into client');
    finally
      LInserter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateInsert_ClientIncludesMappedColumns;
var
  LClient: Tclient;
  LInserter: TCommandInserter;
  LSQL: String;
begin
  LClient := CreateClient;
  try
    LInserter := TCommandInserter.Create(FConnection, dnSQLite, LClient);
    try
      LSQL := LowerCase(LInserter.GenerateInsert(LClient));
      Assert.Contains(LSQL, 'client_id');
      Assert.Contains(LSQL, 'client_name');
    finally
      LInserter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateInsert_ClientOmitsNullBlob;
var
  LClient: Tclient;
  LInserter: TCommandInserter;
  LSQL: String;
begin
  LClient := CreateClient;
  try
    LInserter := TCommandInserter.Create(FConnection, dnSQLite, LClient);
    try
      LSQL := LowerCase(LInserter.GenerateInsert(LClient));
      Assert.DoesNotContain(LSQL, 'client_foto');
    finally
      LInserter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateInsert_ClientBuildsExpectedParamCount;
var
  LClient: Tclient;
  LInserter: TCommandInserter;
begin
  LClient := CreateClient;
  try
    LInserter := TCommandInserter.Create(FConnection, dnSQLite, LClient);
    try
      LInserter.GenerateInsert(LClient);
      Assert.AreEqual(2, LInserter.Params.Count);
    finally
      LInserter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateInsert_ClientBuildsPrimaryKeyParam;
var
  LClient: Tclient;
  LInserter: TCommandInserter;
begin
  LClient := CreateClient;
  try
    LInserter := TCommandInserter.Create(FConnection, dnSQLite, LClient);
    try
      LInserter.GenerateInsert(LClient);
      Assert.AreEqual('client_id', LInserter.Params.ParamByName('client_id').Name);
      Assert.AreEqual(1, LInserter.Params.ParamByName('client_id').AsInteger);
    finally
      LInserter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateInsert_ClientBuildsNameParam;
var
  LClient: Tclient;
  LInserter: TCommandInserter;
begin
  LClient := CreateClient;
  try
    LInserter := TCommandInserter.Create(FConnection, dnSQLite, LClient);
    try
      LInserter.GenerateInsert(LClient);
      Assert.AreEqual('Acme', LInserter.Params.ParamByName('client_name').AsString);
    finally
      LInserter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateInsert_ClientPreservesBindPlaceholderWithoutQuotes;
var
  LClient: Tclient;
  LInserter: TCommandInserter;
  LSQL: String;
begin
  LClient := CreateClient;
  try
    LInserter := TCommandInserter.Create(FConnection, dnSQLite, LClient);
    try
      LSQL := LowerCase(LInserter.GenerateInsert(LClient));
      Assert.Contains(LSQL, ':client_name');
      Assert.DoesNotContain(LSQL, ''':client_name''');
    finally
      LInserter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateUpdate_ClientTargetsMappedTable;
var
  LChanges: TDictionary<String, String>;
  LClient: Tclient;
  LUpdater: TCommandUpdater;
  LSQL: String;
begin
  LChanges := TDictionary<String, String>.Create;
  LClient := CreateClient;
  try
    LChanges.Add('client_name', 'client_name');
    LUpdater := TCommandUpdater.Create(FConnection, dnSQLite, LClient);
    try
      LSQL := LowerCase(LUpdater.GenerateUpdate(LClient, LChanges));
      Assert.Contains(LSQL, 'update client');
    finally
      LUpdater.Free;
    end;
  finally
    LClient.Free;
    LChanges.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateUpdate_ClientBuildsSetClause;
var
  LChanges: TDictionary<String, String>;
  LClient: Tclient;
  LUpdater: TCommandUpdater;
  LSQL: String;
begin
  LChanges := TDictionary<String, String>.Create;
  LClient := CreateClient;
  try
    LChanges.Add('client_name', 'client_name');
    LUpdater := TCommandUpdater.Create(FConnection, dnSQLite, LClient);
    try
      LSQL := LowerCase(LUpdater.GenerateUpdate(LClient, LChanges));
      Assert.Contains(LSQL, 'set');
      Assert.Contains(LSQL, 'client_name');
    finally
      LUpdater.Free;
    end;
  finally
    LClient.Free;
    LChanges.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateUpdate_ClientBuildsWhereClause;
var
  LChanges: TDictionary<String, String>;
  LClient: Tclient;
  LUpdater: TCommandUpdater;
  LSQL: String;
begin
  LChanges := TDictionary<String, String>.Create;
  LClient := CreateClient;
  try
    LChanges.Add('client_name', 'client_name');
    LUpdater := TCommandUpdater.Create(FConnection, dnSQLite, LClient);
    try
      LSQL := LowerCase(LUpdater.GenerateUpdate(LClient, LChanges));
      Assert.Contains(LSQL, 'where');
      Assert.Contains(LSQL, 'client_id');
    finally
      LUpdater.Free;
    end;
  finally
    LClient.Free;
    LChanges.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateUpdate_ClientPreservesBindPlaceholderWithoutQuotes;
var
  LChanges: TDictionary<String, String>;
  LClient: Tclient;
  LUpdater: TCommandUpdater;
  LSQL: String;
begin
  LChanges := TDictionary<String, String>.Create;
  LClient := CreateClient;
  try
    LChanges.Add('client_name', 'client_name');
    LUpdater := TCommandUpdater.Create(FConnection, dnSQLite, LClient);
    try
      LSQL := LowerCase(LUpdater.GenerateUpdate(LClient, LChanges));
      Assert.Contains(LSQL, ':client_name');
      Assert.DoesNotContain(LSQL, ''':client_name''');
    finally
      LUpdater.Free;
    end;
  finally
    LClient.Free;
    LChanges.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateUpdate_EmptyChangesReturnsEmptySql;
var
  LChanges: TDictionary<String, String>;
  LClient: Tclient;
  LUpdater: TCommandUpdater;
begin
  LChanges := TDictionary<String, String>.Create;
  LClient := CreateClient;
  try
    LUpdater := TCommandUpdater.Create(FConnection, dnSQLite, LClient);
    try
      Assert.AreEqual('', LUpdater.GenerateUpdate(LClient, LChanges));
    finally
      LUpdater.Free;
    end;
  finally
    LClient.Free;
    LChanges.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateUpdate_ClientBuildsExpectedParamCount;
var
  LChanges: TDictionary<String, String>;
  LClient: Tclient;
  LUpdater: TCommandUpdater;
begin
  LChanges := TDictionary<String, String>.Create;
  LClient := CreateClient;
  try
    LChanges.Add('client_name', 'client_name');
    LUpdater := TCommandUpdater.Create(FConnection, dnSQLite, LClient);
    try
      LUpdater.GenerateUpdate(LClient, LChanges);
      Assert.AreEqual(2, LUpdater.Params.Count);
    finally
      LUpdater.Free;
    end;
  finally
    LClient.Free;
    LChanges.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateDelete_ClientTargetsMappedTable;
var
  LClient: Tclient;
  LDeleter: TCommandDeleter;
  LSQL: String;
begin
  LClient := CreateClient;
  try
    LDeleter := TCommandDeleter.Create(FConnection, dnSQLite, LClient);
    try
      LSQL := LowerCase(LDeleter.GenerateDelete(LClient));
      Assert.Contains(LSQL, 'delete from client');
    finally
      LDeleter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateDelete_ClientBuildsPrimaryKeyParam;
var
  LClient: Tclient;
  LDeleter: TCommandDeleter;
begin
  LClient := CreateClient;
  try
    LDeleter := TCommandDeleter.Create(FConnection, dnSQLite, LClient);
    try
      LDeleter.GenerateDelete(LClient);
      Assert.AreEqual(1, LDeleter.Params.Count);
      Assert.AreEqual('client_id', LDeleter.Params[0].Name);
    finally
      LDeleter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateSelectAll_ClientBuildsSelect;
var
  LClient: Tclient;
  LSelecter: TCommandSelecter;
  LSQL: String;
begin
  LClient := CreateClient;
  try
    LSelecter := TCommandSelecter.Create(FConnection, dnSQLite, LClient);
    try
      LSQL := LowerCase(LSelecter.GenerateSelectAll(Tclient));
      Assert.Contains(LSQL, 'select');
      Assert.Contains(LSQL, 'from client');
    finally
      LSelecter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateSelectAll_ClientIncludesConfiguredOrderBy;
var
  LClient: Tclient;
  LSelecter: TCommandSelecter;
  LSQL: String;
begin
  LClient := CreateClient;
  try
    LSelecter := TCommandSelecter.Create(FConnection, dnSQLite, LClient);
    try
      LSQL := LowerCase(LSelecter.GenerateSelectAll(Tclient));
      Assert.Contains(LSQL, 'order by');
      Assert.Contains(LSQL, 'client.client_id');
    finally
      LSelecter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateSelectId_ClientBuildsPrimaryKeyPredicate;
var
  LClient: Tclient;
  LSelecter: TCommandSelecter;
  LSQL: String;
begin
  LClient := CreateClient;
  try
    LSelecter := TCommandSelecter.Create(FConnection, dnSQLite, LClient);
    try
      LSQL := LowerCase(LSelecter.GenerateSelectID(Tclient, 10));
      Assert.Contains(LSQL, 'where');
      Assert.Contains(LSQL, 'client.client_id = 10');
    finally
      LSelecter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateSelectWhere_PreservesPercentWildcard;
var
  LClient: Tclient;
  LSelecter: TCommandSelecter;
  LSQL: String;
begin
  LClient := CreateClient;
  try
    LSelecter := TCommandSelecter.Create(FConnection, dnSQLite, LClient);
    try
      LSelecter.SetPageSize(-1);
      LSQL := LSelecter.GeneratorSelectWhere(Tclient, 'client_name LIKE ''A%''', 'client_name');
      Assert.Contains(LSQL, 'A%');
      Assert.DoesNotContain(LSQL, 'A$');
    finally
      LSelecter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateSelect_FirebirdWithWhere_ProducesCorrectSQL;
var
  LClient: Tclient;
  LConnection: IDBConnection;
  LSelecter: TCommandSelecter;
  LSQL: String;
begin
  LClient := CreateClient;
  LConnection := TFakeConnection.Create(dnFirebird);
  try
    LSelecter := TCommandSelecter.Create(LConnection, dnFirebird, LClient);
    try
      LSelecter.SetPageSize(10);
      LSQL := LowerCase(LSelecter.GeneratorSelectWhere(Tclient,
        'client_name like ''A%''', 'client_name'));
      Assert.Contains(LSQL, 'select first');
      Assert.Contains(LSQL, 'skip');
      Assert.Contains(LSQL, 'where client_name like ''a%''');
    finally
      LSelecter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateSelect_SQLiteWithPagination_ProducesLimitOffset;
var
  LClient: Tclient;
  LSelecter: TCommandSelecter;
  LSQL: String;
begin
  LClient := CreateClient;
  try
    LSelecter := TCommandSelecter.Create(FConnection, dnSQLite, LClient);
    try
      LSelecter.SetPageSize(10);
      LSQL := LowerCase(LSelecter.GeneratorSelectWhere(Tclient,
        'client_name like ''A%''', 'client_name'));
      Assert.Contains(LSQL, 'where client_name like ''a%''');
      Assert.Contains(LSQL, 'order by client_name');
      Assert.Contains(LSQL, 'limit');
      Assert.Contains(LSQL, 'offset');
    finally
      LSelecter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateSelect_FirebirdWithJoin_ProducesJoinClause;
var
  LMaster: Tmaster;
  LConnection: IDBConnection;
  LSelecter: TCommandSelecter;
  LSQL: String;
begin
  LMaster := Tmaster.Create;
  LConnection := TFakeConnection.Create(dnFirebird);
  try
    LSelecter := TCommandSelecter.Create(LConnection, dnFirebird, LMaster);
    try
      LSQL := LowerCase(LSelecter.GenerateSelectAll(Tmaster));
      Assert.Contains(LSQL, 'join client');
      Assert.Contains(LSQL, 'aliastable.client_name as aliascollumn');
    finally
      LSelecter.Free;
    end;
  finally
    LMaster.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateSelect_SQLiteOrderBy_AppendsOrderByClause;
var
  LClient: Tclient;
  LSelecter: TCommandSelecter;
  LSQL: String;
begin
  LClient := CreateClient;
  try
    LSelecter := TCommandSelecter.Create(FConnection, dnSQLite, LClient);
    try
      LSelecter.SetPageSize(-1);
      LSQL := LowerCase(LSelecter.GeneratorSelectWhere(Tclient,
        'client_id = 1', 'client_name desc'));
      Assert.Contains(LSQL, 'where client_id = 1');
      Assert.Contains(LSQL, 'order by client_name desc');
    finally
      LSelecter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateInsert_MultiColumn_PreservesAllPlaceholders;
var
  LDetail: Tdetail;
  LInserter: TCommandInserter;
  LSQL: String;
begin
  LDetail := CreateDetail;
  try
    LInserter := TCommandInserter.Create(FConnection, dnSQLite, LDetail);
    try
      LSQL := LowerCase(LInserter.GenerateInsert(LDetail));
      Assert.Contains(LSQL, ':detail_id');
      Assert.Contains(LSQL, ':master_id');
      Assert.Contains(LSQL, ':lookup_id');
      Assert.Contains(LSQL, ':lookup_description');
      Assert.DoesNotContain(LSQL, ''':detail_id''');
      Assert.DoesNotContain(LSQL, ''':lookup_description''');
    finally
      LInserter.Free;
    end;
  finally
    LDetail.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateUpdate_MultiField_AllPlaceholdersWithoutQuotes;
var
  LChanges: TDictionary<String, String>;
  LDetail: Tdetail;
  LUpdater: TCommandUpdater;
  LSQL: String;
begin
  LChanges := TDictionary<String, String>.Create;
  LDetail := CreateDetail;
  try
    LChanges.Add('lookup_id', 'lookup_id');
    LChanges.Add('lookup_description', 'lookup_description');
    LUpdater := TCommandUpdater.Create(FConnection, dnSQLite, LDetail);
    try
      LSQL := LowerCase(LUpdater.GenerateUpdate(LDetail, LChanges));
      Assert.Contains(LSQL, ':lookup_id');
      Assert.Contains(LSQL, ':lookup_description');
      Assert.DoesNotContain(LSQL, ''':lookup_id''');
      Assert.DoesNotContain(LSQL, ''':lookup_description''');
    finally
      LUpdater.Free;
    end;
  finally
    LDetail.Free;
    LChanges.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateNextPacket_UsesSqlitePagination;
var
  LClient: Tclient;
  LSelecter: TCommandSelecter;
  LSQL: String;
begin
  LClient := CreateClient;
  try
    LSelecter := TCommandSelecter.Create(FConnection, dnSQLite, LClient);
    try
      LSQL := LowerCase(LSelecter.GenerateNextPacket(Tclient, 10, 20));
      Assert.Contains(LSQL, 'limit 10');
      Assert.Contains(LSQL, 'offset 20');
    finally
      LSelecter.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateSelectOneToOne_UsesAssociationColumns;
var
  LAssociation: TAssociationMapping;
  LMaster: Tmaster;
  LSelecter: TCommandSelecter;
  LSQL: String;
begin
  LMaster := Tmaster.Create;
  try
    LMaster.client_id := 5;
    LAssociation := FindAssociation(Tmaster, 'Tclient');
    LSelecter := TCommandSelecter.Create(FConnection, dnSQLite, LMaster);
    try
      LSQL := LowerCase(LSelecter.GenerateSelectOneToOne(LMaster, Tclient, LAssociation));
      Assert.Contains(LSQL, 'where');
      Assert.Contains(LSQL, 'client.client_id = 5');
    finally
      LSelecter.Free;
    end;
  finally
    LMaster.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateSelectOneToMany_UsesAssociationColumns;
var
  LAssociation: TAssociationMapping;
  LMaster: Tmaster;
  LSelecter: TCommandSelecter;
  LSQL: String;
begin
  LMaster := Tmaster.Create;
  try
    LMaster.master_id := 9;
    LAssociation := FindAssociation(Tmaster, 'Tdetail');
    LSelecter := TCommandSelecter.Create(FConnection, dnSQLite, LMaster);
    try
      LSQL := LowerCase(LSelecter.GenerateSelectOneToMany(LMaster, Tdetail, LAssociation));
      Assert.Contains(LSQL, 'where');
      Assert.Contains(LSQL, 'detail.master_id = 9');
    finally
      LSelecter.Free;
    end;
  finally
    LMaster.Free;
  end;
end;

procedure TTestDMLGenerator.TestGenerateSelectAll_MasterIncludesJoinAndScope;
var
  LMaster: Tmaster;
  LSelecter: TCommandSelecter;
  LSQL: String;
begin
  LMaster := Tmaster.Create;
  try
    LSelecter := TCommandSelecter.Create(FConnection, dnSQLite, LMaster);
    try
      LSQL := LowerCase(LSelecter.GenerateSelectAll(Tmaster));
      Assert.Contains(LSQL, 'join client');
      Assert.Contains(LSQL, 'client_name');
      Assert.Contains(LSQL, 'master.master_id > 6');
      Assert.Contains(LSQL, 'master.description');
    finally
      LSelecter.Free;
    end;
  finally
    LMaster.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDMLGenerator);

end.