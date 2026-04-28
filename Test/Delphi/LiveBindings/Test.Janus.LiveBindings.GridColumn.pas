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

{ @abstract(Janus R22.4 LiveBindings DUnitX fixture — BindList + BindGridColumn metadata + legacy deprecation)
  @created(25 Apr 2026)
  Covers CA-001..CA-009: BindList wiring, ConfigureGridColumns, Unbind, Destroy, R22.2 regression.
  CA-010 (deprecated directives) verified by /review static check.
}

unit Test.Janus.LiveBindings.GridColumn;

interface

{$IFDEF DCC}

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.Grids,
  Janus.Binder.Attributes,
  Janus.Binder;

type
  TR224Product = class
  private
    FCodigo: Integer;
    FNome: string;
    FObservacao: string;
  published
    [BindGridColumn('Codigo', 60)]
    property Codigo: Integer read FCodigo write FCodigo;
    [BindGridColumn('Nome', 200)]
    property Nome: string read FNome write FNome;
    [BindGridColumn('Hidden', -1, False)]
    property Observacao: string read FObservacao write FObservacao;
  end;

  [Category('R22.4')]
  [TestFixture]
  TTestJanusBinderR224 = class
  private
    FForm: TForm;
    FGridProducts: TStringGrid;
    FListProducts: TListBox;
    FComboProducts: TComboBox;
    FEditName: TEdit;
    FProducts: TObjectList<TR224Product>;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;

    [Test]
    procedure TestBindList_ListBoxWired_FieldNameNome;
    [Test]
    procedure TestBindList_ControlNotFound_Raises;
    [Test]
    procedure TestBindList_ControlNotAList_Raises;
    [Test]
    procedure TestBindList_ComboBoxWired;
    [Test]
    procedure TestConfigureGridColumns_CodigoNome_TitleAndWidth;
    [Test]
    procedure TestConfigureGridColumns_HiddenColumnSkipped;
    [Test]
    procedure TestConfigureGridColumns_GridNotFound_Raises;
    [Test]
    procedure TestUnbind_ClearsListLinks;
    [Test]
    procedure TestDestroy_NoAVAfterBindList;
    [Test]
    procedure TestR222Regression_BindGridStillWorks;
  end;

{$ENDIF DCC}

implementation

{$IFDEF DCC}

{ TTestJanusBinderR224 }

procedure TTestJanusBinderR224.SetupFixture;
var
  LProduct0, LProduct1, LProduct2: TR224Product;
begin
  FForm := TForm.Create(nil);
  FForm.Name := 'TestFormR224';

  FGridProducts := TStringGrid.Create(FForm);
  FGridProducts.Name := 'GridProducts';
  FGridProducts.Parent := FForm;

  FListProducts := TListBox.Create(FForm);
  FListProducts.Name := 'ListProducts';
  FListProducts.Parent := FForm;

  FComboProducts := TComboBox.Create(FForm);
  FComboProducts.Name := 'ComboProducts';
  FComboProducts.Parent := FForm;

  FEditName := TEdit.Create(FForm);
  FEditName.Name := 'EditName';
  FEditName.Parent := FForm;

  FProducts := TObjectList<TR224Product>.Create(True);
  LProduct0 := TR224Product.Create;
  LProduct0.Codigo := 1;
  LProduct0.Nome := 'A';
  LProduct0.Observacao := 'x';
  FProducts.Add(LProduct0);
  LProduct1 := TR224Product.Create;
  LProduct1.Codigo := 2;
  LProduct1.Nome := 'B';
  FProducts.Add(LProduct1);
  LProduct2 := TR224Product.Create;
  LProduct2.Codigo := 3;
  LProduct2.Nome := 'C';
  FProducts.Add(LProduct2);
end;

procedure TTestJanusBinderR224.TearDownFixture;
begin
  FProducts.Free;
  FForm.Free;
end;

procedure TTestJanusBinderR224.TestBindList_ListBoxWired_FieldNameNome;
var
  LBinder: TJanusBinder;
begin
  LBinder := TJanusBinder.Create(FForm);
  try
    LBinder.BindList<TR224Product>(FProducts, 'ListProducts', 'Nome');
    Assert.AreEqual(1, LBinder.ListLinks.Count, 'CA-001a ListLinks.Count');
    Assert.IsTrue(LBinder.ListLinks[0].Active, 'CA-001b active');
    Assert.AreEqual('Nome', LBinder.ListLinks[0].FieldName, 'CA-001c field');
  finally
    LBinder.Free;
  end;
end;

procedure TTestJanusBinderR224.TestBindList_ControlNotFound_Raises;
var
  LBinder: TJanusBinder;
begin
  LBinder := TJanusBinder.Create(FForm);
  try
    Assert.WillRaise(
      procedure begin
        LBinder.BindList<TR224Product>(FProducts, 'NoSuchControl', 'Nome');
      end,
      EJanusBinderException, 'CA-002');
  finally
    LBinder.Free;
  end;
end;

procedure TTestJanusBinderR224.TestBindList_ControlNotAList_Raises;
var
  LBinder: TJanusBinder;
begin
  LBinder := TJanusBinder.Create(FForm);
  try
    Assert.WillRaise(
      procedure begin
        LBinder.BindList<TR224Product>(FProducts, 'EditName', 'Nome');
      end,
      EJanusBinderException, 'CA-003');
  finally
    LBinder.Free;
  end;
end;

procedure TTestJanusBinderR224.TestBindList_ComboBoxWired;
var
  LBinder: TJanusBinder;
begin
  LBinder := TJanusBinder.Create(FForm);
  try
    LBinder.BindList<TR224Product>(FProducts, 'ComboProducts', 'Nome');
    Assert.AreEqual(1, LBinder.ListLinks.Count, 'CA-004a count');
    Assert.AreSame(FComboProducts, LBinder.ListLinks[0].Control, 'CA-004b component');
  finally
    LBinder.Free;
  end;
end;

procedure TTestJanusBinderR224.TestConfigureGridColumns_CodigoNome_TitleAndWidth;
var
  LBinder: TJanusBinder;
begin
  LBinder := TJanusBinder.Create(FForm);
  try
    LBinder.BindGrid<TR224Product>(FProducts, 'GridProducts');
    LBinder.ConfigureGridColumns('GridProducts', TR224Product);
    Assert.IsTrue(FGridProducts.ColCount >= 2, 'CA-005a min 2 columns');
    Assert.AreEqual(60, FGridProducts.ColWidths[0], 'CA-005b Codigo width');
    Assert.AreEqual(200, FGridProducts.ColWidths[1], 'CA-005c Nome width');
  finally
    LBinder.Free;
  end;
end;

procedure TTestJanusBinderR224.TestConfigureGridColumns_HiddenColumnSkipped;
var
  LBinder: TJanusBinder;
begin
  LBinder := TJanusBinder.Create(FForm);
  try
    LBinder.ConfigureGridColumns('GridProducts', TR224Product);
    Assert.AreEqual(2, FGridProducts.ColCount, 'CA-006 hidden column not present');
  finally
    LBinder.Free;
  end;
end;

procedure TTestJanusBinderR224.TestConfigureGridColumns_GridNotFound_Raises;
var
  LBinder: TJanusBinder;
begin
  LBinder := TJanusBinder.Create(FForm);
  try
    Assert.WillRaise(
      procedure begin
        LBinder.ConfigureGridColumns('NoSuchGrid', TR224Product);
      end,
      EJanusBinderException, 'CA-007');
  finally
    LBinder.Free;
  end;
end;

procedure TTestJanusBinderR224.TestUnbind_ClearsListLinks;
var
  LBinder: TJanusBinder;
begin
  LBinder := TJanusBinder.Create(FForm);
  try
    LBinder.BindList<TR224Product>(FProducts, 'ListProducts', 'Nome');
    LBinder.Unbind;
    Assert.AreEqual(0, LBinder.ListLinks.Count, 'CA-008');
  finally
    LBinder.Free;
  end;
end;

procedure TTestJanusBinderR224.TestDestroy_NoAVAfterBindList;
var
  LBinder: TJanusBinder;
begin
  LBinder := TJanusBinder.Create(FForm);
  LBinder.BindList<TR224Product>(FProducts, 'ListProducts', 'Nome');
  Assert.WillNotRaiseAny(
    procedure begin
      LBinder.Free;
    end,
    'CA-009');
end;

procedure TTestJanusBinderR224.TestR222Regression_BindGridStillWorks;
var
  LBinder: TJanusBinder;
begin
  LBinder := TJanusBinder.Create(FForm);
  try
    LBinder.BindGrid<TR224Product>(FProducts, 'GridProducts');
    Assert.AreEqual(3, LBinder.AdapterBindSources[0].Adapter.ItemCount,
      'BindGrid still yields 3 rows after R22.4 extension');
  finally
    LBinder.Free;
  end;
end;

{$ENDIF DCC}

initialization
{$IFDEF DCC}
  TDUnitX.RegisterTestFixture(TTestJanusBinderR224);
{$ENDIF}

end.
