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

// Demonstrates the [RESTReadOnly] attribute guard.
// POST, PUT, and DELETE are intentionally omitted — the framework blocks them
// at the OData parsing layer when [RESTReadOnly] is present on the model class.
unit HorseJanus.Controller.ReadOnly;

interface

uses
  Horse,
  HorseJanus.DAO.Base,
  System.JSON,
  REST.Json,
  Janus.Json,
  System.Generics.Collections,
  Janus.Model.ReadOnly,
  DM.Connection;

procedure List(Req: THorseRequest; Res: THorseResponse; Next: TProc);

implementation

procedure List(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  LItems: TObjectList<TReadOnlyModel>;
  LConn: TDMConn;
  LDao: THorseJanusDAOBase<TReadOnlyModel>;
begin
  LConn := TDMConn.Create(nil);
  try
    LDao := THorseJanusDAOBase<TReadOnlyModel>.Create(LConn.FDConnection1);
    try
      LItems := LDao.listAll;
      try
        Res.Send(TJanusJson.ObjectListToJsonString<TReadOnlyModel>(LItems))
           .ContentType('application/json');
      finally
        LItems.Free;
      end;
    finally
      LDao.Free;
    end;
  finally
    LConn.Free;
  end;
end;

end.
