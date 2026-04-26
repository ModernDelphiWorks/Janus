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

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
}

unit Janus.DML.Generator.InterBase;

interface

uses
  SysUtils,
  StrUtils,
  Rtti,
  Janus.DML.Generator.Firebird,
  Janus.Driver.Register,
  Janus.DML.Interfaces,
  DataEngine.FactoryInterfaces,
  FluentSQL;

type
  // Classe de banco de dados Interbase
  TDMLGeneratorInterbase = class(TDMLGeneratorFirebird)
  protected
  public
    constructor Create; override;
    destructor Destroy; override;
  end;

implementation

{ TDMLGeneratorInterbase }

constructor TDMLGeneratorInterbase.Create;
begin
  inherited;
  FDateFormat := 'MM/dd/yyyy';
  FTimeFormat := 'HH:MM:SS';
end;

destructor TDMLGeneratorInterbase.Destroy;
begin

  inherited;
end;

initialization
  TDriverRegister.RegisterDriver(dnInterbase,
    function: IDMLGeneratorCommand
    begin
      Result := TDMLGeneratorInterbase.Create;
    end);

end.
