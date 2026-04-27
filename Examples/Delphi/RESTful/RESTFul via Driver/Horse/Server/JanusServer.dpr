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

program JanusServer;
{$APPTYPE GUI}

uses
  Vcl.Forms,
  Provider.DataModule in 'Provider\Provider.DataModule.pas' {ProviderDM: TDataModule},
  Main.Server in 'Main.Server.pas' {FormServer},
  Janus.Model.Client in '..\Model\Janus.Model.Client.pas',
  Janus.Model.Detail in '..\Model\Janus.Model.Detail.pas',
  Janus.Model.Lookup in '..\Model\Janus.Model.Lookup.pas',
  Janus.Model.Master in '..\Model\Janus.Model.Master.pas',
  Controller.Janus.Server in 'Controller\Controller.Janus.Server.pas',
  Repository.Janus.Server in 'Repository\Repository.Janus.Server.pas',
  Provider.Janus.Server in 'Provider\Provider.Janus.Server.pas',
  Provider.Interfaces in 'Provider\Provider.Interfaces.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := true;
  Application.Initialize;
  Application.CreateForm(TFormServer, FormServer);
  Application.Run;
end.

