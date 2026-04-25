{ @abstract(Janus R22.3 LiveBindings DUnitX fixture — DataSet backend)
  @created(25 Apr 2026)
  Covers CA-001..CA-008, CA-010: TBindSourceDB wiring, master-detail, Unbind, Destroy, regression.
}

unit Tests.Janus.LiveBindings.R223;

interface

{$IFDEF DCC}

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  Data.DB,
  Data.Bind.Components,
  Data.Bind.DBLinks,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.Grids,
  Vcl.Bind.Grid,
  Vcl.Bind.Editors,
  FireDAC.Comp.Client,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Def,
  FireDAC.Phys,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  FireDAC.ConsoleUI.Wait,
  FireDAC.Comp.DataSet,
  Janus.Binder.Attributes,
  Janus.Binder;

type
  TLocalProduct = class
  private
    FCode: Integer;
    FName: string;
  published
    property Code: Integer read FCode write FCode;
    property Name: string read FName write FName;
  end;

  [TestFixture]
  TTestJanusBinderR223 = class
  private
    FForm: TForm;
    FGridProducts: TStringGrid;
    FGridOrders: TStringGrid;
    FGridLines: TStringGrid;
    FEditName: TEdit;
    FMemProducts: TFDMemTable;
    FMemOrders: TFDMemTable;
    FMemLines: TFDMemTable;
    FProducts: TObjectList<TLocalProduct>;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;

    [Test]
    procedure TestBindDataSetGrid_SourceActiveAndWired;
    [Test]
    procedure TestBindDataSetGrid_GridNotFound_Raises;
    [Test]
    procedure TestBindDataSetGrid_NotAGrid_Raises;
    [Test]
    procedure TestBindDataSetMasterDetail_TwoSourcesWired;
    [Test]
    procedure TestBindDataSetMasterDetailSubdetail_ThreeSources;
    [Test]
    procedure TestUnbind_ClearsDataSetCollections;
    [Test]
    procedure TestDestroy_NoAVAfterBindDataSetGrid;
    [Test]
    procedure TestR222Regression_ObjectBackendUnchanged;
  end;

{$ENDIF DCC}

implementation

{$IFDEF DCC}

{ TTestJanusBinderR223 }

procedure TTestJanusBinderR223.SetupFixture;
var
  LP0, LP1: TLocalProduct;
begin
  FForm := TForm.Create(nil);
  FForm.Name := 'TestFormR223';

  FGridProducts := TStringGrid.Create(FForm);
  FGridProducts.Name := 'GridProducts';
  FGridProducts.Parent := FForm;

  FGridOrders := TStringGrid.Create(FForm);
  FGridOrders.Name := 'GridOrders';
  FGridOrders.Parent := FForm;

  FGridLines := TStringGrid.Create(FForm);
  FGridLines.Name := 'GridLines';
  FGridLines.Parent := FForm;

  FEditName := TEdit.Create(FForm);
  FEditName.Name := 'EditName';
  FEditName.Parent := FForm;

  FMemProducts := TFDMemTable.Create(nil);
  FMemProducts.FieldDefs.Add('Id', ftInteger);
  FMemProducts.FieldDefs.Add('Name', ftString, 50);
  FMemProducts.CreateDataSet;
  FMemProducts.AppendRecord([1, 'Widget']);
  FMemProducts.AppendRecord([2, 'Gadget']);
  FMemProducts.AppendRecord([3, 'Doohickey']);
  FMemProducts.Active := True;

  FMemOrders := TFDMemTable.Create(nil);
  FMemOrders.FieldDefs.Add('Id', ftInteger);
  FMemOrders.FieldDefs.Add('OrderRef', ftString, 20);
  FMemOrders.CreateDataSet;
  FMemOrders.AppendRecord([10, 'ORD-A']);
  FMemOrders.AppendRecord([11, 'ORD-B']);
  FMemOrders.Active := True;

  FMemLines := TFDMemTable.Create(nil);
  FMemLines.FieldDefs.Add('Id', ftInteger);
  FMemLines.FieldDefs.Add('Qty', ftInteger);
  FMemLines.CreateDataSet;
  FMemLines.AppendRecord([100, 5]);
  FMemLines.Active := True;

  FProducts := TObjectList<TLocalProduct>.Create(True);
  LP0 := TLocalProduct.Create; LP0.Code := 1; LP0.Name := 'Widget'; FProducts.Add(LP0);
  LP1 := TLocalProduct.Create; LP1.Code := 2; LP1.Name := 'Gadget'; FProducts.Add(LP1);
end;

procedure TTestJanusBinderR223.TearDownFixture;
begin
  FreeAndNil(FMemLines);
  FreeAndNil(FMemOrders);
  FreeAndNil(FMemProducts);
  FreeAndNil(FProducts);
  FreeAndNil(FForm);
end;

procedure TTestJanusBinderR223.TestBindDataSetGrid_SourceActiveAndWired;
var
  LBinder: TJanusBinder;
begin
  LBinder := TJanusBinder.Create(FForm);
  try
    LBinder.BindDataSetGrid(FMemProducts, 'GridProducts');
    Assert.AreEqual(1, LBinder.DBBindSources.Count,
      'DBBindSources.Count must be 1 (CA-001a)');
    Assert.IsTrue((LBinder.DBBindSources[0] as IScopeActive).Active,
      'TBindSourceDB must be active (CA-001b)');
  finally
    LBinder.Free;
  end;
end;

procedure TTestJanusBinderR223.TestBindDataSetGrid_GridNotFound_Raises;
var
  LBinder: TJanusBinder;
begin
  LBinder := TJanusBinder.Create(FForm);
  try
    Assert.WillRaise(
      procedure
      begin
        LBinder.BindDataSetGrid(FMemProducts, 'NoSuchGrid');
      end,
      EJanusBinderException,
      'Unknown grid must raise EJanusBinderException (CA-002)');
  finally
    LBinder.Free;
  end;
end;

procedure TTestJanusBinderR223.TestBindDataSetGrid_NotAGrid_Raises;
var
  LBinder: TJanusBinder;
begin
  LBinder := TJanusBinder.Create(FForm);
  try
    Assert.WillRaise(
      procedure
      begin
        LBinder.BindDataSetGrid(FMemProducts, 'EditName');
      end,
      EJanusBinderException,
      'Non-grid control must raise EJanusBinderException (CA-003)');
  finally
    LBinder.Free;
  end;
end;

procedure TTestJanusBinderR223.TestBindDataSetMasterDetail_TwoSourcesWired;
var
  LBinder: TJanusBinder;
begin
  LBinder := TJanusBinder.Create(FForm);
  try
    LBinder.BindDataSetMasterDetail(
      FMemProducts, 'GridProducts',
      FMemOrders, 'GridOrders');
    Assert.AreEqual(2, LBinder.DBBindSources.Count,
      'DBBindSources.Count must be 2 (CA-004a)');
    Assert.AreEqual(2, LBinder.GridLinks.Count,
      'GridLinks.Count must be 2 (CA-004b)');
    Assert.IsTrue((LBinder.DBBindSources[0] as IScopeActive).Active,
      'Master TBindSourceDB must be active (CA-004c)');
    Assert.IsTrue((LBinder.DBBindSources[1] as IScopeActive).Active,
      'Detail TBindSourceDB must be active (CA-004d)');
  finally
    LBinder.Free;
  end;
end;

procedure TTestJanusBinderR223.TestBindDataSetMasterDetailSubdetail_ThreeSources;
var
  LBinder: TJanusBinder;
begin
  LBinder := TJanusBinder.Create(FForm);
  try
    LBinder.BindDataSetMasterDetailSubdetail(
      FMemProducts, 'GridProducts',
      FMemOrders, 'GridOrders',
      FMemLines, 'GridLines');
    Assert.AreEqual(3, LBinder.DBBindSources.Count,
      'DBBindSources.Count must be 3 (CA-005)');
    Assert.AreEqual(3, LBinder.GridLinks.Count,
      'GridLinks.Count must be 3 (CA-005b)');
  finally
    LBinder.Free;
  end;
end;

procedure TTestJanusBinderR223.TestUnbind_ClearsDataSetCollections;
var
  LBinder: TJanusBinder;
begin
  LBinder := TJanusBinder.Create(FForm);
  try
    LBinder.BindDataSetGrid(FMemProducts, 'GridProducts');
    LBinder.Unbind;
    Assert.AreEqual(0, LBinder.DBBindSources.Count,
      'DBBindSources must be empty after Unbind (CA-006a)');
    Assert.AreEqual(0, LBinder.DataSources.Count,
      'DataSources must be empty after Unbind (CA-006b)');
  finally
    LBinder.Free;
  end;
end;

procedure TTestJanusBinderR223.TestDestroy_NoAVAfterBindDataSetGrid;
var
  LBinder: TJanusBinder;
begin
  LBinder := TJanusBinder.Create(FForm);
  LBinder.BindDataSetGrid(FMemProducts, 'GridProducts');
  Assert.WillNotRaiseAny(
    procedure
    begin
      LBinder.Free;
    end,
    'TJanusBinder.Destroy after BindDataSetGrid must not AV (CA-007)');
end;

procedure TTestJanusBinderR223.TestR222Regression_ObjectBackendUnchanged;
var
  LBinder: TJanusBinder;
begin
  LBinder := TJanusBinder.Create(FForm);
  try
    LBinder.BindGrid<TLocalProduct>(FProducts, 'GridProducts');
    Assert.AreEqual(2, LBinder.GridBindSources[0].Adapter.ItemCount,
      'Object backend BindGrid must still yield 2 rows after R22.3 extension (CA-008)');
  finally
    LBinder.Free;
  end;
end;

{$ENDIF DCC}

initialization
{$IFDEF DCC}
  TDUnitX.RegisterTestFixture(TTestJanusBinderR223);
{$ENDIF}

end.
