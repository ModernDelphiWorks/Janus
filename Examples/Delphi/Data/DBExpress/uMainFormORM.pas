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
  rtti,
  DB,
  Grids,
  DBGrids,
  StdCtrls,
  DBClient,
  Generics.Collections,
  WideStrings,
  ExtCtrls,
  DBCtrls,
  Mask,
  DbxSqlite,
  SqlExpr,
  /// orm factory
  DataEngine.FactoryInterfaces,
  /// orm injection dependency
  Janus.Container.ClientDataSet,
  Janus.Container.DataSet.Interfaces,
  DataEngine.FactoryDbExpress,
  Janus.DML.Generator.SQLite,
  /// orm model
  Janus.Model.Master,
  Janus.Model.Detail,
  Janus.Model.Lookup,
  Janus.Model.Client;

type
  TForm3 = class(TForm)
    DataSource1: TDataSource;
    DBGrid1: TDBGrid;
    DBNavigator1: TDBNavigator;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    DBGrid2: TDBGrid;
    DataSource2: TDataSource;
    DataSource3: TDataSource;
    DBEdit1: TDBEdit;
    Label1: TLabel;
    Label2: TLabel;
    DBEdit2: TDBEdit;
    Label3: TLabel;
    DBEdit3: TDBEdit;
    Label4: TLabel;
    DBEdit4: TDBEdit;
    Label5: TLabel;
    DBEdit5: TDBEdit;
    Label6: TLabel;
    DBEdit6: TDBEdit;
    Label7: TLabel;
    SQLConnection1: TSQLConnection;
    Label8: TLabel;
    DBEdit7: TDBEdit;
    DBImage1: TDBImage;
    Master: TClientDataSet;
    Detail: TClientDataSet;
    Client: TClientDataSet;
    Lookup: TClientDataSet;
    procedure Button3Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
    oConn: IDBConnection;
    oMaster: IContainerDataSet<Tmaster>;
    oDetail: IContainerDataSet<Tdetail>;
    oClient: IContainerDataSet<Tclient>;
    oLookup: IContainerDataSet<Tlookup>;
  public
    { Public declarations }
  end;

var
  Form3: TForm3;

implementation

uses
  StrUtils;

{$R *.dfm}

procedure TForm3.Button2Click(Sender: TObject);
begin
  oMaster.ApplyUpdates(0);
end;

procedure TForm3.Button3Click(Sender: TObject);
begin
  oMaster.Open;
end;

procedure TForm3.Button4Click(Sender: TObject);
begin
  oMaster.Close;
end;

procedure TForm3.FormCreate(Sender: TObject);
begin
  /// <summary>
  /// Variaveis declaradas em { Private declarations } acima.
  /// </summary>

  // Inst�ncia da class de conex�o via FireDAC
  oConn := TFactoryDBExpress.Create(SQLConnection1, dnSQLite);

  /// Class Adapter
  /// Par�metros: (IDBConnection, TClientDataSet)
  /// 10 representa a quantidadede registros por pacote de retorno para um select muito grande,
  /// defina o quanto achar melhor para sua necessiade
  oMaster := TContainerClientDataSet<Tmaster>.Create(oConn, Master, 10);

  /// Relacionamento Master-Detail
  oDetail := TContainerClientDataSet<Tdetail>.Create(oConn, Detail, oMaster.MasterObject);

  /// Relacionamento 1:1
  oClient := TContainerClientDataSet<Tclient>.Create(oConn, Client, oMaster.MasterObject);

  /// Lookup lista de registro (DBLookupComboBox)
  oLookup := TContainerClientDataSet<Tlookup>.Create(oConn, Lookup);

  /// Campo LookupField pode ser usado em um DBLookupComboBox, ou DBGrid
  oDetail.AddLookupField('fieldname',
                         'lookup_id',
                         oLookup.MasterObject,
                         'lookup_id',
                         'lookup_description');
  oMaster.Open;
  /// Outras formas para fazer um open, se precisar
//  oMaster.DataSet.Open(10);
end;

end.
