program HorseJanus;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Horse,
  System.SysUtils,
  DM.Connection in 'providers\DM.Connection.pas' {DMConn: TDataModule},
  Janus.Model.Client in 'models\Janus.Model.Client.pas',
  Janus.Model.Detail in 'models\Janus.Model.Detail.pas',
  Janus.Model.Lookup in 'models\Janus.Model.Lookup.pas',
  Janus.Model.Master in 'models\Janus.Model.Master.pas',
  HorseJanus.DAO.Base in 'dao\HorseJanus.DAO.Base.pas',
  HorseJanus.Controller.Master in 'controller\HorseJanus.Controller.Master.pas',
  HorseJanus.Controller.Client in 'controller\HorseJanus.Controller.Client.pas',
  System.Classes;

begin
  ReportMemoryLeaksOnShutdown := True;
  IsConsole := False;

  THorse.Get('master', HorseJanus.Controller.Master.List);
  THorse.Post('master', HorseJanus.Controller.Master.Insert);
  THorse.Get('master/:id', HorseJanus.Controller.Master.Find);
  THorse.Put('master/:id', HorseJanus.Controller.Master.Update);
  THorse.Delete('master/:id', HorseJanus.Controller.Master.Delete);

  THorse.Get('client', HorseJanus.Controller.Client.List);
  THorse.Post('client', HorseJanus.Controller.Client.Insert);
  THorse.Get('client/:id', HorseJanus.Controller.Client.Find);
  THorse.Put('client/:id', HorseJanus.Controller.Client.Update);
  THorse.Delete('client/:id', HorseJanus.Controller.Client.Delete);

  THorse.Listen(9000, '127.0.0.1',
    procedure
    begin
      Readln;
    end
  );

end.
