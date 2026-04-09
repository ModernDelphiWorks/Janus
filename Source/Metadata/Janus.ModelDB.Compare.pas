{
      ORM Brasil � um ORM simples e descomplicado para quem utiliza Delphi

                   Copyright (c) 2016, Isaque Pinheiro
                          All rights reserved.

                    GNU Lesser General Public License
                      Vers�o 3, 29 de junho de 2007

       Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
       A todos � permitido copiar e distribuir c�pias deste documento de
       licen�a, mas mud�-lo n�o � permitido.

       Esta vers�o da GNU Lesser General Public License incorpora
       os termos e condi��es da vers�o 3 da GNU General Public License
       Licen�a, complementado pelas permiss�es adicionais listadas no
       arquivo LICENSE na pasta principal.
}

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)

  ORM Brasil � um ORM simples e descomplicado para quem utiliza Delphi.
}

unit Janus.ModelDB.Compare;

interface

uses
  SysUtils,
  Janus.Metadata.Classe.Factory,
  DataEngine.FactoryInterfaces,
  MetaDbDiff.metadata.db.factory,
  MetaDbDiff.database.factory;

type
  TModelDbCompare = class(TDatabaseFactory)
  protected
    FConnMaster: IDBConnection;
    FMetadataMaster: TMetadataClasseAbstract;
    FMetadataTarget: TMetadataDBAbstract;
    procedure ExtractDatabase; override;
    procedure ExecuteDDLCommands; override;
  public
    constructor Create(AConnTarget: IDBConnection); overload;
    destructor Destroy; override;
  end;

implementation

uses
  MetaDbDiff.ddl.commands;

{ TModelDbCompare }

constructor TModelDbCompare.Create(AConnTarget: IDBConnection);
begin
  FConnMaster := AConnTarget;
  FConnMaster.Connect;
  if not FConnMaster.IsConnected then
    raise Exception.Create('N�o foi possivel fazer conex�o com o banco de dados Target');

  inherited Create(AConnTarget.GetDriver);
  FModelForDatabase := True;
  // Metadata do Model
  FMetadataMaster := TMetadataClasseFactory.Create(Self);
  FMetadataMaster.ModelMetadata.Connection := AConnTarget;
  // Metadata do Database
  FMetadataTarget := TMetadataDBFactory.Create(Self, FConnMaster);
end;

destructor TModelDbCompare.Destroy;
begin
  FMetadataTarget.Free;
  FMetadataMaster.Free;
  inherited;
end;

procedure TModelDbCompare.ExecuteDDLCommands;
var
  oCommand: TDDLCommand;
  sCommand: String;
begin
  inherited;
  if FCommandsAutoExecute then
    FConnMaster.StartTransaction;
  try
    for oCommand in FDDLCommands do
    begin
      sCommand := oCommand.BuildCommand(FGeneratorCommand);
      if Length(sCommand) > 0 then
        if FCommandsAutoExecute then
          FConnMaster.ExecuteScript(sCommand);
    end;
    if FConnMaster.InTransaction then
      FConnMaster.Commit;
  except
    on E: Exception do
    begin
      if FConnMaster.InTransaction then
        FConnMaster.Rollback;
      raise Exception.Create('Janus Command : [' + oCommand.Warning + '] - ' + E.Message + sLineBreak +
                             'Script : "' + sCommand + '"');
    end;
  end;
end;

procedure TModelDbCompare.ExtractDatabase;
begin
  inherited;
  // Extrai todo metadata com base nos modelos existentes
  FMetadataMaster.ExtractMetadata(FCatalogMaster);
  // Extrai todo metadata com base banco de dados acessado
  FMetadataTarget.ExtractMetadata(FCatalogTarget);
end;

end.
