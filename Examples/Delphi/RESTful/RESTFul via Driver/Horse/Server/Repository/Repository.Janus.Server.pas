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

unit Repository.Janus.Server;

interface

uses
  Provider.Interfaces,
  Provider.Janus.Server;

type
  TRepositoryServer = class
  private
    FProvider: IProvider;
  protected
  public
    constructor Create;
    destructor Destroy; override;
  end;

implementation

{ TRepositoryServer }

constructor TRepositoryServer.Create;
begin
  FProvider := TProviderJanus.Create;
end;

destructor TRepositoryServer.Destroy;
begin
  inherited;
end;

end.

