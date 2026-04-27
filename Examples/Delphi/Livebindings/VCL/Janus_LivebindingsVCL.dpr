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

program Janus_LivebindingsVCL;

uses
  Vcl.Forms,
  UPrincipal in 'UPrincipal.pas' {FormPrincipal},
  produto in 'produto.pas',
  Janus.Binder.Attributes in '..\..\..\Source\Livebindings\Janus.Binder.Attributes.pas',
  Janus.Binder in '..\..\..\Source\Livebindings\Janus.Binder.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFormPrincipal, FormPrincipal);
  Application.Run;
end.
