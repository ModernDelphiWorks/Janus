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

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
}

unit Janus.DML.Generator.Firebird3;

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
  TDMLGeneratorFirebird3 = class(TDMLGeneratorFirebird)
  protected
    /// Ver TDMLGeneratorAbstract.GuidLiteral: abstract de proposito,
    /// para que um dialeto novo nao herde em silencio o literal de outro.
    function GuidLiteral(const AGuid: TGUID): String; override;
  public
    constructor Create; override;
    destructor Destroy; override;
  end;

implementation

{ TDMLGeneratorInterbase }

constructor TDMLGeneratorFirebird3.Create;
begin
  inherited;
  FDateFormat := 'MM/dd/yyyy';
  FTimeFormat := 'HH:MM:SS';
end;

destructor TDMLGeneratorFirebird3.Destroy;
begin

  inherited;
end;

/// <summary> Declarado explicitamente, e nao herdado de TDMLGeneratorFirebird,
///  para que uma mudanca no literal do Firebird 2.5 nao mova o Firebird 3 em
///  silencio. O conteudo e' o mesmo e ISSO FOI MEDIDO: as funcoes de UUID
///  (GEN_UUID/UUID_TO_CHAR/CHAR_TO_UUID) e a ausencia de tipo nativo valem
///  igualmente na Language Reference de 4.0 e 5.0
///  (https://firebirdsql.org/file/documentation/html/en/refdocs/fblangref50/firebird-50-language-reference.html).
///  Vale aqui a mesma ressalva de inalcancabilidade do irmao:
///  Janus.Command.Selecter.pas:70-71 troca dnFirebird3 por dnSQLite no
///  SELECT. </summary>
function TDMLGeneratorFirebird3.GuidLiteral(const AGuid: TGUID): String;
begin
  Result := CanonicalGuidLiteral(AGuid);
end;

initialization
  TDriverRegister.RegisterDriver(dnFirebird3,
    function: IDMLGeneratorCommand
    begin
      Result := TDMLGeneratorFirebird3.Create;
    end);

end.
