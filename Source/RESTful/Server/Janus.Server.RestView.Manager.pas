{
      ORM Brasil é um ORM simples e descomplicado para quem utiliza Delphi

                   Copyright (c) 2018, Isaque Pinheiro
                          All rights reserved.
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
  DataEngine.FactoryInterfaces,
  MetaDbDiff.Mapping.Explorer,
  FluentSQL,
  FluentSQL.DDL,
  FluentSQL.Interfaces;

type
  TRESTViewManager = class
  private
    class function _GetViewName(const AClassType: TClass): String;
    class function _MapDriverToFluent(const ADriver: TDBEngineDriver): TFluentSQLDriver;
    class function _SupportsCreateOrReplace(const ADriver: TDBEngineDriver): Boolean;
    class procedure _ExecuteDDL(const ASQL: String; const AConnection: IDBConnection);
  public
    // Creates or replaces the VIEW in the database for the given mapped class.
    // AClassType must be decorated with [View] and [Table('view_name','')].
    // ASelect is the IFluentSQL query that defines the view body.
    // Call only at application startup/setup — never inside a REST handler.
    class procedure EnsureView(const AClassType: TClass; const ASelect: IFluentSQL;
      const AConnection: IDBConnection);
  end;

implementation

uses
  FluentSQL.Interfaces,
  MetaDbDiff.Mapping.Classes;

{ TRESTViewManager }

class function TRESTViewManager._GetViewName(const AClassType: TClass): String;
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

class procedure TRESTViewManager._ExecuteDDL(const ASQL: String;
  const AConnection: IDBConnection);
begin
  if ASQL = '' then
    Exit;
  AConnection.ExecuteDirect(ASQL);
end;

class procedure TRESTViewManager.EnsureView(const AClassType: TClass;
  const ASelect: IFluentSQL; const AConnection: IDBConnection);
var
  LViewName: String;
  LDriver: TDBEngineDriver;
  LDialect: TFluentSQLDriver;
  LCreateSQL: String;
  LDropSQL: String;
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
end;

end.
