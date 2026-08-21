{
  ------------------------------------------------------------------------------
  Janus ORM
  State-of-the-art Object-Relational Mapping (ORM) framework for Delphi.

  SPDX-License-Identifier: MIT
  Copyright (c) 2025-2026 Isaque Pinheiro

  Licensed under the MIT License.
  See the LICENSE file in the project root for full license information.
  ------------------------------------------------------------------------------
}

{
  @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
}

unit Janus.Container.DataSet;

interface

uses
  DB,
  RTTi,
  Classes,
  SysUtils,
  Generics.Collections,
  /// Janus
  Janus.Container.DataSet.Interfaces,
  Janus.Session.Abstract,
  DataEngine.FactoryInterfaces,
  Janus.DataSet.Base.Adapter;

type
  TContainerDataSet<M: class, constructor> = class(TInterfacedObject, IContainerDataSet<M>)
  private
    function _GetAutoNextPacket: Boolean;
    procedure _SetAutoNextPacket(const Value: Boolean);
  protected
    FDataSetAdapter: TDataSetBaseAdapter<M>;
  public
    destructor Destroy; override;
    procedure LoadLazy(AOwner: M);
    procedure Open; overload;
    procedure Open(const AID: Int64); overload;
    procedure Open(const AIDs: TArray<TValue>); overload;
    procedure Open(const AID: String); overload;
    procedure OpenWhere(const AWhere: String; const AOrderBy: String = '');
    procedure OpenSQL(const ASQL: String);
    procedure Insert;
    procedure Append;
    procedure Post;
    procedure Edit;
    procedure Delete;
    procedure Close;
    procedure Cancel;
    procedure RefreshRecord;
    procedure RefreshRecordWhere(const AWhere: String);
    procedure EmptyDataSet;
    procedure CancelUpdates;
    procedure Save(AObject: M);
    procedure ApplyUpdates(MaxErros: Integer);
    procedure AddLookupField(AFieldName: String;
                             AKeyFields: String;
                             ALookupDataSet: TObject;
                             ALookupKeyFields: String;
                             ALookupResultField: String;
                             ADisplayLabel: String = '');
    procedure NextPacket; virtual;
    function DataSet: TDataSet;
    function MasterObject: TDataSetBaseAdapter<M>;
    function This: TDataSetBaseAdapter<M>;
    function Current: M;
    // ObjectSet
    function Find: TObjectList<M>; overload;
    function Find(const AID: Int64): M; overload;
    function Find(const AIDs: TArray<TValue>): M; overload;
    function Find(const AID: String): M; overload;
    function FindWhere(const AWhere: String; const AOrderBy: String = ''): TObjectList<M>;
  end;

implementation

{ TContainerDataSet<M> }

procedure TContainerDataSet<M>.AddLookupField(AFieldName, AKeyFields: String;
  ALookupDataSet: TObject; ALookupKeyFields, ALookupResultField: String;
  ADisplayLabel: String);
begin
  inherited;
  FDataSetAdapter.AddLookupField(AFieldName,
                                 AKeyFields,
                                 ALookupDataSet,
                                 ALookupKeyFields,
                                 ALookupResultField,
                                 ADisplayLabel);
end;

procedure TContainerDataSet<M>.Append;
begin
  FDataSetAdapter.Append;
end;

procedure TContainerDataSet<M>.ApplyUpdates(MaxErros: Integer);
begin
  FDataSetAdapter.ApplyUpdates(MaxErros);
end;

procedure TContainerDataSet<M>.Cancel;
begin
  FDataSetAdapter.Cancel;
end;

procedure TContainerDataSet<M>.CancelUpdates;
begin
  FDataSetAdapter.CancelUpdates;
end;

/// <summary> Closes the dataset. It used to CLEAR it instead - byte for byte
///  the body TContainerDataSet<M>.EmptyDataSet still has - and the reason was
///  never taste: a genuine close was a one-way door. Every open path begins with
///  EmptyDataSet, EmptyDataSet goes through CheckBrowseMode, and on a closed
///  dataset that raises, so nothing could reopen what this closed.
///  TDataSetBaseAdapter<M>.EnsureOpen is what removed the door, and only with
///  it in place does closing here become a decision rather than a trap.
///  IT IS A BEHAVIOUR CHANGE and it is meant to be one: what a consumer gets
///  back afterwards is a CLOSED dataset, not an empty open one. Whoever wanted
///  the old shape asks for EmptyDataSet, which is still here, unchanged.
///  WHO IS AFFECTED, counted over Source\, Test\ and Examples\: this method and
///  TManagerDataSet.Close<T> have FOUR call sites outside the framework, all
///  under Examples\Delphi, and they do NOT all have the same shape. The two
///  WebService ones (TForm2.btnBuscaCEPClick and TForm2.btnBuscarClick under
///  RESTFul via Driver) close and reopen in the same handler, so nothing there
///  can tell the difference. The other two (TForm3.Button4Click of the ADO and
///  the DBExpress uMainFormORM) close and STOP - their Open lives in a separate
///  button - so whatever is bound to them stays in the post-Close state until
///  the operator presses Open. What a bound control sees in that state changed
///  from an open empty dataset to an inactive one - measured on the FDMemTable
///  family by
///  Test.Janus.Close.VsEmpty.BoundControl_NowSeesTheContainerCloseAsInactive,
///  which also measures that the control's own reads still do not raise.
///  Pinned by Test.Janus.Reopen.Lazy
///  .Close_TheContainerNowLeavesTheFDMemTableClosed (and the ClientDataSet and
///  manager siblings next to it). </summary>
procedure TContainerDataSet<M>.Close;
begin
  FDataSetAdapter.Close;
end;

function TContainerDataSet<M>.MasterObject: TDataSetBaseAdapter<M>;
begin
  Result := FDataSetAdapter;
end;

procedure TContainerDataSet<M>.Delete;
begin
  FDataSetAdapter.Delete;
end;

destructor TContainerDataSet<M>.Destroy;
begin
  inherited;
end;

procedure TContainerDataSet<M>.Edit;
begin
  FDataSetAdapter.Edit;
end;

procedure TContainerDataSet<M>.EmptyDataSet;
begin
  FDataSetAdapter.EmptyDataSet;
end;

function TContainerDataSet<M>.Find: TObjectList<M>;
begin
  Result := FDataSetAdapter.Find;
end;

function TContainerDataSet<M>.Find(const AIDs: TArray<TValue>): M;
begin
  Result := FDataSetAdapter.Find(AIDs);
end;

function TContainerDataSet<M>.Find(const AID: Int64): M;
begin
  Result := FDataSetAdapter.Find(AID);
end;

function TContainerDataSet<M>.Find(const AID: String): M;
begin
  Result := FDataSetAdapter.Find(AID);
end;

function TContainerDataSet<M>.FindWhere(const AWhere, AOrderBy: String): TObjectList<M>;
begin
  Result := FDataSetAdapter.FindWhere(AWhere, AOrderBy);
end;

function TContainerDataSet<M>._GetAutoNextPacket: Boolean;
begin
  Result := FDataSetAdapter.AutoNextPacket
end;

function TContainerDataSet<M>.Current: M;
begin
  Result := FDataSetAdapter.Current;
end;

function TContainerDataSet<M>.DataSet: TDataSet;
begin
  Result := FDataSetAdapter.FOrmDataSet;
end;

procedure TContainerDataSet<M>.Insert;
begin
  inherited;
  FDataSetAdapter.Insert;
end;

procedure TContainerDataSet<M>.LoadLazy(AOwner: M);
begin
  FDataSetAdapter.LoadLazy(AOwner);
end;

procedure TContainerDataSet<M>.NextPacket;
begin
  FDataSetAdapter.NextPacket;
end;

procedure TContainerDataSet<M>.Open;
begin
  FDataSetAdapter.OpenSQLInternal('');
end;

procedure TContainerDataSet<M>.OpenWhere(const AWhere, AOrderBy: String);
begin
  FDataSetAdapter.OpenWhereInternal(AWhere, AOrderBy);
end;

procedure TContainerDataSet<M>.Open(const AID: String);
begin
  FDataSetAdapter.OpenIDInternal(AID);
end;

procedure TContainerDataSet<M>.OpenSQL(const ASQL: String);
begin
  FDataSetAdapter.OpenSQLInternal(ASQL);
end;

procedure TContainerDataSet<M>.Open(const AIDs: TArray<TValue>);
begin
  FDataSetAdapter.OpenIDInternal(TValue.From<TArray<TValue>>(AIDs));
end;

procedure TContainerDataSet<M>.Open(const AID: Int64);
begin
  FDataSetAdapter.OpenIDInternal(AID);
end;

procedure TContainerDataSet<M>.Post;
begin
  FDataSetAdapter.Post;
end;

procedure TContainerDataSet<M>.RefreshRecord;
begin
  FDataSetAdapter.RefreshRecord;
end;

procedure TContainerDataSet<M>.RefreshRecordWhere(const AWhere: String);
begin
  FDataSetAdapter.RefreshRecordWhere(AWhere);
end;

procedure TContainerDataSet<M>.Save(AObject: M);
begin
  FDataSetAdapter.Save(AObject);
end;

procedure TContainerDataSet<M>._SetAutoNextPacket(const Value: Boolean);
begin
  FDataSetAdapter.AutoNextPacket := Value;
end;

function TContainerDataSet<M>.This: TDataSetBaseAdapter<M>;
begin
  Result := FDataSetAdapter;
end;

end.
