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
  SysUtils,
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
  // Surface a precise error instead of letting a nil factory AV downstream.
  // The historical failure was "offset 0x121421 Read of address 00000008"
  // deep in TDictionary — opaque and nearly undiagnosable. If GetDriver
  // ever hands back nil (e.g., a factory that returned nil without
  // raising), we now fail here with an actionable message.
  if not Assigned(FGeneratorCommand) then
    raise Exception.Create(
      'Janus: o gerador DML para o driver solicitado retornou nil. ' +
      'Verifique se a unit "Janus.DML.Generator.<driver>.pas" est� na ' +
      'cl�usula uses do seu projeto.');
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
