unit Janus.DLL.Query.Facade;

interface

uses
  System.SysUtils,
  Generics.Collections,
  DataEngine.FactoryInterfaces,
  Janus.DLL.Interfaces,
  Janus.DLL.Entity.Proxy,
  Janus.DLL.ObjectSet.Facade;

type
  TJanusQuery = class(TInterfacedObject, IJanusQuery)
  private
    FEntityName: string;
    FDBConn: IDBConnection;
    FWhere: string;
    FOrderBy: string;
    FPageSize: Integer;
  public
    constructor Create(const AEntityName: string;
      const ADBConn: IDBConnection);
    function Where(ASql: PWideChar): IJanusQuery; stdcall;
    function OrderBy(AField: PWideChar): IJanusQuery; stdcall;
    function PageSize(ASize: Integer): IJanusQuery; stdcall;
    function Execute: IJanusObjectSet; stdcall;
  end;

implementation

constructor TJanusQuery.Create(const AEntityName: string;
  const ADBConn: IDBConnection);
begin
  inherited Create;
  FEntityName := AEntityName;
  FDBConn := ADBConn;
  FWhere := '';
  FOrderBy := '';
  FPageSize := -1;
end;

function TJanusQuery.Where(ASql: PWideChar): IJanusQuery;
begin
  FWhere := string(ASql);
  Result := Self;
end;

function TJanusQuery.OrderBy(AField: PWideChar): IJanusQuery;
begin
  FOrderBy := string(AField);
  Result := Self;
end;

function TJanusQuery.PageSize(ASize: Integer): IJanusQuery;
begin
  FPageSize := ASize;
  Result := Self;
end;

function TJanusQuery.Execute: IJanusObjectSet;
var
  LProxy: TEntityProxyBase;
  LRawList: TObjectList<TObject>;
begin
  Result := nil;
  LProxy := TEntityProxyRegistry.Instance.CreateProxy(FEntityName, FDBConn);
  if not Assigned(LProxy) then
    Exit;
  LRawList := nil;
  try
    LRawList := LProxy.FindWhere(FWhere, FOrderBy);
    if (FPageSize > 0) and (LRawList.Count > FPageSize) then
      while LRawList.Count > FPageSize do
        LRawList.Delete(LRawList.Count - 1);
    Result := TJanusObjectSet.CreateFromList(LProxy, LRawList);
  except
    LRawList.Free;
    LProxy.Free;
    Result := nil;
  end;
end;

end.
