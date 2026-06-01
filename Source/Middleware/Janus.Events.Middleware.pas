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
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Janus.Events.Middleware;

interface

uses
  Janus.Before.Insert.Middleware,
  Janus.After.Insert.Middleware,
  Janus.Before.Update.Middleware,
  Janus.After.Update.Middleware,
  Janus.Before.Delete.Middleware,
  Janus.After.Delete.Middleware;

function BeforeInsertMiddleware: IBeforeInsertMiddleware;
function AfterInsertMiddleware: IAfterInsertMiddleware;
function BeforeUpdateMiddleware: IBeforeUpdateMiddleware;
function AfterUpdateMiddleware: IAfterUpdateMiddleware;
function BeforeDeleteMiddleware: IBeforeDeleteMiddleware;
function AfterDeleteMiddleware: IAfterDeleteMiddleware;

implementation

function BeforeInsertMiddleware: IBeforeInsertMiddleware;
begin
  Result := TBeforeInsertMiddleware.Get;
end;

function AfterInsertMiddleware: IAfterInsertMiddleware;
begin
  Result := TAfterInsertMiddleware.Get;
end;

function BeforeUpdateMiddleware: IBeforeUpdateMiddleware;
begin
  Result := TBeforeUpdateMiddleware.Get;
end;

function AfterUpdateMiddleware: IAfterUpdateMiddleware;
begin
  Result := TAfterUpdateMiddleware.Get;
end;

function BeforeDeleteMiddleware: IBeforeDeleteMiddleware;
begin
  Result := TBeforeDeleteMiddleware.Get;
end;

function AfterDeleteMiddleware: IAfterDeleteMiddleware;
begin
  Result := TAfterDeleteMiddleware.Get;
end;

end.
