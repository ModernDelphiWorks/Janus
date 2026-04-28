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

{ @abstract(Reusable FireDAC bootstrap for DUnitX test executors.)
  Required when TFDConnection is used from non-VCL threads (Indy worker
  threads inside Horse). Sets IsMultiThread := True and FDManager.SilentMode
  := True so FireDAC does not invoke VCL cursor callbacks that AV outside
  the main thread. Idempotent — safe to call more than once. }
unit Janus.Test.Bootstrap;

interface

uses
  FireDAC.ConsoleUI.Wait,
  FireDAC.Comp.Client;

type
  TJanusTestBootstrap = class
  public
    class procedure RegisterFireDACSilent;
  end;

implementation

class procedure TJanusTestBootstrap.RegisterFireDACSilent;
begin
  IsMultiThread := True;
  FDManager.SilentMode := True;
end;

end.
