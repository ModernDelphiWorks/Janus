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

program PJSON;

uses
  Forms,
  uJSON in 'uJSON.pas' {Form4},
  Janus.model.person in 'Janus.model.person.pas',
  JsonFlow.Utils in '..\..\Source\Dependencies\JsonFlow\Source\Core\JsonFlow.Utils.pas',
  JsonFlow.Builders in '..\..\Source\Dependencies\JsonFlow\Source\Core\JsonFlow.Builders.pas',
  JsonFlow.Reader in '..\..\Source\Dependencies\JsonFlow\Source\Reader\JsonFlow.Reader.pas',
  JsonFlow.Writer in '..\..\Source\Dependencies\JsonFlow\Source\Writer\JsonFlow.Writer.pas',
  JsonFlow.Types in '..\..\Source\Dependencies\JsonFlow\Source\Core\JsonFlow.Types.pas',
  JsonFlow in '..\..\Source\Dependencies\JsonFlow\Source\JsonFlow.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;

  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm4, Form4);
  Application.Run;
end.
