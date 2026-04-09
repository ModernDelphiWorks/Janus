unit Janus.Dependencies.Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Winapi.UrlMon,
  System.JSON, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Grids, Vcl.ValEdit,
  System.Generics.Collections,
  System.UITypes,
  System.Threading;

type
  TfrmJanusDependencies = class(TForm)
    pnlTop: TPanel;
    Label1: TLabel;
    Label2: TLabel;
    Panel1: TPanel;
    btnExit: TButton;
    Panel2: TPanel;
    vlDependencies: TValueListEditor;
    btnInstall: TButton;
    mmoLog: TMemo;
    procedure btnExitClick(Sender: TObject);
    procedure btnInstallClick(Sender: TObject);
  private
    procedure InstallDependencies;

    function GetCQLVersion: String;
    function GetDBCVersion: String;
    function GetDBEVersion: String;
    function GetJSONVersion: String;

    procedure log(AText: String);
    { Private declarations }
  public
    destructor Destroy; override;
    { Public declarations }
  end;

var
  frmJanusDependencies: TfrmJanusDependencies;

implementation

uses
  Janus.Dependencies.Interfaces;

{$R *.dfm}

procedure TfrmJanusDependencies.btnExitClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmJanusDependencies.btnInstallClick(Sender: TObject);
begin
  mmoLog.Lines.Clear;
  try
    InstallDependencies;
    MessageDlg('Dependencias baixadas com sucesso.', mtConfirmation, [mbOK], 0);
  except
    on e: Exception do
    begin
      log('ERRO: ' + e.Message);
      MessageDlg('Falha na instalacao das dependencias: ' + e.Message, mtError, [mbOK], 0);
    end;
  end;
end;

destructor TfrmJanusDependencies.Destroy;
begin
  inherited;
end;

function TfrmJanusDependencies.GetCQLVersion: String;
begin
  result := vlDependencies.Values['FluentSQL'];
end;

function TfrmJanusDependencies.GetDBCVersion: String;
begin
  result := vlDependencies.Values['MetaDbDiff'];
end;

function TfrmJanusDependencies.GetDBEVersion: String;
begin
  result := vlDependencies.Values['DataEngine'];
end;

function TfrmJanusDependencies.GetJSONVersion: String;
begin
  result := vlDependencies.Values['JsonFlow'];
end;

procedure TfrmJanusDependencies.InstallDependencies;
var
  LExecutor: IJanusDependenciesExecutor;
begin
  LExecutor := NewExecutor;
  LExecutor
    .AddCommand(CommandFluentSQL(GetCQLVersion, log))
    .AddCommand(CommandMetaDbDiff(GetDBCVersion, log))
    .AddCommand(CommandDataEngine(GetDBEVersion, log))
    .AddCommand(CommandJsonFlow(GetJSONVersion, log))
    .Execute;
end;

procedure TfrmJanusDependencies.log(AText: String);
begin
  TThread.Synchronize(TThread.CurrentThread,
    procedure
    begin
      mmoLog.Lines.Add(AText);
    end
    );
end;

end.
