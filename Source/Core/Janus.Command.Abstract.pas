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

{
  @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
}

unit Janus.Command.Abstract;

interface

uses
  DB,
  Rtti,
  DataEngine.FactoryInterfaces,
  Janus.Driver.Register,
  Janus.DML.Interfaces;

type
  TDMLCommandAbstract = class abstract
  protected
    FConnection: IDBConnection;
    FGeneratorCommand: IDMLGeneratorCommand;
    FParams: TParams;
    FResultCommand: String;
  public
    constructor Create(AConnection: IDBConnection; ADriverName: TDBEngineDriver;
      AObject: TObject); virtual;
    destructor Destroy; override;
    function GetDMLCommand: String;
    function Params: TParams;
  end;

implementation

{ TDMLCommandAbstract }

constructor TDMLCommandAbstract.Create(AConnection: IDBConnection;
  ADriverName: TDBEngineDriver; AObject: TObject);
begin
  // Driver de conexao
  FConnection := AConnection;
  // Driver do banco de dados
  FGeneratorCommand := TDriverRegister.GetDriver(ADriverName);
  FGeneratorCommand.SetConnection(AConnection);
  // Lista de parametros
  FParams := TParams.Create;
end;

destructor TDMLCommandAbstract.Destroy;
begin
  FParams.Clear;
  FParams.Free;
  inherited;
end;

function TDMLCommandAbstract.GetDMLCommand: String;
begin
  Result := FResultCommand;
end;

function TDMLCommandAbstract.Params: TParams;
begin
  Result := FParams;
end;

end.
