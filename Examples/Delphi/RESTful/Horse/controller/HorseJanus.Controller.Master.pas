unit HorseJanus.Controller.Master;

interface

uses
  Horse,
  HorseJanus.DAO.Base,
  System.JSON,
  REST.Json,
  Janus.Json,
  System.Generics.Collections,
  Janus.Model.Master,
  DM.Connection;

procedure List(Req: THorseRequest; Res: THorseResponse; Next: TProc);
procedure Find(Req: THorseRequest; Res: THorseResponse; Next: TProc);
procedure Insert(Req: THorseRequest; Res: THorseResponse; Next: TProc);
procedure Update(Req: THorseRequest; Res: THorseResponse; Next: TProc);
procedure Delete(Req: THorseRequest; Res: THorseResponse; Next: TProc);

implementation

procedure Delete(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  conn: TDMConn;
  dao : THorseJanusDAOBase<Tmaster>;
  master : Tmaster;
  id : String;
begin
  id := Req.Params['id'];
  conn := TDMConn.Create(nil);
  try
    dao := THorseJanusDAOBase<Tmaster>.create(conn.FDConnection1);
    try
      master := dao.findWhere('master_id = ' + id);
      try
        dao.delete(master);
        Res.Status(204);
      finally
        master.Free;
      end;
    finally
      dao.Free;
    end;
  finally
    conn.Free;
  end;
end;

procedure Update(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  conn: TDMConn;
  dao : THorseJanusDAOBase<Tmaster>;
  master : Tmaster;
  id : String;
begin
  id := Req.Params['id'];
  conn := TDMConn.Create(nil);
  try
    dao := THorseJanusDAOBase<Tmaster>.create(conn.FDConnection1);
    try
      master := dao.findWhere('master_id = ' + id);
      try
        dao.modify(master);
        TJanusJson.JsonToObject(Req.Body, master);
        dao.update(master);
        Res.Send(TJanusJson.ObjectToJsonString(master))
           .ContentType('application/json');
      finally
        master.Free;
      end;
    finally
      dao.Free;
    end;
  finally
    conn.Free;
  end;
end;

procedure Insert(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  conn: TDMConn;
  dao : THorseJanusDAOBase<Tmaster>;
  master : Tmaster;
begin
  master := TJanusJson.JsonToObject<Tmaster>(Req.Body);
  try
    conn := TDMConn.Create(nil);
    try
      dao := THorseJanusDAOBase<Tmaster>.create(conn.FDConnection1);
      try
        dao.insert(master);
        Res.Send(TJanusJson.ObjectToJsonString(master))
           .Status(201)
           .ContentType('application/json');
      finally
        dao.Free;
      end;
    finally
      conn.Free;
    end;
  finally
    master.Free;
  end;
end;

procedure Find(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  conn: TDMConn;
  dao : THorseJanusDAOBase<Tmaster>;
  master : Tmaster;
  id : String;
begin
  id := Req.Params['id'];
  conn := TDMConn.Create(nil);
  try
    dao := THorseJanusDAOBase<Tmaster>.create(conn.FDConnection1);
    try
      master := dao.findWhere('master_id = ' + id);
      try
        Res.Send(TJanusJson.ObjectToJsonString(master))
           .ContentType('application/json');
      finally
        master.Free;
      end;
    finally
      dao.Free;
    end;
  finally
    conn.Free;
  end;
end;

procedure List(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  masterList: TObjectList<Tmaster>;
  conn: TDMConn;
  dao : THorseJanusDAOBase<Tmaster>;
begin
  conn := TDMConn.Create(nil);
  try
    dao := THorseJanusDAOBase<Tmaster>.create(conn.FDConnection1);
    try
      masterList := dao.listAll;
      try
        Res.Send(TJanusJson.ObjectListToJsonString<Tmaster>(masterList))
           .ContentType('application/json');
      finally
        masterList.Free;
      end;
    finally
      dao.Free;
    end;
  finally
    conn.Free;
  end;
end;

end.
