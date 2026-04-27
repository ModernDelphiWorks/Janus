{
  ------------------------------------------------------------------------------
  Janus
  Modern Object-Relational Mapping (ORM) framework for Delphi.

  SPDX-License-Identifier: MIT
  Copyright (c) 2016-2026 Isaque Pinheiro

  Licensed under the MIT License.
  See the LICENSE file in the project root for full license information.
  ------------------------------------------------------------------------------
}

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit UPrincipal;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ComCtrls,

  produto;

type
  TFormPrincipal = class(TForm)
    EditID: TEdit;
    EditPreco: TEdit;
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    LabelID: TLabel;
    LabelPreco: TLabel;
    ComboEditID: TComboBox;
    EditSoma: TEdit;
    ProgressBarID: TProgressBar;
    Button4: TButton;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
  private
    { Private declarations }
    FProduto_1: TProduto;
    FBinder: TJanusBinder;
  public
    { Public declarations }
  end;

var
  FormPrincipal: TFormPrincipal;

implementation

uses
  Janus.Binder;

{$R *.dfm}

procedure TFormPrincipal.Button1Click(Sender: TObject);
begin
  ShowMessage(FProduto_1.ID.ToString);
end;

procedure TFormPrincipal.Button2Click(Sender: TObject);
begin
  ShowMessage(FProduto_1.Preco.ToString);
end;

procedure TFormPrincipal.Button3Click(Sender: TObject);
begin
  FProduto_1.ID := FProduto_1.ID * 2;
  FProduto_1.Preco := FProduto_1.Preco * 4.5;
  FBinder.Refresh;
end;

procedure TFormPrincipal.Button4Click(Sender: TObject);
begin
  ShowMessage(FProduto_1.Soma.ToString);
end;

procedure TFormPrincipal.FormCreate(Sender: TObject);
begin
  FProduto_1 := TProduto.Create;
  FBinder := TJanusBinder.Create(Self);
  FBinder.Bind(FProduto_1);
  FProduto_1.ID := 1;
  FProduto_1.Preco := 10;
  FBinder.Refresh;
  EditSoma.ReadOnly := True;
end;

procedure TFormPrincipal.FormDestroy(Sender: TObject);
begin
  FBinder.Free;
  FProduto_1.Free;
end;

initialization
  ReportMemoryLeaksOnShutdown := True;

end.
