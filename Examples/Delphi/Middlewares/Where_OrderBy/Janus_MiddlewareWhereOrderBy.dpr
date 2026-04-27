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

program Janus_MiddlewareWhereOrderBy;

uses
  Forms,
  SysUtils,
  uMainFormORM in 'uMainFormORM.pas' {Form3},
  Janus.Model.Client in 'Janus.Model.Client.pas',
  Janus.Model.Detail in 'Janus.Model.Detail.pas',
  Janus.Model.Lookup in 'Janus.Model.Lookup.pas',
  Janus.Model.Master in 'Janus.Model.Master.pas',
  MetaDbDiff.Types.Mapping in '..\..\..\..\MetaDbDiff\Source\Core\MetaDbDiff.Types.Mapping.pas';

{$R *.res}

begin
  Application.Initialize;
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm3, Form3);
  Application.Run;
end.
