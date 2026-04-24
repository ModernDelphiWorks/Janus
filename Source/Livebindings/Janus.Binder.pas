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

{ @abstract(Janus Binder — R22.2 Object backend: simple controls + grid binding)
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
  System.Generics.Collections,
  Data.Bind.ObjectScope,
  Data.Bind.Components,
  Data.Bind.Grid,
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
    FGridBindSources: TObjectList<TAdapterBindSource>;
    FGridLinks: TObjectList<TLinkGridToDataSource>;
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
    property Adapter: TAdapterBindSource read FAdapter;
    property GridListAdapters: TObjectList<TObject> read FGridListAdapters;
    property GridBindSources: TObjectList<TAdapterBindSource> read FGridBindSources;
    property GridLinks: TObjectList<TLinkGridToDataSource> read FGridLinks;
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
  FGridBindSources := TObjectList<TAdapterBindSource>.Create(True);
  FGridLinks := TObjectList<TLinkGridToDataSource>.Create(True);
end;

destructor TJanusBinder.Destroy;
begin
  Unbind;
  FGridLinks.Free;
  FGridBindSources.Free;
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
  LLink: TLinkPropertyToField;
  LGridLink: TLinkGridToDataSource;
  LBindSource: TAdapterBindSource;
begin
  for LGridLink in FGridLinks do
    LGridLink.Active := False;
  FGridLinks.Clear;
  for LBindSource in FGridBindSources do
    LBindSource.Active := False;
  FGridBindSources.Clear;
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
  FGridBindSources.Add(LBindSource);
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
  FGridBindSources.Add(LMasterBindSource);
  LMasterGridLink := TLinkGridToDataSource.Create(nil);
  LMasterGridLink.DataSource := LMasterBindSource;
  LMasterGridLink.GridControl := LMasterGrid;
  LMasterGridLink.Active := True;
  FGridLinks.Add(LMasterGridLink);
  LDetailBindSource := TAdapterBindSource.Create(nil);
  LDetailBindSource.Adapter := LDetailAdapter;
  LDetailBindSource.Active := True;
  FGridBindSources.Add(LDetailBindSource);
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
  FGridBindSources.Add(LMasterBindSource);
  LMasterGridLink := TLinkGridToDataSource.Create(nil);
  LMasterGridLink.DataSource := LMasterBindSource;
  LMasterGridLink.GridControl := LMasterGrid;
  LMasterGridLink.Active := True;
  FGridLinks.Add(LMasterGridLink);
  LDetailBindSource := TAdapterBindSource.Create(nil);
  LDetailBindSource.Adapter := LDetailAdapter;
  LDetailBindSource.Active := True;
  FGridBindSources.Add(LDetailBindSource);
  LDetailGridLink := TLinkGridToDataSource.Create(nil);
  LDetailGridLink.DataSource := LDetailBindSource;
  LDetailGridLink.GridControl := LDetailGrid;
  LDetailGridLink.Active := True;
  FGridLinks.Add(LDetailGridLink);
  LSubdetailBindSource := TAdapterBindSource.Create(nil);
  LSubdetailBindSource.Adapter := LSubdetailAdapter;
  LSubdetailBindSource.Active := True;
  FGridBindSources.Add(LSubdetailBindSource);
  LSubdetailGridLink := TLinkGridToDataSource.Create(nil);
  LSubdetailGridLink.DataSource := LSubdetailBindSource;
  LSubdetailGridLink.GridControl := LSubdetailGrid;
  LSubdetailGridLink.Active := True;
  FGridLinks.Add(LSubdetailGridLink);
end;

{$ENDIF DCC}

end.
