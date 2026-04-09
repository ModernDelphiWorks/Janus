unit HorseJanus.Controller.Client;

interface

uses
  Horse,
  HorseJanus.DAO.Base,
  System.JSON,
  REST.Json,
  Janus.Json,
  System.Generics.Collections,
  Janus.Model.Client,
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
  dao : THorseJanusDAOBase<TClient>;
  client : TClient;
  id : String;
begin
  id := Req.Params['id'];
  conn := TDMConn.Create(nil);
  try
    dao := THorseJanusDAOBase<TClient>.create(conn.FDConnection1);
    try
      client := dao.findWhere('client_id = ' + id);
      try
        dao.delete(client);
        Res.Status(204);
      finally
        client.Free;
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
  dao : THorseJanusDAOBase<TClient>;
  client : TClient;
  id : String;
begin
  id := Req.Params['id'];
  conn := TDMConn.Create(nil);
  try
    dao := THorseJanusDAOBase<TClient>.create(conn.FDConnection1);
    try
      client := dao.findWhere('client_id = ' + id);
      try
        dao.modify(client);
        TJanusJson.JsonToObject(Req.Body, client);
        dao.update(client);
        Res.Send(TJanusJson.ObjectToJsonString(client))
           .ContentType('application/json');
      finally
        client.Free;
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
  dao : THorseJanusDAOBase<Tclient>;
  client : Tclient;
begin
  client := TJanusJson.JsonToObject<Tclient>(Req.Body);
  try
    conn := TDMConn.Create(nil);
    try
      dao := THorseJanusDAOBase<Tclient>.create(conn.FDConnection1);
      try
        dao.insert(client);
        Res.Send(TJanusJson.ObjectToJsonString(client))
           .Status(201)
           .ContentType('application/json');
      finally
        dao.Free;
      end;
    finally
      conn.Free;
    end;
  finally
    client.Free;
  end;
end;

procedure Find(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  conn: TDMConn;
  dao : THorseJanusDAOBase<Tclient>;
  client : Tclient;
  id : String;
begin
  id := Req.Params['id'];
  conn := TDMConn.Create(nil);
  try
    dao := THorseJanusDAOBase<Tclient>.create(conn.FDConnection1);
    try
      client := dao.findWhere('client_id = ' + id);
      try
        Res.Send(TJanusJson.ObjectToJsonString(client))
           .ContentType('application/json');
      finally
        client.Free;
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
  clientList: TObjectList<Tclient>;
  conn: TDMConn;
  dao : THorseJanusDAOBase<Tclient>;
begin
  conn := TDMConn.Create(nil);
  try
    dao := THorseJanusDAOBase<Tclient>.create(conn.FDConnection1);
    try
      clientList := dao.listAll;
      try
        Res.Send(TJanusJson.ObjectListToJsonString<Tclient>(clientList))
           .ContentType('application/json');
      finally
        clientList.Free;
      end;
    finally
      dao.Free;
    end;
  finally
    conn.Free;
  end;
end;

end.

