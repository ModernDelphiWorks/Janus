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
  /// orm factory
  Janus.Types.Database,
  Janus.Factory.Interfaces,
  Janus.Factory.UniDAC,
  Janus.Container.ClientDataSet,
  Janus.Container.DataSet.Interfaces,
  /// orm model
  Janus.Model.Master,
  Janus.Model.Detail,
  Janus.Model.Lookup,
  Janus.Model.Client,
  EncdDecd,
  /// UniDAC
  Uni, DBAccess, UniProvider, SQLiteUniProvider;

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
    Button5: TButton;
    DBImage1: TDBImage;
    Button6: TButton;
    UniConnection: TUniConnection;
    SQLiteUniProvider1: TSQLiteUniProvider;
    procedure FormCreate(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
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
  Janus.Form.Monitor,
  TypInfo;

{$R *.dfm}

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

procedure TForm3.Button5Click(Sender: TObject);
begin
  TCommandMonitor.GetInstance.Show;
end;

procedure TForm3.Button6Click(Sender: TObject);
var
  LMaster: Tmaster;
begin
  LMaster := oMaster.Current;
  if LMaster.MyEnum = fmsEmitente then
    ShowMessage(oMaster.DataSet.FieldByName('MyEnum').AsString + ' - 0=fmsEmitente')
  else
  if LMaster.MyEnum = fmsTerceiros then
    ShowMessage(oMaster.DataSet.FieldByName('MyEnum').AsString + ' - 1=fmsTerceiros')
  else
  if LMaster.MyEnum = fmsDestinatario then
    ShowMessage(oMaster.DataSet.FieldByName('MyEnum').AsString + ' - 2=fmsDestinatario')
  else
  if LMaster.MyEnum = fmsSemFrete then
    ShowMessage(oMaster.DataSet.FieldByName('MyEnum').AsString + ' - 9=fmsSemFrete');

  LMaster.MyEnum := fmsSemFrete;
  oMaster.Save(LMaster);
end;

procedure TForm3.FormCreate(Sender: TObject);
begin
  // Inst�ncia da class de conex�o via FireDAC
  oConn := TFactoryUniDAC.Create(UniConnection, dnSQLite);
  oConn.SetCommandMonitor(TCommandMonitor.GetInstance);

  /// Class Adapter
  /// Par�metros: (IDBConnection, TClientDataSet)
  /// 10 representa a quantidadede registros por pacote de retorno para um select muito grande,
  /// defina o quanto achar melhor para sua necessiade
  oMaster := TContainerClientDataSet<Tmaster>.Create(oConn, CDSMaster, 3);

  /// Relacionamento Master-Detail 1:N
  oDetail := TContainerClientDataSet<Tdetail>.Create(oConn, CDSDetail, oMaster.This);

  /// Relacionamento 1:1
  oClient := TContainerClientDataSet<Tclient>.Create(oConn, CDSClient, oMaster.This);

  /// Lookup lista de registro (DBLookupComboBox)
  oLookup := TContainerClientDataSet<Tlookup>.Create(oConn, CDSLookup);

  /// Campo LookupField pode ser usado em um DBLookupComboBox, ou DBGrid
  oDetail.AddLookupField('fieldname',
                         'lookup_id',
                         oLookup.This,
                         'lookup_id',
                         'lookup_description');
  oMaster.Open;
end;

end.

