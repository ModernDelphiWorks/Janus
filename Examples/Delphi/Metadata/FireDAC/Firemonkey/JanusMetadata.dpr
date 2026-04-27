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

program JanusMetadata;

uses
  System.StartUpCopy,
  FMX.Forms,
  uPrincipal in 'uPrincipal.pas' {Form4},
  Janus.Model.Client in '..\..\..\Data\Models\Janus.Model.Client.pas',
  Janus.Model.Detail in '..\..\..\Data\Models\Janus.Model.Detail.pas',
  Janus.Model.Lookup in '..\..\..\Data\Models\Janus.Model.Lookup.pas',
  Janus.Model.Master in '..\..\..\Data\Models\Janus.Model.Master.pas';

{$R *.res}

begin
  Application.Initialize;
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;
  Application.CreateForm(TForm4, Form4);
  Application.Run;
end.
