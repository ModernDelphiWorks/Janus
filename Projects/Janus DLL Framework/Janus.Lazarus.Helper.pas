unit Janus.Lazarus.Helper;

// =============================================================================
// JANUS ORM -- Lazarus String Helper Layer (SPRINT-05 / SPRINT-06)
//
// Consumer-side helper that eliminates PWideChar(WideString('...')) verbosity
// in Lazarus/FPC projects consuming the Janus DLL.
//
// Provides:
//   - JW(string): PWideChar        -- inline conversion for DLL calls
//   - JStr(PWideChar): string      -- inline conversion from DLL results
//   - TJanusBuilderHelper          -- fluent record wrapper for IJanusEntityBuilder
//   - JanusBuilder()               -- factory for TJanusBuilderHelper
//   - TJanusRecordHelper           -- record wrapper for IJanusRecord (SPRINT-06)
//   - JanusRecord()                -- factory for TJanusRecordHelper
//   - TJanusSetHelper              -- record wrapper for IJanusObjectSet (SPRINT-06)
//   - JanusSet()                   -- factory for TJanusSetHelper
//   - JanusConnectSQLiteStr()      -- string-based connection wrapper (SPRINT-06)
//   - JanusConnectFirebirdStr()    -- string-based connection wrapper (SPRINT-06)
//   - JanusConnectMySQLStr()       -- string-based connection wrapper (SPRINT-06)
//   - JanusConnectPostgreSQLStr()  -- string-based connection wrapper (SPRINT-06)
//   - JanusConnectMSSQLStr()       -- string-based connection wrapper (SPRINT-06)
//   - JanusConnectOracleStr()      -- string-based connection wrapper (SPRINT-06)
//   - JanusObjectSetStr()          -- combined factory returning TJanusSetHelper
//
// IMPORTANT - JW() lifetime:
//   JW() stores the converted WideString in a rotating buffer (8 slots).
//   The returned PWideChar is valid within the same statement and supports
//   up to 8 concurrent JW() calls in a single expression. Do NOT store
//   the result in a variable for later use. For complex scenarios, prefer
//   TJanusBuilderHelper which manages WideString lifetime internally.
//
// Usage:
//   uses Janus.IncludeDll, Janus.Lazarus.Helper;
//
//   // Before (verbose):
//   LConn := JanusConnectSQLite(PWideChar(WideString('test.db')));
//   LSet  := JanusCreateObjectSet(PWideChar(WideString('TOrder')), LConn);
//   LRec  := LSet.NewRecord;
//   LRec.SetStr(PWideChar(WideString('name')), PWideChar(WideString('test')));
//
//   // After (with helpers):
//   LConn := JanusConnectSQLiteStr('test.db');
//   LSet  := JanusObjectSetStr('TOrder', LConn);
//   LRec  := LSet.NewRecord;
//   LRec.SetStr('name', 'test');
//
// Requires: FPC 3.x with {$mode objfpc}{$H+}{$modeswitch advancedrecords}
// =============================================================================

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Janus.DLL.Interfaces,
  Janus.IncludeDll;

// ---------------------------------------------------------------------------
// Free functions: inline string conversion
// ---------------------------------------------------------------------------

{ Converts a FPC UTF-8 string to PWideChar for DLL boundary calls.
  Uses a rotating buffer of 8 WideString slots to keep values alive.
  The returned pointer is valid within the current statement and supports
  up to 8 JW() calls in a single expression. Do NOT store for later use. }
function JW(const AValue: string): PWideChar;

{ Converts a PWideChar (UTF-16) returned by the DLL back to a FPC UTF-8 string. }
function JStr(AValue: PWideChar): string;

// ---------------------------------------------------------------------------
// TJanusBuilderHelper -- fluent record wrapper for IJanusEntityBuilder
// ---------------------------------------------------------------------------

type
  TJanusBuilderHelper = record
  private
    FInner: IJanusEntityBuilder;
  public
    { Wraps IJanusEntityBuilder.EntityName }
    function EntityName(const AName: string): TJanusBuilderHelper;
    { Wraps IJanusEntityBuilder.TableName }
    function TableName(const AName: string): TJanusBuilderHelper;
    { Wraps IJanusEntityBuilder.AddColumn }
    function AddColumn(const AName, AType: string; ASize: Integer): TJanusBuilderHelper;
    { Wraps IJanusEntityBuilder.PrimaryKey }
    function PrimaryKey(const AColumn: string): TJanusBuilderHelper;
    { Wraps IJanusEntityBuilder.Build -- pass-through, no string conversion }
    function Build: LongBool;
    { Wraps IJanusEntityBuilder.AddForeignKey }
    function AddForeignKey(const AName, ARefTable, AFromColumn, AToColumn: string): TJanusBuilderHelper;
    { Wraps IJanusEntityBuilder.ForeignKeyRule -- pass-through, no string conversion }
    function ForeignKeyRule(AOnDelete, AOnUpdate: Integer): TJanusBuilderHelper;
    { Wraps IJanusEntityBuilder.AddJoinColumn }
    function AddJoinColumn(const AColumn, ARefTable, ARefColumn: string; AJoinType: Integer): TJanusBuilderHelper;
    { Wraps IJanusEntityBuilder.AddAssociation }
    function AddAssociation(AMultiplicity: Integer; const AColumn, ARefColumn, ARefEntity: string): TJanusBuilderHelper;
  end;

{ Creates a TJanusBuilderHelper by calling JanusCreateEntityBuilder internally. }
function JanusBuilder: TJanusBuilderHelper;

// ---------------------------------------------------------------------------
// TJanusRecordHelper -- record wrapper for IJanusRecord (SPRINT-06)
// ---------------------------------------------------------------------------

type
  TJanusRecordHelper = record
  public
    FInner: IJanusRecord;
    { Reads a string field and returns FPC UTF-8 string }
    function GetStr(const AField: string): string;
    { Writes a string field from FPC UTF-8 string }
    procedure SetStr(const AField, AValue: string);
    { Reads an integer field }
    function GetInt(const AField: string): Integer;
    { Writes an integer field }
    procedure SetInt(const AField: string; AValue: Integer);
    { Reads a float field }
    function GetFloat(const AField: string): Double;
    { Writes a float field }
    procedure SetFloat(const AField: string; AValue: Double);
    { Reads a boolean field }
    function GetBool(const AField: string): LongBool;
    { Writes a boolean field }
    procedure SetBool(const AField: string; AValue: LongBool);
  end;

{ Wraps an IJanusRecord in a TJanusRecordHelper. }
function JanusRecord(AInner: IJanusRecord): TJanusRecordHelper;

// ---------------------------------------------------------------------------
// TJanusSetHelper -- record wrapper for IJanusObjectSet (SPRINT-06)
// ---------------------------------------------------------------------------

type
  TJanusSetHelper = record
  public
    FInner: IJanusObjectSet;
    { Opens the object set (all records). }
    function Open: LongBool;
    { Opens with WHERE and ORDER BY clauses (FPC string). }
    function OpenWhere(const AWhere, AOrderBy: string): LongBool;
    { Finds a record by integer ID. }
    function FindByID(AID: Integer): TJanusRecordHelper;
    { Returns the number of records in the set. }
    function RecordCount: Integer;
    { Returns the record at the given index. }
    function GetRecord(AIndex: Integer): TJanusRecordHelper;
    { Creates a new empty record. }
    function NewRecord: TJanusRecordHelper;
    { Inserts a record into the set. }
    procedure Insert(ARec: TJanusRecordHelper);
    { Updates a record in the set. }
    procedure Update(ARec: TJanusRecordHelper);
    { Deletes a record from the set. }
    procedure Delete(ARec: TJanusRecordHelper);
    // SPRINT-08 — Pagination + Navigation (ADR-009)
    { Loads the next page of records. APageNext is 1-based. }
    function NextPacket(APageSize, APageNext: Integer): LongBool;
    { Positions the cursor on the first record. }
    function First: LongBool;
    { Advances the cursor to the next record. }
    function Next: LongBool;
    { Moves the cursor to the previous record. }
    function Prior: LongBool;
    { Returns True when cursor is past the last record or set is empty. }
    function Eof: LongBool;
    { Returns the record at the current cursor position. }
    function Current: TJanusRecordHelper;
  end;

{ Wraps an IJanusObjectSet in a TJanusSetHelper. }
function JanusSet(AInner: IJanusObjectSet): TJanusSetHelper;

// ---------------------------------------------------------------------------
// Connection wrapper functions -- string-based (SPRINT-06)
// ---------------------------------------------------------------------------

{ Connects to a SQLite database using FPC string. }
function JanusConnectSQLiteStr(const ADatabase: string): IJanusConnection;

{ Connects to a Firebird database using FPC strings. }
function JanusConnectFirebirdStr(const AHost, ADatabase, AUser, APass: string): IJanusConnection;

{ Connects to a MySQL database using FPC strings. }
function JanusConnectMySQLStr(const AHost, ADatabase, AUser, APass: string; APort: Integer): IJanusConnection;

{ Connects to a PostgreSQL database using FPC strings. }
function JanusConnectPostgreSQLStr(const AHost, ADatabase, AUser, APass: string; APort: Integer): IJanusConnection;

{ Connects to a MSSQL database using FPC strings. }
function JanusConnectMSSQLStr(const AHost, ADatabase, AUser, APass: string; APort: Integer): IJanusConnection;

{ Connects to an Oracle database using FPC strings. }
function JanusConnectOracleStr(const AHost, ADatabase, AUser, APass: string): IJanusConnection;

// ---------------------------------------------------------------------------
// JanusObjectSetStr -- combined factory returning TJanusSetHelper (SPRINT-06)
// ---------------------------------------------------------------------------

{ Creates an object set wrapper using FPC entity name string and connection. }
function JanusObjectSetStr(const AEntityName: string; AConn: IJanusConnection): TJanusSetHelper;

implementation

// ---------------------------------------------------------------------------
// JW / JStr implementation
// ---------------------------------------------------------------------------

const
  CJWBufferSize = 8;

var
  _GJWBuffer: array[0..CJWBufferSize - 1] of WideString;
  _GJWIndex: Integer = 0;

function JW(const AValue: string): PWideChar;
begin
  _GJWBuffer[_GJWIndex] := UTF8Decode(AValue);
  Result := PWideChar(_GJWBuffer[_GJWIndex]);
  _GJWIndex := (_GJWIndex + 1) mod CJWBufferSize;
end;

function JStr(AValue: PWideChar): string;
begin
  if AValue = nil then
    Result := ''
  else
    Result := UTF8Encode(WideString(AValue));
end;

// ---------------------------------------------------------------------------
// TJanusBuilderHelper implementation
// ---------------------------------------------------------------------------

function TJanusBuilderHelper.EntityName(const AName: string): TJanusBuilderHelper;
var
  LWide: WideString;
begin
  LWide := UTF8Decode(AName);
  FInner.EntityName(PWideChar(LWide));
  Result := Self;
end;

function TJanusBuilderHelper.TableName(const AName: string): TJanusBuilderHelper;
var
  LWide: WideString;
begin
  LWide := UTF8Decode(AName);
  FInner.TableName(PWideChar(LWide));
  Result := Self;
end;

function TJanusBuilderHelper.AddColumn(const AName, AType: string; ASize: Integer): TJanusBuilderHelper;
var
  LWideName: WideString;
  LWideType: WideString;
begin
  LWideName := UTF8Decode(AName);
  LWideType := UTF8Decode(AType);
  FInner.AddColumn(PWideChar(LWideName), PWideChar(LWideType), ASize);
  Result := Self;
end;

function TJanusBuilderHelper.PrimaryKey(const AColumn: string): TJanusBuilderHelper;
var
  LWide: WideString;
begin
  LWide := UTF8Decode(AColumn);
  FInner.PrimaryKey(PWideChar(LWide));
  Result := Self;
end;

function TJanusBuilderHelper.Build: LongBool;
begin
  Result := FInner.Build;
end;

function TJanusBuilderHelper.AddForeignKey(const AName, ARefTable, AFromColumn, AToColumn: string): TJanusBuilderHelper;
var
  LWideName: WideString;
  LWideRefTable: WideString;
  LWideFromCol: WideString;
  LWideToCol: WideString;
begin
  LWideName := UTF8Decode(AName);
  LWideRefTable := UTF8Decode(ARefTable);
  LWideFromCol := UTF8Decode(AFromColumn);
  LWideToCol := UTF8Decode(AToColumn);
  FInner.AddForeignKey(PWideChar(LWideName), PWideChar(LWideRefTable),
                       PWideChar(LWideFromCol), PWideChar(LWideToCol));
  Result := Self;
end;

function TJanusBuilderHelper.ForeignKeyRule(AOnDelete, AOnUpdate: Integer): TJanusBuilderHelper;
begin
  FInner.ForeignKeyRule(AOnDelete, AOnUpdate);
  Result := Self;
end;

function TJanusBuilderHelper.AddJoinColumn(const AColumn, ARefTable, ARefColumn: string; AJoinType: Integer): TJanusBuilderHelper;
var
  LWideColumn: WideString;
  LWideRefTable: WideString;
  LWideRefCol: WideString;
begin
  LWideColumn := UTF8Decode(AColumn);
  LWideRefTable := UTF8Decode(ARefTable);
  LWideRefCol := UTF8Decode(ARefColumn);
  FInner.AddJoinColumn(PWideChar(LWideColumn), PWideChar(LWideRefTable),
                       PWideChar(LWideRefCol), AJoinType);
  Result := Self;
end;

function TJanusBuilderHelper.AddAssociation(AMultiplicity: Integer; const AColumn, ARefColumn, ARefEntity: string): TJanusBuilderHelper;
var
  LWideColumn: WideString;
  LWideRefCol: WideString;
  LWideRefEntity: WideString;
begin
  LWideColumn := UTF8Decode(AColumn);
  LWideRefCol := UTF8Decode(ARefColumn);
  LWideRefEntity := UTF8Decode(ARefEntity);
  FInner.AddAssociation(AMultiplicity, PWideChar(LWideColumn),
                        PWideChar(LWideRefCol), PWideChar(LWideRefEntity));
  Result := Self;
end;

// ---------------------------------------------------------------------------
// JanusBuilder factory functions
// ---------------------------------------------------------------------------

function JanusBuilder: TJanusBuilderHelper;
begin
  Result.FInner := JanusCreateEntityBuilder;
end;

// ---------------------------------------------------------------------------
// TJanusRecordHelper implementation (SPRINT-06)
// ---------------------------------------------------------------------------

function TJanusRecordHelper.GetStr(const AField: string): string;
var
  LWideField: WideString;
begin
  LWideField := UTF8Decode(AField);
  Result := JStr(FInner.GetStr(PWideChar(LWideField)));
end;

procedure TJanusRecordHelper.SetStr(const AField, AValue: string);
var
  LWideField: WideString;
  LWideValue: WideString;
begin
  LWideField := UTF8Decode(AField);
  LWideValue := UTF8Decode(AValue);
  FInner.SetStr(PWideChar(LWideField), PWideChar(LWideValue));
end;

function TJanusRecordHelper.GetInt(const AField: string): Integer;
var
  LWideField: WideString;
begin
  LWideField := UTF8Decode(AField);
  Result := FInner.GetInt(PWideChar(LWideField));
end;

procedure TJanusRecordHelper.SetInt(const AField: string; AValue: Integer);
var
  LWideField: WideString;
begin
  LWideField := UTF8Decode(AField);
  FInner.SetInt(PWideChar(LWideField), AValue);
end;

function TJanusRecordHelper.GetFloat(const AField: string): Double;
var
  LWideField: WideString;
begin
  LWideField := UTF8Decode(AField);
  Result := FInner.GetFloat(PWideChar(LWideField));
end;

procedure TJanusRecordHelper.SetFloat(const AField: string; AValue: Double);
var
  LWideField: WideString;
begin
  LWideField := UTF8Decode(AField);
  FInner.SetFloat(PWideChar(LWideField), AValue);
end;

function TJanusRecordHelper.GetBool(const AField: string): LongBool;
var
  LWideField: WideString;
begin
  LWideField := UTF8Decode(AField);
  Result := FInner.GetBool(PWideChar(LWideField));
end;

procedure TJanusRecordHelper.SetBool(const AField: string; AValue: LongBool);
var
  LWideField: WideString;
begin
  LWideField := UTF8Decode(AField);
  FInner.SetBool(PWideChar(LWideField), AValue);
end;

// ---------------------------------------------------------------------------
// JanusRecord factory (SPRINT-06)
// ---------------------------------------------------------------------------

function JanusRecord(AInner: IJanusRecord): TJanusRecordHelper;
begin
  Result.FInner := AInner;
end;

// ---------------------------------------------------------------------------
// TJanusSetHelper implementation (SPRINT-06)
// ---------------------------------------------------------------------------

function TJanusSetHelper.Open: LongBool;
begin
  Result := FInner.Open;
end;

function TJanusSetHelper.OpenWhere(const AWhere, AOrderBy: string): LongBool;
var
  LWideWhere: WideString;
  LWideOrderBy: WideString;
begin
  LWideWhere := UTF8Decode(AWhere);
  LWideOrderBy := UTF8Decode(AOrderBy);
  Result := FInner.OpenWhere(PWideChar(LWideWhere), PWideChar(LWideOrderBy));
end;

function TJanusSetHelper.FindByID(AID: Integer): TJanusRecordHelper;
begin
  Result := JanusRecord(FInner.FindByID(AID));
end;

function TJanusSetHelper.RecordCount: Integer;
begin
  Result := FInner.RecordCount;
end;

function TJanusSetHelper.GetRecord(AIndex: Integer): TJanusRecordHelper;
begin
  Result := JanusRecord(FInner.GetRecord(AIndex));
end;

function TJanusSetHelper.NewRecord: TJanusRecordHelper;
begin
  Result := JanusRecord(FInner.NewRecord);
end;

procedure TJanusSetHelper.Insert(ARec: TJanusRecordHelper);
begin
  FInner.Insert(ARec.FInner);
end;

procedure TJanusSetHelper.Update(ARec: TJanusRecordHelper);
begin
  FInner.Update(ARec.FInner);
end;

procedure TJanusSetHelper.Delete(ARec: TJanusRecordHelper);
begin
  FInner.Delete(ARec.FInner);
end;

{ SPRINT-08 — Pagination + Navigation }

function TJanusSetHelper.NextPacket(APageSize, APageNext: Integer): LongBool;
begin
  Result := FInner.NextPacket(APageSize, APageNext);
end;

function TJanusSetHelper.First: LongBool;
begin
  Result := FInner.First;
end;

function TJanusSetHelper.Next: LongBool;
begin
  Result := FInner.Next;
end;

function TJanusSetHelper.Prior: LongBool;
begin
  Result := FInner.Prior;
end;

function TJanusSetHelper.Eof: LongBool;
begin
  Result := FInner.Eof;
end;

function TJanusSetHelper.Current: TJanusRecordHelper;
begin
  Result := JanusRecord(FInner.CurrentRecord);
end;

// ---------------------------------------------------------------------------
// JanusSet factory (SPRINT-06)
// ---------------------------------------------------------------------------

function JanusSet(AInner: IJanusObjectSet): TJanusSetHelper;
begin
  Result.FInner := AInner;
end;

// ---------------------------------------------------------------------------
// Connection wrapper functions (SPRINT-06)
// ---------------------------------------------------------------------------

function JanusConnectSQLiteStr(const ADatabase: string): IJanusConnection;
var
  LWideDb: WideString;
begin
  LWideDb := UTF8Decode(ADatabase);
  Result := JanusConnectSQLite(PWideChar(LWideDb));
end;

function JanusConnectFirebirdStr(const AHost, ADatabase, AUser, APass: string): IJanusConnection;
var
  LWideHost: WideString;
  LWideDb: WideString;
  LWideUser: WideString;
  LWidePass: WideString;
begin
  LWideHost := UTF8Decode(AHost);
  LWideDb := UTF8Decode(ADatabase);
  LWideUser := UTF8Decode(AUser);
  LWidePass := UTF8Decode(APass);
  Result := JanusConnectFirebird(PWideChar(LWideHost), PWideChar(LWideDb),
                                 PWideChar(LWideUser), PWideChar(LWidePass));
end;

function JanusConnectMySQLStr(const AHost, ADatabase, AUser, APass: string; APort: Integer): IJanusConnection;
var
  LWideHost: WideString;
  LWideDb: WideString;
  LWideUser: WideString;
  LWidePass: WideString;
begin
  LWideHost := UTF8Decode(AHost);
  LWideDb := UTF8Decode(ADatabase);
  LWideUser := UTF8Decode(AUser);
  LWidePass := UTF8Decode(APass);
  Result := JanusConnectMySQL(PWideChar(LWideHost), PWideChar(LWideDb),
                              PWideChar(LWideUser), PWideChar(LWidePass), APort);
end;

function JanusConnectPostgreSQLStr(const AHost, ADatabase, AUser, APass: string; APort: Integer): IJanusConnection;
var
  LWideHost: WideString;
  LWideDb: WideString;
  LWideUser: WideString;
  LWidePass: WideString;
begin
  LWideHost := UTF8Decode(AHost);
  LWideDb := UTF8Decode(ADatabase);
  LWideUser := UTF8Decode(AUser);
  LWidePass := UTF8Decode(APass);
  Result := JanusConnectPostgreSQL(PWideChar(LWideHost), PWideChar(LWideDb),
                                   PWideChar(LWideUser), PWideChar(LWidePass), APort);
end;

function JanusConnectMSSQLStr(const AHost, ADatabase, AUser, APass: string; APort: Integer): IJanusConnection;
var
  LWideHost: WideString;
  LWideDb: WideString;
  LWideUser: WideString;
  LWidePass: WideString;
begin
  LWideHost := UTF8Decode(AHost);
  LWideDb := UTF8Decode(ADatabase);
  LWideUser := UTF8Decode(AUser);
  LWidePass := UTF8Decode(APass);
  Result := JanusConnectMSSQL(PWideChar(LWideHost), PWideChar(LWideDb),
                              PWideChar(LWideUser), PWideChar(LWidePass), APort);
end;

function JanusConnectOracleStr(const AHost, ADatabase, AUser, APass: string): IJanusConnection;
var
  LWideHost: WideString;
  LWideDb: WideString;
  LWideUser: WideString;
  LWidePass: WideString;
begin
  LWideHost := UTF8Decode(AHost);
  LWideDb := UTF8Decode(ADatabase);
  LWideUser := UTF8Decode(AUser);
  LWidePass := UTF8Decode(APass);
  Result := JanusConnectOracle(PWideChar(LWideHost), PWideChar(LWideDb),
                               PWideChar(LWideUser), PWideChar(LWidePass));
end;

// ---------------------------------------------------------------------------
// JanusObjectSetStr factory (SPRINT-06)
// ---------------------------------------------------------------------------

function JanusObjectSetStr(const AEntityName: string; AConn: IJanusConnection): TJanusSetHelper;
var
  LWideName: WideString;
begin
  LWideName := UTF8Decode(AEntityName);
  Result := JanusSet(JanusCreateObjectSet(PWideChar(LWideName), AConn));
end;

end.
