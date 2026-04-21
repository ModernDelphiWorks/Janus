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
