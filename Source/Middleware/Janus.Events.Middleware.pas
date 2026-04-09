{
      ORM Brasil � um ORM simples e descomplicado para quem utiliza Delphi

                   Copyright (c) 2016, Isaque Pinheiro
                          All rights reserved.

                    GNU Lesser General Public License
                      Vers�o 3, 29 de junho de 2007

       Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
       A todos � permitido copiar e distribuir c�pias deste documento de
       licen�a, mas mud�-lo n�o � permitido.

       Esta vers�o da GNU Lesser General Public License incorpora
       os termos e condi��es da vers�o 3 da GNU General Public License
       Licen�a, complementado pelas permiss�es adicionais listadas no
       arquivo LICENSE na pasta principal.
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
