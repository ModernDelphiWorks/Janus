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
  Vcl.Forms,
  Client.Forms.Main in 'Client.Forms.Main.pas' {Form3},
  Janus.Model.Client in '..\Janus.Model.Client.pas',
  Janus.Model.Detail in '..\Janus.Model.Detail.pas',
  Janus.Model.Lookup in '..\Janus.Model.Lookup.pas',
  Janus.Model.Master in '..\Janus.Model.Master.pas',
  Janus.Client.WiRL in '..\..\..\..\Source\RESTful Components\Client\Janus.Client.WiRL.pas',
  Janus.driver.rest.wirl in '..\..\..\..\Source\RESTful Components\Client\Janus.driver.rest.wirl.pas',
  Janus.factory.rest.wirl in '..\..\..\..\Source\RESTful Components\Client\Janus.factory.rest.wirl.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;

  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm3, Form3);
  Application.Run;
end.

