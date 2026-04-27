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

unit uLookupServerModule;

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
  Janus.Model.Lookup,
  Janus.DML.Generator.SQLite;

type
  Tapilookup = class(TDSServerModule)
    procedure DSServerModuleCreate(Sender: TObject);
  private
    { Private declarations }
    FConnection: IDBConnection;
    FLookup: IContainerObjectSet<Tlookup>;
  public
    { Public declarations }
    function lookup: TJSONArray;
    function selectid(AID: Integer): TJSONValue;
    function selectwhere(AWhere: String; AOrderBy: String = ''): TJSONArray;
    function api(AResource: String): TJSONString;
    function acceptapi(AResource: String): TJSONString;
    /// <summary>
    /// "Suffix" � o nome definido na propriedade Post_Put_Delete_Suffix do
    /// componentes TRestDataSnapConnection
    /// </summary>
    function acceptlookup(AValue: TJSONArray): TJSONString;
    function updatelookup(AValue: TJSONArray): TJSONString;
    function cancellookup(AID: Integer): TJSONString;
  end;

implementation

uses
  uDataModuleServer;

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

function Tapilookup.acceptlookup(AValue: TJSONArray): TJSONString;
begin

end;

function Tapilookup.cancellookup(AID: Integer): TJSONString;
begin

end;

procedure Tapilookup.DSServerModuleCreate(Sender: TObject);
begin
  FConnection := TFactoryFireDAC.Create(DataModuleServer.FDConnection1, dnSQLite);
  FLookup := TContainerObjectSet<Tlookup>.Create(FConnection);
end;

function Tapilookup.lookup: TJSONArray;
var
  LLookupList: TObjectList<Tlookup>;
begin
  try
    LLookupList := FLookup.Find;
    /// <summary>
    /// Retorna o JSON
    /// </summary>
    Result := TJanusJson.JSONObjectListToJSONArray<Tlookup>(LLookupList);
  finally
    LLookupList.Free;
  end;
end;

function Tapilookup.selectid(AID: Integer): TJSONValue;
begin

end;

function Tapilookup.selectwhere(AWhere, AOrderBy: String): TJSONArray;
begin

end;

function Tapilookup.updatelookup(AValue: TJSONArray): TJSONString;
begin

end;

function Tapilookup.api(AResource: String): TJSONString;
begin
  Result := TJSONString.Create('{"GET":"' + AResource + '"}');
end;

function Tapilookup.acceptapi(AResource: String): TJSONString;
begin
  Result := TJSONString.Create('{"POST":"' + AResource + '"}');
end;

end.
