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

unit Janus.VCL.Controls;

interface

uses
  System.Generics.Collections,
  System.Rtti,
  System.Classes,
  System.SysUtils,
  System.Bindings.Expression,
  System.Bindings.Helper,
  //
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ComCtrls,
  Vcl.Mask,
  Vcl.ExtCtrls,
  //
  Winapi.Windows,
  //
  Janus.Controls.Helpers;

type
  // TEdit Component (Shadowing technique)
  TEdit = class(Vcl.StdCtrls.TEdit)
  protected
    procedure Change; override;
    procedure SetName(const NewName: TComponentName); override;
  end;

  // TMaskEdit Component (Shadowing technique)
  TMaskEdit = class(Vcl.Mask.TMaskEdit)
  protected
    procedure Change; override;
    procedure SetName(const NewName: TComponentName); override;
  end;

  // TLabel Component (Shadowing technique)
  TLabel = class(Vcl.StdCtrls.TLabel)
  protected
    procedure SetName(const NewName: TComponentName); override;
  end;

  // TComboBox Component (Shadowing technique)
  TComboBox = class(Vcl.StdCtrls.TComboBox)
  protected
    procedure Change; override;
    procedure SetName(const NewName: TComponentName); override;
  end;

  // TMemo Component (Shadowing technique)
  TMemo = class(Vcl.StdCtrls.TMemo)
  protected
    procedure Change; override;
    procedure SetName(const NewName: TComponentName); override;
  end;

  // TProgressBar Component (Shadowing technique)
  TProgressBar = class(Vcl.ComCtrls.TProgressBar)
  protected
    procedure SetName(const NewName: TComponentName); override;
  end;

  // TButtonedEdit Component (Shadowing technique)
  TButtonedEdit = class(Vcl.ExtCtrls.TButtonedEdit)
  protected
    procedure Change; override;
    procedure SetName(const NewName: TComponentName); override;
  end;

  // TButtonedEdit Component (Shadowing technique)
  TListView = class(Vcl.ComCtrls.TListView)
  protected
    procedure SetName(const NewName: TComponentName); override;
  end;

implementation

{ TEdit }

procedure TEdit.Change;
begin
  inherited Change;
  if TListControls.ListFieldNames.ContainsKey(Self.Name) then
    TBindings.Notify(Self, TListControls.ListFieldNames.Items[Self.Name]);
end;

procedure TEdit.SetName(const NewName: TComponentName);
begin
  inherited SetName(NewName);
  TListControls.ListComponents.AddOrSetValue(NewName, Self);
end;

{ TLabel }

procedure TLabel.SetName(const NewName: TComponentName);
begin
  inherited SetName(NewName);
  TListControls.ListComponents.AddOrSetValue(NewName, Self);
end;

{ TMaskEdit }

procedure TMaskEdit.Change;
begin
  inherited Change;
  if TListControls.ListFieldNames.ContainsKey(Self.Name) then
    TBindings.Notify(Self, TListControls.ListFieldNames.Items[Self.Name]);
end;

procedure TMaskEdit.SetName(const NewName: TComponentName);
begin
  inherited SetName(NewName);
  TListControls.ListComponents.AddOrSetValue(NewName, Self);
end;

{ TComboBox }

procedure TComboBox.Change;
begin
  inherited Change;
  if TListControls.ListFieldNames.ContainsKey(Self.Name) then
    TBindings.Notify(Self, TListControls.ListFieldNames.Items[Self.Name]);
end;

procedure TComboBox.SetName(const NewName: TComponentName);
begin
  inherited SetName(NewName);
  TListControls.ListComponents.AddOrSetValue(NewName, Self);
end;

{ TProgressBar }

procedure TProgressBar.SetName(const NewName: TComponentName);
begin
  inherited SetName(NewName);
  TListControls.ListComponents.AddOrSetValue(NewName, Self);
end;

{ TMemo }

procedure TMemo.Change;
begin
  inherited Change;
  if TListControls.ListFieldNames.ContainsKey(Self.Name) then
    TBindings.Notify(Self, TListControls.ListFieldNames.Items[Self.Name]);
end;

procedure TMemo.SetName(const NewName: TComponentName);
begin
  inherited SetName(NewName);
  TListControls.ListComponents.AddOrSetValue(NewName, Self);
end;

{ TButtonedEdit }

procedure TButtonedEdit.Change;
begin
  inherited Change;
  if TListControls.ListFieldNames.ContainsKey(Self.Name) then
    TBindings.Notify(Self, TListControls.ListFieldNames.Items[Self.Name]);
end;

procedure TButtonedEdit.SetName(const NewName: TComponentName);
begin
  inherited SetName(NewName);
  TListControls.ListComponents.AddOrSetValue(NewName, Self);
end;

{ TListView }

procedure TListView.SetName(const NewName: TComponentName);
begin
  inherited SetName(NewName);
  TListControls.ListComponents.AddOrSetValue(NewName, Self);
end;

end.
