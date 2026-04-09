unit Janus.DLL.Interfaces;

// =============================================================================
// JANUS ORM -- DLL Bridge Interfaces
//
// Declares the COM-compatible interface types shared between the DLL
// implementation and the consumer file (Janus.IncludeDll.pas).
//
// Rules:
//   - No `external` declarations here (this unit is used BY the DLL itself).
//   - Consumer projects MUST use Janus.IncludeDll.pas, not this unit directly.
//   - Compatible with Delphi XE+ (DLL side) and Delphi 7+/FPC 3.x (consumer).
// =============================================================================

interface

type
  IJanusRecord = interface(IInterface)
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567891}']
    function  GetStr(AField: PWideChar): PWideChar; stdcall;
    function  GetInt(AField: PWideChar): Integer; stdcall;
    function  GetFloat(AField: PWideChar): Double; stdcall;
    function  GetBool(AField: PWideChar): LongBool; stdcall;
    procedure SetStr(AField, AValue: PWideChar); stdcall;
    procedure SetInt(AField: PWideChar; AValue: Integer); stdcall;
    procedure SetFloat(AField: PWideChar; AValue: Double); stdcall;
    procedure SetBool(AField: PWideChar; AValue: LongBool); stdcall;
  end;

  IJanusObjectSet = interface(IInterface)
    ['{B2C3D4E5-F6A7-8901-BCDE-F12345678902}']
    function  Open: LongBool; stdcall;
    function  OpenWhere(AWhere, AOrderBy: PWideChar): LongBool; stdcall;
    function  FindByID(AID: Integer): IJanusRecord; stdcall;
    function  RecordCount: Integer; stdcall;
    function  GetRecord(AIndex: Integer): IJanusRecord; stdcall;
    function  NewRecord: IJanusRecord; stdcall;
    procedure Insert(ARecord: IJanusRecord); stdcall;
    procedure Update(ARecord: IJanusRecord); stdcall;
    procedure Delete(ARecord: IJanusRecord); stdcall;
    // SPRINT-08 — Pagination + Navigation (vtable append, ADR-009)
    function  NextPacket(APageSize, APageNext: Integer): LongBool; stdcall;
    function  First: LongBool; stdcall;
    function  Next: LongBool; stdcall;
    function  Prior: LongBool; stdcall;
    function  Eof: LongBool; stdcall;
    function  CurrentRecord: IJanusRecord; stdcall;
  end;

  IJanusConnection = interface(IInterface)
    ['{C3D4E5F6-A7B8-9012-CDEF-123456789013}']
    function IsConnected: LongBool; stdcall;
  end;

  IJanusQuery = interface(IInterface)
    ['{E4F5A6B7-C8D9-0123-EFA0-23456789B015}']
    function Where(ASql: PWideChar): IJanusQuery; stdcall;
    function OrderBy(AField: PWideChar): IJanusQuery; stdcall;
    function PageSize(ASize: Integer): IJanusQuery; stdcall;
    function Execute: IJanusObjectSet; stdcall;
  end;

  // SPRINT-03 — Strategy 2: Programmatic entity registration
  // Fluent, COM-safe builder for defining entities without pre-compiled Delphi models.
  // Usage: JanusCreateEntityBuilder.EntityName(...).TableName(...).AddColumn(...).PrimaryKey(...).Build
  //
  // SPRINT-04 — Relationship methods added via vtable append (ADR-006):
  //   .AddForeignKey(Name, RefTable, FromCol, ToCol)
  //   .ForeignKeyRule(OnDelete, OnUpdate)       -- applies to last FK added
  //   .AddJoinColumn(Col, RefTable, RefCol, JoinType)
  //   .AddAssociation(Multiplicity, Col, RefCol, RefEntity)
  //
  // Enum values (Integer):
  //   JoinType:     0=InnerJoin, 1=LeftJoin, 2=RightJoin, 3=FullJoin
  //   RuleAction:   0=NoAction,  1=Cascade,  2=SetNull,   3=SetDefault
  //   Multiplicity: 0=OneToOne,  1=OneToMany, 2=ManyToOne, 3=ManyToMany
  IJanusEntityBuilder = interface(IInterface)
    ['{F5A6B7C8-D9E0-1234-F0A1-3456789BC026}']
    function EntityName(AName: PWideChar): IJanusEntityBuilder; stdcall;
    function TableName(AName: PWideChar): IJanusEntityBuilder; stdcall;
    function AddColumn(AName, AType: PWideChar; ASize: Integer): IJanusEntityBuilder; stdcall;
    function PrimaryKey(AColumn: PWideChar): IJanusEntityBuilder; stdcall;
    function Build: LongBool; stdcall;
    // SPRINT-04 — Relationship methods (vtable append, ADR-006)
    function AddForeignKey(AName, ARefTable, AFromColumn, AToColumn: PWideChar): IJanusEntityBuilder; stdcall;
    function ForeignKeyRule(AOnDelete, AOnUpdate: Integer): IJanusEntityBuilder; stdcall;
    function AddJoinColumn(AColumn, ARefTable, ARefColumn: PWideChar; AJoinType: Integer): IJanusEntityBuilder; stdcall;
    function AddAssociation(AMultiplicity: Integer; AColumn, ARefColumn, ARefEntity: PWideChar): IJanusEntityBuilder; stdcall;
  end;

implementation

end.
