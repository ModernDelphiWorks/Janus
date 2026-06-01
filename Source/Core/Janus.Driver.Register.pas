{
  ------------------------------------------------------------------------------
  Janus ORM
  State-of-the-art Object-Relational Mapping (ORM) framework for Delphi.

  SPDX-License-Identifier: MIT
  Copyright (c) 2025-2026 Isaque Pinheiro

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

unit Janus.Driver.Register;

interface

uses
  SysUtils,
  Generics.Collections,
  Janus.DML.Interfaces,
  DataEngine.FactoryInterfaces;

type
  TDMLGeneratorFactory = reference to function: IDMLGeneratorCommand;

  TDriverRegister = class
  strict private
    class var FDriver: TDictionary<TDBEngineDriver, TDMLGeneratorFactory>;
  private
    class constructor Create;
    class destructor Destroy;
  public
    class procedure RegisterDriver(const ADriverName: TDBEngineDriver;
      const ADriverFactory: TDMLGeneratorFactory);
    class function GetDriver(const ADriverName: TDBEngineDriver): IDMLGeneratorCommand;
  end;

implementation

class constructor TDriverRegister.Create;
begin
  FDriver := TDictionary<TDBEngineDriver, TDMLGeneratorFactory>.Create;
end;

class destructor TDriverRegister.Destroy;
begin
  FDriver.Clear;
  FDriver.Free;
  inherited;
end;

class function TDriverRegister.GetDriver(const ADriverName: TDBEngineDriver): IDMLGeneratorCommand;
var
  LFactory: TDMLGeneratorFactory;
begin
  if not FDriver.ContainsKey(ADriverName) then
    raise Exception
            .Create('O driver ' + TStrDBEngineDriver[ADriverName] + ' n�o est� registrado, adicione a unit "Janus.DML.Generator.???.pas" onde ??? nome do driver, na cl�usula USES do seu projeto!');

  LFactory := FDriver[ADriverName];
  Result := LFactory();
end;

class procedure TDriverRegister.RegisterDriver(const ADriverName: TDBEngineDriver;
  const ADriverFactory: TDMLGeneratorFactory);
begin
  FDriver.AddOrSetValue(ADriverName, ADriverFactory);
end;

end.

