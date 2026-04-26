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

{
  @abstract(REST View Manager)
  @created(20 Apr 2026)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @abstract(Website : http://www.Janus.com.br)

  Administrative utility that generates or updates database VIEWs at application
  startup via FluentSQL DDL and DataEngine. Never call EnsureView inside a REST
  request handler — it is a setup-time operation only (ADR-003).
}

unit Janus.Server.RestView.Manager;

interface

uses
  SysUtils,
  Generics.Collections,
  DataEngine.FactoryInterfaces,
  MetaDbDiff.Mapping.Explorer,
  FluentSQL,
  FluentSQL.DDL,
  FluentSQL.Interfaces;

type
  ERegistryMissingException = class(Exception);

  TRESTViewManager = class
  private
    class var FViewDefinitionRegistry: TDictionary<string, TFunc<IFluentSQL>>;
    class var FViewEnsuredCache: TDictionary<string, Boolean>;
    class function _GetViewName(const AClassType: TClass): string;
    class function _MapDriverToFluent(const ADriver: TDBEngineDriver): TFluentSQLDriver;
    class function _SupportsCreateOrReplace(const ADriver: TDBEngineDriver): Boolean;
    class procedure _ExecuteDDL(const ASQL: string; const AConnection: IDBConnection);
  public
    class procedure EnsureView(const AClassType: TClass; const ASelect: IFluentSQL;
      const AConnection: IDBConnection);
    class procedure Register(const AClassType: TClass;
      const ASelectFactory: TFunc<IFluentSQL>);
    class procedure EnsureViewLazy(const AClassType: TClass;
      const AConnection: IDBConnection);
    class procedure ClearCache;
  end;

implementation

uses
  MetaDbDiff.Mapping.Classes;

{ TRESTViewManager }

class function TRESTViewManager._GetViewName(const AClassType: TClass): string;
var
  LTableMapping: TTableMapping;
  LViewMapping: TViewMapping;
begin
  Result := '';
  LTableMapping := TMappingExplorer.GetMappingTable(AClassType);
  if Assigned(LTableMapping) and (LTableMapping.Name <> '') then
    Exit(LTableMapping.Name);

  LViewMapping := TMappingExplorer.GetMappingView(AClassType);
  if Assigned(LViewMapping) and (LViewMapping.Name <> '') then
    Exit(LViewMapping.Name);
end;

class function TRESTViewManager._MapDriverToFluent(
  const ADriver: TDBEngineDriver): TFluentSQLDriver;
begin
  case ADriver of
    dnMySQL, dnMariaDB:     Result := dbnMySQL;
    dnFirebird, dnFirebird3: Result := dbnFirebird;
    dnInterbase:             Result := dbnInterbase;
    dnSQLite:                Result := dbnSQLite;
    dnMSSQL:                 Result := dbnMSSQL;
    dnOracle:                Result := dbnOracle;
    dnPostgreSQL:            Result := dbnPostgreSQL;
    dnDB2:                   Result := dbnDB2;
  else
    Result := dbnSQLite;
  end;
end;

// Returns True for databases that natively support CREATE OR REPLACE VIEW.
class function TRESTViewManager._SupportsCreateOrReplace(
  const ADriver: TDBEngineDriver): Boolean;
begin
  Result := ADriver in [dnMySQL, dnMariaDB, dnPostgreSQL, dnOracle];
end;

class procedure TRESTViewManager._ExecuteDDL(const ASQL: string;
  const AConnection: IDBConnection);
begin
  if ASQL = '' then
    Exit;
  AConnection.ExecuteDirect(ASQL);
end;

class procedure TRESTViewManager.EnsureView(const AClassType: TClass;
  const ASelect: IFluentSQL; const AConnection: IDBConnection);
var
  LViewName: string;
  LDriver: TDBEngineDriver;
  LDialect: TFluentSQLDriver;
  LCreateSQL: string;
  LDropSQL: string;
  LSchema: IFluentSchema;
begin
  if not Assigned(AClassType) then
    raise EArgumentNilException.Create('AClassType must not be nil');
  if not Assigned(ASelect) then
    raise EArgumentNilException.Create('ASelect must not be nil');
  if not Assigned(AConnection) then
    raise EArgumentNilException.Create('AConnection must not be nil');

  LViewName := _GetViewName(AClassType);
  if LViewName = '' then
    raise Exception.CreateFmt(
      'Class %s has no [Table] or [View] attribute with a name — cannot derive view name.',
      [AClassType.ClassName]);

  LDriver  := AConnection.GetDriver;
  LDialect := _MapDriverToFluent(LDriver);
  LSchema  := FluentSQL.Schema(LDialect);

  if _SupportsCreateOrReplace(LDriver) then
  begin
    LCreateSQL := LSchema.CreateView(LViewName).OrReplace.&As(ASelect).AsString;
    _ExecuteDDL(LCreateSQL, AConnection);
  end
  else
  begin
    // Databases without CREATE OR REPLACE VIEW support (SQLite, Firebird < 3.x, etc.)
    LDropSQL   := LSchema.DropView(LViewName).IfExists.AsString;
    LCreateSQL := LSchema.CreateView(LViewName).&As(ASelect).AsString;
    _ExecuteDDL(LDropSQL, AConnection);
    _ExecuteDDL(LCreateSQL, AConnection);
  end;
  FViewEnsuredCache.AddOrSetValue(AClassType.ClassName, True);
end;

class procedure TRESTViewManager.Register(const AClassType: TClass;
  const ASelectFactory: TFunc<IFluentSQL>);
begin
  if not Assigned(AClassType) then
    raise EArgumentNilException.Create('AClassType must not be nil');
  if not Assigned(ASelectFactory) then
    raise EArgumentNilException.Create('ASelectFactory must not be nil');
  FViewDefinitionRegistry.AddOrSetValue(AClassType.ClassName, ASelectFactory);
end;

class procedure TRESTViewManager.EnsureViewLazy(const AClassType: TClass;
  const AConnection: IDBConnection);
var
  LFactory: TFunc<IFluentSQL>;
  LSelect: IFluentSQL;
begin
  if FViewEnsuredCache.ContainsKey(AClassType.ClassName) then
    Exit;
  if not FViewDefinitionRegistry.TryGetValue(AClassType.ClassName, LFactory) then
    raise ERegistryMissingException.CreateFmt(
      'No view definition registered for class %s. ' +
      'Call TRESTViewManager.Register before the server handles GET requests.',
      [AClassType.ClassName]);
  LSelect := LFactory;
  EnsureView(AClassType, LSelect, AConnection);
end;

class procedure TRESTViewManager.ClearCache;
begin
  FViewEnsuredCache.Clear;
end;

initialization
  TRESTViewManager.FViewDefinitionRegistry :=
    TDictionary<string, TFunc<IFluentSQL>>.Create;
  TRESTViewManager.FViewEnsuredCache :=
    TDictionary<string, Boolean>.Create;

finalization
  FreeAndNil(TRESTViewManager.FViewDefinitionRegistry);
  FreeAndNil(TRESTViewManager.FViewEnsuredCache);

end.
