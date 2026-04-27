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

program JanusElevateDB;

uses
  Forms,
  SysUtils,
  uMainFormORM in 'uMainFormORM.pas' {Form3},
  Janus.Model.Client in '..\Models\Janus.Model.Client.pas',
  Janus.Model.Detail in '..\Models\Janus.Model.Detail.pas',
  Janus.Model.Lookup in '..\Models\Janus.Model.Lookup.pas',
  Janus.Model.Master in '..\Models\Janus.Model.Master.pas',
  Janus.driver.elevatedb in '..\..\..\Source\Drivers\Janus.driver.elevatedb.pas',
  Janus.driver.elevatedb.transaction in '..\..\..\Source\Drivers\Janus.driver.elevatedb.transaction.pas',
  Janus.factory.elevatedb in '..\..\..\Source\Drivers\Janus.factory.elevatedb.pas',
  Janus.Form.Monitor in '..\..\..\Source\Monitor\Janus.Form.Monitor.pas' {CommandMonitor},
  Janus.monitor in '..\..\..\Source\Monitor\Janus.monitor.pas';

{$R *.res}

begin
  Application.Initialize;
  ReportMemoryLeaksOnShutdown := True;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm3, Form3);
  Application.Run;
end.
