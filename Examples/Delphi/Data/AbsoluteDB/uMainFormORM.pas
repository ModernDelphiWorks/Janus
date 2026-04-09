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
  MidasLib,
  /// orm interface de conex�o
  Janus.Factory.Interfaces,
  Janus.Factory.AbsoluteDB,
  Janus.DML.Generator.AbsoluteDB,
  /// orm injection dependency
  Janus.Container.DataSet.Interfaces,
  Janus.Container.ClientDataSet,
  /// modelos usados
  Janus.Model.Master,
  Janus.Model.Detail,
  Janus.Model.Lookup,
  Janus.Model.Client,
  /// Zeos
  ABSMain;

type
  TForm3 = class(TForm)
    DataSource1: TDataSource;
    DBGrid1: TDBGrid;
    DBNavigator1: TDBNavigator;
    Button2: TButton;
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
    DBEdit7: TDBEdit;
    Label8: TLabel;
    CDSDetail: TClientDataSet;
    CDSClient: TClientDataSet;
    CDSLookup: TClientDataSet;
    Button1: TButton;
    CDSMaster: TClientDataSet;
    ABSDatabase1: TABSDatabase;
    Button3: TButton;
    procedure FormCreate(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
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

{$R *.dfm}

uses Janus.Form.Monitor;

procedure TForm3.Button1Click(Sender: TObject);
var
  LMasterCurrent: Tmaster;
begin
  LMasterCurrent := oMaster.Current;
  LMasterCurrent.description := 'Object Update Master';
  oMaster.Save(LMasterCurrent);
end;

procedure TForm3.Button2Click(Sender: TObject);
begin
  oMaster.ApplyUpdates(0);
end;

procedure TForm3.Button3Click(Sender: TObject);
begin
  TCommandMonitor.GetInstance.Show;
end;

procedure TForm3.FormCreate(Sender: TObject);
begin
  // Inst�ncia da class de conex�o via FireDAC
  oConn := TFactoryAbsoluteDB.Create(ABSDatabase1, dnAbsoluteDB);
  oConn.SetCommandMonitor(TCommandMonitor.GetInstance);

  oMaster := TContainerClientDataSet<Tmaster>.Create(oConn, CDSMaster, 10);
  oDetail := TContainerClientDataSet<Tdetail>.Create(oConn, CDSDetail, oMaster.This);
  oClient := TContainerClientDataSet<Tclient>.Create(oConn, CDSClient, oMaster.This);
  oLookup := TContainerClientDataSet<Tlookup>.Create(oConn, CDSLookup);
  oDetail.AddLookupField('fieldname',
                         'lookup_id',
                         oLookup.This,
                         'lookup_id',
                         'lookup_description',
                         'Descri��o Lookup');
  oMaster.Open;
  /// Outras formas para fazer um open, se precisar
///  oMaster.DataSet.Open(10);
///  oMaster.DataSet.Open('select * from Master order by description');
end;

end.

