unit uMainFormORM;

interface

uses
  Windows,
  Messages,
  SysUtils,
  Variants,
  Classes,
  Graphics,
  Controls,
  Forms,
  Dialogs,
  DB,
  Grids,
  DBGrids,
  StdCtrls,
  Mask,
  DBClient,
  DBCtrls,
  ExtCtrls,
  Rtti,
  /// orm factory
  DataEngine.FactoryInterfaces,
  /// orm injection dependency
  Janus.Container.DataSet.Interfaces,
  Janus.Container.ClientDataSet,
  Janus.Container.ObjectSet.Interfaces,
  Janus.Container.ObjectSet,
  DataEngine.factory.wire.mongodb,
  Janus.Json,
  /// orm model
  Janus.Model.Client,

  JSON.Types,
  JSON.Readers,
  JSON.BSON,
  JSON.Builders, MongoWireConnection;

type
  TForm3 = class(TForm)
    DBGrid1: TDBGrid;
    DBNavigator1: TDBNavigator;
    Button2: TButton;
    DataSource3: TDataSource;
    Label3: TLabel;
    DBEdit3: TDBEdit;
    Label4: TLabel;
    DBEdit4: TDBEdit;
    CDSClient: TClientDataSet;
    Button1: TButton;
    DataSource1: TDataSource;
    DBGrid2: TDBGrid;
    ClientDataSet1: TClientDataSet;
    Memo1: TMemo;
    MongoWireConnection1: TMongoWireConnection;
    procedure FormCreate(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
    oConn: IDBConnection;
    oContainerClient: IContainerDataSet<Tclient>;
    oContainerObject: IContainerObjectSet<Tclient>;
public
    { Public declarations }
  end;

var
  Form3: TForm3;

implementation

uses
  StrUtils,
  Generics.Collections, MetaDbDiff.Mapping.Register, MetaDbDiff.mapping.explorer;

{$R *.dfm}

procedure TForm3.Button1Click(Sender: TObject);
var
  LClient: Tclient;
begin
  LClient := oContainerClient.Current;
  LClient.client_name := 'Mudar campo "Nome" pelo objeto';
  oContainerClient.Save(LClient);
end;

procedure TForm3.Button2Click(Sender: TObject);
begin
  oContainerClient.ApplyUpdates(0);
end;

procedure TForm3.FormCreate(Sender: TObject);
var
  LClientList: TObjectList<Tclient>;
  I: Integer;
begin
  // Inst�ncia da class de conex�o via FireDAC
  oConn := TFactoryMongoWire.Create(MongoWireConnection1, dnMongoDB);

  // Client
  oContainerClient := TContainerClientDataSet<Tclient>.Create(oConn, CDSClient);
  oContainerClient.Open;
//  oContainerClient.OpenWhere('{"client_id": 2}', '');

  // Campo do tipo TDataSetField que recebe os sub-objects da cole��o selecionada
  // Ser� criado um campo desse tipo para cada sub-object, veja como definir o tipo
  // no modelo na unit Janus.Model.Client.pas que segue junto como o exemplo.
  DataSource1.DataSet := (CDSClient.FieldByName('address') as TDataSetField).NestedDataSet;

  oContainerObject := TContainerObjectSet<Tclient>.Create(oConn);

  // Somente demonstra��o de funcionalidade
  LClientList := oContainerObject.Find;
//  LClientList := oContainerObject.FindWhere('{"client_id": 2}', '');
  /// Converte lista para JSON
  try
    Memo1.Lines.Text := TJanusJson.ObjectListToJsonString<Tclient>(LClientList);
  finally
    LClientList.Free;
  end;
  /// Converte JSON para lista
  try
    LClientList := TJanusJson.JsonToObjectList<Tclient>(Memo1.Lines.Text);
  finally
    LClientList.Free;
  end;
end;

end.

