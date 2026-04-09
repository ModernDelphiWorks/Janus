unit Janus.Wizard.Form;

interface

uses
  SysUtils,
  Classes,
  Controls,
  Forms,
  StdCtrls,
  ComCtrls,
  ExtCtrls,
  Buttons,
  CheckLst,
  FireDAC.Comp.Client,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.VCLUI.Wait,
  FireDAC.Comp.UI,
  Janus.CodeGen.Types,
  Janus.CodeGen.Schema,
  Janus.CodeGen.Engine,
  Janus.CodeGen.Options;

type
  TJanusWizardForm = class(TForm)
  private
    { Layout components }
    FPageControl: TPageControl;
    FTabConnection: TTabSheet;
    FTabTables: TTabSheet;
    FTabOptions: TTabSheet;
    FTabPreview: TTabSheet;
    { Connection page }
    FLblDriver: TLabel;
    FCboDriver: TComboBox;
    FLblServer: TLabel;
    FEdtServer: TEdit;
    FLblPort: TLabel;
    FEdtPort: TEdit;
    FLblDatabase: TLabel;
    FEdtDatabase: TEdit;
    FLblUser: TLabel;
    FEdtUser: TEdit;
    FLblPassword: TLabel;
    FEdtPassword: TEdit;
    FBtnTestConnection: TButton;
    { Tables page }
    FClbTables: TCheckListBox;
    FBtnSelectAll: TButton;
    FBtnDeselectAll: TButton;
    { Options page }
    FChkLowerCase: TCheckBox;
    FChkLazy: TCheckBox;
    FChkNullable: TCheckBox;
    FChkDictionary: TCheckBox;
    FLblProject: TLabel;
    FEdtProject: TEdit;
    FLblOutputPath: TLabel;
    FEdtOutputPath: TEdit;
    FBtnBrowse: TButton;
    { Preview page }
    FMemoPreview: TMemo;
    FBtnGenerate: TButton;
    { Navigation }
    FPnlButtons: TPanel;
    FBtnBack: TButton;
    FBtnNext: TButton;
    FBtnCancel: TButton;
    { Internal }
    FConnection: TFDConnection;
    FGUIxWaitCursor: TFDGUIxWaitCursor;
    FSchemaReader: IJanusSchemaReader;
    FOptions: TJanusCodeGenOptions;
    FTables: TArray<TTableInfo>;
    procedure _CreateComponents;
    procedure _CreateConnectionPage;
    procedure _CreateTablesPage;
    procedure _CreateOptionsPage;
    procedure _CreatePreviewPage;
    procedure _CreateNavigationPanel;
    procedure _OnTestConnectionClick(Sender: TObject);
    procedure _OnSelectAllClick(Sender: TObject);
    procedure _OnDeselectAllClick(Sender: TObject);
    procedure _OnBrowseClick(Sender: TObject);
    procedure _OnNextClick(Sender: TObject);
    procedure _OnBackClick(Sender: TObject);
    procedure _OnCancelClick(Sender: TObject);
    procedure _OnGenerateClick(Sender: TObject);
    procedure _OnTableClick(Sender: TObject);
    procedure _UpdateButtons;
    procedure _ConnectToDatabase;
    procedure _LoadTables;
    procedure _UpdatePreview;
    procedure _ConfigureConnection;
  protected
    procedure DoCreate; override;
    procedure DoDestroy; override;
  end;

implementation

uses
  Dialogs,
  StrUtils,
  FireDAC.Stan.Option;

{ TJanusWizardForm }

procedure TJanusWizardForm.DoCreate;
begin
  inherited;
  Caption := 'Janus Model Generator';
  Width := 700;
  Height := 520;
  Position := poScreenCenter;
  BorderStyle := bsDialog;
  FConnection := TFDConnection.Create(Self);
  FConnection.LoginPrompt := False;
  FGUIxWaitCursor := TFDGUIxWaitCursor.Create(Self);
  FOptions := TJanusCodeGenOptions.Create;
  _CreateComponents;
  _UpdateButtons;
end;

procedure TJanusWizardForm.DoDestroy;
begin
  FOptions.Free;
  inherited;
end;

procedure TJanusWizardForm._CreateComponents;
begin
  FPageControl := TPageControl.Create(Self);
  FPageControl.Parent := Self;
  FPageControl.Align := alClient;
  FPageControl.Style := tsButtons;
  FPageControl.TabHeight := 0;

  FTabConnection := TTabSheet.Create(FPageControl);
  FTabConnection.PageControl := FPageControl;
  FTabConnection.Caption := 'Connection';

  FTabTables := TTabSheet.Create(FPageControl);
  FTabTables.PageControl := FPageControl;
  FTabTables.Caption := 'Tables';

  FTabOptions := TTabSheet.Create(FPageControl);
  FTabOptions.PageControl := FPageControl;
  FTabOptions.Caption := 'Options';

  FTabPreview := TTabSheet.Create(FPageControl);
  FTabPreview.PageControl := FPageControl;
  FTabPreview.Caption := 'Preview';

  _CreateConnectionPage;
  _CreateTablesPage;
  _CreateOptionsPage;
  _CreatePreviewPage;
  _CreateNavigationPanel;

  FPageControl.ActivePageIndex := 0;
end;

procedure TJanusWizardForm._CreateConnectionPage;
var
  LTop: Integer;
begin
  LTop := 20;

  FLblDriver := TLabel.Create(FTabConnection);
  FLblDriver.Parent := FTabConnection;
  FLblDriver.Left := 20;
  FLblDriver.Top := LTop;
  FLblDriver.Caption := 'Driver:';

  FCboDriver := TComboBox.Create(FTabConnection);
  FCboDriver.Parent := FTabConnection;
  FCboDriver.Left := 120;
  FCboDriver.Top := LTop - 3;
  FCboDriver.Width := 200;
  FCboDriver.Style := csDropDownList;
  FCboDriver.Items.AddStrings(['SQLite', 'Firebird', 'Interbase', 'MySQL',
    'PostgreSQL', 'MSSQL', 'Oracle']);
  FCboDriver.ItemIndex := 0;

  Inc(LTop, 35);

  FLblServer := TLabel.Create(FTabConnection);
  FLblServer.Parent := FTabConnection;
  FLblServer.Left := 20;
  FLblServer.Top := LTop;
  FLblServer.Caption := 'Server:';

  FEdtServer := TEdit.Create(FTabConnection);
  FEdtServer.Parent := FTabConnection;
  FEdtServer.Left := 120;
  FEdtServer.Top := LTop - 3;
  FEdtServer.Width := 400;
  FEdtServer.Text := 'LOCALHOST';

  Inc(LTop, 35);

  FLblPort := TLabel.Create(FTabConnection);
  FLblPort.Parent := FTabConnection;
  FLblPort.Left := 20;
  FLblPort.Top := LTop;
  FLblPort.Caption := 'Port:';

  FEdtPort := TEdit.Create(FTabConnection);
  FEdtPort.Parent := FTabConnection;
  FEdtPort.Left := 120;
  FEdtPort.Top := LTop - 3;
  FEdtPort.Width := 80;
  FEdtPort.Text := '0';

  Inc(LTop, 35);

  FLblDatabase := TLabel.Create(FTabConnection);
  FLblDatabase.Parent := FTabConnection;
  FLblDatabase.Left := 20;
  FLblDatabase.Top := LTop;
  FLblDatabase.Caption := 'Database:';

  FEdtDatabase := TEdit.Create(FTabConnection);
  FEdtDatabase.Parent := FTabConnection;
  FEdtDatabase.Left := 120;
  FEdtDatabase.Top := LTop - 3;
  FEdtDatabase.Width := 400;

  Inc(LTop, 35);

  FLblUser := TLabel.Create(FTabConnection);
  FLblUser.Parent := FTabConnection;
  FLblUser.Left := 20;
  FLblUser.Top := LTop;
  FLblUser.Caption := 'User:';

  FEdtUser := TEdit.Create(FTabConnection);
  FEdtUser.Parent := FTabConnection;
  FEdtUser.Left := 120;
  FEdtUser.Top := LTop - 3;
  FEdtUser.Width := 200;

  Inc(LTop, 35);

  FLblPassword := TLabel.Create(FTabConnection);
  FLblPassword.Parent := FTabConnection;
  FLblPassword.Left := 20;
  FLblPassword.Top := LTop;
  FLblPassword.Caption := 'Password:';

  FEdtPassword := TEdit.Create(FTabConnection);
  FEdtPassword.Parent := FTabConnection;
  FEdtPassword.Left := 120;
  FEdtPassword.Top := LTop - 3;
  FEdtPassword.Width := 200;
  FEdtPassword.PasswordChar := '*';

  Inc(LTop, 40);

  FBtnTestConnection := TButton.Create(FTabConnection);
  FBtnTestConnection.Parent := FTabConnection;
  FBtnTestConnection.Left := 120;
  FBtnTestConnection.Top := LTop;
  FBtnTestConnection.Width := 150;
  FBtnTestConnection.Caption := 'Test Connection';
  FBtnTestConnection.OnClick := _OnTestConnectionClick;
end;

procedure TJanusWizardForm._CreateTablesPage;
begin
  FClbTables := TCheckListBox.Create(FTabTables);
  FClbTables.Parent := FTabTables;
  FClbTables.Left := 20;
  FClbTables.Top := 20;
  FClbTables.Width := 400;
  FClbTables.Height := 350;
  FClbTables.OnClick := _OnTableClick;

  FBtnSelectAll := TButton.Create(FTabTables);
  FBtnSelectAll.Parent := FTabTables;
  FBtnSelectAll.Left := 440;
  FBtnSelectAll.Top := 20;
  FBtnSelectAll.Width := 120;
  FBtnSelectAll.Caption := 'Select All';
  FBtnSelectAll.OnClick := _OnSelectAllClick;

  FBtnDeselectAll := TButton.Create(FTabTables);
  FBtnDeselectAll.Parent := FTabTables;
  FBtnDeselectAll.Left := 440;
  FBtnDeselectAll.Top := 55;
  FBtnDeselectAll.Width := 120;
  FBtnDeselectAll.Caption := 'Deselect All';
  FBtnDeselectAll.OnClick := _OnDeselectAllClick;
end;

procedure TJanusWizardForm._CreateOptionsPage;
var
  LTop: Integer;
begin
  LTop := 20;

  FChkLowerCase := TCheckBox.Create(FTabOptions);
  FChkLowerCase.Parent := FTabOptions;
  FChkLowerCase.Left := 20;
  FChkLowerCase.Top := LTop;
  FChkLowerCase.Caption := 'Lowercase property names';

  Inc(LTop, 30);

  FChkLazy := TCheckBox.Create(FTabOptions);
  FChkLazy.Parent := FTabOptions;
  FChkLazy.Left := 20;
  FChkLazy.Top := LTop;
  FChkLazy.Caption := 'Generate Lazy<T> for foreign keys';

  Inc(LTop, 30);

  FChkNullable := TCheckBox.Create(FTabOptions);
  FChkNullable.Parent := FTabOptions;
  FChkNullable.Left := 20;
  FChkNullable.Top := LTop;
  FChkNullable.Caption := 'Generate Nullable<T> for nullable fields';
  FChkNullable.Checked := True;

  Inc(LTop, 30);

  FChkDictionary := TCheckBox.Create(FTabOptions);
  FChkDictionary.Parent := FTabOptions;
  FChkDictionary.Left := 20;
  FChkDictionary.Top := LTop;
  FChkDictionary.Caption := 'Generate Dictionary attributes';
  FChkDictionary.Checked := True;

  Inc(LTop, 40);

  FLblProject := TLabel.Create(FTabOptions);
  FLblProject.Parent := FTabOptions;
  FLblProject.Left := 20;
  FLblProject.Top := LTop;
  FLblProject.Caption := 'Project prefix:';

  FEdtProject := TEdit.Create(FTabOptions);
  FEdtProject.Parent := FTabOptions;
  FEdtProject.Left := 130;
  FEdtProject.Top := LTop - 3;
  FEdtProject.Width := 200;

  Inc(LTop, 35);

  FLblOutputPath := TLabel.Create(FTabOptions);
  FLblOutputPath.Parent := FTabOptions;
  FLblOutputPath.Left := 20;
  FLblOutputPath.Top := LTop;
  FLblOutputPath.Caption := 'Output path:';

  FEdtOutputPath := TEdit.Create(FTabOptions);
  FEdtOutputPath.Parent := FTabOptions;
  FEdtOutputPath.Left := 130;
  FEdtOutputPath.Top := LTop - 3;
  FEdtOutputPath.Width := 350;

  FBtnBrowse := TButton.Create(FTabOptions);
  FBtnBrowse.Parent := FTabOptions;
  FBtnBrowse.Left := 490;
  FBtnBrowse.Top := LTop - 3;
  FBtnBrowse.Width := 75;
  FBtnBrowse.Caption := 'Browse...';
  FBtnBrowse.OnClick := _OnBrowseClick;
end;

procedure TJanusWizardForm._CreatePreviewPage;
begin
  FMemoPreview := TMemo.Create(FTabPreview);
  FMemoPreview.Parent := FTabPreview;
  FMemoPreview.Left := 20;
  FMemoPreview.Top := 20;
  FMemoPreview.Width := 540;
  FMemoPreview.Height := 340;
  FMemoPreview.ScrollBars := ssBoth;
  FMemoPreview.Font.Name := 'Consolas';
  FMemoPreview.Font.Size := 9;
  FMemoPreview.ReadOnly := True;

  FBtnGenerate := TButton.Create(FTabPreview);
  FBtnGenerate.Parent := FTabPreview;
  FBtnGenerate.Left := 580;
  FBtnGenerate.Top := 20;
  FBtnGenerate.Width := 90;
  FBtnGenerate.Height := 30;
  FBtnGenerate.Caption := 'Generate';
  FBtnGenerate.OnClick := _OnGenerateClick;
end;

procedure TJanusWizardForm._CreateNavigationPanel;
begin
  FPnlButtons := TPanel.Create(Self);
  FPnlButtons.Parent := Self;
  FPnlButtons.Align := alBottom;
  FPnlButtons.Height := 45;
  FPnlButtons.BevelOuter := bvNone;

  FBtnBack := TButton.Create(FPnlButtons);
  FBtnBack.Parent := FPnlButtons;
  FBtnBack.Left := 420;
  FBtnBack.Top := 10;
  FBtnBack.Width := 80;
  FBtnBack.Caption := '< Back';
  FBtnBack.OnClick := _OnBackClick;

  FBtnNext := TButton.Create(FPnlButtons);
  FBtnNext.Parent := FPnlButtons;
  FBtnNext.Left := 510;
  FBtnNext.Top := 10;
  FBtnNext.Width := 80;
  FBtnNext.Caption := 'Next >';
  FBtnNext.OnClick := _OnNextClick;

  FBtnCancel := TButton.Create(FPnlButtons);
  FBtnCancel.Parent := FPnlButtons;
  FBtnCancel.Left := 600;
  FBtnCancel.Top := 10;
  FBtnCancel.Width := 80;
  FBtnCancel.Caption := 'Cancel';
  FBtnCancel.OnClick := _OnCancelClick;
end;

procedure TJanusWizardForm._UpdateButtons;
var
  LPage: Integer;
begin
  LPage := FPageControl.ActivePageIndex;
  FBtnBack.Enabled := LPage > 0;
  FBtnNext.Visible := LPage < 3;
end;

procedure TJanusWizardForm._ConfigureConnection;
var
  LDriver: String;
  LPort: Integer;
begin
  LDriver := FCboDriver.Items[FCboDriver.ItemIndex];
  LPort := StrToIntDef(FEdtPort.Text, 0);

  FConnection.Connected := False;
  FConnection.Params.Clear;

  if LDriver = 'SQLite' then
  begin
    FConnection.DriverName := 'SQLite';
    FConnection.Params.DriverID := 'SQLite';
    FConnection.Params.Values['Database'] := FEdtDatabase.Text;
  end
  else if LDriver = 'Firebird' then
  begin
    FConnection.DriverName := 'FB';
    FConnection.Params.DriverID := 'FB';
    FConnection.Params.Values['Server'] := FEdtServer.Text;
    if LPort > 0 then
      FConnection.Params.Values['Port'] := IntToStr(LPort);
    FConnection.Params.Values['Database'] := FEdtDatabase.Text;
    FConnection.Params.Values['User_Name'] := FEdtUser.Text;
    FConnection.Params.Values['Password'] := FEdtPassword.Text;
  end
  else if LDriver = 'Interbase' then
  begin
    FConnection.DriverName := 'IB';
    FConnection.Params.DriverID := 'IB';
    FConnection.Params.Values['Server'] := FEdtServer.Text;
    if LPort > 0 then
      FConnection.Params.Values['Port'] := IntToStr(LPort);
    FConnection.Params.Values['Database'] := FEdtDatabase.Text;
    FConnection.Params.Values['User_Name'] := FEdtUser.Text;
    FConnection.Params.Values['Password'] := FEdtPassword.Text;
  end
  else if LDriver = 'MySQL' then
  begin
    FConnection.DriverName := 'MySQL';
    FConnection.Params.DriverID := 'MySQL';
    FConnection.Params.Values['Server'] := FEdtServer.Text;
    if LPort > 0 then
      FConnection.Params.Values['Port'] := IntToStr(LPort);
    FConnection.Params.Values['Database'] := FEdtDatabase.Text;
    FConnection.Params.Values['User_Name'] := FEdtUser.Text;
    FConnection.Params.Values['Password'] := FEdtPassword.Text;
  end
  else if LDriver = 'PostgreSQL' then
  begin
    FConnection.DriverName := 'PG';
    FConnection.Params.DriverID := 'PG';
    FConnection.Params.Values['Server'] := FEdtServer.Text;
    if LPort > 0 then
      FConnection.Params.Values['Port'] := IntToStr(LPort);
    FConnection.Params.Values['Database'] := FEdtDatabase.Text;
    FConnection.Params.Values['User_Name'] := FEdtUser.Text;
    FConnection.Params.Values['Password'] := FEdtPassword.Text;
  end
  else if LDriver = 'MSSQL' then
  begin
    FConnection.DriverName := 'MSSQL';
    FConnection.Params.DriverID := 'MSSQL';
    FConnection.Params.Values['Server'] := FEdtServer.Text;
    FConnection.Params.Values['Database'] := FEdtDatabase.Text;
    if (FEdtUser.Text = '') and (FEdtPassword.Text = '') then
      FConnection.Params.Values['OSAuthent'] := 'Yes'
    else
    begin
      FConnection.Params.Values['OSAuthent'] := 'No';
      FConnection.Params.Values['User_Name'] := FEdtUser.Text;
      FConnection.Params.Values['Password'] := FEdtPassword.Text;
    end;
    FConnection.Params.Values['MetaDefSchema'] := 'dbo';
    FConnection.Params.Values['MetaDefCatalog'] := FEdtDatabase.Text;
  end
  else if LDriver = 'Oracle' then
  begin
    FConnection.DriverName := 'Ora';
    FConnection.Params.DriverID := 'Ora';
    FConnection.Params.Values['Database'] :=
      '(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=' + FEdtServer.Text +
      ')(PORT=' + IntToStr(LPort) + '))(CONNECT_DATA=(SERVICE_NAME=XE)))';
    FConnection.Params.Values['User_Name'] := FEdtUser.Text;
    FConnection.Params.Values['Password'] := FEdtPassword.Text;
  end;
end;

procedure TJanusWizardForm._ConnectToDatabase;
begin
  _ConfigureConnection;
  FConnection.Connected := True;
end;

procedure TJanusWizardForm._LoadTables;
var
  LReader: TFireDACSchemaReader;
  LIndex: Integer;
begin
  LReader := TFireDACSchemaReader.Create(FConnection, False);
  if UpperCase(FConnection.DriverName) = 'MYSQL' then
    LReader.CatalogName := FEdtDatabase.Text;
  FSchemaReader := LReader;
  FTables := FSchemaReader.GetTables;
  FClbTables.Items.Clear;
  for LIndex := 0 to Length(FTables) - 1 do
    FClbTables.Items.Add(FTables[LIndex].Name);
end;

procedure TJanusWizardForm._UpdatePreview;
var
  LEngine: TJanusCodeGenEngine;
  LIndex: Integer;
  LSelectedIndex: Integer;
begin
  FOptions.LowerCaseNames := FChkLowerCase.Checked;
  FOptions.GenerateLazy := FChkLazy.Checked;
  FOptions.GenerateNullable := FChkNullable.Checked;
  FOptions.GenerateDictionary := FChkDictionary.Checked;
  FOptions.ProjectPrefix := FEdtProject.Text;
  FOptions.OutputPath := FEdtOutputPath.Text;

  LSelectedIndex := -1;
  for LIndex := 0 to FClbTables.Count - 1 do
    if FClbTables.Checked[LIndex] then
    begin
      LSelectedIndex := LIndex;
      Break;
    end;

  if LSelectedIndex < 0 then
  begin
    FMemoPreview.Lines.Text := '// No table selected';
    Exit;
  end;

  LEngine := TJanusCodeGenEngine.Create(FSchemaReader, FOptions);
  try
    FMemoPreview.Lines.Text := LEngine.GenerateUnit(FTables[LSelectedIndex]);
  finally
    LEngine.Free;
  end;
end;

procedure TJanusWizardForm._OnTestConnectionClick(Sender: TObject);
begin
  try
    _ConnectToDatabase;
    ShowMessage('Connection successful!');
  except
    on E: Exception do
      ShowMessage('Connection failed: ' + E.Message);
  end;
end;

procedure TJanusWizardForm._OnSelectAllClick(Sender: TObject);
var
  LIndex: Integer;
begin
  for LIndex := 0 to FClbTables.Count - 1 do
    FClbTables.Checked[LIndex] := True;
end;

procedure TJanusWizardForm._OnDeselectAllClick(Sender: TObject);
var
  LIndex: Integer;
begin
  for LIndex := 0 to FClbTables.Count - 1 do
    FClbTables.Checked[LIndex] := False;
end;

procedure TJanusWizardForm._OnBrowseClick(Sender: TObject);
var
  LDialog: TFileOpenDialog;
begin
  LDialog := TFileOpenDialog.Create(Self);
  try
    LDialog.Options := LDialog.Options + [fdoPickFolders];
    if LDialog.Execute then
      FEdtOutputPath.Text := LDialog.FileName;
  finally
    LDialog.Free;
  end;
end;

procedure TJanusWizardForm._OnNextClick(Sender: TObject);
var
  LPage: Integer;
begin
  LPage := FPageControl.ActivePageIndex;
  if (LPage = 0) then
  begin
    try
      if not FConnection.Connected then
        _ConnectToDatabase;
      _LoadTables;
    except
      on E: Exception do
      begin
        ShowMessage('Connection failed: ' + E.Message);
        Exit;
      end;
    end;
  end;
  if (LPage = 2) then
    _UpdatePreview;
  if LPage < 3 then
    FPageControl.ActivePageIndex := LPage + 1;
  _UpdateButtons;
end;

procedure TJanusWizardForm._OnBackClick(Sender: TObject);
var
  LPage: Integer;
begin
  LPage := FPageControl.ActivePageIndex;
  if LPage > 0 then
    FPageControl.ActivePageIndex := LPage - 1;
  _UpdateButtons;
end;

procedure TJanusWizardForm._OnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TJanusWizardForm._OnTableClick(Sender: TObject);
begin
  if FPageControl.ActivePageIndex = 3 then
    _UpdatePreview;
end;

procedure TJanusWizardForm._OnGenerateClick(Sender: TObject);
var
  LEngine: TJanusCodeGenEngine;
  LSelectedTables: TArray<TTableInfo>;
  LCount: Integer;
  LIndex: Integer;
begin
  FOptions.LowerCaseNames := FChkLowerCase.Checked;
  FOptions.GenerateLazy := FChkLazy.Checked;
  FOptions.GenerateNullable := FChkNullable.Checked;
  FOptions.GenerateDictionary := FChkDictionary.Checked;
  FOptions.ProjectPrefix := FEdtProject.Text;
  FOptions.OutputPath := FEdtOutputPath.Text;

  if Trim(FOptions.OutputPath) = '' then
  begin
    ShowMessage('Please specify an output path.');
    Exit;
  end;

  LCount := 0;
  SetLength(LSelectedTables, FClbTables.Count);
  for LIndex := 0 to FClbTables.Count - 1 do
    if FClbTables.Checked[LIndex] then
    begin
      LSelectedTables[LCount] := FTables[LIndex];
      Inc(LCount);
    end;
  SetLength(LSelectedTables, LCount);

  if LCount = 0 then
  begin
    ShowMessage('No tables selected.');
    Exit;
  end;

  LEngine := TJanusCodeGenEngine.Create(FSchemaReader, FOptions);
  try
    LEngine.GenerateAll(LSelectedTables, FOptions.OutputPath);
    ShowMessage('Generated ' + IntToStr(LCount) + ' unit(s) successfully.');
  finally
    LEngine.Free;
  end;
end;

end.
