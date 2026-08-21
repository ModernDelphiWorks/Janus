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

{ @abstract(Janus Framework - test fixture: a cursor double that YIELDS ROWS.)

  WHY THIS EXISTS
  ---------------
  Until this unit, the whole suite had exactly ONE IDBConnection double
  (TFakeConnection in Test.Janus.DML.Generator.SQLite) and its CreateDataSet
  returned nil. Consequence: NOT A SINGLE TEST ever iterated a cursor that had
  rows in it. That is precisely why "while not <cursor>.Eof do ... end" bodies
  that never call .Next survived in Source\ - the defect is invisible to a
  suite that never opens a populated cursor.

  THE HANG PROBLEM
  ----------------
  A loop that polls Eof and never advances does not FAIL, it HANGS. A hanging
  test is not a test, it is a stuck build. So the double converts the hang into
  a deterministic, fast, readable RED:

    * TSpyResultSet wraps a REAL cursor (TDriverDataSet<TFDMemTable> over an
      in-memory table with N real rows), so Eof/Next/FieldByName all behave
      exactly like production.
    * Every call to Eof is counted. A correct loop polls Eof exactly N+1 times.
      The double allows a generous budget - (N+1)*8 + 64 - and the moment the
      caller exceeds it, Eof raises ECursorRunaway instead of answering.
    * A non-advancing loop burns the whole budget in microseconds, so the test
      fails in well under a second with a message naming the cursor, the poll
      count, the row count and how many times Next was actually called.

  The budget can never be reached by a loop that advances: it is 8x the
  theoretical maximum plus a fixed slack for the incidental Eof polls the ORM
  and the FireDAC layer make around the loop.
}

unit Test.Janus.Cursor.Double;

interface

uses
  DB,
  Classes,
  SysUtils,
  Generics.Collections,
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
  DataEngine.DriverConnection;

type
  /// <summary> Raised by TSpyResultSet when a caller polls Eof far more times
  ///  than the row count can justify - i.e. it is looping without advancing.
  ///  In production the very same code path is an infinite loop. </summary>
  ECursorRunaway = class(Exception);

  /// <summary> Declares the columns of the double's in-memory table. </summary>
  TCursorSchemaProc = reference to procedure(const ADataSet: TFDMemTable);
  /// <summary> Fills row AIndex (0-based) of the double's in-memory table. </summary>
  TCursorRowProc = reference to procedure(const ADataSet: TFDMemTable;
    const AIndex: Integer);

  /// <summary> A real IDBDataSet over N in-memory rows, instrumented so that a
  ///  caller which never advances it fails fast instead of hanging. </summary>
  TSpyResultSet = class(TDriverDataSet<TFDMemTable>)
  private
    FEofPolls: Integer;
    FNextCalls: Integer;
    FPollBudget: Integer;
    FRows: Integer;
    FTag: string;
  public
    constructor CreateSpy(const ADataSet: TFDMemTable; const ARows: Integer;
      const ATag: string);
    function Eof: Boolean; override;
    procedure Next; override;
    /// How many times the caller asked "are we at the end?".
    property EofPolls: Integer read FEofPolls;
    /// How many times the caller actually moved the cursor forward.
    property NextCalls: Integer read FNextCalls;
    /// The ceiling above which Eof stops answering and starts raising.
    property PollBudget: Integer read FPollBudget;
    property Rows: Integer read FRows;
  end;

  /// <summary> An IDBConnection whose CreateDataSet hands out a populated
  ///  TSpyResultSet instead of nil. Everything else is inert - the ORM only
  ///  needs GetDriver plus CreateDataSet to reach its cursor loops. </summary>
  TRowsConnection = class(TInterfacedObject, IDBConnection)
  private
    FDriver: TDriverName;
    FRows: Integer;
    FSchema: TCursorSchemaProc;
    FRow: TCursorRowProc;
    FTag: string;
    FLastSet: IDBDataSet;
    FLastSpy: TSpyResultSet;
    FCreateCount: Integer;
    FLastSQL: string;
    FMaxNextCalls: Integer;
    FMaxEofPolls: Integer;
    procedure _Retire;
  public
    constructor Create(const ADriver: TDriverName; const ARows: Integer;
      const ASchema: TCursorSchemaProc; const ARow: TCursorRowProc;
      const ATag: string = 'cursor');
    /// The spy handed out by the LAST CreateDataSet call. nil before the first.
    /// Only valid while this connection is alive.
    function LastSpy: TSpyResultSet;
    /// How many cursors this connection has handed out.
    function CreateCount: Integer;
    function LastSQL: string;
    /// Highest NextCalls seen across EVERY cursor handed out (the last one is
    /// not necessarily the interesting one when the ORM opens several).
    function MaxNextCalls: Integer;
    function MaxEofPolls: Integer;
    // --- IDBConnection ---------------------------------------------------
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
    /// VIRTUAL so a fixture can answer DIFFERENT questions differently - the
    /// generator asks for one row and a child re-open asks for the rows of a
    /// table nothing ever saved. A double that answers both with the same
    /// canned cursor cannot serve a test that needs to do both in one run.
    /// See Test.Janus.AutoInc.Distribution.TTreeConnection.
    function CreateDataSet(const ASQL: String = ''): IDBDataSet; virtual;
    function GetSQLScripts: String;
    function RowsAffected: UInt32;
    function GetDriver: TDriverName;
    function CommandMonitor: ICommandMonitor;
    function MonitorCallback: TMonitorProc;
    function Options: IOptions;
    procedure SetCommandMonitor(AMonitor: ICommandMonitor);
    function BulkLoader: IDBBulkLoader;
    function Cache: IDBCacheProvider;
    function MetadataCache: IDBMetadataCache;
    procedure SetCacheProvider(ACache: IDBCacheProvider);
    procedure SetMetadataCacheProvider(AMetadataCache: IDBMetadataCache);
    procedure RefreshMetadata(const ATableName: string);
    function IsAlive: Boolean;
    function ResiliencePolicy: IDBResiliencePolicy;
    procedure SetResiliencePolicy(APolicy: IDBResiliencePolicy);
    procedure AddObserver(const AObserver: IDBObserver);
    procedure RemoveObserver(const AObserver: IDBObserver);
    function SlowQueryThreshold: Integer;
    procedure SetSlowQueryThreshold(const AValue: Integer);
    function _GetTransaction(const AKey: String): TComponent;
    procedure StartTransaction(const ALevel: TDBIsolationLevel = ilDefault);
    procedure Commit;
    procedure Rollback;
    procedure AddTransaction(const AKey: String; const ATransaction: TComponent);
    procedure UseTransaction(const AKey: String);
    function TransactionActive: TComponent;
    function InTransaction: Boolean;
  end;

/// <summary> Schema/row pair for Test.Janus.Model.KeyOnly.TKeyOnly (k1, k2). </summary>
function KeyOnlySchema: TCursorSchemaProc;
function KeyOnlyRow: TCursorRowProc;
/// <summary> Schema/row pair wide enough for the lazy example models
///  (Model.Procedimento / Model.Setor). </summary>
function LazySchema: TCursorSchemaProc;
function LazyRow: TCursorRowProc;

implementation

{ TSpyResultSet }

constructor TSpyResultSet.CreateSpy(const ADataSet: TFDMemTable;
  const ARows: Integer; const ATag: string);
begin
  inherited Create(ADataSet, nil);
  FEofPolls := 0;
  FNextCalls := 0;
  FRows := ARows;
  FTag := ATag;
  // A correct loop polls Eof exactly ARows+1 times. Eight times that, plus a
  // fixed slack, absorbs every incidental poll the ORM/FireDAC make around the
  // loop, and is still reached instantly by a loop that never advances.
  FPollBudget := (ARows + 1) * 8 + 64;
end;

function TSpyResultSet.Eof: Boolean;
begin
  Inc(FEofPolls);
  if FEofPolls > FPollBudget then
    raise ECursorRunaway.CreateFmt(
      'Cursor "%s" over %d row(s): Eof polled %d times (budget %d) but Next ' +
      'called only %d time(s). The loop is not advancing the cursor - in ' +
      'production this is an infinite loop, not a slow one.',
      [FTag, FRows, FEofPolls, FPollBudget, FNextCalls]);
  Result := inherited Eof;
end;

procedure TSpyResultSet.Next;
begin
  Inc(FNextCalls);
  inherited;
end;

{ TRowsConnection }

constructor TRowsConnection.Create(const ADriver: TDriverName;
  const ARows: Integer; const ASchema: TCursorSchemaProc;
  const ARow: TCursorRowProc; const ATag: string);
begin
  inherited Create;
  FDriver := ADriver;
  FRows := ARows;
  FSchema := ASchema;
  FRow := ARow;
  FTag := ATag;
  FLastSpy := nil;
  FCreateCount := 0;
  FLastSQL := '';
  FMaxNextCalls := 0;
  FMaxEofPolls := 0;
end;

procedure TRowsConnection._Retire;
begin
  if FLastSpy <> nil then
  begin
    if FLastSpy.NextCalls > FMaxNextCalls then
      FMaxNextCalls := FLastSpy.NextCalls;
    if FLastSpy.EofPolls > FMaxEofPolls then
      FMaxEofPolls := FLastSpy.EofPolls;
  end;
end;

function TRowsConnection.CreateDataSet(const ASQL: String): IDBDataSet;
var
  LTable: TFDMemTable;
  LFor: Integer;
  LSpy: TSpyResultSet;
begin
  _Retire;
  Inc(FCreateCount);
  FLastSQL := ASQL;
  LTable := TFDMemTable.Create(nil);
  try
    LTable.ResourceOptions.SilentMode := True;
    FSchema(LTable);
    LTable.CreateDataSet;
    for LFor := 0 to FRows - 1 do
    begin
      LTable.Append;
      FRow(LTable, LFor);
      LTable.Post;
    end;
    LTable.First;
  except
    LTable.Free;
    raise;
  end;
  // TDriverDataSet<T> takes ownership of LTable and frees it on destruction.
  LSpy := TSpyResultSet.CreateSpy(LTable, FRows, FTag);
  FLastSpy := LSpy;
  FLastSet := LSpy;      // keeps the spy alive for post-hoc assertions
  Result := FLastSet;
end;

function TRowsConnection.LastSpy: TSpyResultSet;
begin
  Result := FLastSpy;
end;

function TRowsConnection.CreateCount: Integer;
begin
  Result := FCreateCount;
end;

function TRowsConnection.LastSQL: string;
begin
  Result := FLastSQL;
end;

function TRowsConnection.MaxNextCalls: Integer;
begin
  _Retire;
  Result := FMaxNextCalls;
end;

function TRowsConnection.MaxEofPolls: Integer;
begin
  _Retire;
  Result := FMaxEofPolls;
end;

function TRowsConnection.GetDriver: TDriverName;
begin
  Result := FDriver;
end;

procedure TRowsConnection.AddObserver(const AObserver: IDBObserver);
begin
end;

procedure TRowsConnection.AddScript(const AScript: String);
begin
end;

procedure TRowsConnection.AddTransaction(const AKey: String;
  const ATransaction: TComponent);
begin
end;

procedure TRowsConnection.ApplyUpdates(const ADataSets: array of IDBDataSet);
begin
end;

function TRowsConnection.BulkLoader: IDBBulkLoader;
begin
  Result := nil;
end;

function TRowsConnection.Cache: IDBCacheProvider;
begin
  Result := nil;
end;

function TRowsConnection.CommandMonitor: ICommandMonitor;
begin
  Result := nil;
end;

procedure TRowsConnection.Commit;
begin
end;

procedure TRowsConnection.Connect;
begin
end;

function TRowsConnection.CreateQuery: IDBQuery;
begin
  Result := nil;
end;

procedure TRowsConnection.Disconnect;
begin
end;

procedure TRowsConnection.ExecuteDirect(const ASQL: String);
begin
end;

procedure TRowsConnection.ExecuteDirect(const ASQL: String;
  const AParams: TParams);
begin
end;

procedure TRowsConnection.ExecuteScript(const AScript: String);
begin
end;

procedure TRowsConnection.ExecuteScripts;
begin
end;

function TRowsConnection.GetSQLScripts: String;
begin
  Result := '';
end;

function TRowsConnection.InTransaction: Boolean;
begin
  Result := False;
end;

function TRowsConnection.IsAlive: Boolean;
begin
  Result := True;
end;

function TRowsConnection.IsConnected: Boolean;
begin
  Result := True;
end;

function TRowsConnection.MetadataCache: IDBMetadataCache;
begin
  Result := nil;
end;

function TRowsConnection.MonitorCallback: TMonitorProc;
begin
  Result := nil;
end;

function TRowsConnection.Options: IOptions;
begin
  Result := nil;
end;

procedure TRowsConnection.RefreshMetadata(const ATableName: string);
begin
end;

procedure TRowsConnection.RemoveObserver(const AObserver: IDBObserver);
begin
end;

function TRowsConnection.ResiliencePolicy: IDBResiliencePolicy;
begin
  Result := nil;
end;

procedure TRowsConnection.Rollback;
begin
end;

function TRowsConnection.RowsAffected: UInt32;
begin
  Result := 0;
end;

procedure TRowsConnection.SetCacheProvider(ACache: IDBCacheProvider);
begin
end;

procedure TRowsConnection.SetCommandMonitor(AMonitor: ICommandMonitor);
begin
end;

procedure TRowsConnection.SetMetadataCacheProvider(
  AMetadataCache: IDBMetadataCache);
begin
end;

procedure TRowsConnection.SetResiliencePolicy(APolicy: IDBResiliencePolicy);
begin
end;

procedure TRowsConnection.SetSlowQueryThreshold(const AValue: Integer);
begin
end;

function TRowsConnection.SlowQueryThreshold: Integer;
begin
  Result := 0;
end;

procedure TRowsConnection.StartTransaction(const ALevel: TDBIsolationLevel);
begin
end;

function TRowsConnection.TransactionActive: TComponent;
begin
  Result := nil;
end;

procedure TRowsConnection.UseTransaction(const AKey: String);
begin
end;

function TRowsConnection._GetTransaction(const AKey: String): TComponent;
begin
  Result := nil;
end;

{ Schemas }

function KeyOnlySchema: TCursorSchemaProc;
begin
  Result :=
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add('k1', ftInteger);
      ADataSet.FieldDefs.Add('k2', ftInteger);
    end;
end;

function KeyOnlyRow: TCursorRowProc;
begin
  Result :=
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName('k1').AsInteger := 100 + AIndex;
      ADataSet.FieldByName('k2').AsInteger := 200 + AIndex;
    end;
end;

function LazySchema: TCursorSchemaProc;
begin
  Result :=
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add('SETOR', ftInteger);
      ADataSet.FieldDefs.Add('MNEMONICO', ftString, 7);
      ADataSet.FieldDefs.Add('DESCRICAO', ftString, 40);
    end;
end;

function LazyRow: TCursorRowProc;
begin
  Result :=
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName('SETOR').AsInteger := 10 + AIndex;
      ADataSet.FieldByName('MNEMONICO').AsString := 'MN' + IntToStr(AIndex);
      ADataSet.FieldByName('DESCRICAO').AsString := 'Row ' + IntToStr(AIndex);
    end;
end;

end.
