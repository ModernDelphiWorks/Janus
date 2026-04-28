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

{ @abstract(Janus LiveBindings DUnitX fixtures — Object backend Base unit)
  @created(23 Apr 2026)
  Consolidates R22.1 (TJanusBinder.Bind) and R22.2 (TJanusBinder.BindGrid +
  master-detail). Release tags survive as class-level [Category] attributes.
}

unit Test.Janus.LiveBindings.Base;

interface

{$IFDEF DCC}

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
  System.Rtti,
  System.Generics.Collections,
  Data.Bind.ObjectScope,
  Data.Bind.Components,
  Data.Bind.EngExt,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.Grids,
  Vcl.Bind.Grid,
  Vcl.Bind.Editors,
  Janus.Binder.Attributes,
  Janus.Binder.Resolver,
  Janus.Binder;

type
  TTestPersonR221 = class
  private
    FNome: string;
    FIdade: Integer;
  published
    [Bind('EditNome', 'Text')]
    property Nome: string read FNome write FNome;
    [Bind('EditIdade', 'Text')]
    property Idade: Integer read FIdade write FIdade;
  end;

  [Category('R22.1')]
  [TestFixture]
  TTestJanusBinderR221 = class
  private
    FForm: TForm;
    FEditNome: TEdit;
    FEditIdade: TEdit;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;

    [Test]
    procedure TestBind_SimpleControl_TwoWaySync;
    [Test]
    procedure TestBind_TwoOwners_NoGlobalStateCollision;
    [Test]
    procedure TestResolver_FindComponent_ByName;
    [Test]
    procedure TestDestroy_FreesAllLinkComponents;
  end;

  TTestProduct = class
  private
    FCode: Integer;
    FName: string;
  published
    property Code: Integer read FCode write FCode;
    property Name: string read FName write FName;
  end;

  TTestOrder = class
  private
    FOrderId: Integer;
    FProductCode: Integer;
  published
    property OrderId: Integer read FOrderId write FOrderId;
    property ProductCode: Integer read FProductCode write FProductCode;
  end;

  TTestOrderLine = class
  private
    FLineId: Integer;
    FQty: Integer;
  published
    property LineId: Integer read FLineId write FLineId;
    property Qty: Integer read FQty write FQty;
  end;

  TTestProductBindable = class
  private
    FCodeStr: string;
  published
    [Bind('EditCode', 'Text')]
    property CodeStr: string read FCodeStr write FCodeStr;
  end;

  [Category('R22.2')]
  [TestFixture]
  TTestJanusBinderR222 = class
  private
    FForm: TForm;
    FGridProducts: TStringGrid;
    FGridOrders: TStringGrid;
    FGridLines: TStringGrid;
    FEditCode: TEdit;
    FProducts: TObjectList<TTestProduct>;
    FOrders0: TObjectList<TTestOrder>;
    FOrders1: TObjectList<TTestOrder>;
    FLines0: TObjectList<TTestOrderLine>;
    function _GetOrders(const AMaster: TTestProduct): TObjectList<TTestOrder>;
    function _GetLines(const ADetail: TTestOrder): TObjectList<TTestOrderLine>;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;

    [Test]
    procedure TestBindGrid_AdapterHasCorrectRowCount;
    [Test]
    procedure TestBindGrid_GridNotFound_RaisesException;
    [Test]
    procedure TestMasterDetail_Scroll_UpdatesDetailCount;
    [Test]
    procedure TestMasterDetail_EmptyMaster_NoException;
    [Test]
    procedure TestMasterDetailSubdetail_Scroll_UpdatesSubdetailCount;
    [Test]
    procedure TestDestroy_FreesAllGridComponents;
    [Test]
    procedure TestBind_R221Regression_StillWorks;
    [Test]
    procedure TestBind_ControlToEntity_Sync;
    [Test]
    procedure TestTwoBinders_SameGridName_IndependentWiring;
  end;

{$ENDIF DCC}

implementation

{$IFDEF DCC}

{ TTestJanusBinderR221 }

procedure TTestJanusBinderR221.SetupFixture;
begin
  FForm := TForm.Create(nil);
  FForm.Name := 'TestForm';
  FEditNome := TEdit.Create(FForm);
  FEditNome.Name := 'EditNome';
  FEditNome.Parent := FForm;
  FEditIdade := TEdit.Create(FForm);
  FEditIdade.Name := 'EditIdade';
  FEditIdade.Parent := FForm;
end;

procedure TTestJanusBinderR221.TearDownFixture;
begin
  FreeAndNil(FForm);
end;

procedure TTestJanusBinderR221.TestBind_SimpleControl_TwoWaySync;
var
  LPerson: TTestPersonR221;
  LBinder: TJanusBinder;
  LEdit: TEdit;
begin
  LPerson := TTestPersonR221.Create;
  LBinder := TJanusBinder.Create(FForm);
  try
    LPerson.Nome := 'Alice';
    LBinder.Bind(LPerson);
    LEdit := FForm.FindComponent('EditNome') as TEdit;
    Assert.IsNotNull(LEdit, 'EditNome must exist on form');
    Assert.AreEqual('Alice', LEdit.Text, 'Initial bind: entity -> control');
    LPerson.Nome := 'Bob';
    LBinder.Refresh;
    Assert.AreEqual('Bob', LEdit.Text, 'After refresh: entity change -> control');
  finally
    LBinder.Free;
    LPerson.Free;
  end;
end;

procedure TTestJanusBinderR221.TestBind_TwoOwners_NoGlobalStateCollision;
var
  LForm1, LForm2: TForm;
  LEdit1, LEdit2: TEdit;
  LEditIdade1, LEditIdade2: TEdit;
  LPerson1, LPerson2: TTestPersonR221;
  LBinder1, LBinder2: TJanusBinder;
begin
  LForm1 := TForm.Create(nil);
  LForm2 := TForm.Create(nil);
  LEdit1 := TEdit.Create(LForm1);
  LEdit2 := TEdit.Create(LForm2);
  LEditIdade1 := TEdit.Create(LForm1);
  LEditIdade2 := TEdit.Create(LForm2);
  LPerson1 := TTestPersonR221.Create;
  LPerson2 := TTestPersonR221.Create;
  LBinder1 := TJanusBinder.Create(LForm1);
  LBinder2 := TJanusBinder.Create(LForm2);
  try
    LEdit1.Name := 'EditNome';
    LEdit1.Parent := LForm1;
    LEdit2.Name := 'EditNome';
    LEdit2.Parent := LForm2;
    LEditIdade1.Name := 'EditIdade';
    LEditIdade1.Parent := LForm1;
    LEditIdade2.Name := 'EditIdade';
    LEditIdade2.Parent := LForm2;
    LPerson1.Nome := 'Alice';
    LPerson2.Nome := 'Bob';
    LBinder1.Bind(LPerson1);
    LBinder2.Bind(LPerson2);
    Assert.AreEqual('Alice', LEdit1.Text, 'Form1 EditNome must show Alice');
    Assert.AreEqual('Bob',   LEdit2.Text, 'Form2 EditNome must show Bob');
    Assert.AreNotEqual(LEdit1.Text, LEdit2.Text, 'No shared state between binders');
  finally
    LBinder2.Free;
    LBinder1.Free;
    LPerson2.Free;
    LPerson1.Free;
    LForm2.Free;
    LForm1.Free;
  end;
end;

procedure TTestJanusBinderR221.TestResolver_FindComponent_ByName;
var
  LForm: TForm;
  LEdit: TEdit;
  LFound: TComponent;
begin
  LForm := TForm.Create(nil);
  LEdit := TEdit.Create(LForm);
  try
    LEdit.Name := 'LookupTarget';
    LEdit.Parent := LForm;
    LFound := TJanusBinderResolver.Resolve(LForm, 'LookupTarget');
    Assert.IsNotNull(LFound, 'Resolve must find existing component');
    Assert.AreSame(LEdit, LFound, 'Resolved component must be the TEdit');
    LFound := TJanusBinderResolver.Resolve(LForm, 'NonExistent');
    Assert.IsNull(LFound, 'Resolve must return nil for missing name');
  finally
    LForm.Free;
  end;
end;

procedure TTestJanusBinderR221.TestDestroy_FreesAllLinkComponents;
var
  LPerson: TTestPersonR221;
  LBinder: TJanusBinder;
begin
  LPerson := TTestPersonR221.Create;
  try
    LPerson.Nome := 'Alice';
    LBinder := TJanusBinder.Create(FForm);
    LBinder.Bind(LPerson);
    Assert.WillNotRaiseAny(
      procedure begin
        LBinder.Free;
      end,
      'TJanusBinder.Destroy must free all owned links without error');
  finally
    LPerson.Free;
  end;
end;

{ TTestJanusBinderR222 }

function TTestJanusBinderR222._GetOrders(
  const AMaster: TTestProduct): TObjectList<TTestOrder>;
begin
  if AMaster.Code = 1 then
    Result := FOrders0
  else
    Result := FOrders1;
end;

function TTestJanusBinderR222._GetLines(
  const ADetail: TTestOrder): TObjectList<TTestOrderLine>;
begin
  Result := FLines0;
end;

procedure TTestJanusBinderR222.SetupFixture;
var
  LP0, LP1: TTestProduct;
  LO0, LO1, LO2, LO3: TTestOrder;
  LLine0, LLine1: TTestOrderLine;
begin
  FForm := TForm.Create(nil);
  FForm.Name := 'TestFormR222';

  FGridProducts := TStringGrid.Create(FForm);
  FGridProducts.Name := 'GridProducts';
  FGridProducts.Parent := FForm;

  FGridOrders := TStringGrid.Create(FForm);
  FGridOrders.Name := 'GridOrders';
  FGridOrders.Parent := FForm;

  FGridLines := TStringGrid.Create(FForm);
  FGridLines.Name := 'GridLines';
  FGridLines.Parent := FForm;

  FEditCode := TEdit.Create(FForm);
  FEditCode.Name := 'EditCode';
  FEditCode.Parent := FForm;

  FProducts := TObjectList<TTestProduct>.Create(True);
  LP0 := TTestProduct.Create; LP0.Code := 1; LP0.Name := 'Widget'; FProducts.Add(LP0);
  LP1 := TTestProduct.Create; LP1.Code := 2; LP1.Name := 'Gadget'; FProducts.Add(LP1);

  FOrders0 := TObjectList<TTestOrder>.Create(True);
  LO0 := TTestOrder.Create; LO0.OrderId := 10; LO0.ProductCode := 1; FOrders0.Add(LO0);
  LO1 := TTestOrder.Create; LO1.OrderId := 11; LO1.ProductCode := 1; FOrders0.Add(LO1);
  LO2 := TTestOrder.Create; LO2.OrderId := 12; LO2.ProductCode := 1; FOrders0.Add(LO2);

  FOrders1 := TObjectList<TTestOrder>.Create(True);
  LO3 := TTestOrder.Create; LO3.OrderId := 20; LO3.ProductCode := 2; FOrders1.Add(LO3);

  FLines0 := TObjectList<TTestOrderLine>.Create(True);
  LLine0 := TTestOrderLine.Create; LLine0.LineId := 100; LLine0.Qty := 5; FLines0.Add(LLine0);
  LLine1 := TTestOrderLine.Create; LLine1.LineId := 101; LLine1.Qty := 3; FLines0.Add(LLine1);
end;

procedure TTestJanusBinderR222.TearDownFixture;
begin
  FreeAndNil(FLines0);
  FreeAndNil(FOrders1);
  FreeAndNil(FOrders0);
  FreeAndNil(FProducts);
  FreeAndNil(FForm);
end;

procedure TTestJanusBinderR222.TestBindGrid_AdapterHasCorrectRowCount;
var
  LBinder: TJanusBinder;
begin
  LBinder := TJanusBinder.Create(FForm);
  try
    LBinder.BindGrid<TTestProduct>(FProducts, 'GridProducts');
    Assert.AreEqual(2, LBinder.GridBindSources[0].Adapter.ItemCount,
      'Adapter item count must equal list count (CA-001)');
  finally
    LBinder.Free;
  end;
end;

procedure TTestJanusBinderR222.TestBindGrid_GridNotFound_RaisesException;
var
  LBinder: TJanusBinder;
begin
  LBinder := TJanusBinder.Create(FForm);
  try
    Assert.WillRaise(
      procedure
      begin
        LBinder.BindGrid<TTestProduct>(FProducts, 'NonExistentGrid');
      end,
      EJanusBinderException,
      'BindGrid with unknown grid name must raise EJanusBinderException (CA-002)');
  finally
    LBinder.Free;
  end;
end;

procedure TTestJanusBinderR222.TestMasterDetail_Scroll_UpdatesDetailCount;
var
  LBinder: TJanusBinder;
begin
  LBinder := TJanusBinder.Create(FForm);
  try
    LBinder.BindMasterDetail<TTestProduct, TTestOrder>(
      FProducts, 'GridProducts', _GetOrders, 'GridOrders');
    LBinder.GridBindSources[0].Next;
    Assert.AreEqual(1, LBinder.GridBindSources[1].Adapter.ItemCount,
      'After master scroll to product[1] detail count must be 1 (CA-003)');
  finally
    LBinder.Free;
  end;
end;

procedure TTestJanusBinderR222.TestMasterDetail_EmptyMaster_NoException;
var
  LBinder: TJanusBinder;
  LEmptyList: TObjectList<TTestProduct>;
begin
  LEmptyList := TObjectList<TTestProduct>.Create(False);
  LBinder := TJanusBinder.Create(FForm);
  try
    LBinder.BindMasterDetail<TTestProduct, TTestOrder>(
      LEmptyList, 'GridProducts', _GetOrders, 'GridOrders');
    Assert.AreEqual(0, LBinder.GridBindSources[0].Adapter.ItemCount,
      'Master grid must show 0 rows for empty list (CA-004)');
  finally
    LBinder.Free;
    LEmptyList.Free;
  end;
end;

procedure TTestJanusBinderR222.TestMasterDetailSubdetail_Scroll_UpdatesSubdetailCount;
var
  LBinder: TJanusBinder;
begin
  LBinder := TJanusBinder.Create(FForm);
  try
    LBinder.BindMasterDetailSubdetail<TTestProduct, TTestOrder, TTestOrderLine>(
      FProducts, 'GridProducts', _GetOrders, 'GridOrders', _GetLines, 'GridLines');
    LBinder.GridBindSources[0].Next;    // master → product[1], detail → FOrders1 (1 order)
    LBinder.GridBindSources[0].Prior;   // master → product[0], detail → FOrders0 (3 orders)
    LBinder.GridBindSources[1].First;   // detail → order[0], subdetail → FLines0 (2 lines)
    Assert.AreEqual(2, LBinder.GridBindSources[2].Adapter.ItemCount,
      'Subdetail adapter count must be 2 after scrolling to order[0] (CA-005)');
  finally
    LBinder.Free;
  end;
end;

procedure TTestJanusBinderR222.TestDestroy_FreesAllGridComponents;
var
  LBinder: TJanusBinder;
begin
  LBinder := TJanusBinder.Create(FForm);
  LBinder.BindGrid<TTestProduct>(FProducts, 'GridProducts');
  Assert.WillNotRaiseAny(
    procedure
    begin
      LBinder.Free;
    end,
    'TJanusBinder.Destroy after BindGrid must not raise (CA-006)');
end;

procedure TTestJanusBinderR222.TestBind_R221Regression_StillWorks;
var
  LBinder: TJanusBinder;
  LProduct: TTestProduct;
begin
  LProduct := TTestProduct.Create;
  LBinder := TJanusBinder.Create(FForm);
  try
    LProduct.Code := 99;
    Assert.WillNotRaiseAny(
      procedure
      begin
        LBinder.Bind(LProduct);
        LBinder.Refresh;
      end,
      'R22.1 TJanusBinder.Bind must remain functional after R22.2 extension (CA-007)');
  finally
    LBinder.Free;
    LProduct.Free;
  end;
end;

procedure TTestJanusBinderR222.TestBind_ControlToEntity_Sync;
var
  LBinder: TJanusBinder;
  LProduct: TTestProductBindable;
  LField: TBindSourceAdapterField;
begin
  LProduct := TTestProductBindable.Create;
  LBinder := TJanusBinder.Create(FForm);
  try
    LProduct.CodeStr := 'Alice';
    LBinder.Bind(LProduct);
    Assert.AreEqual('Alice', FEditCode.Text,
      'Initial bind must sync entity->control (CA-008a)');
    // CA-008b: control->entity sync. In a headless console test the Windows
    // message loop is not running, so EN_CHANGE notifications from TEdit are
    // never dispatched to TLinkPropertyToField. Instead we drive the same
    // underlying mechanism: adapter Edit/SetTValue/Post propagates to the entity
    // exactly as TLinkPropertyToField would at runtime.
    LBinder.Adapter.Edit;
    LField := LBinder.Adapter.Adapter.FindField('CodeStr');
    Assert.IsNotNull(LField, 'Adapter must expose CodeStr field (CA-008b)');
    LField.SetTValue(TValue.From<string>('Bob'));
    LBinder.Adapter.Post;
    Assert.AreEqual('Bob', LProduct.CodeStr,
      'Adapter edit/post must propagate field value to entity property (CA-008b)');
  finally
    LBinder.Free;
    LProduct.Free;
  end;
end;

procedure TTestJanusBinderR222.TestTwoBinders_SameGridName_IndependentWiring;
var
  LForm2: TForm;
  LGrid2: TStringGrid;
  LBinder1, LBinder2: TJanusBinder;
  LProducts2: TObjectList<TTestProduct>;
  LP: TTestProduct;
begin
  LForm2 := TForm.Create(nil);
  LGrid2 := TStringGrid.Create(LForm2);
  LGrid2.Name := 'GridProducts';
  LGrid2.Parent := LForm2;
  LProducts2 := TObjectList<TTestProduct>.Create(True);
  LP := TTestProduct.Create; LP.Code := 99; LP.Name := 'Solo'; LProducts2.Add(LP);
  LBinder1 := TJanusBinder.Create(FForm);
  LBinder2 := TJanusBinder.Create(LForm2);
  try
    LBinder1.BindGrid<TTestProduct>(FProducts, 'GridProducts');
    LBinder2.BindGrid<TTestProduct>(LProducts2, 'GridProducts');
    Assert.AreEqual(2, LBinder1.GridBindSources[0].Adapter.ItemCount,
      'Binder1 must show 2 rows for FProducts');
    Assert.AreEqual(1, LBinder2.GridBindSources[0].Adapter.ItemCount,
      'Binder2 must show 1 row independently (CA-009)');
  finally
    LBinder2.Free;
    LBinder1.Free;
    LProducts2.Free;
    LForm2.Free;
  end;
end;

{$ENDIF DCC}

initialization
{$IFDEF DCC}
  TDUnitX.RegisterTestFixture(TTestJanusBinderR221);
  TDUnitX.RegisterTestFixture(TTestJanusBinderR222);
{$ENDIF}

end.
