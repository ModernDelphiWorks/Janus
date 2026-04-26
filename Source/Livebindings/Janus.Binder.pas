{
                   Copyright (c) 2016, Isaque Pinheiro
                          All rights reserved.

                    GNU Lesser General Public License
                      Versão 3, 29 de junho de 2007

       Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
       A todos é permitido copiar e distribuir cópias deste documento de
       licença, mas mudá-lo não é permitido.

       Esta versão da GNU Lesser General Public License incorpora
       os termos e condições da versão 3 da GNU General Public License
       Licença, complementado pelas permissões adicionais listadas no
       arquivo LICENSE na pasta principal.
}

{ @abstract(Janus Binder — R22.4: BindList + BindGridColumn metadata + FListLinks)
  @created(23 Apr 2026)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
}

unit Janus.Binder;

interface

{$IFDEF DCC}

uses
  System.Classes,
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  System.Generics.Collections,
  Data.DB,
  Data.Bind.DBScope,
  Data.Bind.ObjectScope,
  Data.Bind.Components,
  Data.Bind.Grid,
  Vcl.Controls,
  Vcl.Grids,
  Janus.Binder.Attributes,
  Janus.Binder.Resolver;

type
  EJanusBinderException = class(Exception);

  TJanusChildListFunc<M: class; D: class> =
    reference to function(const AMaster: M): TObjectList<D>;

  // Bridge object — wraps the scroll-propagation callback as an of-object method.
  // Stored in FGridListAdapters to tie its lifetime to the binder.
  TJanusScrollBridge<M: class; D: class> = class
  private
    FGetDetail: TJanusChildListFunc<M, D>;
    FDetailAdapter: TListBindSourceAdapter<D>;
  public
    constructor Create(const AGetDetail: TJanusChildListFunc<M, D>;
      const ADetailAdapter: TListBindSourceAdapter<D>);
    procedure AfterScroll(AAdapter: TBindSourceAdapter);
    procedure BeforeScroll(AAdapter: TBindSourceAdapter);
  end;

  TJanusBinder = class
  private
    FOwner: TComponent;
    FAdapter: TAdapterBindSource;
    FObjectAdapter: TObjectBindSourceAdapter;
    FLinks: TObjectList<TLinkPropertyToField>;
    FGridListAdapters: TObjectList<TObject>;
    FAdapterBindSources: TObjectList<TAdapterBindSource>;
    FGridLinks: TObjectList<TLinkGridToDataSource>;
    FDataSources: TObjectList<TDataSource>;
    FDBBindSources: TObjectList<TBindSourceDB>;
    FListLinks: TObjectList<TLinkListControlToField>;
    procedure _BindDataSetToGrid(ADataSet: TDataSet; const AGridName: string);
  public
    constructor Create(const AOwner: TComponent);
    destructor Destroy; override;
    procedure Bind(const AEntity: TObject);
    procedure Unbind;
    procedure Refresh;
    procedure BindGrid<TItem: class>(const AList: TObjectList<TItem>;
      const AGridName: string);
    procedure BindMasterDetail<TMaster: class; TDetail: class>(
      const AMasterList: TObjectList<TMaster>;
      const AMasterGridName: string;
      const AGetDetail: TJanusChildListFunc<TMaster, TDetail>;
      const ADetailGridName: string);
    procedure BindMasterDetailSubdetail<TMaster: class; TDetail: class; TSubdetail: class>(
      const AMasterList: TObjectList<TMaster>;
      const AMasterGridName: string;
      const AGetDetail: TJanusChildListFunc<TMaster, TDetail>;
      const ADetailGridName: string;
      const AGetSubdetail: TJanusChildListFunc<TDetail, TSubdetail>;
      const ASubdetailGridName: string);
    procedure BindDataSetGrid(ADataSet: TDataSet; const AGridName: string);
    procedure BindDataSetMasterDetail(
      AMasterDS: TDataSet; const AMasterGridName: string;
      ADetailDS: TDataSet; const ADetailGridName: string);
    procedure BindDataSetMasterDetailSubdetail(
      AMasterDS: TDataSet; const AMasterGridName: string;
      ADetailDS: TDataSet; const ADetailGridName: string;
      ASubdetailDS: TDataSet; const ASubdetailGridName: string);
    procedure BindList<TItem: class>(const AList: TObjectList<TItem>;
      const AControlName: string; const ADisplayFieldName: string);
    procedure ConfigureGridColumns(const AGridName: string; const AItemType: TClass);
    property Adapter: TAdapterBindSource read FAdapter;
    property GridListAdapters: TObjectList<TObject> read FGridListAdapters;
    property AdapterBindSources: TObjectList<TAdapterBindSource> read FAdapterBindSources;
    property GridLinks: TObjectList<TLinkGridToDataSource> read FGridLinks;
    property DBBindSources: TObjectList<TBindSourceDB> read FDBBindSources;
    property DataSources: TObjectList<TDataSource> read FDataSources;
    property ListLinks: TObjectList<TLinkListControlToField> read FListLinks;
  end;

{$ENDIF DCC}

implementation

{$IFDEF DCC}

{ TJanusScrollBridge<M, D> }

constructor TJanusScrollBridge<M, D>.Create(
  const AGetDetail: TJanusChildListFunc<M, D>;
  const ADetailAdapter: TListBindSourceAdapter<D>);
begin
  FGetDetail := AGetDetail;
  FDetailAdapter := ADetailAdapter;
end;

procedure TJanusScrollBridge<M, D>.AfterScroll(AAdapter: TBindSourceAdapter);
begin
  if (AAdapter.Current <> nil) and (AAdapter.Current is M) then
  begin
    FDetailAdapter.SetList(FGetDetail(M(AAdapter.Current)), False);
    FDetailAdapter.Active := True;
  end
  else
    FDetailAdapter.SetList(nil, False);
end;

procedure TJanusScrollBridge<M, D>.BeforeScroll(AAdapter: TBindSourceAdapter);
begin
  if FDetailAdapter.State in seEditModes then
    FDetailAdapter.Post;
end;

{ TJanusBinder }

constructor TJanusBinder.Create(const AOwner: TComponent);
begin
  FOwner := AOwner;
  FLinks := TObjectList<TLinkPropertyToField>.Create(True);
  FGridListAdapters := TObjectList<TObject>.Create(True);
  FAdapterBindSources := TObjectList<TAdapterBindSource>.Create(True);
  FGridLinks := TObjectList<TLinkGridToDataSource>.Create(True);
  FDataSources := TObjectList<TDataSource>.Create(True);
  FDBBindSources := TObjectList<TBindSourceDB>.Create(True);
  FListLinks := TObjectList<TLinkListControlToField>.Create(True);
end;

destructor TJanusBinder.Destroy;
begin
  Unbind;
  FListLinks.Free;
  FDBBindSources.Free;
  FDataSources.Free;
  FGridLinks.Free;
  FAdapterBindSources.Free;
  FGridListAdapters.Free;
  FLinks.Free;
  inherited;
end;

procedure TJanusBinder.Bind(const AEntity: TObject);
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProperty: TRttiProperty;
  LAttribute: TCustomAttribute;
  LBindAttr: Janus.Binder.Attributes.Bind;
  LControl: TComponent;
  LLink: TLinkPropertyToField;
begin
  Unbind;
  FObjectAdapter := TObjectBindSourceAdapter.Create(nil, AEntity, AEntity.ClassType, False);
  FAdapter := TAdapterBindSource.Create(nil);
  FAdapter.Adapter := FObjectAdapter;
  FAdapter.Active := True;
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(AEntity.ClassType);
    if LType = nil then
      Exit;
    for LProperty in LType.GetProperties do
    begin
      for LAttribute in LProperty.GetAttributes do
      begin
        if not (LAttribute is Janus.Binder.Attributes.Bind) then
          Continue;
        LBindAttr := Janus.Binder.Attributes.Bind(LAttribute);
        LControl := TJanusBinderResolver.Resolve(FOwner, LBindAttr.ControlName);
        if LControl = nil then
          raise EJanusBinderException.CreateFmt(
            'Control [%s] not found on owner [%s]',
            [LBindAttr.ControlName, FOwner.Name]);
        LLink := TLinkPropertyToField.Create(nil);
        LLink.DataSource := FAdapter;
        LLink.FieldName := LProperty.Name;
        LLink.Component := LControl;
        LLink.ComponentProperty := LBindAttr.FieldName;
        LLink.Active := True;
        FLinks.Add(LLink);
      end;
    end;
  finally
    LContext.Free;
  end;
end;

procedure TJanusBinder.Unbind;
var
  LListLink: TLinkListControlToField;
  LLink: TLinkPropertyToField;
  LGridLink: TLinkGridToDataSource;
  LBindSource: TAdapterBindSource;
  LDBSource: TBindSourceDB;
begin
  for LListLink in FListLinks do
    LListLink.Active := False;
  FListLinks.Clear;
  for LGridLink in FGridLinks do
    LGridLink.Active := False;
  FGridLinks.Clear;
  for LDBSource in FDBBindSources do
    LDBSource.DataSource := nil;
  FDBBindSources.Clear;
  FDataSources.Clear;
  for LBindSource in FAdapterBindSources do
    LBindSource.Active := False;
  FAdapterBindSources.Clear;
  FGridListAdapters.Clear;
  for LLink in FLinks do
    LLink.Active := False;
  FLinks.Clear;
  if Assigned(FAdapter) then
  begin
    FAdapter.Active := False;
    FreeAndNil(FAdapter);
  end;
  FreeAndNil(FObjectAdapter);
end;

procedure TJanusBinder.Refresh;
begin
  if Assigned(FAdapter) then
    FAdapter.Refresh;
end;

procedure TJanusBinder.BindGrid<TItem>(const AList: TObjectList<TItem>;
  const AGridName: string);
var
  LGrid: TComponent;
  LListAdapter: TListBindSourceAdapter<TItem>;
  LBindSource: TAdapterBindSource;
  LGridLink: TLinkGridToDataSource;
begin
  LGrid := TJanusBinderResolver.Resolve(FOwner, AGridName);
  if LGrid = nil then
    raise EJanusBinderException.CreateFmt(
      'Grid [%s] not found on owner [%s]',
      [AGridName, FOwner.Name]);
  if not (LGrid is TCustomGrid) then
    raise EJanusBinderException.CreateFmt(
      'Control [%s] is not a TCustomGrid',
      [AGridName]);
  LListAdapter := TListBindSourceAdapter<TItem>.Create(nil, AList, False);
  FGridListAdapters.Add(LListAdapter);
  LBindSource := TAdapterBindSource.Create(nil);
  LBindSource.Adapter := LListAdapter;
  LBindSource.Active := True;
  FAdapterBindSources.Add(LBindSource);
  LGridLink := TLinkGridToDataSource.Create(nil);
  LGridLink.DataSource := LBindSource;
  LGridLink.GridControl := LGrid;
  LGridLink.Active := True;
  FGridLinks.Add(LGridLink);
end;

procedure TJanusBinder.BindMasterDetail<TMaster, TDetail>(
  const AMasterList: TObjectList<TMaster>;
  const AMasterGridName: string;
  const AGetDetail: TJanusChildListFunc<TMaster, TDetail>;
  const ADetailGridName: string);
var
  LMasterGrid: TComponent;
  LDetailGrid: TComponent;
  LMasterAdapter: TListBindSourceAdapter<TMaster>;
  LDetailPlaceholder: TObjectList<TDetail>;
  LDetailAdapter: TListBindSourceAdapter<TDetail>;
  LBridge: TJanusScrollBridge<TMaster, TDetail>;
  LMasterBindSource: TAdapterBindSource;
  LMasterGridLink: TLinkGridToDataSource;
  LDetailBindSource: TAdapterBindSource;
  LDetailGridLink: TLinkGridToDataSource;
begin
  LMasterGrid := TJanusBinderResolver.Resolve(FOwner, AMasterGridName);
  if LMasterGrid = nil then
    raise EJanusBinderException.CreateFmt(
      'Grid [%s] not found on owner [%s]',
      [AMasterGridName, FOwner.Name]);
  if not (LMasterGrid is TCustomGrid) then
    raise EJanusBinderException.CreateFmt(
      'Control [%s] is not a TCustomGrid',
      [AMasterGridName]);
  LDetailGrid := TJanusBinderResolver.Resolve(FOwner, ADetailGridName);
  if LDetailGrid = nil then
    raise EJanusBinderException.CreateFmt(
      'Grid [%s] not found on owner [%s]',
      [ADetailGridName, FOwner.Name]);
  if not (LDetailGrid is TCustomGrid) then
    raise EJanusBinderException.CreateFmt(
      'Control [%s] is not a TCustomGrid',
      [ADetailGridName]);
  LMasterAdapter := TListBindSourceAdapter<TMaster>.Create(nil, AMasterList, False);
  FGridListAdapters.Add(LMasterAdapter);
  LDetailPlaceholder := TObjectList<TDetail>.Create(False);
  FGridListAdapters.Add(LDetailPlaceholder);
  LDetailAdapter := TListBindSourceAdapter<TDetail>.Create(nil, LDetailPlaceholder, False);
  FGridListAdapters.Add(LDetailAdapter);
  LBridge := TJanusScrollBridge<TMaster, TDetail>.Create(AGetDetail, LDetailAdapter);
  FGridListAdapters.Add(LBridge);
  LMasterAdapter.AfterScroll := LBridge.AfterScroll;
  LMasterAdapter.BeforeScroll := LBridge.BeforeScroll;
  LMasterBindSource := TAdapterBindSource.Create(nil);
  LMasterBindSource.Adapter := LMasterAdapter;
  LMasterBindSource.Active := True;
  FAdapterBindSources.Add(LMasterBindSource);
  LMasterGridLink := TLinkGridToDataSource.Create(nil);
  LMasterGridLink.DataSource := LMasterBindSource;
  LMasterGridLink.GridControl := LMasterGrid;
  LMasterGridLink.Active := True;
  FGridLinks.Add(LMasterGridLink);
  LDetailBindSource := TAdapterBindSource.Create(nil);
  LDetailBindSource.Adapter := LDetailAdapter;
  LDetailBindSource.Active := True;
  FAdapterBindSources.Add(LDetailBindSource);
  LDetailGridLink := TLinkGridToDataSource.Create(nil);
  LDetailGridLink.DataSource := LDetailBindSource;
  LDetailGridLink.GridControl := LDetailGrid;
  LDetailGridLink.Active := True;
  FGridLinks.Add(LDetailGridLink);
end;

procedure TJanusBinder.BindMasterDetailSubdetail<TMaster, TDetail, TSubdetail>(
  const AMasterList: TObjectList<TMaster>;
  const AMasterGridName: string;
  const AGetDetail: TJanusChildListFunc<TMaster, TDetail>;
  const ADetailGridName: string;
  const AGetSubdetail: TJanusChildListFunc<TDetail, TSubdetail>;
  const ASubdetailGridName: string);
var
  LMasterGrid: TComponent;
  LDetailGrid: TComponent;
  LSubdetailGrid: TComponent;
  LMasterAdapter: TListBindSourceAdapter<TMaster>;
  LDetailPlaceholder: TObjectList<TDetail>;
  LDetailAdapter: TListBindSourceAdapter<TDetail>;
  LSubdetailPlaceholder: TObjectList<TSubdetail>;
  LSubdetailAdapter: TListBindSourceAdapter<TSubdetail>;
  LMasterBridge: TJanusScrollBridge<TMaster, TDetail>;
  LDetailBridge: TJanusScrollBridge<TDetail, TSubdetail>;
  LMasterBindSource: TAdapterBindSource;
  LMasterGridLink: TLinkGridToDataSource;
  LDetailBindSource: TAdapterBindSource;
  LDetailGridLink: TLinkGridToDataSource;
  LSubdetailBindSource: TAdapterBindSource;
  LSubdetailGridLink: TLinkGridToDataSource;
begin
  LMasterGrid := TJanusBinderResolver.Resolve(FOwner, AMasterGridName);
  if LMasterGrid = nil then
    raise EJanusBinderException.CreateFmt(
      'Grid [%s] not found on owner [%s]',
      [AMasterGridName, FOwner.Name]);
  if not (LMasterGrid is TCustomGrid) then
    raise EJanusBinderException.CreateFmt(
      'Control [%s] is not a TCustomGrid',
      [AMasterGridName]);
  LDetailGrid := TJanusBinderResolver.Resolve(FOwner, ADetailGridName);
  if LDetailGrid = nil then
    raise EJanusBinderException.CreateFmt(
      'Grid [%s] not found on owner [%s]',
      [ADetailGridName, FOwner.Name]);
  if not (LDetailGrid is TCustomGrid) then
    raise EJanusBinderException.CreateFmt(
      'Control [%s] is not a TCustomGrid',
      [ADetailGridName]);
  LSubdetailGrid := TJanusBinderResolver.Resolve(FOwner, ASubdetailGridName);
  if LSubdetailGrid = nil then
    raise EJanusBinderException.CreateFmt(
      'Grid [%s] not found on owner [%s]',
      [ASubdetailGridName, FOwner.Name]);
  if not (LSubdetailGrid is TCustomGrid) then
    raise EJanusBinderException.CreateFmt(
      'Control [%s] is not a TCustomGrid',
      [ASubdetailGridName]);
  LMasterAdapter := TListBindSourceAdapter<TMaster>.Create(nil, AMasterList, False);
  FGridListAdapters.Add(LMasterAdapter);
  LDetailPlaceholder := TObjectList<TDetail>.Create(False);
  FGridListAdapters.Add(LDetailPlaceholder);
  LDetailAdapter := TListBindSourceAdapter<TDetail>.Create(nil, LDetailPlaceholder, False);
  FGridListAdapters.Add(LDetailAdapter);
  LSubdetailPlaceholder := TObjectList<TSubdetail>.Create(False);
  FGridListAdapters.Add(LSubdetailPlaceholder);
  LSubdetailAdapter := TListBindSourceAdapter<TSubdetail>.Create(nil, LSubdetailPlaceholder, False);
  FGridListAdapters.Add(LSubdetailAdapter);
  LMasterBridge := TJanusScrollBridge<TMaster, TDetail>.Create(AGetDetail, LDetailAdapter);
  FGridListAdapters.Add(LMasterBridge);
  LMasterAdapter.AfterScroll := LMasterBridge.AfterScroll;
  LMasterAdapter.BeforeScroll := LMasterBridge.BeforeScroll;
  LDetailBridge := TJanusScrollBridge<TDetail, TSubdetail>.Create(AGetSubdetail, LSubdetailAdapter);
  FGridListAdapters.Add(LDetailBridge);
  LDetailAdapter.AfterScroll := LDetailBridge.AfterScroll;
  LDetailAdapter.BeforeScroll := LDetailBridge.BeforeScroll;
  LMasterBindSource := TAdapterBindSource.Create(nil);
  LMasterBindSource.Adapter := LMasterAdapter;
  LMasterBindSource.Active := True;
  FAdapterBindSources.Add(LMasterBindSource);
  LMasterGridLink := TLinkGridToDataSource.Create(nil);
  LMasterGridLink.DataSource := LMasterBindSource;
  LMasterGridLink.GridControl := LMasterGrid;
  LMasterGridLink.Active := True;
  FGridLinks.Add(LMasterGridLink);
  LDetailBindSource := TAdapterBindSource.Create(nil);
  LDetailBindSource.Adapter := LDetailAdapter;
  LDetailBindSource.Active := True;
  FAdapterBindSources.Add(LDetailBindSource);
  LDetailGridLink := TLinkGridToDataSource.Create(nil);
  LDetailGridLink.DataSource := LDetailBindSource;
  LDetailGridLink.GridControl := LDetailGrid;
  LDetailGridLink.Active := True;
  FGridLinks.Add(LDetailGridLink);
  LSubdetailBindSource := TAdapterBindSource.Create(nil);
  LSubdetailBindSource.Adapter := LSubdetailAdapter;
  LSubdetailBindSource.Active := True;
  FAdapterBindSources.Add(LSubdetailBindSource);
  LSubdetailGridLink := TLinkGridToDataSource.Create(nil);
  LSubdetailGridLink.DataSource := LSubdetailBindSource;
  LSubdetailGridLink.GridControl := LSubdetailGrid;
  LSubdetailGridLink.Active := True;
  FGridLinks.Add(LSubdetailGridLink);
end;

procedure TJanusBinder._BindDataSetToGrid(ADataSet: TDataSet;
  const AGridName: string);
var
  LGrid: TComponent;
  LDataSource: TDataSource;
  LDBBindSource: TBindSourceDB;
  LGridLink: TLinkGridToDataSource;
begin
  LGrid := TJanusBinderResolver.Resolve(FOwner, AGridName);
  if LGrid = nil then
    raise EJanusBinderException.CreateFmt(
      'Grid [%s] not found on owner [%s]',
      [AGridName, FOwner.Name]);
  if not (LGrid is TCustomGrid) then
    raise EJanusBinderException.CreateFmt(
      'Control [%s] is not a TCustomGrid',
      [AGridName]);
  LDataSource := TDataSource.Create(nil);
  LDataSource.DataSet := ADataSet;
  FDataSources.Add(LDataSource);
  LDBBindSource := TBindSourceDB.Create(nil);
  LDBBindSource.DataSource := LDataSource;
  FDBBindSources.Add(LDBBindSource);
  LGridLink := TLinkGridToDataSource.Create(nil);
  LGridLink.DataSource := LDBBindSource;
  LGridLink.GridControl := LGrid;
  LGridLink.Active := True;
  FGridLinks.Add(LGridLink);
end;

procedure TJanusBinder.BindDataSetGrid(ADataSet: TDataSet;
  const AGridName: string);
begin
  _BindDataSetToGrid(ADataSet, AGridName);
end;

procedure TJanusBinder.BindDataSetMasterDetail(
  AMasterDS: TDataSet; const AMasterGridName: string;
  ADetailDS: TDataSet; const ADetailGridName: string);
begin
  _BindDataSetToGrid(AMasterDS, AMasterGridName);
  _BindDataSetToGrid(ADetailDS, ADetailGridName);
end;

procedure TJanusBinder.BindDataSetMasterDetailSubdetail(
  AMasterDS: TDataSet; const AMasterGridName: string;
  ADetailDS: TDataSet; const ADetailGridName: string;
  ASubdetailDS: TDataSet; const ASubdetailGridName: string);
begin
  _BindDataSetToGrid(AMasterDS, AMasterGridName);
  _BindDataSetToGrid(ADetailDS, ADetailGridName);
  _BindDataSetToGrid(ASubdetailDS, ASubdetailGridName);
end;

procedure TJanusBinder.BindList<TItem>(const AList: TObjectList<TItem>;
  const AControlName: string; const ADisplayFieldName: string);
var
  LControl: TComponent;
  LListAdapter: TListBindSourceAdapter<TItem>;
  LBindSource: TAdapterBindSource;
  LListLink: TLinkListControlToField;
begin
  LControl := TJanusBinderResolver.Resolve(FOwner, AControlName);
  if LControl = nil then
    raise EJanusBinderException.CreateFmt(
      'Control [%s] not found on owner [%s]',
      [AControlName, FOwner.Name]);
  if not (LControl is TCustomListControl) then
    raise EJanusBinderException.CreateFmt(
      'Control [%s] is not a TCustomListControl',
      [AControlName]);
  LListAdapter := TListBindSourceAdapter<TItem>.Create(nil, AList, False);
  FGridListAdapters.Add(LListAdapter);
  LBindSource := TAdapterBindSource.Create(nil);
  LBindSource.Adapter := LListAdapter;
  LBindSource.Active := True;
  FAdapterBindSources.Add(LBindSource);
  LListLink := TLinkListControlToField.Create(nil);
  LListLink.DataSource := LBindSource;
  LListLink.FieldName := ADisplayFieldName;
  LListLink.Control := LControl;
  LListLink.Active := True;
  FListLinks.Add(LListLink);
end;

procedure TJanusBinder.ConfigureGridColumns(const AGridName: string;
  const AItemType: TClass);
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProperty: TRttiProperty;
  LAttribute: TCustomAttribute;
  LColAttr: Janus.Binder.Attributes.BindGridColumn;
  LGrid: TStringGrid;
  LResolved: TComponent;
  LTitle: string;
  LWidth: Integer;
  LColIndex: Integer;
  LVisibleCount: Integer;
begin
  LResolved := TJanusBinderResolver.Resolve(FOwner, AGridName);
  if LResolved = nil then
    raise EJanusBinderException.CreateFmt(
      'Grid [%s] not found on owner [%s]',
      [AGridName, FOwner.Name]);
  if not (LResolved is TStringGrid) then
    raise EJanusBinderException.CreateFmt(
      'Control [%s] is not a TStringGrid (column metadata is TStringGrid-specific)',
      [AGridName]);
  LGrid := TStringGrid(LResolved);
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(AItemType);
    if LType = nil then
      Exit;
    LVisibleCount := 0;
    for LProperty in LType.GetProperties do
    begin
      if LProperty.Visibility <> mvPublished then
        Continue;
      LColAttr := nil;
      for LAttribute in LProperty.GetAttributes do
        if LAttribute is Janus.Binder.Attributes.BindGridColumn then
        begin
          LColAttr := Janus.Binder.Attributes.BindGridColumn(LAttribute);
          Break;
        end;
      if Assigned(LColAttr) and (not LColAttr.Visible) then
        Continue;
      Inc(LVisibleCount);
    end;
    if LVisibleCount = 0 then
      Exit;
    LGrid.ColCount := LVisibleCount;
    LColIndex := 0;
    for LProperty in LType.GetProperties do
    begin
      if LProperty.Visibility <> mvPublished then
        Continue;
      LTitle := LProperty.Name;
      LWidth := -1;
      LColAttr := nil;
      for LAttribute in LProperty.GetAttributes do
        if LAttribute is Janus.Binder.Attributes.BindGridColumn then
        begin
          LColAttr := Janus.Binder.Attributes.BindGridColumn(LAttribute);
          Break;
        end;
      if Assigned(LColAttr) then
      begin
        if not LColAttr.Visible then
          Continue;
        LTitle := LColAttr.Title;
        LWidth := LColAttr.Width;
      end;
      LGrid.Cells[LColIndex, 0] := LTitle;
      if LWidth >= 0 then
        LGrid.ColWidths[LColIndex] := LWidth;
      Inc(LColIndex);
    end;
  finally
    LContext.Free;
  end;
end;

{$ENDIF DCC}

end.
