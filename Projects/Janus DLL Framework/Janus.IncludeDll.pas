unit Janus.IncludeDll;

// =============================================================================
// JANUS ORM -- DLL Bridge  (Consumer File)
// Compatible with: Delphi 7+, Lazarus/FPC 3.x, Delphi XE+
//
// USAGE (Lazarus / FPC):
//
//   uses Janus.IncludeDll;
//   var
//     LConn: IJanusConnection;
//     LSet:  IJanusObjectSet;
//     LRec:  IJanusRecord;
//   begin
//     JanusRegisterModels;
//     LConn := JanusConnectSQLite(PWideChar(WideString('mydb.db')));
//     LSet  := JanusCreateObjectSet(PWideChar(WideString('TClientModel')), LConn);
//     LRec  := LSet.NewRecord;
//     LRec.SetStr(PWideChar(WideString('client_name')),
//                 PWideChar(UTF8Decode('Isaque')));
//     LSet.Insert(LRec);
//     LSet.Open;
//     WriteLn(UTF8Encode(WideString(LSet.GetRecord(0).GetStr(
//       PWideChar(WideString('client_name'))))));
//   end;
//
// USAGE (Delphi 7):
//   Same pattern, but use WideString() casts instead of UTF8Decode.
//
// USAGE (Delphi XE+):
//   LSet.GetRecord(0).GetStr(PWideChar('client_name'))
//   (string is already UTF-16, cast directly with PWideChar)
//
// RULES:
//   - All strings cross the DLL boundary as PWideChar (UTF-16 null-terminated).
//   - Do NOT use AnsiString or UnicodeString Delphi-managed types at the boundary.
//   - JanusRegisterModels must be the first call before any CreateObjectSet.
// =============================================================================

interface

uses
  Janus.DLL.Interfaces;

// Interface types IJanusRecord, IJanusObjectSet and IJanusConnection are
// declared in Janus.DLL.Interfaces and re-exported to consumers via the uses
// clause above. Do not redeclare them here.

// -----------------------------------------------------------------------------
// Exported function declarations
// All functions are stdcall and use only COM-safe types.
// -----------------------------------------------------------------------------

function JanusRegisterModels: LongBool; stdcall;
  external 'JanusFramework.dll' name 'RegisterModels';

function JanusConnectSQLite(ADatabase: PWideChar): IJanusConnection; stdcall;
  external 'JanusFramework.dll' name 'ConnectSQLite';

function JanusConnectFirebird(AHost, ADatabase, AUser, APass: PWideChar): IJanusConnection; stdcall;
  external 'JanusFramework.dll' name 'ConnectFirebird';

function JanusConnectMySQL(AHost, ADatabase, AUser, APass: PWideChar;
  APort: Integer): IJanusConnection; stdcall;
  external 'JanusFramework.dll' name 'ConnectMySQL';

function JanusConnectPostgreSQL(AHost, ADatabase, AUser, APass: PWideChar;
  APort: Integer): IJanusConnection; stdcall;
  external 'JanusFramework.dll' name 'ConnectPostgreSQL';

function JanusCreateObjectSet(AEntityName: PWideChar;
  AConn: IJanusConnection): IJanusObjectSet; stdcall;
  external 'JanusFramework.dll' name 'CreateObjectSet';

// SPRINT-02 — MSSQL driver
function JanusConnectMSSQL(AHost, ADatabase, AUser, APass: PWideChar;
  APort: Integer): IJanusConnection; stdcall;
  external 'JanusFramework.dll' name 'ConnectMSSQL';

// SPRINT-02 — Oracle driver
// AHost: server/host or TNS alias; ADatabase: SID or service name
function JanusConnectOracle(AHost, ADatabase, AUser, APass: PWideChar): IJanusConnection; stdcall;
  external 'JanusFramework.dll' name 'ConnectOracle';

// SPRINT-02 — Query factory
// Usage: JanusCreateQuery(...).Where(...).OrderBy(...).PageSize(N).Execute
function JanusCreateQuery(AEntityName: PWideChar;
  AConn: IJanusConnection): IJanusQuery; stdcall;
  external 'JanusFramework.dll' name 'CreateQuery';

// SPRINT-03 — Programmatic entity registration (Strategy 2)
// Usage: JanusCreateEntityBuilder
//          .EntityName(PWideChar(WideString('TOrder')))
//          .TableName(PWideChar(WideString('orders')))
//          .AddColumn(PWideChar(WideString('id')),    PWideChar(WideString('integer')), 0)
//          .AddColumn(PWideChar(WideString('descr')), PWideChar(WideString('string')),  100)
//          .PrimaryKey(PWideChar(WideString('id')))
//          .Build;
// After Build = True, call JanusCreateObjectSet with the entity name.
//
// SPRINT-04 — Relationship methods (vtable append, ADR-006):
//   .AddForeignKey(AName, ARefTable, AFromColumn, AToColumn)
//   .ForeignKeyRule(AOnDelete, AOnUpdate)    -- applies to last FK added
//   .AddJoinColumn(AColumn, ARefTable, ARefColumn, AJoinType)
//   .AddAssociation(AMultiplicity, AColumn, ARefColumn, ARefEntity)
//
// Enum values (Integer):
//   JoinType:     0=InnerJoin, 1=LeftJoin, 2=RightJoin, 3=FullJoin
//   RuleAction:   0=NoAction,  1=Cascade,  2=SetNull,   3=SetDefault
//   Multiplicity: 0=OneToOne,  1=OneToMany, 2=ManyToOne, 3=ManyToMany
//
// Example master/detail:
//   JanusCreateEntityBuilder
//     .EntityName(PWideChar(WideString('TOrderItem')))
//     .TableName(PWideChar(WideString('order_items')))
//     .AddColumn(PWideChar(WideString('id')),       PWideChar(WideString('integer')), 0)
//     .AddColumn(PWideChar(WideString('order_id')), PWideChar(WideString('integer')), 0)
//     .AddColumn(PWideChar(WideString('product')),  PWideChar(WideString('string')), 100)
//     .PrimaryKey(PWideChar(WideString('id')))
//     .AddForeignKey(PWideChar(WideString('fk_order')),
//                    PWideChar(WideString('orders')),
//                    PWideChar(WideString('order_id')),
//                    PWideChar(WideString('id')))
//     .ForeignKeyRule(1, 0)   // OnDelete=Cascade, OnUpdate=NoAction
//     .AddJoinColumn(PWideChar(WideString('order_id')),
//                    PWideChar(WideString('orders')),
//                    PWideChar(WideString('id')), 1)  // LeftJoin
//     .AddAssociation(2,     // ManyToOne
//                     PWideChar(WideString('order_id')),
//                     PWideChar(WideString('id')),
//                     PWideChar(WideString('TOrder')))
//     .Build;
function JanusCreateEntityBuilder: IJanusEntityBuilder; stdcall;
  external 'JanusFramework.dll' name 'CreateEntityBuilder';

implementation

end.
