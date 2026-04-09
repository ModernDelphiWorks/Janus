unit Janus.Query.ResultSet;

interface

uses
  Generics.Collections,
  DataEngine.FactoryInterfaces,
  Janus.Bind;

type
  IJanusQueryResultSet = interface
    ['{0285A016-824C-41C7-9680-44127BB62AD0}']
    function SetConnection(const AConnection: IDBConnection): IJanusQueryResultSet;
    function SQL(const ASQL: String): IJanusQueryResultSet;
    function AsResultSet: IDBDataSet;
  end;

  TJanusQueryResultSet = class(TInterfacedObject, IJanusQueryResultSet)
  private
    FSQL: String;
    FConnection: IDBConnection;
  public
    class function New: IJanusQueryResultSet;
    function SetConnection(const AConnection: IDBConnection): IJanusQueryResultSet;
    function SQL(const ASQL: String): IJanusQueryResultSet;
    function AsResultSet: IDBDataSet;
  end;

  IJanusQueryObject<M: class, constructor> = interface
    ['{E1AA571D-E8BC-4A79-8B67-D7E77680F29C}']
    function SetConnection(AConnection: IDBConnection): IJanusQueryObject<M>;
    function SQL(ASQL: String): IJanusQueryObject<M>;
    function AsList: TObjectList<M>;
    function AsValue: M;
  end;

  TJanusQueryObject<M: class, constructor> = class(TInterfacedObject, IJanusQueryObject<M>)
  private
    FSQL: String;
    FConnection: IDBConnection;
  public
    class function New: IJanusQueryObject<M>;
    function SetConnection(AConnection: IDBConnection): IJanusQueryObject<M>;
    function SQL(ASQL: String): IJanusQueryObject<M>;
    function AsList: TObjectList<M>;
    function AsValue: M;
  end;

implementation

function TJanusQueryResultSet.AsResultSet: IDBDataSet;
begin
  Result := FConnection.CreateDataSet(FSQL);
end;

class function TJanusQueryResultSet.New: IJanusQueryResultSet;
begin
  Result := Self.Create;
end;

function TJanusQueryResultSet.SetConnection(
  const AConnection: IDBConnection): IJanusQueryResultSet;
begin
  FConnection := AConnection;
  Result := Self;
end;

function TJanusQueryResultSet.SQL(const ASQL: String): IJanusQueryResultSet;
begin
  FSQL := ASQL;
  Result := Self;
end;

function TJanusQueryObject<M>.AsList: TObjectList<M>;
var
  LResultSet: IDBDataSet;
  LObject: M;
begin
  LResultSet := FConnection.CreateDataSet(FSQL);
  try
    if LResultSet.RecordCount = 0 then
      Exit(nil);
    Result := TObjectList<M>.Create;
    while not LResultSet.Eof do
    begin
      LObject := M.Create;
      TBind.Instance.SetFieldToProperty(LResultSet, LObject);
      Result.Add(LObject);
    end;
  finally
    LResultSet.Close;
    FConnection.Disconnect;
  end;
end;

function TJanusQueryObject<M>.AsValue: M;
var
  LResultSet: IDBDataSet;
begin
  LResultSet := FConnection.CreateDataSet(FSQL);
  try
    if LResultSet.RecordCount = 0 then
      Exit(nil);
    Result := M.Create;
    TBind.Instance.SetFieldToProperty(LResultSet, Result);
  finally
    LResultSet.Close;
    FConnection.Disconnect;
  end;
end;

class function TJanusQueryObject<M>.New: IJanusQueryObject<M>;
begin
  Result := Self.Create;
end;

function TJanusQueryObject<M>.SetConnection(
  AConnection: IDBConnection): IJanusQueryObject<M>;
begin
  FConnection := AConnection;
  Result := Self;
end;

function TJanusQueryObject<M>.SQL(const ASQL: String): IJanusQueryObject<M>;
begin
  FSQL := ASQL;
  Result := Self;
end;

end.