{
                   Copyright (c) 2016, Isaque Pinheiro
                          All rights reserved.

                    GNU Lesser General Public License
                      Vers�o 3, 29 de junho de 2007

       Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
       A todos � permitido copiar e distribuir c�pias deste documento de
       licen�a, mas mud�-lo n�o � permitido.

       Esta vers�o da GNU Lesser General Public License incorpora
       os termos e condi��es da vers�o 3 da GNU General Public License
       Licen�a, complementado pelas permiss�es adicionais listadas no
       arquivo LICENSE na pasta principal.
}

{ @abstract(Janus Livebindings)
  @created(29 Nov 2020)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Telegram : @IsaquePinheiro)
}

unit Janus.LiveBindings;

interface

uses
  RTTI,
  Classes,
  SysUtils,
  Controls,
  TypInfo,
  Bindings.Expression,
  Bindings.Helper,
  Data.Bind.ObjectScope,
  Generics.Collections,
  Janus.Controls.Helpers;

type
  LiveBindingsControl = class(TCustomAttribute)
  private
    FLinkControl: String;
    FFieldName: String;
    FExpression: String;
  public
    constructor Create(const ALinkControl, AFieldName, AExpression: String); overload;
    constructor Create(const ALinkControl, AFieldName: String); overload;
    property LinkControl: String read FLinkControl;
    property FieldName: String read FFieldName;
    property Expression: String read FExpression;
  end;

  LiveBindingsGridMaster = class(TCustomAttribute)
  private
    FGridName: String;
  public
    constructor Create(const AGridName: String);
    property GridName: String read FGridName;
  end;

  LiveBindingsGridDetail = class(TCustomAttribute)
  private
    FGridName: String;
    FMasterField: String;
  public
    constructor Create(const AGridName, AMasterField: String);
    property GridName: String read FGridName;
    property MasterField: String read FMasterField;
  end;

  TJanusLivebindings = class
  private
    FBindingExpressions: TObjectList<TBindingExpression>;
    procedure _GenerateLiveBindingsControls(const AAttribute: TCustomAttribute;
      const AProperty: TRttiProperty);
    procedure _GenerateLiveBindingsGridMaster(const AAttribute: TCustomAttribute;
      const AProperty: TRttiProperty);
    procedure _GenerateLiveBindingsGridDetail(
      const AAttribute: TCustomAttribute; const AProperty: TRttiProperty);
  public
    constructor Create; virtual;
    destructor Destroy; override;
  end;

implementation

uses
  Vcl.ComCtrls, Vcl.Grids;

constructor TJanusLiveBindings.Create;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProperty: TRttiProperty;
  LCustomAttribute: TCustomAttribute;
begin
  FBindingExpressions := TObjectList<TBindingExpression>.Create(True);
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(Self.ClassType);
    if LType = nil then
      Exit;

    for LProperty in LType.GetProperties do
    begin
      for LCustomAttribute in LProperty.GetAttributes do
      begin
        if LCustomAttribute is LiveBindingsControl then
          _GenerateLiveBindingsControls(LCustomAttribute, LProperty)
        else if LCustomAttribute is LiveBindingsGridMaster then
          _GenerateLiveBindingsGridMaster(LCustomAttribute, LProperty)
        else if LCustomAttribute is LiveBindingsGridDetail then
          _GenerateLiveBindingsGridDetail(LCustomAttribute, LProperty);
      end;
    end;
  finally
    LContext.Free;
  end;
end;

procedure TJanusLivebindings._GenerateLiveBindingsControls(const AAttribute: TCustomAttribute;
  const AProperty: TRttiProperty);
var
  LControl: TControl;
  LExpression: String;
  LLiveBindingsControl: LiveBindingsControl;
  LBindingExpressionObject: TBindingExpression;
  LBindingExpressionComponent: TBindingExpression;
begin
  LLiveBindingsControl := LiveBindingsControl(AAttribute);
  // Get Component
  LControl := TListControls.ListComponents.Items[LLiveBindingsControl.LinkControl] as TControl;
  if LControl = nil then
    raise Exception.Create('Component [' + LLiveBindingsControl.LinkControl + '] not found!');
  // Expression do atributo
  LExpression := LLiveBindingsControl.Expression;
  if LExpression = '' then
    LExpression := Self.ClassName + '.' + AProperty.Name;
  // Add Components List
  TListControls.ListFieldNames.AddOrSetValue(LLiveBindingsControl.LinkControl, LLiveBindingsControl.FieldName);

  // Registro no LiveBindings
  LBindingExpressionObject := TBindings.CreateManagedBinding(
        [
                  TBindings.CreateAssociationScope(
                            [Associate(Self, Self.ClassName)])
        ],
                            LExpression,
        [
                  TBindings.CreateAssociationScope(
                            [Associate(LControl, LLiveBindingsControl.LinkControl)])
        ],
                            LLiveBindingsControl.LinkControl + '.' + LLiveBindingsControl.FieldName,
                  nil);
  // Component
  LBindingExpressionComponent := TBindings.CreateManagedBinding(
        [
                  TBindings.CreateAssociationScope(
                            [Associate(LControl, LLiveBindingsControl.LinkControl)])
        ],
                            LLiveBindingsControl.LinkControl + '.' + LLiveBindingsControl.FieldName,
        [
                  TBindings.CreateAssociationScope(
                            [Associate(Self, Self.ClassName)])
        ],
                            Self.ClassName + '.' + AProperty.Name,
                  nil);
  FBindingExpressions.Add(LBindingExpressionObject);
  FBindingExpressions.Add(LBindingExpressionComponent);
end;

procedure TJanusLiveBindings._GenerateLiveBindingsGridMaster(const AAttribute: TCustomAttribute;
  const AProperty: TRttiProperty);
var
  LGrid: TCustomGrid;
  LExpression: String;
  LMasterGrid: String;
  LLiveBindingsGridMaster: LiveBindingsGridMaster;
  LBindingExpressionGrid: TBindingExpression;
begin
  LLiveBindingsGridMaster := LiveBindingsGridMaster(AAttribute);
  LMasterGrid := LLiveBindingsGridMaster.GridName;

  LGrid := TListControls.ListComponents.Items[LMasterGrid] as TCustomGrid;
  if LGrid = nil then
    raise Exception.Create('Grid [' + LMasterGrid + '] not found!');

  LExpression := Self.ClassName + '.' + AProperty.Name;
  LBindingExpressionGrid := TBindings.CreateManagedBinding(
    [TBindings.CreateAssociationScope([Associate(Self, Self.ClassName)])],
    LExpression,
    [TBindings.CreateAssociationScope([Associate(LGrid, LMasterGrid)])],
    LMasterGrid + '.' + AProperty.Name,
    nil);
  FBindingExpressions.Add(LBindingExpressionGrid);
end;

procedure TJanusLiveBindings._GenerateLiveBindingsGridDetail(const AAttribute: TCustomAttribute;
  const AProperty: TRttiProperty);
var
  LGrid: TCustomGrid;
  LExpression: String;
  LMasterGrid: String;
  LLiveBindingsGridMaster: LiveBindingsGridMaster;
  LLiveBindingsGridDetail: LiveBindingsGridDetail;
  LBindingExpressionGrid: TBindingExpression;
begin
  LLiveBindingsGridDetail := LiveBindingsGridDetail(AAttribute);
  LMasterGrid := LLiveBindingsGridDetail.GridName;

  LGrid := TListControls.ListComponents.Items[LMasterGrid] as TCustomGrid;
  if LGrid = nil then
    raise Exception.Create('Grid [' + LMasterGrid + '] not found!');

  LExpression := Self.ClassName + '.' + AProperty.Name + '.' + LLiveBindingsGridDetail.MasterField;
  LBindingExpressionGrid := TBindings.CreateManagedBinding(
    [TBindings.CreateAssociationScope([Associate(Self, Self.ClassName)])],
    LExpression,
    [TBindings.CreateAssociationScope([Associate(LGrid, LMasterGrid)])],
    LMasterGrid + '.' + LLiveBindingsGridDetail.GridName,
    nil);
  FBindingExpressions.Add(LBindingExpressionGrid);
end;


{ LiveBindingControl }

constructor LiveBindingsControl.Create(const ALinkControl, AFieldName, AExpression: String);
begin
  FLinkControl := ALinkControl;
  FFieldName := AFieldName;
  FExpression := AExpression;
end;

constructor LiveBindingsControl.Create(const ALinkControl, AFieldName: String);
begin
  Create(ALinkControl, AFieldName, '');
end;

destructor TJanusLivebindings.Destroy;
begin
  FBindingExpressions.Free;
  inherited;
end;

{ LiveBindingsGridMaster }

constructor LiveBindingsGridMaster.Create(const AGridName: String);
begin
  FGridName := AGridName;
end;

{ LiveBindingsGridDetail }

constructor LiveBindingsGridDetail.Create(const AGridName, AMasterField: String);
begin
  FGridName := AGridName;
  FMasterField := AMasterField;
end;

end.
