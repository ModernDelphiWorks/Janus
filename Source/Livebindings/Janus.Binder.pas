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

{ @abstract(Janus Binder — R22.1 Object backend, simple controls)
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
  Janus.Binder.Attributes,
  Janus.Binder.Resolver;

type
  EJanusBinderException = class(Exception);

  TJanusBinder = class
  private
    FOwner: TComponent;
    FAdapter: TAdapterBindSource;
    FObjectAdapter: TObjectBindSourceAdapter;
    FLinks: TObjectList<TLinkPropertyToField>;
  public
    constructor Create(const AOwner: TComponent);
    destructor Destroy; override;
    procedure Bind(const AEntity: TObject);
    procedure Unbind;
    procedure Refresh;
  end;

{$ENDIF DCC}

implementation

{$IFDEF DCC}

{ TJanusBinder }

constructor TJanusBinder.Create(const AOwner: TComponent);
begin
  FOwner := AOwner;
  FLinks := TObjectList<TLinkPropertyToField>.Create(True);
end;

destructor TJanusBinder.Destroy;
begin
  Unbind;
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
begin
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

{$ENDIF DCC}

end.
