unit Client.Forms.Main;

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
  /// Janus Modelos
  Janus.Model.Master,
  Janus.Model.Detail,
  Janus.Model.Lookup,
  Janus.Model.Client,
  /// Janus Manager
  Janus.Manager.DataSet,
  Janus.Client.Base,
  Janus.Client,
  Janus.Client.DMVC,
  Janus.Client.Methods,

  FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf,
  FireDAC.DApt.Intf, FireDAC.Comp.DataSet, FireDAC.Comp.Client;

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
    FDMaster: TFDMemTable;
    FDDetail: TFDMemTable;
    FDClient: TFDMemTable;
    FDLookup: TFDMemTable;
    Label8: TLabel;
    DBEdit7: TDBEdit;
    Button1: TButton;
    DBImage1: TDBImage;
    Memo1: TMemo;
    RESTClientDelphiMVC1: TRESTClientDelphiMVC;
    procedure FormCreate(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
    oManager: TManagerDataSet;
  public
    { Public declarations }
  end;

var
  Form3: TForm3;

implementation

uses
  StrUtils,
  Generics.Collections,
  Janus.Form.Monitor,
  Janus.Json;

{$R *.dfm}

procedure TForm3.Button1Click(Sender: TObject);
var
  LCurrent: Tmaster;
begin
  LCurrent := oManager.Current<Tmaster>;
  LCurrent.description := 'Object Update Master';
  oManager.Save<Tmaster>(LCurrent);
end;

procedure TForm3.Button2Click(Sender: TObject);
begin
  oManager.ApplyUpdates<Tmaster>(0);
end;

procedure TForm3.FormCreate(Sender: TObject);
var
  LMaster: TMaster;
  LMasterList: TObjectList<TMaster>;
begin
  RESTClientDelphiMVC1.AsConnection.SetCommandMonitor(TCommandMonitor.GetInstance);

  oManager := TManagerDataSet.Create(RESTClientDelphiMVC1.AsConnection);
  oManager.AddAdapter<Tmaster>(FDMaster, 2);
  oManager.AddAdapter<Tdetail, Tmaster>(FDDetail);
  oManager.AddAdapter<Tclient, Tmaster>(FDClient);
  oManager.AddAdapter<Tlookup>(FDLookup);
  oManager.AddLookupField<Tdetail, Tlookup>('fieldname',
                                            'lookup_id',
                                            'lookup_id',
                                            'lookup_description',
                                            'Descri��o Lookup');
  oManager.Open<Tmaster>;
//  oManager.OpenWhere<Tmaster>('master_id=22');


  /// <summary>
  ///   Neste exemplo eu trago a lista para a VAR LMasterList, e passo a ser repons�vel por ela.
  /// </summary>
  oManager.OwnerNestedList := False;
  LMasterList := oManager.Find<Tmaster>;
  try
    if LMasterList.Count > 0 then
    begin
      for LMaster in LMasterList do
      begin
        if LMaster <> nil then
          Memo1.Lines.Add(TJanusJson.ObjectToJsonString(LMaster));
      end;
    end;
  finally
    LMasterList.Free;
  end;


  /// <summary>
  ///   Neste exemplo o Janus preenche a lista interna dele e ele tem o controle de libera-la.
  /// </summary>

//  oManager.OwnerNestedList := True; // Valor j� � Padr�o
//  oManager.Find<Tmaster>;
//  if oManager.NestedList<Tmaster>.Count > 0 then
//  begin
//    oManager.NestedList<Tmaster>.First;
//    for LMaster in oManager.NestedList<Tmaster> do
//    begin
//      if LMaster <> nil then
//        Memo1.Lines.Add(TJanusJson.ObjectToJsonString(LMaster));
//    end;
//  end;
end;

procedure TForm3.FormDestroy(Sender: TObject);
begin
  oManager.Free;
end;

end.

