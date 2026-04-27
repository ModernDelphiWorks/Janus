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

unit HorseJanus.DAO.Base;

interface

uses
  FireDAC.Comp.Client,
  DataEngine.FactoryInterfaces,
  DataEngine.FactoryFireDac,
  Janus.Container.ObjectSet.Interfaces,
  Janus.Container.ObjectSet,
  System.Generics.Collections;

type
  THorseJanusDAOBase<T: class, constructor> = class
  protected
    FConnection : IDBConnection;
    FJanusContainer : IContainerObjectSet<T>;
  public
    procedure insert(Value: T);
    procedure update(Value: T);
    procedure delete(Value: T);
    procedure modify(Value: T);

    function listAll: TObjectList<T>;
    function findWhere(AWhere: String): T;

    constructor create(Connection: TFDConnection);
end;

implementation

{ THorseJanusDAOBase<T> }

constructor THorseJanusDAOBase<T>.create(Connection: TFDConnection);
begin
  FConnection := TFactoryFiredac.Create(Connection, dnFirebird);
  FJanusContainer := TContainerObjectSet<T>.Create(FConnection);
end;

procedure THorseJanusDAOBase<T>.delete(Value: T);
begin
  FJanusContainer.Delete(Value);
end;

function THorseJanusDAOBase<T>.findWhere(AWhere: String): T;
var
  list : TObjectList<T>;
  i: Integer;
begin
  result := nil;
  list := FJanusContainer.FindWhere(AWhere);
  try
    list.OwnsObjects := False;
    if list.Count > 0 then
      result := list.First;

    for i := 1 to list.Count - 1 do
      list[i].free;
  finally
    list.Free;
  end;
end;

procedure THorseJanusDAOBase<T>.insert(Value: T);
begin
  FJanusContainer.Insert(Value);
end;

function THorseJanusDAOBase<T>.listAll: TObjectList<T>;
begin
  result := FJanusContainer.Find;
end;

procedure THorseJanusDAOBase<T>.modify(Value: T);
begin
  FJanusContainer.Modify(Value);
end;

procedure THorseJanusDAOBase<T>.update(Value: T);
begin
  FJanusContainer.Update(Value);
end;

end.
