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

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)

  ORM Brasil: um ORM simples e descomplicado para quem utiliza Delphi.
}

{$INCLUDE ..\..\Janus.inc}

unit Janus.RestDataSet.ClientDataSet;

interface

uses
  Classes,
  SysUtils,
  DB,
  Rtti,
  DBClient,
  Variants,
  Generics.Collections,
  /// Janus
  Janus.RestFactory.Interfaces,
  FluentSQL,
  Janus.DataSet.Base.Adapter,
  Janus.RestDataSet.Adapter,
  Janus.DataSet.Events,
  Janus.Objects.Helper,
  Janus.RTTI.Helper,
  // MetaDbDiff
  MetaDbDiff.mapping.classes,
  MetaDbDiff.types.mapping,
  MetaDbDiff.mapping.explorer,
  MetaDbDiff.mapping.exceptions,
  MetaDbDiff.mapping.attributes;

type
  TRESTClientDataSetEvents = class(TDataSetEvents)
  private
    FBeforeApplyUpdates: TRemoteEvent;
    FAfterApplyUpdates: TRemoteEvent;
  public
    property BeforeApplyUpdates: TRemoteEvent read FBeforeApplyUpdates write FBeforeApplyUpdates;
    property AfterApplyUpdates: TRemoteEvent read FAfterApplyUpdates write FAfterApplyUpdates;
  end;

  TRESTClientDataSetAdapter<M: class, constructor> = class(TRESTDataSetAdapter<M>)
  private
    FOrmDataSet: TClientDataSet;
    FClientDataSetEvents: TRESTClientDataSetEvents;
    procedure DoBeforeApplyUpdates(Sender: TObject; var OwnerData: OleVariant);
    procedure DoAfterApplyUpdates(Sender: TObject; var OwnerData: OleVariant);
    procedure FilterDataSetChilds;
  protected
    procedure PopularDataSetOneToOne(const AObject: TObject;
      const AAssociation: TAssociationMapping); override;
    procedure EmptyDataSetChilds; override;
    procedure GetDataSetEvents; override;
    procedure SetDataSetEvents; override;
    procedure OpenIDInternal(const AID: TValue); override;
    procedure OpenSQLInternal(const ASQL: String); override;
    procedure OpenWhereInternal(const AWhere: String; const AOrderBy: String = ''); override;
    procedure ApplyInternal(const MaxErros: Integer); override;
    procedure ApplyUpdates(const MaxErros: Integer); override;
    procedure EmptyDataSet; override;
  public
    constructor Create(const AConnection: IRESTConnection; ADataSet: TDataSet;
      APageSize: Integer; AMasterObject: TObject); overload; override;
    destructor Destroy; override;
  end;

implementation

uses
  Janus.Bind,
  Janus.DataSet.Fields;

{ TRESTClientDataSetAdapter<M> }

constructor TRESTClientDataSetAdapter<M>.Create(const AConnection: IRESTConnection;
  ADataSet: TDataSet; APageSize: Integer; AMasterObject: TObject);
begin
  inherited Create(Aconnection, ADataSet, APageSize, AMasterObject);
  /// <summary>
  /// Captura o component TClientDataset da IDE passado como parametro
  /// </summary>
  FOrmDataSet := ADataSet as TClientDataSet;
  FClientDataSetEvents := TRESTClientDataSetEvents.Create;
  /// <summary>
  /// Captura e guarda os eventos do dataset
  /// </summary>
  GetDataSetEvents;
  /// <summary>
  /// Seta os eventos do ORM no dataset, para que ele sejam disparados
  /// </summary>
  SetDataSetEvents;
  ///
  if not FOrmDataSet.Active then
  begin
     FOrmDataSet.CreateDataSet;
     FOrmDataSet.LogChanges := False;
  end;
end;

destructor TRESTClientDataSetAdapter<M>.Destroy;
begin
  FOrmDataSet := nil;
  FClientDataSetEvents.Free;
  inherited;
end;

procedure TRESTClientDataSetAdapter<M>.DoAfterApplyUpdates(Sender: TObject;
  var OwnerData: OleVariant);
begin
  if Assigned(FClientDataSetEvents.AfterApplyUpdates) then
    FClientDataSetEvents.AfterApplyUpdates(Sender, OwnerData);
end;

procedure TRESTClientDataSetAdapter<M>.DoBeforeApplyUpdates(Sender: TObject;
  var OwnerData: OleVariant);
begin
  if Assigned(FClientDataSetEvents.BeforeApplyUpdates) then
    FClientDataSetEvents.BeforeApplyUpdates(Sender, OwnerData);
end;

procedure TRESTClientDataSetAdapter<M>.EmptyDataSet;
begin
  inherited;
  FOrmDataSet.EmptyDataSet;
  /// <summary>
  /// Lista os registros das tabelas filhas relacionadas
  /// </summary>
  EmptyDataSetChilds;
end;

procedure TRESTClientDataSetAdapter<M>.EmptyDataSetChilds;
var
  LChild: TPair<String, TDataSetBaseAdapter<M>>;
  LDataSet: TClientDataSet;
begin
  inherited;
  if FMasterObject.Count > 0 then
  begin
    for LChild in FMasterObject do
    begin
      LDataSet := TRESTClientDataSetAdapter<M>(LChild.Value).FOrmDataSet;
      if LDataSet.Active then
        LDataSet.EmptyDataSet;
    end;
  end;
end;

procedure TRESTClientDataSetAdapter<M>.FilterDataSetChilds;
var
  LRttiType: TRttiType;
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LChild: TDataSetBaseAdapter<M>;
  LFor: Integer;
  LFields: String;
  LIndexFields: String;
  LClassName: String;
begin
  if not FOrmDataSet.Active then
    Exit;

  LAssociations := TMappingExplorer.GetMappingAssociation(FCurrentInternal.ClassType);
  if LAssociations = nil then
    Exit;

  for LAssociation in LAssociations do
  begin
    if LAssociation.PropertyRtti.isList then
      LRttiType := LAssociation.PropertyRtti.GetTypeValue(LAssociation.PropertyRtti.PropertyType)
    else
      LRttiType := LAssociation.PropertyRtti.PropertyType;

    LClassName := LRttiType.AsInstance.MetaclassType.ClassName;
    if not FMasterObject.TryGetValue(LClassName, LChild) then
      Continue;

    LFields := '';
    LIndexFields := '';
    TClientDataSet(LChild.FOrmDataSet).MasterSource := FOrmDataSource;
    /// <summary> Which end of the association feeds which property is fixed by
    ///  the VCL, not by taste: TCustomClientDataSet.GetDetailLinkFields resolves
    ///  MasterFields against MasterSource.DataSet - the MASTER - and the index
    ///  fields against Self - the DETAIL. So MasterFields takes ColumnsName (the
    ///  column declared on the master entity) and IndexFieldNames takes
    ///  ColumnsNameRef (the column of the referenced child table), which is also
    ///  the convention TDataSetBaseAdapter<M>._AutoIncToChildRows resolves them
    ///  by. Fed the other way round, IndexFieldNames gets a name the child has
    ///  not got and TCustomClientDataSet.SetIndex raises 'Field ... not found'.
    ///  This method sent them the other way round until
    ///  Test.Janus.MasterDetail.Link was written, and never blew up because
    ///  nothing ever reached it: the only production construction sites of this
    ///  class are TManagerDataSet.AddAdapter (both overloads), and there it
    ///  is selected only when DRIVERRESTFUL is defined AND USEFDMEMTABLE is not
    ///  - a combination Janus.inc does not ship (DRIVERRESTFUL commented out,
    ///  USEFDMEMTABLE on). Name symmetry is NOT what hid it: the tree does
    ///  carry associations whose two ends are spelled differently. </summary>
    for LFor := 0 to LAssociation.ColumnsName.Count -1 do
    begin
      LFields := LFields + LAssociation.ColumnsName[LFor];
      LIndexFields := LIndexFields + LAssociation.ColumnsNameRef[LFor];
      if LAssociation.ColumnsName.Count -1 > LFor then
      begin
        LFields := LFields + '; ';
        LIndexFields := LIndexFields + '; ';
      end;
    end;
    TClientDataSet(LChild.FOrmDataSet).IndexFieldNames := LIndexFields;
    TClientDataSet(LChild.FOrmDataSet).MasterFields := LFields;
    /// <summary>
    /// Filtra os registros filhos associados ao LChild caso ele seja
    /// master de outros objetos.
    /// </summary>
    if LChild.FMasterObject.Count > 0 then
      TRESTClientDataSetAdapter<M>(LChild).FilterDataSetChilds;
  end;
end;

procedure TRESTClientDataSetAdapter<M>.GetDataSetEvents;
begin
  inherited;
  if Assigned(FOrmDataSet.BeforeApplyUpdates) then
    FClientDataSetEvents.BeforeApplyUpdates := FOrmDataSet.BeforeApplyUpdates;
  if Assigned(FOrmDataSet.AfterApplyUpdates)  then
    FClientDataSetEvents.AfterApplyUpdates  := FOrmDataSet.AfterApplyUpdates;
end;

procedure TRESTClientDataSetAdapter<M>.OpenSQLInternal(const ASQL: String);
var
  LObjectList: TObjectList<M>;
begin
  FOrmDataSet.DisableControls;
  DisableDataSetEvents;
  try
    /// <summary> Limpa os registro do dataset antes de garregar os novos dados </summary>
    /// <summary> Reabre antes de limpar: EmptyDataSet passa por
    ///  CheckBrowseMode e, com o dataset fechado, levanta "Cannot perform this
    ///  operation on a closed dataset" - ver
    ///  TDataSetBaseAdapter<M>.EnsureOpen. </summary>
    EnsureOpen;
    EmptyDataSet;
    inherited;
    LObjectList := FSession.Find;
    if LObjectList <> nil then
    begin
      try
        PopularDataSetList(LObjectList);
        /// <summary> Filtra os registros nas sub-tabelas </summary>
        if FOwnerMasterObject = nil then
          FilterDataSetChilds;
      finally
        LObjectList.Clear;
        LObjectList.Free;
      end;
    end;
  finally
    EnableDataSetEvents;
    FOrmDataSet.First;
    FOrmDataSet.EnableControls;
  end;
end;

procedure TRESTClientDataSetAdapter<M>.OpenIDInternal(const AID: TValue);
var
  LObject: M;
begin
  FOrmDataSet.DisableControls;
  DisableDataSetEvents;
  try
    /// <summary> Limpa os registro do dataset antes de garregar os novos dados </summary>
    /// <summary> Reabre antes de limpar: EmptyDataSet passa por
    ///  CheckBrowseMode e, com o dataset fechado, levanta "Cannot perform this
    ///  operation on a closed dataset" - ver
    ///  TDataSetBaseAdapter<M>.EnsureOpen. </summary>
    EnsureOpen;
    EmptyDataSet;
    inherited;
    /// <summary> ISSUE #328 - THE RESULT OF Find WAS DISCARDED AND LObject WAS
    ///  NEVER ASSIGNED. Three things came out of that one missing assignment:
    ///  "open by id" emptied the dataset and put nothing back, the instance
    ///  the session had just built leaked once per call, and the `<> nil`
    ///  test plus the `Free` below ran on stack leftovers.
    ///
    ///  The third one was not hypothetical. Measured on b66b04b, in
    ///  Janus.Tests.Units.exe (Debug/Win32, DCC_MapFile=3), over ALL FIVE
    ///  instantiations of this method the linker kept: the prologue is
    ///  `add esp,-14h / xor ecx,ecx / mov [ebp-14h],ecx` and the ONLY slot it
    ///  zeroes is the UnicodeString temp for AID.ToString - zeroed because it
    ///  is a MANAGED type. LObject lives at [ebp-8], nothing writes it, and
    ///  `cmp [ebp-8],0` reads it anyway. That is the opposite of what issue
    ///  #313 measured for TSessionRestFul<M>.Insert, whose prologue zeroed
    ///  its whole local area - so "the compiler happens to zero it" is not a
    ///  property of this compiler, it is a property of each frame.
    ///
    ///  The `<> nil` guard is KEPT rather than dropped as unreachable. It is
    ///  what the sibling of this family does with the same answer -
    ///  TRESTFDMemTableAdapter<M>.OpenIDInternal exits and leaves the dataset
    ///  empty - and today nothing can reach it only because
    ///  TJsonBuilder.JsonToObject<T> raises instead of answering nil. That is
    ///  the serialiser's contract, not this adapter's.
    ///
    ///  Driven by Test.Janus.Rest.OpenIdPopulates. </summary>
    LObject := FSession.Find(AID.ToString);
    if LObject <> nil then
    begin
      try
        PopularDataSet(LObject);
        /// <summary> Filtra os registros nas sub-tabelas </summary>
        if FOwnerMasterObject = nil then
          FilterDataSetChilds;
      finally
        LObject.Free;
      end;
    end;
  finally
    EnableDataSetEvents;
    FOrmDataSet.First;
    FOrmDataSet.EnableControls;
  end;
end;

procedure TRESTClientDataSetAdapter<M>.OpenWhereInternal(const AWhere, AOrderBy: String);
var
  LObjectList: TObjectList<M>;
begin
  FOrmDataSet.DisableControls;
  DisableDataSetEvents;
  try
    /// <summary> Limpa os registro do dataset antes de garregar os novos dados </summary>
    /// <summary> Reabre antes de limpar: EmptyDataSet passa por
    ///  CheckBrowseMode e, com o dataset fechado, levanta "Cannot perform this
    ///  operation on a closed dataset" - ver
    ///  TDataSetBaseAdapter<M>.EnsureOpen. </summary>
    EnsureOpen;
    EmptyDataSet;
    inherited;
    LObjectList := FSession.FindWhere(AWhere, AOrderBy);
    if LObjectList <> nil then
    begin
      try
        PopularDataSetList(LObjectList);
        /// <summary> Filtra os registros nas sub-tabelas </summary>
        if FOwnerMasterObject = nil then
          FilterDataSetChilds;
      finally
        LObjectList.Clear;
        LObjectList.Free;
      end;
    end;
  finally
    EnableDataSetEvents;
    FOrmDataSet.First;
    FOrmDataSet.EnableControls;
  end;
end;

procedure TRESTClientDataSetAdapter<M>.PopularDataSetOneToOne(
  const AObject: TObject; const AAssociation: TAssociationMapping);
var
  LRttiType: TRttiType;
  LChild: TDataSetBaseAdapter<M>;
  LField: String;
  LKeyFields: String;
  LKeyValues: String;
begin
  inherited;
  if not FMasterObject.TryGetValue(AObject.ClassName, LChild) then
    Exit;

  LChild.FOrmDataSet.DisableControls;
  LChild.DisableDataSetEvents;
  TClientDataSet(LChild.FOrmDataSet).MasterSource := nil;
  try
    AObject.GetType(LRttiType);
    LKeyFields := '';
    LKeyValues := '';
    for LField in AAssociation.ColumnsNameRef do
    begin
      LKeyFields := LKeyFields + LField + ', ';
      LKeyValues := LKeyValues + VarToStrDef(LRttiType.GetProperty(LField).GetNullableValue(AObject).AsVariant,'') + ', ';
    end;
    LKeyFields := Copy(LKeyFields, 1, Length(LKeyFields) -2);
    LKeyValues := Copy(LKeyValues, 1, Length(LKeyValues) -2);
    // Evitar duplicidade de registro em memoria
    if not LChild.FOrmDataSet.Locate(LKeyFields, LKeyValues, [loCaseInsensitive]) then
    begin
      LChild.FOrmDataSet.Append;
      TBind.Instance.SetPropertyToField(AObject, LChild.FOrmDataSet);
      LChild.FOrmDataSet.Post;
    end;
  finally
    TClientDataSet(LChild.FOrmDataSet).MasterSource := FOrmDataSource;
    LChild.FOrmDataSet.First;
    LChild.FOrmDataSet.EnableControls;
    LChild.EnableDataSetEvents;
  end;
end;

procedure TRESTClientDataSetAdapter<M>.ApplyInternal(const MaxErros: Integer);
var
  LRecnoBook: TBookmark;
begin
  LRecnoBook := FOrmDataSet.Bookmark;
  FOrmDataSet.DisableControls;
  // DisableDataSetEvents is LOAD-BEARING, not cosmetic: it unhooks
  // TDataSetBaseAdapter<M>.DoBeforePost, and ApplyUpdater does not terminate
  // without it. See the note on cInternalField in Janus.DataSet.Fields;
  // pinned by Test.Janus.Apply.Loops.
  DisableDataSetEvents;
  try
    ApplyInserter(MaxErros);
    ApplyUpdater(MaxErros);
    ApplyDeleter(MaxErros);
  finally
    FOrmDataSet.GotoBookmark(LRecnoBook);
    FOrmDataSet.FreeBookmark(LRecnoBook);
    FOrmDataSet.EnableControls;
    EnableDataSetEvents;
  end;
end;

procedure TRESTClientDataSetAdapter<M>.ApplyUpdates(const MaxErros: Integer);
var
  LOwnerData: OleVariant;
begin
  inherited;
  try
    DoBeforeApplyUpdates(FOrmDataSet, LOwnerData);
    ApplyInternal(MaxErros);
    DoAfterApplyUpdates(FOrmDataSet, LOwnerData);
  finally
    if FSession.ModifiedFields.ContainsKey(M.ClassName) then
    begin
      FSession.ModifiedFields.Items[M.ClassName].Clear;
      FSession.ModifiedFields.Items[M.ClassName].TrimExcess;
    end;
    FSession.DeleteList.Clear;
    FSession.DeleteList.TrimExcess;
  end;
end;

procedure TRESTClientDataSetAdapter<M>.SetDataSetEvents;
begin
  inherited;
  FOrmDataSet.BeforeApplyUpdates := DoBeforeApplyUpdates;
  FOrmDataSet.AfterApplyUpdates  := DoAfterApplyUpdates;
end;

end.
