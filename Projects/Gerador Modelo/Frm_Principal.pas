  unit Frm_Principal;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, WideStrings, Buttons, StdCtrls, DB, ExtCtrls,
  ComCtrls, FMTBcd, MidasLib, DBClient, Menus, DBCtrls,
  Mask, AnsiStrings,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error,
  FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool,
  FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Phys.FB, FireDAC.Phys.FBDef,
  FireDAC.VCLUI.Wait, FireDAC.Comp.Client, FireDAC.Stan.Param, FireDAC.DatS,
  FireDAC.DApt.Intf, FireDAC.DApt, FireDAC.Comp.DataSet, FireDAC.Stan.ExprFuncs,
  FireDAC.Phys.SQLiteDef, FireDAC.Phys.MySQLDef, FireDAC.Phys.MSSQLDef,
  FireDAC.Phys.IBBase, FireDAC.Phys.ODBCBase, FireDAC.Phys.MSSQL,
  FireDAC.Phys.MySQL, FireDAC.Phys.SQLite, FireDAC.Comp.UI,
  Generics.Collections, Vcl.Grids, Vcl.DBGrids, Vcl.WinXCtrls, Vcl.Imaging.pngimage,
  Vcl.DBCGrids,StrUtils, FireDAC.Phys.OracleDef, FireDAC.Phys.DB2Def,
  FireDAC.Phys.IBDef, FireDAC.Phys.IB, FireDAC.Phys.DB2, FireDAC.Phys.Oracle,
  FireDAC.Phys.PGDef, FireDAC.Phys.PG, FireDAC.Phys.SQLiteWrapper.Stat,
  Janus.CodeGen.Types,
  Janus.CodeGen.Schema,
  Janus.CodeGen.Engine,
  Janus.CodeGen.Options;

type
  TFrmPrincipal = class(TForm)
    Panel1: TPanel;
    StatusBar1: TStatusBar;
    FDGUIxWaitCursor1: TFDGUIxWaitCursor;
    FDPhysSQLiteDriverLink1: TFDPhysSQLiteDriverLink;
    FDPhysMySQLDriverLink1: TFDPhysMySQLDriverLink;
    FDPhysMSSQLDriverLink1: TFDPhysMSSQLDriverLink;
    FDPhysFBDriverLink1: TFDPhysFBDriverLink;
    Entidade_: TFDTable;
    FDPhysSQLiteDriverLink2: TFDPhysSQLiteDriverLink;
    Metadata: TFDMetaInfoQuery;
    Fields: TFDMetaInfoQuery;
    Entidade: TFDQuery;
    pnDisplayCode: TPanel;
    Panel5: TPanel;
    PageControl1: TPageControl;
    tabModel: TTabSheet;
    Panel3: TPanel;
    Splitter1: TSplitter;
    lstTabelas: TListBox;
    Splitter3: TSplitter;
    Panel4: TPanel;
    Panel6: TPanel;
    lstCampos: TListBox;
    Panel7: TPanel;
    CDS_CNN: TClientDataSet;
    CDS_CNNCNN_Type: TStringField;
    CDS_CNNCNN_Name: TStringField;
    CDS_CNNCNN_Server: TStringField;
    CDS_CNNCNN_Database: TStringField;
    CDS_CNNCNN_Schema: TStringField;
    CDS_CNNCNN_UserName: TStringField;
    CDS_CNNCNN_Password: TStringField;
    DTS_CNN: TDataSource;
    pnCONN: TPanel;
    Panel9: TPanel;
    pnCONN_NAV: TPanel;
    DBNavigator1: TDBNavigator;
    Panel10: TPanel;
    DBText3: TDBText;
    DBRichEdit1: TDBRichEdit;
    Combo_Connection: TComboBox;
    btnConectar: TBitBtn;
    pnConfig: TPanel;
    btnReverseAll: TButton;
    edtProjeto: TEdit;
    Label1: TLabel;
    Panel2: TPanel;
    edtPath: TEdit;
    Label2: TLabel;
    memModel: TMemo;
    FDConn: TFDConnection;
    CDS_CNNCNN_Port: TIntegerField;
    FDPhysOracleDriverLink1: TFDPhysOracleDriverLink;
    FDPhysDB2DriverLink1: TFDPhysDB2DriverLink;
    FDPhysIBDriverLink1: TFDPhysIBDriverLink;
    FDPhysPgDriverLink1: TFDPhysPgDriverLink;
    Button1: TButton;
    checkLowerCase: TCheckBox;
    checkLazy: TCheckBox;
    procedure lstTabelasClick(Sender: TObject);
    procedure btnReverseAllClick(Sender: TObject);
    procedure memoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure CDS_CNNAfterInsert(DataSet: TDataSet);
    procedure CDS_CNNNewRecord(DataSet: TDataSet);
    procedure Combo_ConnectionChange(Sender: TObject);
    procedure CDS_CNNBeforePost(DataSet: TDataSet);
    procedure CDS_CNNAfterPost(DataSet: TDataSet);
    procedure CDS_CNNAfterDelete(DataSet: TDataSet);
    procedure btnConectarClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
    FAppPathName: String;
    FSchemaReader: IJanusSchemaReader;
    FCodeGenEngine: TJanusCodeGenEngine;
    FCodeGenOptions: TJanusCodeGenOptions;

    procedure SaveConnection;
    procedure LoadConnection;
    procedure _GenerateClassUnit;
    procedure _PreviewUnit(const ATableName: String);
    procedure _Conectar(const ADriver: String; AConn: TFDConnection;
      const AServer, ADatabase, AUser, APass: String; APort: Integer = 0);
    function _DriverCatalogExists: Boolean;
  public
    { Public declarations }
  end;

var
  FrmPrincipal: TFrmPrincipal;

implementation

{$R *.dfm}

uses Frm_Connection;

procedure TFrmPrincipal.CDS_CNNAfterDelete(DataSet: TDataSet);
begin
   SaveConnection;
   LoadConnection;
end;

procedure TFrmPrincipal.CDS_CNNAfterInsert(DataSet: TDataSet);
begin
  FrmConnection       := TFrmConnection.Create(Self);
  FrmConnection.Left  := pnCONN.Left;
  FrmConnection.Width := pnCONN.Width;
  FrmConnection.Top   := (pnCONN.Top + pnCONN.Height + 28);
  FrmConnection.Show;
end;

procedure TFrmPrincipal.CDS_CNNAfterPost(DataSet: TDataSet);
begin
   SaveConnection;
   LoadConnection;
end;

procedure TFrmPrincipal.CDS_CNNBeforePost(DataSet: TDataSet);
begin
  CDS_CNN.FieldByName('CNN_NAME').AsString := '[ '+UpperCase(CDS_CNN.FieldByName('CNN_TYPE').AsString)+' ] '+ CDS_CNN.FieldByName('CNN_NAME').AsString;
end;

procedure TFrmPrincipal.CDS_CNNNewRecord(DataSet: TDataSet);
begin
   CDS_CNN.FieldByName('CNN_TYPE').AsString := 'MSSQL';
   CDS_CNN.FieldByName('CNN_SERVER').AsString := 'LOCALHOST';
   CDS_CNN.FieldByName('CNN_NAME').AsString := 'Conex�o Local ';
end;

procedure TFrmPrincipal.Combo_ConnectionChange(Sender: TObject);
begin
   CDS_CNN.Locate('CNN_NAME',Combo_Connection.Text,[]);
end;

procedure TFrmPrincipal._Conectar(const ADriver: String; AConn: TFDConnection;
  const AServer, ADatabase, AUser, APass: String; APort: Integer = 0);
const
  DBOracle = '(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=%s)(PORT=%s))(CONNECT_DATA=(SERVICE_NAME=XE)))';
begin
  AConn.Connected := False;
  if (ADriver = 'MSSQL') then
  begin
    AConn.Params.Clear;
    AConn.DriverName                      := 'MSSQL';
    AConn.Params.DriverID                 := 'MSSQL';
    AConn.Params.Values['Server']         := AServer;
    AConn.Params.Values['DataBase']       := ADatabase;
    if (Length(Trim(AUser)) = 0) and (Length(Trim(APass)) = 0) then
    begin
      AConn.Params.Values['OSAuthent']    := 'Yes';
      AConn.Params.Values['User_Name']    := '';
      AConn.Params.Values['Password']     := '';
    end
    else
    begin
      AConn.Params.Values['OSAuthent']    := 'No';
      AConn.Params.Values['User_Name']    := AUser;
      AConn.Params.Values['Password']     := APass;
    end;
    AConn.Params.Values['MetaDefSchema']  := 'dbo';
    AConn.Params.Values['MetaDefCatalog'] := ADatabase;
    AConn.Params.Values['DriverID']       := 'MSSQL';
  end
  else
  if (ADriver = 'Firebird') then
  begin
     AConn.Params.Clear;
     AConn.DriverName                     := 'FB';
     AConn.Params.DriverID                := 'FB';
     AConn.Params.Values['DriverID']      := 'FB';
     AConn.Params.Values['Server']        := AServer;
     if APort > 0 then
        AConn.Params.Values['Port']       := IntToStr(APort);
     AConn.Params.Values['DataBase']      := ADatabase;
     AConn.Params.Values['User_Name']     := AUser;
     AConn.Params.Values['Password']      := APass;
  end
  else
  if (ADriver = 'Interbase') then
  begin
     AConn.Params.Clear;
     AConn.DriverName                     := 'IB';
     AConn.Params.DriverID                := 'IB';
     AConn.Params.Values['DriverID']      := 'IB';
     AConn.Params.Values['Server']        := AServer;
     if APort > 0 then
        AConn.Params.Values['Port']       := IntToStr(APort);
     AConn.Params.Values['DataBase']      := ADatabase;
     AConn.Params.Values['User_Name']     := AUser;
     AConn.Params.Values['Password']      := APass;
  end
  else
  if (ADriver = 'Oracle') then
  begin
     AConn.Params.Clear;
     AConn.DriverName                     := 'Ora';
     AConn.Params.DriverID                := 'Ora';
     AConn.Params.Values['DataBase']      := Format(DBOracle, [AServer, IntToStr(APort)]);
     AConn.Params.Values['User_Name']     := AUser;
     AConn.Params.Values['Password']      := APass;
  end
  else
  if (ADriver = 'MySQL') then
  begin
     AConn.Params.Clear;
     AConn.DriverName                     := 'MySQL';
     AConn.Params.DriverID                := 'MySQL';
     AConn.Params.Values['Server']        := AServer;
     if APort > 0 then
        AConn.Params.Values['Port']       := IntToStr(APort);
     AConn.Params.Values['DataBase']      := ADatabase;
     AConn.Params.Values['User_Name']     := AUser;
     AConn.Params.Values['Password']      := APass;
  end
  else
  if (ADriver = 'SQLite') then
  begin
     AConn.DriverName                     := 'SQLite';
     AConn.Params.Clear;
     AConn.Params.DriverID                := 'SQLite';
     AConn.Params.Values['HostName']      := '';
     AConn.Params.Values['DataBase']      := ADatabase;
     AConn.Params.Values['User_Name']     := '';
     AConn.Params.Values['Password']      := '';
  end
  else
  if (ADriver = 'PostgreSQL') then
  begin
     AConn.DriverName                     := 'PG';
     AConn.Params.Clear;
     AConn.Params.DriverID                := 'PG';
     AConn.Params.Values['Server']        := AServer;
     if APort > 0 then
        AConn.Params.Values['Port']       := IntToStr(APort);
     AConn.Params.Values['DataBase']      := ADatabase;
     AConn.Params.Values['User_Name']     := AUser;
     AConn.Params.Values['Password']      := APass;
  end;
  AConn.Connected                         := True;
  Metadata.Connection                     := AConn;
end;

procedure TFrmPrincipal.LoadConnection;
begin
 if FileExists(ExtractFilePath(ParamStr(0))+'Connection.xml') then
   begin
      CDS_CNN.Close;
      CDS_CNN.CreateDataSet;
      CDS_CNN.LoadFromFile(FAppPathName+'Connection.xml');
      CDS_CNN.Open;
      CDS_CNN.First;

      Combo_Connection.Clear;
      while not CDS_CNN.Eof do
      begin
        Combo_Connection.Items.Add(CDS_CNN.FieldByName('CNN_Name').AsString);
        CDS_CNN.Next;
      end;
      Combo_Connection.ItemIndex := 0;
      Combo_ConnectionChange(Self);
   end
   else
   begin
    CDS_CNN.CreateDataSet;
   end;
end;

procedure TFrmPrincipal.SaveConnection;
begin
  CDS_CNN.SaveToFile(ExtractFilePath(ParamStr(0))+'Connection.xml', dfXML);
end;

{ Acrescentar mais drivers onde no --> lstTabelas <-- � listado o NOME_DO_BANCO.TABELA }
function TFrmPrincipal._DriverCatalogExists(): Boolean;
begin
  Result := AnsiMatchStr(UpperCase(FDConn.DriverName), ['MYSQL']);
end;

procedure TFrmPrincipal.lstTabelasClick(Sender: TObject);
begin
  Metadata.Connection.GetFieldNames('', '', lstTabelas.Items.Strings[lstTabelas.itemindex], '', lstCampos.items);
  _PreviewUnit(lstTabelas.Items.Strings[lstTabelas.itemindex]);
end;

procedure TFrmPrincipal.memoKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Shift = [ssCtrl]) and (Key = Ord('A')) then
     memModel.SelectAll;
end;

procedure TFrmPrincipal.btnConectarClick(Sender: TObject);
begin
  _Conectar(CDS_CNN.FieldByName('CNN_TYPE').AsString,
           FDConn,
           CDS_CNN.FieldByName('CNN_SERVER').AsString,
           CDS_CNN.FieldByName('CNN_DATABASE').AsString,
           CDS_CNN.FieldByName('CNN_USERNAME').AsString,
           CDS_CNN.FieldByName('CNN_PASSWORD').AsString,
           CDS_CNN.FieldByName('CNN_PORT').AsInteger);

  if not FDConn.Connected then
    exit;

  // Create the schema reader wrapping FDConn
  FSchemaReader := TFireDACSchemaReader.Create(FDConn, False);
  if _DriverCatalogExists then
    (FSchemaReader as TFireDACSchemaReader).CatalogName :=
      CDS_CNN.FieldByName('CNN_DATABASE').AsString;

  if _DriverCatalogExists then
    with TFDMetaInfoQuery.Create(Self) do
      try
        Connection   := FDConn;
        ObjectScopes := [osMy];
        TableKinds   := [tkTable, tkView];
        CatalogName  := CDS_CNN.FieldByName('CNN_DATABASE').AsString;
        Active       := True;
        First;

        if not isEmpty then
        begin
          lstTabelas.Items.Clear;

          repeat
            Application.ProcessMessages;

            lstTabelas.Items.Add( FieldByName('TABLE_NAME').AsString );

            Next;
          until Eof;
        end;

      finally
        Free;
      end
  else
    Metadata.Connection.GetTableNames( '', '', '', lstTabelas.Items, [osMy], [tkTable, tkView] );

  if lstTabelas.itemindex > -1 then
     if not Trim( lstTabelas.Items.Strings[lstTabelas.itemindex] ).isEmpty then
        Metadata.Connection.GetFieldNames('', '', lstTabelas.Items.Strings[lstTabelas.itemindex], '', lstCampos.items);


end;

procedure TFrmPrincipal.btnReverseAllClick(Sender: TObject);
begin
   _GenerateClassUnit;
end;


procedure TFrmPrincipal.Button1Click(Sender: TObject);
var
  OpenDialog: TFileOpenDialog;
begin
  OpenDialog := TFileOpenDialog.Create(Self);
  try
    OpenDialog.Options := OpenDialog.Options + [fdoPickFolders];
    if not OpenDialog.Execute then
      Abort;
    edtPath.Text := OpenDialog.FileName;
  finally
    OpenDialog.Free;
  end;
end;

procedure TFrmPrincipal._PreviewUnit(const ATableName: String);
var
  LTableInfo: TTableInfo;
  LSource: String;
begin
  if not Assigned(FSchemaReader) then
  begin
    ShowMessage('Conecte-se ao banco de dados primeiro.');
    Exit;
  end;

  FCodeGenOptions.LowerCaseNames := checkLowerCase.Checked;
  FCodeGenOptions.GenerateLazy := checkLazy.Checked;
  FCodeGenOptions.ProjectPrefix := edtProjeto.Text;
  FCodeGenOptions.OutputPath := edtPath.Text;

  FreeAndNil(FCodeGenEngine);
  FCodeGenEngine := TJanusCodeGenEngine.Create(FSchemaReader, FCodeGenOptions);

  LTableInfo.Name := ATableName;
  LTableInfo.Schema := '';
  LTableInfo.Catalog := '';

  LSource := FCodeGenEngine.GenerateUnit(LTableInfo);
  memModel.Lines.Text := LSource;
end;

procedure TFrmPrincipal._GenerateClassUnit;
var
  LIndex: Integer;
  LTableInfo: TTableInfo;
  LSource: String;
  LLines: TStringList;
begin
  if lstTabelas.ItemIndex < 0 then
    Exit;

  if not Assigned(FSchemaReader) then
  begin
    ShowMessage('Conecte-se ao banco de dados primeiro.');
    Exit;
  end;

  FCodeGenOptions.LowerCaseNames := checkLowerCase.Checked;
  FCodeGenOptions.GenerateLazy := checkLazy.Checked;
  FCodeGenOptions.ProjectPrefix := edtProjeto.Text;
  FCodeGenOptions.OutputPath := edtPath.Text;

  FreeAndNil(FCodeGenEngine);
  FCodeGenEngine := TJanusCodeGenEngine.Create(FSchemaReader, FCodeGenOptions);

  for LIndex := 0 to lstTabelas.Count - 1 do
  begin
    if not lstTabelas.Selected[LIndex] then
      Continue;

    LTableInfo.Name := lstTabelas.Items[LIndex];
    LTableInfo.Schema := '';
    LTableInfo.Catalog := '';

    LSource := FCodeGenEngine.GenerateUnit(LTableInfo);
    memModel.Lines.Text := LSource;

    if not DirectoryExists(edtPath.Text) then
      ForceDirectories(edtPath.Text);

    LLines := TStringList.Create;
    try
      LLines.Text := LSource;
      LLines.SaveToFile(edtPath.Text + '\' + edtProjeto.Text +
        LowerCase(lstTabelas.Items[LIndex]) + '.pas');
    finally
      LLines.Free;
    end;

    Application.ProcessMessages;
  end;
end;



procedure TFrmPrincipal.FormClose(Sender: TObject; var Action: TCloseAction);
begin
   CDS_CNN.SaveToFile(ExtractFilePath(ParamStr(0))+'Connection.xml', dfXML);
   FreeAndNil(FCodeGenEngine);
   FreeAndNil(FCodeGenOptions);
   FSchemaReader := nil;
end;

procedure TFrmPrincipal.FormCreate(Sender: TObject);
begin
  FAppPathName := ExtractFilePath(ParamStr(0));
  FCodeGenOptions := TJanusCodeGenOptions.Create;

  //Abre Configura��es de Conex�o
  LoadConnection;

  tabModel.Show;
end;


end.
