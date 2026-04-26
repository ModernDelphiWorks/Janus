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

{ @abstract(Janus Binder Attributes — R22.4)
  @created(23 Apr 2026)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
}

unit Janus.Binder.Attributes;

interface

{$IFDEF DCC}

uses
  System.Classes;

type
  Bind = class(TCustomAttribute)
  private
    FControlName: string;
    FFieldName: string;
  public
    constructor Create(const AControlName, AFieldName: string);
    property ControlName: string read FControlName;
    property FieldName: string read FFieldName;
  end;

  BindGrid = class(TCustomAttribute)
  private
    FGridName: string;
  public
    constructor Create(const AGridName: string);
    property GridName: string read FGridName;
  end;

  BindGridDetail = class(TCustomAttribute)
  private
    FGridName: string;
    FMasterProperty: string;
  public
    constructor Create(const AGridName: string; const AMasterProperty: string);
    property GridName: string read FGridName;
    property MasterProperty: string read FMasterProperty;
  end;

  BindListControl = class(TCustomAttribute)
  private
    FControlName: string;
    FFieldName: string;
  public
    constructor Create(const AControlName, AFieldName: string);
    property ControlName: string read FControlName;
    property FieldName: string read FFieldName;
  end;

  BindGridColumn = class(TCustomAttribute)
  private
    FTitle: string;
    FWidth: Integer;
    FVisible: Boolean;
  public
    constructor Create(const ATitle: string;
      const AWidth: Integer = -1;
      const AVisible: Boolean = True);
    property Title: string read FTitle;
    property Width: Integer read FWidth;
    property Visible: Boolean read FVisible;
  end;

{$ENDIF DCC}

implementation

{$IFDEF DCC}

{ Bind }

constructor Bind.Create(const AControlName, AFieldName: string);
begin
  FControlName := AControlName;
  FFieldName := AFieldName;
end;

{ BindGrid }

constructor BindGrid.Create(const AGridName: string);
begin
  FGridName := AGridName;
end;

{ BindGridDetail }

constructor BindGridDetail.Create(const AGridName: string; const AMasterProperty: string);
begin
  FGridName := AGridName;
  FMasterProperty := AMasterProperty;
end;

{ BindListControl }

constructor BindListControl.Create(const AControlName, AFieldName: string);
begin
  FControlName := AControlName;
  FFieldName := AFieldName;
end;

{ BindGridColumn }

constructor BindGridColumn.Create(const ATitle: string;
  const AWidth: Integer; const AVisible: Boolean);
begin
  FTitle := ATitle;
  FWidth := AWidth;
  FVisible := AVisible;
end;

{$ENDIF DCC}

end.
