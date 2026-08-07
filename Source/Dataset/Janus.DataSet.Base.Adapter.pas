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
  @abstract(Website : http://www.Janus.com.br)
}

{$INCLUDE ..\Janus.inc}

unit Janus.DataSet.Base.Adapter;

interface

uses
  DB,
  Rtti,
  TypInfo,
  Classes,
  SysUtils,
  StrUtils,
  Variants,
  Generics.Collections,
  Janus.DataSet.Events,
  Janus.DataSet.Abstract,
  Janus.Session.Abstract,
  MetaDbDiff.mapping.classes;

type
 TDataSetBaseAdapter<M: class, constructor> = class(TDataSetAbstract<M>)
  private
  class var
    /// <summary> Source of row identities for cRowTokenField. Monotonic, and
    ///  never compared across entity types: a child copies the token out of
    ///  its master's own row, so both sides of every comparison
    ///  _IsOwnedByMasterRow makes were minted by the SAME instantiation of
    ///  this counter. Two adapters over the same entity - which is the REST
    ///  client's normal shape - therefore cannot hand out the same identity,
    ///  which is the only collision that would matter. </summary>
    FRowTokenSeq: Integer;
  private
    FOrmDataSetEvents: TDataSetLocal;
    FPageSize: Integer;
    procedure _ExecuteOneToOne(AObject: M; AProperty: TRttiProperty;
      ADatasetBase: TDataSetBaseAdapter<M>);
    procedure _ExecuteOneToMany(AObject: M; AProperty: TRttiProperty;
      ADatasetBase: TDataSetBaseAdapter<M>; ARttiType: TRttiType);
    procedure _GetMasterValues;
    function _FindEvents(AEventName: String): Boolean;
    function _GetAutoNextPacket: Boolean;
    procedure _SetAutoNextPacket(const Value: Boolean);
    procedure _ValideFieldEvents(const AFieldEvents: TFieldEventsMappingList);
    function _DetachMasterLink(const ADataSet: TDataSet): TObject;
    procedure _RestoreMasterLink(const ADataSet: TDataSet; const ASource: TObject);
    function _IsPendingInsertRow(const ADataSet: TDataSet): Boolean;
    procedure _StampRowTokens;
    function _IsOwnedByMasterRow(const AChild: TDataSet;
      const AMasterToken: Integer): Boolean;
    procedure _RecurseOverChildRows(
      const AChildAdapter: TDataSetBaseAdapter<M>);
    procedure _AutoIncToChildRows(const AMaster, AChild: TDataSet;
      const AAssociation: TAssociationMapping);
    function _HasPendingRows(const AAdapter: TDataSetBaseAdapter<M>): Boolean;
    function _PendingChilds: TArray<TDataSet>;
  protected
    FBeforeScrollPendingChilds: TBeforeScrollPendingChildsEvent;
    FDataSetEvents: TDataSetEvents;
    FOwnerMasterObject: TObject;
    FCurrentInternal: M;
    FMasterObject: TDictionary<String, TDataSetBaseAdapter<M>>;
    FLookupsField: TList<TDataSetBaseAdapter<M>>;
    FInternalIndex: Integer;
    FAutoNextPacket: Boolean;
    FCheckedFieldEvents: Boolean;
    FLastPKValue: String;
    FProxiesInjectedForCurrentRow: Boolean;
    function _GetCurrentPKAsString: String;
    procedure DoBeforeScroll(DataSet: TDataSet); virtual;
    procedure DoBeforeScrollPendingChilds; virtual;
    procedure DoAfterScroll(DataSet: TDataSet); virtual;
    procedure DoBeforeOpen(DataSet: TDataSet); virtual;
    procedure DoAfterOpen(DataSet: TDataSet); virtual;
    procedure DoBeforeClose(DataSet: TDataSet); virtual;
    procedure DoAfterClose(DataSet: TDataSet); virtual;
    procedure DoBeforeDelete(DataSet: TDataSet); virtual;
    procedure DoAfterDelete(DataSet: TDataSet); virtual;
    procedure DoBeforeInsert(DataSet: TDataSet); virtual;
    procedure DoAfterInsert(DataSet: TDataSet); virtual;
    procedure DoBeforeEdit(DataSet: TDataSet); virtual;
    procedure DoAfterEdit(DataSet: TDataSet); virtual;
    procedure DoBeforePost(DataSet: TDataSet); virtual;
    procedure DoAfterPost(DataSet: TDataSet); virtual;
    procedure DoBeforeCancel(DataSet: TDataSet); virtual;
    procedure DoAfterCancel(DataSet: TDataSet); virtual;
    procedure DoNewRecord(DataSet: TDataSet); virtual;
    procedure GetDataSetEvents; virtual;
    procedure SetDataSetEvents; virtual;
    procedure DisableDataSetEvents; virtual;
    procedure EnableDataSetEvents; virtual;
    procedure Insert; virtual;
    procedure Append; virtual;
    procedure Post; virtual;
    procedure Edit; virtual;
    procedure Delete; virtual;
    procedure Close; virtual;
    procedure EnsureOpen;
    procedure Cancel; virtual;
    procedure SetAutoIncValueChilds; virtual;
    procedure SetMasterObject(const AValue: TObject); virtual;
    procedure FillMastersClass(const ADatasetBase: TDataSetBaseAdapter<M>; AObject: M); virtual;
    function IsAssociationUpdateCascade(ADataSetChild: TDataSetBaseAdapter<M>;
      AColumnsNameRef: String): Boolean; virtual;
  public
    constructor Create(ADataSet: TDataSet; APageSize: Integer;
      AMasterObject: TObject); overload; override;
    destructor Destroy; override;
    procedure RefreshRecordInternal(const AObject: TObject); virtual;
    procedure RefreshRecord; virtual;
    procedure RefreshRecordWhere(const AWhere: String); virtual;
    procedure NextPacket; overload; virtual; abstract;
    procedure Save(AObject: M); virtual;
    procedure CancelUpdates; virtual;
    procedure AddLookupField(const AFieldName: String;
                             const AKeyFields: String;
                             const ALookupDataSet: TObject;
                             const ALookupKeyFields: String;
                             const ALookupResultField: String;
                             const ADisplayLabel: String = '');
    function Current: M;
    // ObjectSet
    function Find: TObjectList<M>; overload; virtual;
    function Find(const AID: Integer): M; overload; virtual;
    function Find(const AID: String): M; overload; virtual;
    function FindWhere(const AWhere: String; const AOrderBy: String = ''): TObjectList<M>; virtual;
    // Property
    property AutoNextPacket: Boolean read _GetAutoNextPacket write _SetAutoNextPacket;
    /// <summary> Says what must happen to child rows that are typed in and not
    ///  yet saved when the master is about to scroll. LEAVE IT UNASSIGNED AND
    ///  NOTHING CHANGES: DoBeforeScrollPendingChilds returns on its first line,
    ///  so not one child dataset is even inspected and the historical discard
    ///  stands. Assign it and the discard stops being a side effect of the
    ///  re-query inside TDataSetAdapter<M>.DoAfterScroll and becomes something
    ///  somebody chose - see TPendingChildsAction.
    ///  Reached from a consumer as IContainerDataSet<M>.This.
    ///  FIRED ONLY BY THE TDataSetAdapter<M> FAMILY (TFDMemTableAdapter,
    ///  TClientDataSetAdapter). TRESTDataSetAdapter<M> inherits the property
    ///  and never fires it, because its own OpenDataSetChilds has an empty body
    ///  and therefore discards nothing - there is no loss there to decide
    ///  about. Measured by Test.Janus.Scroll.PendingChilds. </summary>
    property OnBeforeScrollPendingChilds: TBeforeScrollPendingChildsEvent
      read FBeforeScrollPendingChilds write FBeforeScrollPendingChilds;
  end;

implementation

uses
  Janus.Bind,
  Janus.DataSet.Fields,
  Janus.DataSet.Consts,
  Janus.Objects.Helper,
  Janus.Objects.Utils,
  Janus.RTTI.Helper,
  MetaDbDiff.mapping.explorer,
  MetaDbDiff.mapping.attributes,
  MetaDbDiff.types.mapping;

const
  /// <summary> The value cRowTokenField and cOwnerTokenField carry when the
  ///  framework never saw the row created - a row appended while the adapter's
  ///  events were unhooked, or read back from a store that has no such column.
  ///  It is the zero a TField answers for a NULL integer, so it costs no
  ///  default expression and no migration.
  ///  DECLARED HERE, in the implementation, and not beside the two column
  ///  names: nothing outside this unit needs it, and the public surface of a
  ///  framework the community consumes is not the place to put a private
  ///  convention. </summary>
  cNoRowToken = 0;

{ TDataSetBaseAdapter<M> }

constructor TDataSetBaseAdapter<M>.Create(ADataSet: TDataSet;
  APageSize: Integer; AMasterObject: TObject);
begin
  FOrmDataSet := ADataSet;
  FPageSize := APageSize;
  FLastPKValue := '';
  FProxiesInjectedForCurrentRow := False;
  FBeforeScrollPendingChilds := nil;
  FOrmDataSetEvents := TDataSetLocal.Create(nil);
  FMasterObject := TDictionary<String, TDataSetBaseAdapter<M>>.Create;
  FLookupsField := TList<TDataSetBaseAdapter<M>>.Create;
  FCurrentInternal := M.Create;
  Bind.SetInternalInitFieldDefsObjectClass(ADataSet, FCurrentInternal);
  Bind.SetDataDictionary(ADataSet, FCurrentInternal);
  FDataSetEvents := TDataSetEvents.Create;
  FAutoNextPacket := True;
  // Variavel que identifica o campo que armazena o estado do registro.
  FInternalIndex := 0;
  FCheckedFieldEvents := False;
  if AMasterObject <> nil then
    SetMasterObject(AMasterObject);
  inherited Create(ADataSet, APageSize, AMasterObject);
end;

destructor TDataSetBaseAdapter<M>.Destroy;
begin
  FOrmDataSet := nil;
  FOwnerMasterObject := nil;
  FDataSetEvents.Free;
  FOrmDataSetEvents.Free;
  FCurrentInternal.Free;
  FMasterObject.Clear;
  FMasterObject.Free;
  FLookupsField.Clear;
  FLookupsField.Free;
  inherited;
end;

procedure TDataSetBaseAdapter<M>.Save(AObject: M);
begin
  // Aualiza o DataSet com os dados a variavel interna
  FOrmDataSet.Edit;
  Bind.SetPropertyToField(AObject, FOrmDataSet);
  FOrmDataSet.Post;
end;

procedure TDataSetBaseAdapter<M>.Cancel;
begin
  FOrmDataSet.Cancel;
end;

procedure TDataSetBaseAdapter<M>.CancelUpdates;
begin
  FSession.ModifiedFields.Items[M.ClassName].Clear;
end;

procedure TDataSetBaseAdapter<M>.Close;
begin
  FOrmDataSet.Close;
end;

/// <summary> Gives the adapter back the one thing it could not do: come back
///  from a closed dataset. It is called at the head of every Open*Internal of
///  the four dataset adapters, AHEAD of the EmptyDataSet that opens them -
///  EmptyDataSet goes through CheckBrowseMode, and on a closed dataset that
///  raises "Cannot perform this operation on a closed dataset".
///  A BARE Open IS THE WHOLE FIX, and it was measured to be enough on each of
///  the four separately - Test.Janus.Reopen.Lazy has one Reopen_* per adapter
///  and infers nothing from one family to another.
///  WHAT A GENUINE CLOSE COSTS IS NOT A RESOURCE THE ADAPTER HAS TO REBUILD.
///  The runtime TFields survive it because TFieldSingleton.AddField names them
///  and binds them to the dataset, which makes them persistent, so
///  DestroyFields - which only clears the automatic ones - leaves them alone.
///  Measured on both the FDMemTable and the ClientDataSet family, and it is the
///  SAME TField objects before the close, after it and after the reopen:
///  Test.Janus.Reopen.Lazy
///  .Fields_TheSameObjectsSurviveCloseAndReopen_BothFamilies.
///  WHAT THE REOPEN DOES NOT BRING BACK IS THE ROWS, and the two families do
///  not agree: a reopened TFDMemTable comes back with 0 records, a reopened
///  TClientDataSet comes back with the records it had - measured by
///  Test.Janus.Reopen.Lazy
///  .Rows_ABareReopenBringsBackNothingOnFDMemTableAndEverythingOnClientDataSet.
///  It costs the callers nothing because every one of them clears the dataset
///  on the very next line, but it is the reason this is not a way to preserve
///  data across a close.
///  HOW EACH ADAPTER USED TO REPORT THE FAILED REOPEN IS NOT PINNED ANYWHERE,
///  because with this method in place none of them fails. What can be read
///  without running anything is that TFDMemTableAdapter and TClientDataSetAdapter
///  wrap their whole open block in `on E: Exception do raise
///  Exception.Create(E.Message)` while the two REST adapters have no except
///  block at all; the only runtime datum that survives is #246's, on
///  TFDMemTableAdapter, where the failure arrived already re-wrapped as a plain
///  Exception.
///  Not virtual on purpose: no family was found to need anything else.
///  Pinned by Test.Janus.Reopen.Lazy - every Reopen_* test there fails without
///  this method. </summary>
procedure TDataSetBaseAdapter<M>.EnsureOpen;
begin
  if FOrmDataSet = nil then
    Exit;
  if FOrmDataSet.Active then
    Exit;
  FOrmDataSet.Open;
end;

procedure TDataSetBaseAdapter<M>.AddLookupField(const AFieldName: String;
                                                const AKeyFields: String;
                                                const ALookupDataSet: TObject;
                                                const ALookupKeyFields: String;
                                                const ALookupResultField: String;
                                                const ADisplayLabel: String);
var
  LColumn: TColumnMapping;
  LColumns: TColumnMappingList;
begin
  // Guarda o datasetlookup em uma lista para controle interno
  FLookupsField.Add(TDataSetBaseAdapter<M>(ALookupDataSet));
  LColumns := TMappingExplorer.GetMappingColumn(FLookupsField.Last.FCurrentInternal.ClassType);
  if LColumns = nil then
    Exit;

  for LColumn in LColumns do
  begin
    if LColumn.ColumnName <> ALookupResultField then
      Continue;

    DisableDataSetEvents;
    FOrmDataSet.Close;
    try
      TFieldSingleton.GetInstance
                     .AddLookupField(AFieldName,
                                     FOrmDataSet,
                                     AKeyFields,
                                     FLookupsField.Last.FOrmDataSet,
                                     ALookupKeyFields,
                                     ALookupResultField,
                                     LColumn.FieldType,
                                     LColumn.Size,
                                     ADisplayLabel);
    finally
      FOrmDataSet.Open;
      EnableDataSetEvents;
    end;
    // Abre a tabela do TLookupField
    FLookupsField.Last.OpenSQLInternal('');
  end;
end;

procedure TDataSetBaseAdapter<M>.Append;
begin
  FOrmDataSet.Append;
end;

procedure TDataSetBaseAdapter<M>.EnableDataSetEvents;
var
  LClassType: TRttiType;
  LProperty: TRttiProperty;
  LPropInfo: PPropInfo;
  LMethod: TMethod;
  LMethodNil: TMethod;
begin
  LClassType := RttiSingleton.GetRttiType(FOrmDataSet.ClassType);
  for LProperty in LClassType.GetProperties do
  begin
    if LProperty.PropertyType.TypeKind <> tkMethod then
      Continue;
    if not _FindEvents(LProperty.Name) then
      Continue;
    LPropInfo := GetPropInfo(FOrmDataSet, LProperty.Name);
    if LPropInfo = nil then
      Continue;
    LMethod := GetMethodProp(FOrmDataSetEvents, LPropInfo);
    if not Assigned(LMethod.Code) then
      Continue;
    LMethodNil.Code := nil;
    SetMethodProp(FOrmDataSet, LPropInfo, LMethod);
    SetMethodProp(FOrmDataSetEvents, LPropInfo, LMethodNil);
  end;
end;

procedure TDataSetBaseAdapter<M>.FillMastersClass(
  const ADatasetBase: TDataSetBaseAdapter<M>; AObject: M);
var
  LRttiType: TRttiType;
  LProperty: TRttiProperty;
  LAssociation: Association;
begin
  LRttiType := RttiSingleton.GetRttiType(AObject.ClassType);
  for LProperty in LRttiType.GetProperties do
  begin
    for LAssociation in LProperty.GetAssociation do
    begin
      if LAssociation = nil then
        Continue;
      if LAssociation.Multiplicity in [TMultiplicity.OneToOne,
                                       TMultiplicity.ManyToOne] then
        _ExecuteOneToOne(AObject, LProperty, ADatasetBase)
      else
      if LAssociation.Multiplicity in [TMultiplicity.OneToMany,
                                       TMultiplicity.ManyToMany] then
        _ExecuteOneToMany(AObject, LProperty, ADatasetBase, LRttiType);
    end;
  end;
end;

procedure TDataSetBaseAdapter<M>._ExecuteOneToOne(AObject: M;
  AProperty: TRttiProperty; ADatasetBase: TDataSetBaseAdapter<M>);
var
  LBookMark: TBookmark;
  LValue: TValue;
  LObject: TObject;
  LDataSetChild: TDataSetBaseAdapter<M>;
begin
  if ADatasetBase.FCurrentInternal.ClassType <>
     AProperty.PropertyType.AsInstance.MetaclassType then
    Exit;
  LValue := AProperty.GetNullableValue(TObject(AObject));
  if not LValue.IsObject then
    Exit;
  LObject := LValue.AsObject;
  LBookMark := ADatasetBase.FOrmDataSet.Bookmark;
  ADatasetBase.FOrmDataSet.First;
  ADatasetBase.FOrmDataSet.BlockReadSize := MaxInt;
  try
    while not ADatasetBase.FOrmDataSet.Eof do
    begin
      // Popula o objeto M e o adiciona na lista e objetos com o registro do DataSet.
      Bind.SetFieldToProperty(ADatasetBase.FOrmDataSet, LObject);
      // Proximo registro
      ADatasetBase.FOrmDataSet.Next;
    end;
  finally
    ADatasetBase.FOrmDataSet.GotoBookmark(LBookMark);
    ADatasetBase.FOrmDataSet.FreeBookmark(LBookMark);
    ADatasetBase.FOrmDataSet.BlockReadSize := 0;
  end;
  // Populando em hierarquia de varios niveis
  for LDataSetChild in ADatasetBase.FMasterObject.Values do
    LDataSetChild.FillMastersClass(LDataSetChild, LObject);
end;

procedure TDataSetBaseAdapter<M>._ExecuteOneToMany(AObject: M;
  AProperty: TRttiProperty; ADatasetBase: TDataSetBaseAdapter<M>;
  ARttiType: TRttiType);
var
  LBookMark: TBookmark;
  LPropertyType: TRttiType;
  LObjectType: TObject;
  LObjectList: TObject;
  LDataSetChild: TDataSetBaseAdapter<M>;
  LDataSet: TDataSet;
begin
  LPropertyType := AProperty.PropertyType;
  LPropertyType := AProperty.GetTypeValue(LPropertyType);
  if not LPropertyType.IsInstance then
    raise Exception
            .Create('Not in instance ' + LPropertyType.Parent.ClassName + ' - '
                                       + LPropertyType.Name);
  //
  if ADatasetBase.FCurrentInternal.ClassType <>
     LPropertyType.AsInstance.MetaclassType then
    Exit;
  LDataSet := ADatasetBase.FOrmDataSet;
  LBookMark := LDataSet.Bookmark;
  LDataSet.First;
  LDataSet.BlockReadSize := MaxInt;
  try
    while not LDataSet.Eof do
    begin
      LObjectType := LPropertyType.AsInstance.MetaclassType.Create;
      LObjectType.MethodCall('Create', []);
      // Popula o objeto M e o adiciona na lista e objetos com o registro do DataSet.
      Bind.SetFieldToProperty(LDataSet, LObjectType);

      LObjectList := AProperty.GetNullableValue(TObject(AObject)).AsObject;
      LObjectList.MethodCall('Add', [LObjectType]);
      // Populando em hierarquia de varios niveis
      for LDataSetChild in ADatasetBase.FMasterObject.Values do
        LDataSetChild.FillMastersClass(LDataSetChild, LObjectType);

      // Proximo registro
      LDataSet.Next;
    end;
  finally
    LDataSet.BlockReadSize := 0;
    LDataSet.GotoBookmark(LBookMark);
    LDataSet.FreeBookmark(LBookMark);
  end;
end;

procedure TDataSetBaseAdapter<M>.DisableDataSetEvents;
var
  LClassType: TRttiType;
  LProperty: TRttiProperty;
  LPropInfo: PPropInfo;
  LMethod: TMethod;
  LMethodNil: TMethod;
begin
  LClassType := RttiSingleton.GetRttiType(FOrmDataSet.ClassType);
  for LProperty in LClassType.GetProperties do
  begin
    if LProperty.PropertyType.TypeKind <> tkMethod then
      Continue;
    if not _FindEvents(LProperty.Name) then
      Continue;
    LPropInfo := GetPropInfo(FOrmDataSet, LProperty.Name);
    if LPropInfo = nil then
      Continue;
    LMethod := GetMethodProp(FOrmDataSet, LPropInfo);
    if not Assigned(LMethod.Code) then
      Continue;
    LMethodNil.Code := nil;
    SetMethodProp(FOrmDataSet, LPropInfo, LMethodNil);
    SetMethodProp(FOrmDataSetEvents, LPropInfo, LMethod);
  end;
end;

function TDataSetBaseAdapter<M>.Find: TObjectList<M>;
begin
  Result := FSession.Find;
end;

function TDataSetBaseAdapter<M>.Find(const AID: Integer): M;
begin
  Result := FSession.Find(AID);
end;

function TDataSetBaseAdapter<M>._FindEvents(AEventName: String): Boolean;
begin
  Result := MatchStr(AEventName, ['AfterCancel'   ,'AfterClose'   ,'AfterDelete' ,
                                  'AfterEdit'     ,'AfterInsert'  ,'AfterOpen'   ,
                                  'AfterPost'     ,'AfterRefresh' ,'AfterScroll' ,
                                  'BeforeCancel'  ,'BeforeClose'  ,'BeforeDelete',
                                  'BeforeEdit'    ,'BeforeInsert' ,'BeforeOpen'  ,
                                  'BeforePost'    ,'BeforeRefresh','BeforeScroll',
                                  'OnCalcFields'  ,'OnDeleteError','OnEditError' ,
                                  'OnFilterRecord','OnNewRecord'  ,'OnPostError']);
end;

function TDataSetBaseAdapter<M>.FindWhere(const AWhere,
  AOrderBy: String): TObjectList<M>;
begin
  Result := FSession.FindWhere(AWhere, AOrderBy);
end;

procedure TDataSetBaseAdapter<M>.DoAfterClose(DataSet: TDataSet);
begin
  if Assigned(FDataSetEvents.AfterClose) then
    FDataSetEvents.AfterClose(DataSet);
end;

procedure TDataSetBaseAdapter<M>.DoAfterDelete(DataSet: TDataSet);
begin
  if Assigned(FDataSetEvents.AfterDelete) then
    FDataSetEvents.AfterDelete(DataSet);
end;

procedure TDataSetBaseAdapter<M>.DoAfterEdit(DataSet: TDataSet);
begin
  if Assigned(FDataSetEvents.AfterEdit) then
    FDataSetEvents.AfterEdit(DataSet);
end;

procedure TDataSetBaseAdapter<M>.DoAfterInsert(DataSet: TDataSet);
begin
  if Assigned(FDataSetEvents.AfterInsert) then
    FDataSetEvents.AfterInsert(DataSet);
end;

procedure TDataSetBaseAdapter<M>.DoAfterOpen(DataSet: TDataSet);
begin
  if Assigned(FDataSetEvents.AfterOpen) then
    FDataSetEvents.AfterOpen(DataSet);
end;

procedure TDataSetBaseAdapter<M>.DoAfterPost(DataSet: TDataSet);
begin
  if Assigned(FDataSetEvents.AfterPost) then
    FDataSetEvents.AfterPost(DataSet);
end;

procedure TDataSetBaseAdapter<M>.DoAfterScroll(DataSet: TDataSet);
begin
  if Assigned(FDataSetEvents.AfterScroll) then
    FDataSetEvents.AfterScroll(DataSet);
  if FPageSize = -1 then
    Exit;
  if not (FOrmDataSet.State in [dsBrowse]) then
    Exit;
  if not FOrmDataSet.Eof then
    Exit;
  if FOrmDataSet.IsEmpty then
    Exit;
  if not FAutoNextPacket then
    Exit;
  // Controle de paginacao de registros retornados do banco de dados
  NextPacket;
end;

procedure TDataSetBaseAdapter<M>.Insert;
begin
  FOrmDataSet.Insert;
end;

procedure TDataSetBaseAdapter<M>.DoBeforeCancel(DataSet: TDataSet);
var
  LChild: TDataSetBaseAdapter<M>;
  LLookup: TDataSetBaseAdapter<M>;
begin
  if Assigned(FDataSetEvents.BeforeCancel) then
    FDataSetEvents.BeforeCancel(DataSet);
  // Executa comando Cancel em cascata
  if not Assigned(FMasterObject) then
    Exit;

  if FMasterObject.Count = 0 then
    Exit;

  for LChild in FMasterObject.Values do
  begin
    if not (LChild.FOrmDataSet.State in [dsInsert, dsEdit]) then
      Continue;

    LChild.Cancel;
  end;
end;

procedure TDataSetBaseAdapter<M>.DoAfterCancel(DataSet: TDataSet);
begin
  if Assigned(FDataSetEvents.AfterCancel) then
    FDataSetEvents.AfterCancel(DataSet);
end;

procedure TDataSetBaseAdapter<M>.DoBeforeClose(DataSet: TDataSet);
var
  LChild: TDataSetBaseAdapter<M>;
  LLookup: TDataSetBaseAdapter<M>;
begin
  if Assigned(FDataSetEvents.BeforeClose) then
    FDataSetEvents.BeforeClose(DataSet);
  // Executa o comando Close em cascata
  if Assigned(FLookupsField) then
    if FLookupsField.Count > 0 then
      for LChild in FLookupsField do
        LChild.Close;

  if Assigned(FMasterObject) then
    if FMasterObject.Count > 0 then
      for LChild in FMasterObject.Values do
        LChild.Close;
end;

procedure TDataSetBaseAdapter<M>.DoBeforeDelete(DataSet: TDataSet);
begin
  if Assigned(FDataSetEvents.BeforeDelete) then
    FDataSetEvents.BeforeDelete(DataSet);
end;

procedure TDataSetBaseAdapter<M>.DoBeforeEdit(DataSet: TDataSet);
var
  LFieldEvents: TFieldEventsMappingList;
begin
  if Assigned(FDataSetEvents.BeforeEdit) then
    FDataSetEvents.BeforeEdit(DataSet);

  // Checa o Attributo "FieldEvents" nos TFields somente uma vez
  if FCheckedFieldEvents then
    Exit;

  // ForeingnKey da Child
  LFieldEvents := TMappingExplorer.GetMappingFieldEvents(FCurrentInternal.ClassType);
  if LFieldEvents = nil then
    Exit;

  _ValideFieldEvents(LFieldEvents);
  FCheckedFieldEvents := True;
end;

procedure TDataSetBaseAdapter<M>.DoBeforeInsert(DataSet: TDataSet);
var
  LFieldEvents: TFieldEventsMappingList;
begin
  if Assigned(FDataSetEvents.BeforeInsert) then
    FDataSetEvents.BeforeInsert(DataSet);
  // Checa o Attributo "FieldEvents()" nos TFields somente uma vez
  if FCheckedFieldEvents then
    Exit;
  // ForeingnKey da Child
  LFieldEvents := TMappingExplorer.GetMappingFieldEvents(FCurrentInternal.ClassType);
  if LFieldEvents = nil then
    Exit;
  _ValideFieldEvents(LFieldEvents);
  FCheckedFieldEvents := True;
end;

procedure TDataSetBaseAdapter<M>.DoBeforeOpen(DataSet: TDataSet);
begin
  if Assigned(FDataSetEvents.BeforeOpen) then
    FDataSetEvents.BeforeOpen(DataSet);
end;

procedure TDataSetBaseAdapter<M>.DoBeforePost(DataSet: TDataSet);
var
  LDataSetChild: TDataSetBaseAdapter<M>;
  LField: TField;
begin
  // Muda o Status do registro, para identificacao do Janus dos registros que
  // sofreram alteracoes.
  LField := FOrmDataSet.Fields[FInternalIndex];
  case FOrmDataSet.State of
    dsInsert:
      begin
        LField.AsInteger := Integer(FOrmDataSet.State);
      end;
    dsEdit:
      begin
        if LField.AsInteger = -1 then
          LField.AsInteger := Integer(FOrmDataSet.State);
      end;
  end;
  // Dispara o evento do componente
  if Assigned(FDataSetEvents.BeforePost) then
    FDataSetEvents.BeforePost(DataSet);

  if not FOrmDataSet.Active then
    Exit;

  // Tratamento dos datasets filhos.
  for LDataSetChild in FMasterObject.Values do
  begin
    if LDataSetChild.FOrmDataSet = nil then
      Continue;
    if not LDataSetChild.FOrmDataSet.Active then
      Continue;
    if not (LDataSetChild.FOrmDataSet.State in [dsInsert, dsEdit]) then
      Continue;
    LDataSetChild.FOrmDataSet.Post;
  end;
end;

procedure TDataSetBaseAdapter<M>.DoBeforeScroll(DataSet: TDataSet);
begin
  if Assigned(FDataSetEvents.BeforeScroll) then
    FDataSetEvents.BeforeScroll(DataSet);
end;

/// <summary> Says whether AAdapter is holding rows the operator typed and did
///  not save. TWO markers are needed and neither one alone is enough, which is
///  a measurement and not a reading:
///  - the row being typed RIGHT NOW never reached DoBeforePost, so the internal
///    column still carries its default of -1. That default is written by
///    TBind.SetInternalInitFieldDefsObjectClass, which creates the column -
///    NOT by Bind.SetDataDictionary, which only walks columns that are MAPPED
///    and carry a Dictionary attribute, and the internal column is neither.
///    Measured by Test.Janus.Apply.Loops
///    .InternalFieldCarriesTheMinusOneDefault, over an entity that declares no
///    Dictionary at all. Only State shows it;
///  - rows already posted into the in-memory table carry Integer(dsInsert) or
///    Integer(dsEdit) in that column, written by DoBeforePost and reset to -1
///    by ApplyInserter/ApplyUpdater once the row reaches the database; State is
///    dsBrowse by then and shows nothing.
///  Modified is not usable: Post clears it, so it answers False on exactly the
///  posted-but-unsaved rows this has to find - measured by
///  Marker_APostedButUnsavedRowCarriesTheInsertMarker. ChangeCount is not
///  usable either:
///  TFDMemTableAdapter<M>.Create sets CachedUpdates := False and
///  LogChanges := False, so FireDAC's own change log is empty by construction -
///  pinned by Marker_ChangeCountIsBlindToPendingRows.
///  THE WALK MUTES THE CHILD'S EVENTS ON PURPOSE. Advancing a child dataset
///  fires its own AfterScroll, which calls OpenDataSetChilds and re-reads the
///  GRANDCHILDREN from the database - merely asking whether a child is dirty
///  would destroy its unsaved children. Same reason SetAutoIncValueChilds mutes
///  them. Pinned by Detecting_DoesNotDestroyTheGrandchildren. </summary>
function TDataSetBaseAdapter<M>._HasPendingRows(
  const AAdapter: TDataSetBaseAdapter<M>): Boolean;
var
  LDataSet: TDataSet;
  LField: TField;
  LMark: TBookmark;
begin
  Result := False;
  if AAdapter = nil then
    Exit;
  LDataSet := AAdapter.FOrmDataSet;
  if LDataSet = nil then
    Exit;
  if not LDataSet.Active then
    Exit;
  if LDataSet.State in [dsInsert, dsEdit] then
    Exit(True);
  LField := LDataSet.FindField(cInternalField);
  if LField = nil then
    Exit;
  if LDataSet.IsEmpty then
    Exit;
  AAdapter.DisableDataSetEvents;
  LDataSet.DisableControls;
  LMark := LDataSet.GetBookmark;
  try
    LDataSet.First;
    while not LDataSet.Eof do
    begin
      if (LField.AsInteger = Integer(dsInsert)) or
         (LField.AsInteger = Integer(dsEdit)) then
        Exit(True);
      LDataSet.Next;
    end;
  finally
    if LDataSet.BookmarkValid(LMark) then
      LDataSet.GotoBookmark(LMark);
    LDataSet.FreeBookmark(LMark);
    LDataSet.EnableControls;
    AAdapter.EnableDataSetEvents;
  end;
end;

/// <summary> The child datasets that would lose rows if the master scrolled
///  now. Empty array when there is nothing to lose - which is the normal case
///  and the reason the caller can leave without doing anything. </summary>
function TDataSetBaseAdapter<M>._PendingChilds: TArray<TDataSet>;
var
  LChild: TDataSetBaseAdapter<M>;
  LCount: Integer;
begin
  SetLength(Result, 0);
  if not Assigned(FMasterObject) then
    Exit;
  LCount := 0;
  for LChild in FMasterObject.Values do
  begin
    if not _HasPendingRows(LChild) then
      Continue;
    SetLength(Result, LCount + 1);
    Result[LCount] := LChild.FOrmDataSet;
    Inc(LCount);
  end;
end;

/// <summary> Turns the discard into a decision. WITH NO HANDLER ASSIGNED THIS
///  IS A SINGLE COMPARISON AND A RETURN - no child is inspected, no cursor is
///  moved, no event is muted - so the default path is exactly the code that
///  shipped before this method existed. Called from
///  TDataSetAdapter<M>.DoBeforeScroll, the only family whose OpenDataSetChilds
///  really re-queries. </summary>
procedure TDataSetBaseAdapter<M>.DoBeforeScrollPendingChilds;
var
  LPendings: TArray<TDataSet>;
  LAction: TPendingChildsAction;
  LChild: TDataSetBaseAdapter<M>;
begin
  if not Assigned(FBeforeScrollPendingChilds) then
    Exit;
  LPendings := _PendingChilds;
  if Length(LPendings) = 0 then
    Exit;
  // Pre-seeded with the historical behaviour: a handler that reads nothing and
  // writes nothing leaves the framework doing what it always did.
  LAction := pcaDiscard;
  FBeforeScrollPendingChilds(Self, LPendings, LAction);
  case LAction of
    pcaPost:
      for LChild in FMasterObject.Values do
      begin
        if not _HasPendingRows(LChild) then
          Continue;
        if LChild.FOrmDataSet.State in [dsInsert, dsEdit] then
          LChild.FOrmDataSet.Post;
        LChild.ApplyUpdates(0);
      end;
    pcaCancel:
      // Abort, not a named exception: EAbort is the signal TDataSet already
      // understands for "this move is not happening", it unwinds MoveBy before
      // the cursor leaves the row, and a VCL application swallows it silently
      // instead of showing a dialog nobody asked for.
      Abort;
  end;
end;

procedure TDataSetBaseAdapter<M>.DoNewRecord(DataSet: TDataSet);
begin
  if Assigned(FDataSetEvents.OnNewRecord) then
    FDataSetEvents.OnNewRecord(DataSet);
  // Registra QUEM E esta linha e DE QUEM ela e filha. Fora do teste
  // FMasterObject.Count > 0 abaixo de proposito: aquele teste pergunta "eu
  // tenho filhos", e o ultimo nivel da hierarquia - justamente o que mais
  // precisa dizer de quem e filho - responde nao.
  _StampRowTokens;
  // Busca valor da tabela master, caso aqui seja uma tabela detalhe.
  if FMasterObject.Count > 0 then
    _GetMasterValues;
end;

procedure TDataSetBaseAdapter<M>.Delete;
begin
  FOrmDataSet.Delete;
end;

procedure TDataSetBaseAdapter<M>.Edit;
begin
  FOrmDataSet.Edit;
end;

procedure TDataSetBaseAdapter<M>.GetDataSetEvents;
begin
  // Scroll Events
  if Assigned(FOrmDataSet.BeforeScroll) then
    FDataSetEvents.BeforeScroll := FOrmDataSet.BeforeScroll;
  if Assigned(FOrmDataSet.AfterScroll) then
    FDataSetEvents.AfterScroll := FOrmDataSet.AfterScroll;
  // Open Events
  if Assigned(FOrmDataSet.BeforeOpen) then
    FDataSetEvents.BeforeOpen := FOrmDataSet.BeforeOpen;
  if Assigned(FOrmDataSet.AfterOpen) then
    FDataSetEvents.AfterOpen := FOrmDataSet.AfterOpen;
  // Close Events
  if Assigned(FOrmDataSet.BeforeClose) then
    FDataSetEvents.BeforeClose := FOrmDataSet.BeforeClose;
  if Assigned(FOrmDataSet.AfterClose) then
    FDataSetEvents.AfterClose := FOrmDataSet.AfterClose;
  // Delete Events
  if Assigned(FOrmDataSet.BeforeDelete) then
    FDataSetEvents.BeforeDelete := FOrmDataSet.BeforeDelete;
  if Assigned(FOrmDataSet.AfterDelete) then
    FDataSetEvents.AfterDelete := FOrmDataSet.AfterDelete;
  // Post Events
  if Assigned(FOrmDataSet.BeforePost) then
    FDataSetEvents.BeforePost := FOrmDataSet.BeforePost;
  if Assigned(FOrmDataSet.AfterPost) then
    FDataSetEvents.AfterPost := FOrmDataSet.AfterPost;
  // Cancel Events
  if Assigned(FOrmDataSet.BeforeCancel) then
    FDataSetEvents.BeforeCancel := FOrmDataSet.BeforeCancel;
  if Assigned(FOrmDataSet.AfterCancel) then
    FDataSetEvents.AfterCancel := FOrmDataSet.AfterCancel;
  // Insert Events
  if Assigned(FOrmDataSet.BeforeInsert) then
    FDataSetEvents.BeforeInsert := FOrmDataSet.BeforeInsert;
  if Assigned(FOrmDataSet.AfterInsert) then
    FDataSetEvents.AfterInsert := FOrmDataSet.AfterInsert;
  // Edit Events
  if Assigned(FOrmDataSet.BeforeEdit) then
    FDataSetEvents.BeforeEdit := FOrmDataSet.BeforeEdit;
  if Assigned(FOrmDataSet.AfterEdit) then
    FDataSetEvents.AfterEdit := FOrmDataSet.AfterEdit;
  // NewRecord Events
  if Assigned(FOrmDataSet.OnNewRecord) then
    FDataSetEvents.OnNewRecord := FOrmDataSet.OnNewRecord
end;

function TDataSetBaseAdapter<M>.IsAssociationUpdateCascade(
  ADataSetChild: TDataSetBaseAdapter<M>; AColumnsNameRef: String): Boolean;
var
  LForeignKey: TForeignKeyMapping;
  LForeignKeys: TForeignKeyMappingList;
begin
  Result := False;
  LForeignKeys := TMappingExplorer.GetMappingForeignKey(ADataSetChild.FCurrentInternal.ClassType);
  if LForeignKeys = nil then
    Exit;
  for LForeignKey in LForeignKeys do
  begin
    if not LForeignKey.FromColumns.Contains(AColumnsNameRef) then
      Continue;

    if LForeignKey.RuleUpdate = TRuleAction.Cascade then
      Exit(True);
  end;
end;

function TDataSetBaseAdapter<M>._GetAutoNextPacket: Boolean;
begin
  Result := FAutoNextPacket;
end;

function TDataSetBaseAdapter<M>.Current: M;
var
  LDataSetChild: TDataSetBaseAdapter<M>;
begin
  if not FOrmDataSet.Active then
    Exit(FCurrentInternal);

  if FOrmDataSet.RecordCount = 0 then
    Exit(FCurrentInternal);

  Bind.SetFieldToProperty(FOrmDataSet, TObject(FCurrentInternal));

  if not FProxiesInjectedForCurrentRow then
  begin
    if Assigned(FSession) then
      FSession.InjectLazyProxies(TObject(FCurrentInternal));
    FProxiesInjectedForCurrentRow := True;
  end;

  for LDataSetChild in FMasterObject.Values do
    LDataSetChild.FillMastersClass(LDataSetChild, FCurrentInternal);

  Result := FCurrentInternal;
end;

procedure TDataSetBaseAdapter<M>.Post;
begin
  FOrmDataSet.Post;
end;

procedure TDataSetBaseAdapter<M>.RefreshRecord;
var
  LPrimaryKey: TPrimaryKeyMapping;
  LParams: TParams;
  LFor: Integer;
begin
  inherited;
  if FOrmDataSet.RecordCount = 0 then
    Exit;
  LPrimaryKey := TMappingExplorer
                   .GetMappingPrimaryKey(FCurrentInternal.ClassType);
  if LPrimaryKey = nil then
    Exit;
  FOrmDataSet.DisableControls;
  DisableDataSetEvents;
  LParams := TParams.Create(nil);
  try
    for LFor := 0 to LPrimaryKey.Columns.Count -1 do
    begin
      with LParams.Add as TParam do
      begin
        Name := LPrimaryKey.Columns.Items[LFor];
        ParamType := ptInput;
        DataType := FOrmDataSet.FieldByName(LPrimaryKey.Columns
                                                       .Items[LFor]).DataType;
        Value := FOrmDataSet.FieldByName(LPrimaryKey.Columns
                                                    .Items[LFor]).Value;
      end;
    end;
    if LParams.Count > 0 then
      FSession.RefreshRecord(LParams);
  finally
    LParams.Clear;
    LParams.Free;
    FOrmDataSet.EnableControls;
    EnableDataSetEvents;
  end;
end;

procedure TDataSetBaseAdapter<M>.RefreshRecordInternal(const AObject: TObject);
begin

end;

procedure TDataSetBaseAdapter<M>.RefreshRecordWhere(const AWhere: String);
begin
  FOrmDataSet.DisableControls;
  DisableDataSetEvents;
  try
    FSession.RefreshRecordWhere(AWhere);
  finally
    FOrmDataSet.EnableControls;
    EnableDataSetEvents;
  end
end;

/// <summary> Desliga o vinculo master-detail do dataset filho e devolve o
///  TDataSource que estava la, para ser restaurado depois.
///  POR QUE ISTO EXISTE: o vinculo restringe o filho as linhas cuja FK e igual
///  a chave CORRENTE do master. Quando SetAutoIncValueChilds roda, o master ja
///  carrega a chave NOVA e os filhos ainda carregam a ANTIGA, de modo que o
///  conjunto filho fica com ZERO linhas visiveis: o metodo cujo trabalho e
///  atualizar os filhos nao enxerga nenhum. Medido em TFDMemTable e em
///  TClientDataSet. A propriedade e publicada nos dois, e e por ela que
///  TRESTFDMemTableAdapter<M>._FilterDataSetChilds e
///  TRESTClientDataSetAdapter<M>.FilterDataSetChilds amarram cada filho ao seu
///  master. </summary>
function TDataSetBaseAdapter<M>._DetachMasterLink(
  const ADataSet: TDataSet): TObject;
const
  cMASTERSOURCEPROP = 'MasterSource';
begin
  Result := nil;
  if ADataSet = nil then
    Exit;
  if not IsPublishedProp(ADataSet, cMASTERSOURCEPROP) then
    Exit;
  Result := GetObjectProp(ADataSet, cMASTERSOURCEPROP);
  if Result <> nil then
    SetObjectProp(ADataSet, cMASTERSOURCEPROP, nil);
end;

procedure TDataSetBaseAdapter<M>._RestoreMasterLink(const ADataSet: TDataSet;
  const ASource: TObject);
const
  cMASTERSOURCEPROP = 'MasterSource';
begin
  if (ADataSet = nil) or (ASource = nil) then
    Exit;
  if not IsPublishedProp(ADataSet, cMASTERSOURCEPROP) then
    Exit;
  SetObjectProp(ADataSet, cMASTERSOURCEPROP, ASource);
end;

/// <summary> Diz se a linha corrente do dataset filho esta PENDENTE DE
///  INSERCAO. Somente essas podem ser reapontadas para a chave nova: uma linha
///  ja gravada pertence a outro master - no cliente REST o dataset filho guarda
///  os filhos de TODOS os masters que a listagem trouxe - e carimbar nela a
///  chave recem-gerada re-parentaria dado alheio em silencio. O marcador e o
///  mesmo campo interno que ApplyInserter filtra. </summary>
function TDataSetBaseAdapter<M>._IsPendingInsertRow(
  const ADataSet: TDataSet): Boolean;
var
  LField: TField;
begin
  LField := ADataSet.FindField(cInternalField);
  Result := (LField = nil) or (LField.AsInteger = Integer(dsInsert));
end;

/// <summary> Grava a proveniencia da linha que esta sendo criada: uma
///  identidade PROPRIA, nova a cada linha, e a identidade da linha do master
///  que estava corrente neste instante. As duas sao necessarias e uma so nao
///  serve: uma linha de nivel intermediario precisa dizer QUEM ELA E, para os
///  seus proprios filhos, e DE QUEM ELA E FILHA, para o seu pai.
///  ESTE E O UNICO MOMENTO EM QUE A RESPOSTA EXISTE. Depois que a insercao
///  comeca, o master ja carrega a chave NOVA e os filhos ainda carregam a
///  ANTIGA, e nenhuma comparacao de chave consegue separa-los - foi assim que
///  o range master-detail, o bookmark e a captura previa do conjunto filho
///  falharam, cada um medido. Aqui ninguem precisa comparar nada: o cursor do
///  master esta, por construcao, sobre a linha sob a qual o usuario esta
///  digitando.
///  Chamado de DoNewRecord, isto e, so quando os eventos do adapter estao
///  ligados. Uma linha criada com eles desligados fica em cNoRowToken e cai no
///  comportamento historico - ver _IsOwnedByMasterRow. </summary>
procedure TDataSetBaseAdapter<M>._StampRowTokens;
var
  LRowToken: TField;
  LOwnerToken: TField;
  LMaster: TDataSetBaseAdapter<M>;
  LMasterToken: TField;
begin
  if FOrmDataSet = nil then
    Exit;
  LRowToken := FOrmDataSet.FindField(cRowTokenField);
  if LRowToken = nil then
    Exit;
  LRowToken.AsInteger := AtomicIncrement(FRowTokenSeq);
  LOwnerToken := FOrmDataSet.FindField(cOwnerTokenField);
  if LOwnerToken = nil then
    Exit;
  LOwnerToken.AsInteger := cNoRowToken;
  if not Assigned(FOwnerMasterObject) then
    Exit;
  LMaster := TDataSetBaseAdapter<M>(FOwnerMasterObject);
  if LMaster.FOrmDataSet = nil then
    Exit;
  if not LMaster.FOrmDataSet.Active then
    Exit;
  LMasterToken := LMaster.FOrmDataSet.FindField(cRowTokenField);
  if LMasterToken = nil then
    Exit;
  LOwnerToken.AsInteger := LMasterToken.AsInteger;
end;

/// <summary> Diz se a linha corrente do dataset filho foi criada sob a linha
///  de master identificada por AMasterToken.
///  A FOLGA E DE UM LADO SO, e isso e uma decisao medida. Quando o FILHO nao
///  tem proveniencia registrada - linha acrescentada com os eventos do adapter
///  filho desligados, ou lida de um armazenamento que nao tem a coluna - a
///  resposta e True e a linha recebe a chave como sempre recebeu; tirar essa
///  folga faria o filho deixar de ser escrito, que e regressao silenciosa.
///  Medido por Test.Janus.AutoInc.Distribution
///  .ChildRowWithNoRecordedParentage_IsStillWrittenByItsMaster.
///  Do lado do MASTER nao ha folga: um filho que sabe de quem e filho nao e
///  reapontado para uma linha de master que nao se identifica. Quando NENHUM
///  dos dois se identifica os dois valores sao cNoRowToken e a comparacao
///  responde True sozinha - que e o comportamento historico, medido por
///  UntokenisedRows_KeepTheHistoricalBehaviour. </summary>
function TDataSetBaseAdapter<M>._IsOwnedByMasterRow(const AChild: TDataSet;
  const AMasterToken: Integer): Boolean;
var
  LField: TField;
begin
  Result := True;
  LField := AChild.FindField(cOwnerTokenField);
  if LField = nil then
    Exit;
  if LField.AsInteger = cNoRowToken then
    Exit;
  Result := LField.AsInteger = AMasterToken;
end;

/// <summary> Percorre as linhas PENDENTES do adapter filho e dispara a cascata
///  do nivel seguinte UMA VEZ POR LINHA, com o cursor do filho parado sobre
///  ela.
///  POR QUE ISTO E METADE DO CONSERTO. Marcar cada neto com o pai certo nao
///  adianta se a recursao entra uma unica vez: SetAutoIncValueChilds recursava
///  uma vez por ADAPTER filho, montada em qualquer linha que o `finally` de
///  _AutoIncToChildRows tivesse deixado corrente - a primeira - e os netos
///  digitados sob qualquer outra linha nao eram alcancados por ninguem. A
///  identidade diz QUAIS linhas escrever; a caminhada e o que faz a escrita
///  acontecer mais de uma vez. Nenhuma das duas metades resolve sozinha.
///  Percorre por BOOKMARK pela mesma razao que _AutoIncToChildRows: a escrita
///  do nivel de baixo pode reordenar o filho quando ele esta indexado pela
///  coluna que esta sendo reescrita.
///  SEM NENHUMA LINHA PENDENTE recursa uma unica vez, de onde o cursor
///  estiver, que e exatamente o que este metodo substituiu - um filho ja
///  gravado tem chave propria e os seus filhos continuam a receber. </summary>
procedure TDataSetBaseAdapter<M>._RecurseOverChildRows(
  const AChildAdapter: TDataSetBaseAdapter<M>);
var
  LDataSet: TDataSet;
  LMarks: TList<TBookmark>;
  LMark: TBookmark;
  LFor: Integer;
begin
  LDataSet := AChildAdapter.FOrmDataSet;
  if LDataSet = nil then
    Exit;
  if not LDataSet.Active then
    Exit;
  LMarks := TList<TBookmark>.Create;
  LMark := LDataSet.GetBookmark;
  LDataSet.DisableControls;
  try
    LDataSet.First;
    while not LDataSet.Eof do
    begin
      if _IsPendingInsertRow(LDataSet) then
        LMarks.Add(LDataSet.GetBookmark);
      LDataSet.Next;
    end;
    if LMarks.Count = 0 then
      AChildAdapter.SetAutoIncValueChilds
    else
      for LFor := 0 to LMarks.Count -1 do
      begin
        LDataSet.GotoBookmark(LMarks[LFor]);
        AChildAdapter.SetAutoIncValueChilds;
      end;
  finally
    if LDataSet.BookmarkValid(LMark) then
      LDataSet.GotoBookmark(LMark);
    LDataSet.FreeBookmark(LMark);
    LDataSet.EnableControls;
    LMarks.Free;
  end;
end;

/// <summary> Escreve a chave do master em cada linha elegivel do dataset filho.
///  Percorre por BOOKMARK de proposito: quando o filho esta indexado pela
///  propria coluna que esta sendo reescrita - o que
///  TFDMemTableAdapter<M>._GetIndexFieldNames produz para uma entidade cujo
///  [OrderBy] e a sua FK - o Post REORDENA a linha, e um laco Post+Next cai
///  fora do conjunto depois da primeira. Bookmark identifica a LINHA, nao a
///  posicao. Medido: Post+Next atualiza 1 de 3; por bookmark, 3 de 3. </summary>
procedure TDataSetBaseAdapter<M>._AutoIncToChildRows(const AMaster,
  AChild: TDataSet; const AAssociation: TAssociationMapping);
var
  LMasterFields: TList<TField>;
  LChildFields: TList<TField>;
  LMarks: TList<TBookmark>;
  LSource: TObject;
  LMasterField: TField;
  LChildField: TField;
  LMasterToken: Integer;
  LTokenField: TField;
  LFor: Integer;
  LCol: Integer;
begin
  if (AMaster = nil) or (AChild = nil) then
    Exit;
  if not AChild.Active then
    Exit;
  LMasterFields := TList<TField>.Create;
  LChildFields := TList<TField>.Create;
  LMarks := TList<TBookmark>.Create;
  try
    for LFor := 0 to AAssociation.ColumnsName.Count -1 do
    begin
      if LFor > AAssociation.ColumnsNameRef.Count -1 then
        Break;
      LMasterField := AMaster.FindField(AAssociation.ColumnsName[LFor]);
      LChildField := AChild.FindField(AAssociation.ColumnsNameRef[LFor]);
      if (LMasterField = nil) or (LChildField = nil) then
        Continue;
      LMasterFields.Add(LMasterField);
      LChildFields.Add(LChildField);
    end;
    if LMasterFields.Count = 0 then
      Exit;
    // A identidade da linha de master sobre a qual estamos parados. Lida ANTES
    // de mexer no filho, porque e o cursor do master que a define.
    LMasterToken := cNoRowToken;
    LTokenField := AMaster.FindField(cRowTokenField);
    if LTokenField <> nil then
      LMasterToken := LTokenField.AsInteger;
    LSource := _DetachMasterLink(AChild);
    AChild.DisableControls;
    try
      // 1a passada: marca as linhas elegiveis ANTES de escrever qualquer uma.
      // DOIS filtros, e nao um: pendente de insercao - senao a linha ja
      // pertence a outro master e gravado - E filha DESTA linha de master. O
      // segundo e o que impede que uma segunda linha de master pendente, na sua
      // propria passagem por ApplyInserter, reaponte os filhos da primeira.
      AChild.First;
      while not AChild.Eof do
      begin
        if _IsPendingInsertRow(AChild) and
           _IsOwnedByMasterRow(AChild, LMasterToken) then
          LMarks.Add(AChild.GetBookmark);
        AChild.Next;
      end;
      // 2a passada: carimba a chave nova em cada linha marcada.
      for LFor := 0 to LMarks.Count -1 do
      begin
        AChild.GotoBookmark(LMarks[LFor]);
        AChild.Edit;
        for LCol := 0 to LMasterFields.Count -1 do
          LChildFields[LCol].Value := LMasterFields[LCol].Value;
        AChild.Post;
      end;
    finally
      _RestoreMasterLink(AChild, LSource);
      AChild.First;
      AChild.EnableControls;
    end;
  finally
    LMarks.Free;
    LChildFields.Free;
    LMasterFields.Free;
  end;
end;

procedure TDataSetBaseAdapter<M>.SetAutoIncValueChilds;
var
  LAssociation: TAssociationMapping;
  LAssociations: TAssociationMappingList;
  LDataSetChild: TDataSetBaseAdapter<M>;
begin
  LAssociations := TMappingExplorer
                     .GetMappingAssociation(FCurrentInternal.ClassType);
  if LAssociations = nil then
    Exit;
  for LAssociation in LAssociations do
  begin
    if not (TCascadeAction.CascadeAutoInc in LAssociation.CascadeActions) then
      Continue;
    // TryGetValue, nao Items[]: TDictionary.Items[] LEVANTA EListError quando a
    // chave nao existe, de modo que o teste de nil que vinha logo abaixo era
    // inalcancavel. Um model que declara CascadeAutoInc para uma classe cujo
    // dataset filho nunca foi criado derrubava a insercao do master.
    if not FMasterObject.TryGetValue(LAssociation.ClassNameRef,
                                     LDataSetChild) then
      Continue;
    if LDataSetChild = nil then
      Continue;
    // Eventos do filho desligados durante a escrita: o AfterScroll do adapter
    // filho chama OpenDataSetChilds, que RE-ABRE os netos a partir do banco.
    // Percorrer o filho com os eventos ligados apagaria os netos ainda nao
    // gravados antes que a recursao logo abaixo pudesse carimba-los.
    // O contrato novo (OnBeforeScrollPendingChilds) NAO substitui isto, e nao
    // ha dois mecanismos para um problema: aquele responde a uma rolagem do
    // MASTER feita pelo usuario; aqui ninguem esta rolando nada - quem anda no
    // cursor do filho e o proprio ApplyInserter, no meio de uma gravacao.
    // Medido: com o contrato novo no lugar, remover este par ainda derruba
    // Test.Janus.AutoInc.Childs.Linked_EveryGrandchildRowReceivesTheNewKey.
    // O que os dois compartilham e a TECNICA (DisableDataSetEvents), pela mesma
    // razao - e o detector de pendencia precisa dela tambem, medido por
    // Test.Janus.Scroll.PendingChilds.Detecting_DoesNotDestroyTheGrandchildren.
    LDataSetChild.DisableDataSetEvents;
    try
      _AutoIncToChildRows(FOrmDataSet, LDataSetChild.FOrmDataSet, LAssociation);
      // Populando em hierarquia de varios niveis: netos, bisnetos...
      // UMA VEZ POR LINHA do filho, e nao uma vez por adapter filho: o neto
      // pertence a uma linha determinada do meio, e so com o cursor do meio
      // parado sobre ela e que a chave que chega ao neto e a do pai dele.
      // O par de mute acima passou a cobrir tambem esta chamada porque agora
      // ela ANDA no cursor do filho, e andar com os eventos ligados dispara o
      // AfterScroll que reabre - e portanto apaga - os netos ainda nao
      // gravados.
      if LDataSetChild.FMasterObject.Count > 0 then
        _RecurseOverChildRows(LDataSetChild);
    finally
      LDataSetChild.EnableDataSetEvents;
    end;
  end;
end;

procedure TDataSetBaseAdapter<M>._SetAutoNextPacket(const Value: Boolean);
begin
  FAutoNextPacket := Value;
end;

function TDataSetBaseAdapter<M>._GetCurrentPKAsString: String;
var
  LPKColumns: TPrimaryKeyColumnsMapping;
  LFor: Integer;
begin
  Result := '';
  LPKColumns := TMappingExplorer.GetMappingPrimaryKeyColumns(M);
  if LPKColumns = nil then
    Exit;
  for LFor := 0 to LPKColumns.Columns.Count - 1 do
  begin
    if LFor > 0 then
      Result := Result + '|';
    Result := Result + VarToStr(FOrmDataSet.FieldByName(LPKColumns.Columns[LFor].ColumnName).Value);
  end;
end;

procedure TDataSetBaseAdapter<M>.SetDataSetEvents;
begin
  FOrmDataSet.BeforeScroll := DoBeforeScroll;
  FOrmDataSet.AfterScroll  := DoAfterScroll;
  FOrmDataSet.BeforeClose  := DoBeforeClose;
  FOrmDataSet.BeforeOpen   := DoBeforeOpen;
  FOrmDataSet.AfterOpen    := DoAfterOpen;
  FOrmDataSet.AfterClose   := DoAfterClose;
  FOrmDataSet.BeforeDelete := DoBeforeDelete;
  FOrmDataSet.AfterDelete  := DoAfterDelete;
  FOrmDataSet.BeforeInsert := DoBeforeInsert;
  FOrmDataSet.AfterInsert  := DoAfterInsert;
  FOrmDataSet.BeforeEdit   := DoBeforeEdit;
  FOrmDataSet.AfterEdit    := DoAfterEdit;
  FOrmDataSet.BeforePost   := DoBeforePost;
  FOrmDataSet.AfterPost    := DoAfterPost;
  FOrmDataSet.OnNewRecord  := DoNewRecord;
end;

procedure TDataSetBaseAdapter<M>._GetMasterValues;
var
  LAssociation: TAssociationMapping;
  LAssociations: TAssociationMappingList;
  LDataSetMaster: TDataSetBaseAdapter<M>;
  LField: TField;
  LFor: Integer;
begin
  if not Assigned(FOwnerMasterObject) then
    Exit;
  LDataSetMaster := TDataSetBaseAdapter<M>(FOwnerMasterObject);
  LAssociations := TMappingExplorer
                     .GetMappingAssociation(LDataSetMaster.FCurrentInternal.ClassType);
  if LAssociations = nil then
    Exit;
  for LAssociation in LAssociations do
  begin
    if not (TCascadeAction.CascadeAutoInc in LAssociation.CascadeActions) then
      Continue;
    for LFor := 0 to LAssociation.ColumnsName.Count -1 do
    begin
      LField := LDataSetMaster
                  .FOrmDataSet.FindField(LAssociation.ColumnsName.Items[LFor]);
      if LField = nil then
        Continue;
      FOrmDataSet
        .FieldByName(LAssociation.ColumnsNameRef
                                 .Items[LFor]).Value := LField.Value;
    end;
  end;
end;

procedure TDataSetBaseAdapter<M>.SetMasterObject(const AValue: TObject);
var
  LOwnerObject: TDataSetBaseAdapter<M>;
begin
  if FOwnerMasterObject = AValue then
    Exit;
  if FOwnerMasterObject <> nil then
  begin
    LOwnerObject := TDataSetBaseAdapter<M>(FOwnerMasterObject);
    if LOwnerObject.FMasterObject.ContainsKey(FCurrentInternal.ClassName) then
    begin
      LOwnerObject.FMasterObject.Remove(FCurrentInternal.ClassName);
      LOwnerObject.FMasterObject.TrimExcess;
    end;
  end;
  if AValue <> nil then
    TDataSetBaseAdapter<M>(AValue).FMasterObject
                                  .Add(FCurrentInternal.ClassName, Self);

  FOwnerMasterObject := AValue;
end;

procedure TDataSetBaseAdapter<M>._ValideFieldEvents(
  const AFieldEvents: TFieldEventsMappingList);
var
  LFor: Integer;
  LField: TField;
begin
  for LFor := 0 to AFieldEvents.Count -1 do
  begin
    LField := FOrmDataSet.FindField(AFieldEvents.Items[LFor].FieldName);
    if LField = nil then
      Continue;

    if TFieldEvent.onSetText in AFieldEvents.Items[LFor].Events then
      if not Assigned(LField.OnSetText) then
        raise Exception.CreateFmt(cFIELDEVENTS, ['OnSetText()', LField.FieldName]);

    if TFieldEvent.onGetText in AFieldEvents.Items[LFor].Events then
      if not Assigned(LField.OnGetText) then
        raise Exception.CreateFmt(cFIELDEVENTS, ['OnGetText()', LField.FieldName]);

    if TFieldEvent.onChange in AFieldEvents.Items[LFor].Events then
      if not Assigned(LField.OnChange) then
        raise Exception.CreateFmt(cFIELDEVENTS, ['OnChange()', LField.FieldName]);

    if TFieldEvent.onValidate in AFieldEvents.Items[LFor].Events then
      if not Assigned(LField.OnValidate) then
        raise Exception.CreateFmt(cFIELDEVENTS, ['OnValidate()', LField.FieldName]);
  end;
end;

function TDataSetBaseAdapter<M>.Find(const AID: String): M;
begin
  Result := FSession.Find(AID);
end;

end.
