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

program Janus_ObjectLazy;

uses
  Vcl.Forms,
  Principal in 'Principal.pas' {Form1},
  Model.Atendimento in 'Model.Atendimento.pas',
  Model.Exame in 'Model.Exame.pas',
  Model.Procedimento in 'Model.Procedimento.pas',
  Model.Setor in 'Model.Setor.pas',
  Janus.Types.Lazy in '..\..\..\Source\Core\Janus.Types.Lazy.pas',
  Janus.Form.Monitor in '..\..\..\Source\Monitor\Janus.Form.Monitor.pas' {CommandMonitor};

{$R *.res}

begin
  Application.Initialize;
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
