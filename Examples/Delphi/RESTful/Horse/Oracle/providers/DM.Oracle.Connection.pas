unit DM.Oracle.Connection;

interface

uses
  System.SysUtils,
  System.Classes,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Def,
  FireDAC.Phys,
  FireDAC.Phys.Oracle,
  FireDAC.Phys.OracleDef,
  FireDAC.ConsoleUI.Wait;

type
  TOracleProviderDM = class(TDataModule)
  public
    FDConnection1: TFDConnection;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

constructor TOracleProviderDM.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDConnection1 := TFDConnection.Create(nil);
  FDConnection1.Params.DriverID := 'Ora';
  FDConnection1.Params.Values['Server'] := 'localhost';
  FDConnection1.Params.Values['Port'] := '1521';
  FDConnection1.Params.Values['Database'] := 'XE';
  FDConnection1.Params.Values['User_Name'] := 'LOCAL';
  FDConnection1.Params.Values['Password'] := 'local';
  FDConnection1.Connected := True;
end;

destructor TOracleProviderDM.Destroy;
begin
  FDConnection1.Connected := False;
  FreeAndNil(FDConnection1);
  inherited;
end;

end.
