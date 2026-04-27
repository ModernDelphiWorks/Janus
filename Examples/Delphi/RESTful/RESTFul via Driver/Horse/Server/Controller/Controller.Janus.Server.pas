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

unit Controller.Janus.Server;

interface

uses
  Repository.Janus.Server;

type
  TControllerServer = class
  private
    FRepositoryServer: TRepositoryServer;
  protected
  public
    constructor Create;
    destructor Destroy; override;
  end;

implementation

{ TControllerServer }

constructor TControllerServer.Create;
begin
  FRepositoryServer := TRepositoryServer.Create;
end;

destructor TControllerServer.Destroy;
begin
  FRepositoryServer.Free;
  inherited;
end;

end.
