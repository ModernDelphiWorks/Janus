{
  ------------------------------------------------------------------------------
  Janus ORM
  State-of-the-art Object-Relational Mapping (ORM) framework for Delphi.

  SPDX-License-Identifier: MIT
  Copyright (c) 2025-2026 Isaque Pinheiro

  Licensed under the MIT License.
  See the LICENSE file in the project root for full license information.
  ------------------------------------------------------------------------------
}

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)

  ORM Brasil � um ORM simples e descomplicado para quem utiliza Delphi.
}

unit Janus.Manager.ClientDataSet.Reg;

interface

uses
  Classes,
//  DesignIntf,
//  DesignEditors,
  Janus.Manager.ClientDataSet;

procedure register;

implementation

procedure register;
begin
  RegisterComponents('Janus-DB', [TJanusManagerClientDataSet]);
end;

end.
