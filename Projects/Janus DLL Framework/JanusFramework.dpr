library JanusFramework;

{ Important note about DLL memory management: ShareMem must be the
  first unit in your library's USES clause AND your project's (select
  Project-View Source) USES clause if your DLL exports any procedures or
  functions that pass strings as parameters or function results. This
  applies to all strings passed to and from your DLL--even those that
  are nested in records and classes. ShareMem is the interface unit to
  the BORLNDMM.DLL shared memory manager, which must be deployed along
  with your DLL. To avoid using BORLNDMM.DLL, pass string information
  using PChar or ShortString parameters. }

uses
  System.SysUtils,
  System.Classes,
  FireDAC.Comp.Client,
  DataEngine.FactoryInterfaces in '..\..\Source\Dependencies\DataEngine\Core\DataEngine.FactoryInterfaces.pas',
  DataEngine.FactoryFireDac in '..\..\Source\Dependencies\DataEngine\Drivers\DataEngine.FactoryFireDac.pas',
  Janus.DLL.Interfaces in 'Janus.DLL.Interfaces.pas',
  Janus.DLL.Entity.Proxy in 'Source\Janus.DLL.Entity.Proxy.pas',
  Janus.DLL.JanusRecord.Facade in 'Source\Janus.DLL.JanusRecord.Facade.pas',
  Janus.DLL.ObjectSet.Facade in 'Source\Janus.DLL.ObjectSet.Facade.pas',
  Janus.DLL.Connection.Facade in 'Source\Janus.DLL.Connection.Facade.pas',
  Janus.DLL.Models.Registry in 'Source\Janus.DLL.Models.Registry.pas',
  Janus.DLL.Model.Client in 'Source\Models\Janus.DLL.Model.Client.pas',
  Janus.DLL.Query.Facade in 'Source\Janus.DLL.Query.Facade.pas',
  Janus.DLL.Dynamic.Entity.Registry in 'Source\Janus.DLL.Dynamic.Entity.Registry.pas',
  Janus.DLL.Dynamic.Proxy in 'Source\Janus.DLL.Dynamic.Proxy.pas',
  Janus.DLL.Entity.Builder in 'Source\Janus.DLL.Entity.Builder.pas',
  Janus.Bind in '..\..\Source\Core\Janus.Bind.pas',
  Janus.Command.Abstract in '..\..\Source\Core\Janus.Command.Abstract.pas',
  Janus.Command.Deleter in '..\..\Source\Core\Janus.Command.Deleter.pas',
  Janus.Command.Factory in '..\..\Source\Core\Janus.Command.Factory.pas',
  Janus.Command.Inserter in '..\..\Source\Core\Janus.Command.Inserter.pas',
  Janus.Command.Selecter in '..\..\Source\Core\Janus.Command.Selecter.pas',
  Janus.Command.Updater in '..\..\Source\Core\Janus.Command.Updater.pas',
  Janus.Core.Consts in '..\..\Source\Core\Janus.Core.Consts.pas',
  Janus.DML.Cache in '..\..\Source\Core\Janus.DML.Cache.pas',
  Janus.DML.Commands in '..\..\Source\Core\Janus.DML.Commands.pas',
  Janus.DML.Generator.AbsoluteDB in '..\..\Source\Core\Janus.DML.Generator.AbsoluteDB.pas',
  Janus.DML.Generator.ADS in '..\..\Source\Core\Janus.DML.Generator.ADS.pas',
  Janus.DML.Generator.ElevateDB in '..\..\Source\Core\Janus.DML.Generator.ElevateDB.pas',
  Janus.DML.Generator.Firebird in '..\..\Source\Core\Janus.DML.Generator.Firebird.pas',
  Janus.DML.Generator.InterBase in '..\..\Source\Core\Janus.DML.Generator.InterBase.pas',
  Janus.DML.Generator.MongoDB in '..\..\Source\Core\Janus.DML.Generator.MongoDB.pas',
  Janus.DML.Generator.MSSQL in '..\..\Source\Core\Janus.DML.Generator.MSSQL.pas',
  Janus.DML.Generator.MySQL in '..\..\Source\Core\Janus.DML.Generator.MySQL.pas',
  Janus.DML.Generator.NexusDB in '..\..\Source\Core\Janus.DML.Generator.NexusDB.pas',
  Janus.DML.Generator.NoSQL in '..\..\Source\Core\Janus.DML.Generator.NoSQL.pas',
  Janus.DML.Generator.Oracle in '..\..\Source\Core\Janus.DML.Generator.Oracle.pas',
  Janus.DML.Generator in '..\..\Source\Core\Janus.DML.Generator.pas',
  Janus.DML.Generator.PostgreSQL in '..\..\Source\Core\Janus.DML.Generator.PostgreSQL.pas',
  Janus.DML.Generator.SQLite in '..\..\Source\Core\Janus.DML.Generator.SQLite.pas',
  Janus.DML.Interfaces in '..\..\Source\Core\Janus.DML.Interfaces.pas',
  Janus.Driver.Register in '..\..\Source\Core\Janus.Driver.Register.pas',
  Janus.Json in '..\..\Source\Core\Janus.Json.pas',
  Janus.Objects.Helper in '..\..\Source\Core\Janus.Objects.Helper.pas',
  Janus.Objects.Utils in '..\..\Source\Core\Janus.Objects.Utils.pas',
  Janus.RTTI.Helper in '..\..\Source\Core\Janus.RTTI.Helper.pas',
  Janus.Session.Abstract in '..\..\Source\Core\Janus.Session.Abstract.pas',
  Janus.Types.Blob in '..\..\Source\Core\Janus.Types.Blob.pas',
  Janus.Types.Lazy in '..\..\Source\Core\Janus.Types.Lazy.pas',
  Janus.Types.Nullable in '..\..\Source\Core\Janus.Types.Nullable.pas',
  Janus.Utils in '..\..\Source\Core\Janus.Utils.pas',
  Janus.Container.ObjectSet.Interfaces in '..\..\Source\Objectset\Janus.Container.ObjectSet.Interfaces.pas',
  Janus.Container.ObjectSet in '..\..\Source\Objectset\Janus.Container.ObjectSet.pas',
  Janus.Manager.ObjectSet in '..\..\Source\Objectset\Janus.Manager.ObjectSet.pas',
  Janus.ObjectSet.Abstract in '..\..\Source\Objectset\Janus.ObjectSet.Abstract.pas',
  Janus.ObjectSet.Adapter in '..\..\Source\Objectset\Janus.ObjectSet.Adapter.pas',
  Janus.ObjectSet.Base.Adapter in '..\..\Source\Objectset\Janus.ObjectSet.Base.Adapter.pas',
  Janus.Session.ObjectSet in '..\..\Source\Objectset\Janus.Session.ObjectSet.pas';

{$R *.res}

function NewManagerObjectSet: TManagerObjectSet; stdcall; export;
begin
  Result := TManagerObjectSet.Create(nil);
end;

function RegisterModels: LongBool; stdcall; export;
begin
  try
    RegisterAllModels;
    Result := True;
  except
    Result := False;
  end;
end;

function ConnectSQLite(ADatabase: PWideChar): IJanusConnection; stdcall; export;
var
  LFDConn: TFDConnection;
  LConn: IDBConnection;
begin
  Result := nil;
  LFDConn := nil;
  try
    LFDConn := TFDConnection.Create(nil);
    LFDConn.Params.DriverID := 'SQLite';
    LFDConn.Params.Database := string(ADatabase);
    LFDConn.LoginPrompt := False;
    LFDConn.Connected := True;
    LConn := TFactoryFiredac.Create(LFDConn, dnSQLite);
    Result := TJanusConnection.Create(LConn, LFDConn);
  except
    FreeAndNil(LFDConn);
    Result := nil;
  end;
end;

function ConnectFirebird(AHost, ADatabase, AUser, APass: PWideChar): IJanusConnection; stdcall; export;
var
  LFDConn: TFDConnection;
  LConn: IDBConnection;
begin
  Result := nil;
  LFDConn := nil;
  try
    LFDConn := TFDConnection.Create(nil);
    LFDConn.Params.DriverID := 'FB';
    LFDConn.Params.Values['Server'] := string(AHost);
    LFDConn.Params.Database := string(ADatabase);
    LFDConn.Params.Values['User_Name'] := string(AUser);
    LFDConn.Params.Values['Password'] := string(APass);
    LFDConn.LoginPrompt := False;
    LFDConn.Connected := True;
    LConn := TFactoryFiredac.Create(LFDConn, dnFirebird);
    Result := TJanusConnection.Create(LConn, LFDConn);
  except
    FreeAndNil(LFDConn);
    Result := nil;
  end;
end;

function ConnectMySQL(AHost, ADatabase, AUser, APass: PWideChar; APort: Integer): IJanusConnection; stdcall; export;
var
  LFDConn: TFDConnection;
  LConn: IDBConnection;
begin
  Result := nil;
  LFDConn := nil;
  try
    LFDConn := TFDConnection.Create(nil);
    LFDConn.Params.DriverID := 'MySQL';
    LFDConn.Params.Values['Server'] := string(AHost);
    LFDConn.Params.Database := string(ADatabase);
    LFDConn.Params.Values['User_Name'] := string(AUser);
    LFDConn.Params.Values['Password'] := string(APass);
    LFDConn.Params.Values['Port'] := IntToStr(APort);
    LFDConn.LoginPrompt := False;
    LFDConn.Connected := True;
    LConn := TFactoryFiredac.Create(LFDConn, dnMySQL);
    Result := TJanusConnection.Create(LConn, LFDConn);
  except
    FreeAndNil(LFDConn);
    Result := nil;
  end;
end;

function ConnectPostgreSQL(AHost, ADatabase, AUser, APass: PWideChar; APort: Integer): IJanusConnection; stdcall; export;
var
  LFDConn: TFDConnection;
  LConn: IDBConnection;
begin
  Result := nil;
  LFDConn := nil;
  try
    LFDConn := TFDConnection.Create(nil);
    LFDConn.Params.DriverID := 'PG';
    LFDConn.Params.Values['Server'] := string(AHost);
    LFDConn.Params.Database := string(ADatabase);
    LFDConn.Params.Values['User_Name'] := string(AUser);
    LFDConn.Params.Values['Password'] := string(APass);
    LFDConn.Params.Values['Port'] := IntToStr(APort);
    LFDConn.LoginPrompt := False;
    LFDConn.Connected := True;
    LConn := TFactoryFiredac.Create(LFDConn, dnPostgreSQL);
    Result := TJanusConnection.Create(LConn, LFDConn);
  except
    FreeAndNil(LFDConn);
    Result := nil;
  end;
end;

function CreateObjectSet(AEntityName: PWideChar;
  AConn: IJanusConnection): IJanusObjectSet; stdcall; export;
var
  LEntityName:   string;
  LInternalConn: IJanusConnectionInternal;
  LProxy:        TEntityProxyBase;
  LSchema:       TEntitySchema;
  LDBConn:       IDBConnection;
begin
  Result      := nil;
  LEntityName := string(AEntityName);
  if not Supports(AConn, IJanusConnectionInternal, LInternalConn) then
    Exit;
  // Strategy 1: modelo Delphi pré-compilado
  if TEntityProxyRegistry.Instance.HasFactory(LEntityName) then
  begin
    LDBConn := LInternalConn.InternalConnection;
    LProxy  := TEntityProxyRegistry.Instance.CreateProxy(LEntityName, LDBConn);
    if Assigned(LProxy) then
      Result := TJanusObjectSet.Create(LProxy);
    Exit;
  end;
  // Strategy 2: entidade registrada via IJanusEntityBuilder
  LSchema := TDynamicEntityRegistry.Instance.FindSchema(LEntityName);
  if Assigned(LSchema) then
    Result := TDynamicObjectSet.Create(LSchema, AConn);
end;

// SPRINT-02 — MSSQL driver
// FireDAC params: DriverID='MSSQL', Server=host, Database, User_Name, Password, Port
function ConnectMSSQL(AHost, ADatabase, AUser, APass: PWideChar;
  APort: Integer): IJanusConnection; stdcall; export;
var
  LFDConn: TFDConnection;
  LConn: IDBConnection;
begin
  Result := nil;
  LFDConn := nil;
  try
    LFDConn := TFDConnection.Create(nil);
    LFDConn.Params.DriverID := 'MSSQL';
    LFDConn.Params.Values['Server'] := string(AHost);
    LFDConn.Params.Database := string(ADatabase);
    LFDConn.Params.Values['User_Name'] := string(AUser);
    LFDConn.Params.Values['Password'] := string(APass);
    LFDConn.Params.Values['Port'] := IntToStr(APort);
    LFDConn.LoginPrompt := False;
    LFDConn.Connected := True;
    LConn := TFactoryFiredac.Create(LFDConn, dnMSSQL);
    Result := TJanusConnection.Create(LConn, LFDConn);
  except
    FreeAndNil(LFDConn);
    Result := nil;
  end;
end;

// SPRINT-02 — Oracle driver
// FireDAC params: DriverID='Oracle', Server=host/TNS alias, Database=SID/service, User_Name, Password
// Note: for TNS-less connections use Server=host and Database=service_name; for TNS use Database=TNS_alias.
function ConnectOracle(AHost, ADatabase, AUser, APass: PWideChar): IJanusConnection; stdcall; export;
var
  LFDConn: TFDConnection;
  LConn: IDBConnection;
begin
  Result := nil;
  LFDConn := nil;
  try
    LFDConn := TFDConnection.Create(nil);
    LFDConn.Params.DriverID := 'Oracle';
    LFDConn.Params.Values['Server'] := string(AHost);
    LFDConn.Params.Database := string(ADatabase);
    LFDConn.Params.Values['User_Name'] := string(AUser);
    LFDConn.Params.Values['Password'] := string(APass);
    LFDConn.LoginPrompt := False;
    LFDConn.Connected := True;
    LConn := TFactoryFiredac.Create(LFDConn, dnOracle);
    Result := TJanusConnection.Create(LConn, LFDConn);
  except
    FreeAndNil(LFDConn);
    Result := nil;
  end;
end;

// SPRINT-03 — Programmatic entity registration (Strategy 2)
function CreateEntityBuilder: IJanusEntityBuilder; stdcall; export;
begin
  Result := TJanusEntityBuilder.Create;
end;

// SPRINT-02 — Query factory
function CreateQuery(AEntityName: PWideChar;
  AConn: IJanusConnection): IJanusQuery; stdcall; export;
var
  LInternalConn: IJanusConnectionInternal;
  LDBConn: IDBConnection;
  LEntityName: string;
begin
  Result := nil;
  LEntityName := string(AEntityName);
  if not TEntityProxyRegistry.Instance.HasFactory(LEntityName) then
    Exit;
  LDBConn := nil;
  if Assigned(AConn) and Supports(AConn, IJanusConnectionInternal, LInternalConn) then
    LDBConn := LInternalConn.InternalConnection;
  Result := TJanusQuery.Create(LEntityName, LDBConn);
end;

exports
  NewManagerObjectSet,
  RegisterModels,
  ConnectSQLite,
  ConnectFirebird,
  ConnectMySQL,
  ConnectPostgreSQL,
  CreateObjectSet,
  ConnectMSSQL,
  ConnectOracle,
  CreateQuery,
  CreateEntityBuilder;

begin

end.
