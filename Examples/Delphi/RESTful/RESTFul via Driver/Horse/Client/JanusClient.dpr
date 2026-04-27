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

program JanusClient;

uses
  Forms,
  SysUtils,
  Main.Client in 'View\Main.Client.pas' {FormClient},
  Janus.Model.Client in '..\Model\Janus.Model.Client.pas',
  Janus.Model.Detail in '..\Model\Janus.Model.Detail.pas',
  Janus.Model.Lookup in '..\Model\Janus.Model.Lookup.pas',
  Janus.Model.Master in '..\Model\Janus.Model.Master.pas',
  Provider.Janus in 'Provider\Provider.Janus.pas',
  Repository.Master in 'Repository\Repository.Master.pas',
  Controller.Master in 'Controller\Controller.Master.pas',
  Provider.DataModule in 'Provider\Provider.DataModule.pas' {ProviderDM: TDataModule},
  Janus.Manager.DataSet in '..\..\..\..\..\Source\Dataset\Janus.Manager.DataSet.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFormClient, FormClient);
  Application.Run;
end.

