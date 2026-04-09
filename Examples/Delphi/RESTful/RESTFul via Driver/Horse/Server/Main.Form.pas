unit Main.Form;

interface

uses
  Winapi.Windows,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.Buttons,
  System.SysUtils,

  DataEngine.FactoryInterfaces,
  DataEngine.FactoryFireDac,
  // Janus Driver SQLite
  Janus.DML.Generator.SQLite,
  Janus.Form.Monitor,
  // Janus Server Horse
  Janus.Server.Horse;

type
  TFrmVCL = class(TForm)
    lbPorta: TLabel;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
  private
    FRESTServerHorse: TRESTServerHorse;
    FConnection: IDBConnection;
  end;

var
  FrmVCL: TFrmVCL;

implementation

uses
  uDataModuleServer,
  Horse;

{$R *.dfm}

procedure TFrmVCL.FormCreate(Sender: TObject);
begin
  // DataEngine Engine de Conex�o a Banco de Dados
  FConnection := TFactoryFireDAC.Create(DataModuleServer.FDConnection1, dnSQLite);

  // Janus - REST Server Horse
  FRESTServerHorse := TRESTServerHorse.Create(Self);
  FRESTServerHorse.Connection := FConnection;



  THorse.Get('api/Janus/ping/:id',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    begin
      Res.Send('{"Result": "Recebi ping, toma pong ' + Req.Params['id'] + '"}').ContentType('application/json');
    end);

  THorse.Get('/ping',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    begin
      Res.Send('{"Result": "Recebi ping, toma pong"}').ContentType('application/json');
    end);


  THorse.Listen(9000);
end;

procedure TFrmVCL.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if THorse.IsRunning then
    THorse.StopListen;
end;

end.
