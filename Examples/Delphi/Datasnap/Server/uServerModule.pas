unit uServerModule;

interface

uses
  System.SysUtils, System.Classes, System.Json,
  DataSnap.DSProviderDataModuleAdapter,
  Datasnap.DSServer,
  Datasnap.DSAuth,
  Datasnap.DSSession,
  System.Generics.Collections,
  /// Janus JSON e DataSnap
  Janus.Json,
  /// Janus Conex�o database
  DataEngine.FactoryFireDac,
  DataEngine.FactoryInterfaces,
  /// Janus
  Janus.Container.ObjectSet,
  Janus.Container.ObjectSet.Interfaces,
  Janus.Session.DataSet,
  Janus.Model.Master,
  Janus.Model.Detail,
  Janus.Model.Lookup,
  Janus.DML.Generator.SQLite,

  uServerContainer,
  FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef, FireDAC.Stan.ExprFuncs, FireDAC.VCLUI.Wait, Data.DB,
  FireDAC.Comp.Client;

type
  TJanus = class(TDSServerModule)
    FDConnection1: TFDConnection;
    procedure DataModuleCreate(Sender: TObject);
  private
    { Private declarations }
    FConnection: IDBConnection;
    FContainerMaster: IContainerObjectSet<Tmaster>;
    FContainerLookup: IContainerObjectSet<Tlookup>;
  public
    { Public declarations }
    function lookup(AID: Integer = 0): TJSONArray;
    function master(AID: Integer = 0): TJSONArray;
    function masterWhere(AWhere: String; AOrderBy: String = ''): TJSONArray;
    function acceptmaster(AValue: TJSONObject): TJSONString;
    function updatemaster(AValue: TJSONArray): TJSONString;
    function cancelmaster(AID: Integer): TJSONString;
  end;

implementation

uses
  uFormServer;

{$R *.dfm}

{ TServerMethods1 }

function TJanus.acceptmaster(AValue: TJSONObject): TJSONString;
var
  LMaste: Tmaster;
  LFor: Integer;
begin
  try
    LMaste := TJanusJson.JsonToObject<Tmaster>(AValue.ToJSON);
    try
      FContainerMaster.Insert(LMaste);
      Result := TJSONString.Create('Dados inserido no banco com sucesso!!!');
    finally
      LMaste.Free;
    end;
  except
    Result := TJSONString.Create('Houve um erro ao tentar inserir os dados no banco!!!');
  end;
end;

function TJanus.cancelmaster(AID: Integer): TJSONString;
var
  LMaster: Tmaster;
begin
  try
    LMaster := FContainerMaster.Find(AID);
    FContainerMaster.Delete(LMaster);
    Result := TJSONString.Create('Dados exclu�dos do banco com sucesso!!!');
  except
    Result := TJSONString.Create('Houve um erro ao tentar excluir os dados no banco!!!');
  end;
end;

procedure TJanus.DataModuleCreate(Sender: TObject);
begin
  FConnection := TFactoryFireDAC.Create(FDConnection1, dnSQLite);
  FContainerMaster := TContainerObjectSet<Tmaster>.Create(FConnection);
  FContainerLookup := TContainerObjectSet<Tlookup>.Create(FConnection);
end;

function TJanus.lookup(AID: Integer): TJSONArray;
var
  LLookupList: TObjectList<Tlookup>;
begin
  LLookupList := TObjectList<Tlookup>.Create;
  try
    if AID = 0 then
      LLookupList := FContainerLookup.Find
    else
      LLookupList := FContainerLookup.FindWhere('lookup_id = ' + IntToStr(AID));
    /// <summary>
    /// Retorna o JSON
    /// </summary>
    Result := TJanusJson.JSONObjectListToJSONArray<Tlookup>(LLookupList);
  finally
    LLookupList.Free;
  end;
end;

function TJanus.masterWhere(AWhere, AOrderBy: String): TJSONArray;
var
  LMasterList: TObjectList<Tmaster>;
begin
  /// <summary>
  /// Controle se Sess�o
  /// </summary>
//  ControleDeSessao;

  LMasterList := TObjectList<Tmaster>.Create;
  try
    LMasterList := FContainerMaster.FindWhere(AWhere, AOrderBy);
    /// <summary>
    /// Retorna o JSON
    /// </summary>
    Result := TJanusJson.JSONObjectListToJSONArray<Tmaster>(LMasterList);
  finally
    LMasterList.Free;
  end;
end;

function TJanus.updatemaster(AValue: TJSONArray): TJSONString;
var
  LMasterList: TObjectList<Tmaster>;
  LMasterUpdate: Tmaster;
  LFor: Integer;
begin
  try
    LMasterList := TJanusJson.JsonToObjectList<Tmaster>(AValue.ToJSON);
    try
      for LFor := 0 to LMasterList.Count -1 do
      begin
        LMasterUpdate := FContainerMaster.Find(LMasterList.Items[LFor].master_id);
        FContainerMaster.Modify(LMasterUpdate);
        FContainerMaster.Update(LMasterList.Items[LFor]);
      end;
      Result := TJSONString.Create('Dados alterado no banco com sucesso!!!');
    finally
      LMasterList.Clear;
      LMasterList.Free;
    end;
  except
    Result := TJSONString.Create('Houve um erro ao tentar alterar os dados no banco!!!');
  end;
end;

function TJanus.master(AID: Integer): TJSONArray;
var
  LMasterList: TObjectList<Tmaster>;
begin
  LMasterList := TObjectList<Tmaster>.Create;
  try
    if AID = 0 then
      LMasterList := FContainerMaster.Find
    else
      LMasterList := FContainerMaster.FindWhere('master_id = ' + IntToStr(AID));
    /// <summary>
    /// Retorna o JSON
    /// </summary>
    Result := TJanusJson.JSONObjectListToJSONArray<Tmaster>(LMasterList);
  finally
    LMasterList.Free;
  end;
end;

end.

