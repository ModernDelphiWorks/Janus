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

unit Janus.DML.Generator.MongoDB;

interface

uses
  DB,
  Classes,
  Generics.Collections,
  Janus.DML.Generator.NoSQL,
  MetaDbDiff.Mapping.Classes,
  DataEngine.FactoryInterfaces,
  Janus.Driver.Register,
  Janus.DML.Interfaces,
  Janus.DML.Commands;

type
  // Classe de conex�o concreta com NoSQL
  TDMLGeneratorMongoDB = class(TDMLGeneratorNoSQL)
  protected
  public
    constructor Create; override;
    destructor Destroy; override;
  end;

implementation

{ TDMLGeneratorMongoDB }

constructor TDMLGeneratorMongoDB.Create;
begin
  inherited;
  FDateFormat := 'yyyy-mm-dd';
  FTimeFormat := 'HH:MM:SS';
end;

destructor TDMLGeneratorMongoDB.Destroy;
begin

  inherited;
end;

initialization
  TDriverRegister.RegisterDriver(dnMongoDB,
    function: IDMLGeneratorCommand
    begin
      Result := TDMLGeneratorMongoDB.Create;
    end);

end.
