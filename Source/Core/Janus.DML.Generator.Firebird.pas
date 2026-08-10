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
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Janus.DML.Generator.Firebird;

interface

uses
  Classes,
  SysUtils,
  StrUtils,
  Variants,
  Rtti,
  Janus.DML.Generator,
  Janus.Driver.Register,
  Janus.DML.Interfaces,
  Janus.DML.Commands,
  Janus.DML.Cache,
  FluentSQL,
  FluentSQL.Interfaces,
  MetaDbDiff.Mapping.Classes,
  MetaDbDiff.Mapping.Explorer,
  DataEngine.FactoryInterfaces;

type
  // Classe de banco de dados Firebird
  TDMLGeneratorFirebird = class(TDMLGeneratorAbstract)
  protected
    /// Ver TDMLGeneratorAbstract.GuidLiteral: abstract de proposito,
    /// para que um dialeto novo nao herde em silencio o literal de outro.
    function GuidLiteral(const AGuid: TGUID): String; override;
  public
    constructor Create; override;
    destructor Destroy; override;
    function GeneratorSelectAll(AClass: TClass;
      APageSize: Integer; AID: TValue): String; override;
    function GeneratorSelectWhere(AClass: TClass; AWhere: String;
      AOrderBy: String; APageSize: Integer): String; override;
    function GeneratorAutoIncCurrentValue(AObject: TObject;
      AAutoInc: TDMLCommandAutoInc): Int64; override;
    function GeneratorAutoIncNextValue(AObject: TObject;
      AAutoInc: TDMLCommandAutoInc): Int64; override;
  end;

implementation

{ TDMLGeneratorFirebird }

constructor TDMLGeneratorFirebird.Create;
begin
  inherited;
  ConfigureFluentSQLDriver(dnFirebird);
  FDateFormat := 'MM/dd/yyyy';
  FTimeFormat := 'HH:MM:SS';
end;

destructor TDMLGeneratorFirebird.Destroy;
begin
  inherited;
end;

function TDMLGeneratorFirebird.GeneratorSelectAll(AClass: TClass;
  APageSize: Integer; AID: TValue): String;
const
  SELECT_CLAUSE = 'SELECT ';
var
  LSQL: IFluentSQL;
  LPreviousDriver: TFluentSQLDriver;
  LTable: TTableMapping;
  LKey: string;
  LPos: Integer;
begin
  LKey := AClass.ClassName + '-SELECT';
  if APageSize > -1 then
    LKey := LKey + '-PAGINATE';
  if not FQueryCache.TryGetValue(LKey, Result) then
  begin
    LPreviousDriver := FFluentSQLDriver;
    FFluentSQLDriver := dbnSQLite;
    try
      LSQL := _BuildSelectSQL(AClass, AID);
    finally
      FFluentSQLDriver := LPreviousDriver;
    end;
    Result := LSQL.AsString;
    if APageSize > -1 then
    begin
      LPos := Pos(SELECT_CLAUSE, UpperCase(Result));
      if LPos > 0 then
        Insert('FIRST %s SKIP %s ', Result, LPos + Length(SELECT_CLAUSE));
    end;
    FQueryCache.AddOrSetValue(LKey, Result);
  end;
  LTable := TMappingExplorer.GetMappingTable(AClass);
  Result := Result + GetGeneratorWhere(AClass, LTable.Name, AID);
  Result := Result + GetGeneratorOrderBy(AClass, LTable.Name, AID);
end;

function TDMLGeneratorFirebird.GeneratorSelectWhere(AClass: TClass;
  AWhere: String; AOrderBy: String; APageSize: Integer): String;
const
  SELECT_CLAUSE = 'SELECT ';
var
  LSQL: IFluentSQL;
  LPreviousDriver: TFluentSQLDriver;
  LScopeWhere: String;
  LScopeOrderBy: String;
  LKey: string;
  LPos: Integer;
begin
  LKey := AClass.ClassName + '-SELECT';
  if APageSize > -1 then
    LKey := LKey + '-PAGINATE';
  if not FQueryCache.TryGetValue(LKey, Result) then
  begin
    LPreviousDriver := FFluentSQLDriver;
    FFluentSQLDriver := dbnSQLite;
    try
      LSQL := _BuildSelectSQL(AClass, '-1');
    finally
      FFluentSQLDriver := LPreviousDriver;
    end;
    Result := LSQL.AsString;
    if APageSize > -1 then
    begin
      LPos := Pos(SELECT_CLAUSE, UpperCase(Result));
      if LPos > 0 then
        Insert('FIRST %s SKIP %s ', Result, LPos + Length(SELECT_CLAUSE));
    end;
    FQueryCache.AddOrSetValue(LKey, Result);
  end;
  LScopeWhere := GetGeneratorQueryScopeWhere(AClass);
  if LScopeWhere <> '' then
    Result := Result + ' WHERE ' + LScopeWhere;
  if Length(AWhere) > 0 then
  begin
    Result := Result + IfThen(LScopeWhere = '', ' WHERE ', ' AND ');
    Result := Result + AWhere;
  end;
  LScopeOrderBy := GetGeneratorQueryScopeOrderBy(AClass);
  if LScopeOrderBy <> '' then
    Result := Result + ' ORDER BY ' + LScopeOrderBy;
  if Length(AOrderBy) > 0 then
  begin
    Result := Result + IfThen(LScopeOrderBy = '', ' ORDER BY ', ', ');
    Result := Result + AOrderBy;
  end;
end;

function TDMLGeneratorFirebird.GeneratorAutoIncCurrentValue(AObject: TObject;
  AAutoInc: TDMLCommandAutoInc): Int64;
begin
  Result := ExecuteSequence(Format('SELECT GEN_ID(%s, 0) FROM RDB$DATABASE;',
                                   [AAutoInc.Sequence.Name]));
end;

function TDMLGeneratorFirebird.GeneratorAutoIncNextValue(AObject: TObject;
  AAutoInc: TDMLCommandAutoInc): Int64;
begin
  Result := ExecuteSequence(Format('SELECT GEN_ID(%s, %s) FROM RDB$DATABASE;',
                                   [AAutoInc.Sequence.Name,
                           IntToStr(AAutoInc.Sequence.Increment)]));
end;

/// <summary> O Firebird NAO TEM tipo GUID/UUID - a Language Reference nao o
///  lista; o que existe sao funcoes: GEN_UUID() devolve CHAR(16) CHARACTER SET
///  OCTETS, UUID_TO_CHAR() devolve CHAR(36) MAIUSCULO com hifen e SEM chaves
///  (https://www.firebirdsql.org/refdocs/langrefupd25-intfunc-uuid_to_char.html),
///  e CHAR_TO_UUID() aceita hex em caixa mista.
///  O DDL desta casa emite CHAR(n) para dnFirebird
///  (MetaDbDiff.Metadata.Extract.pas:432) e guarda o texto de 38 que o INSERT
///  gravou - texto contra texto, sensivel a caixa, forma canonica.
///  DUAS RESSALVAS MEDIDAS:
///    * com IOptions.StoreGUIDAsOctet ligada, o DDL vira CHAR(n) CHARACTER SET
///      OCTETS de 16 bytes (MetaDbDiff.Metadata.Extract.pas:509-526) e a
///      comparacao passaria a exigir CHAR_TO_UUID('36 com hifen') ou x'32hex'.
///      NAO implementado: e' outro eixo, mede-se contra banco vivo.
///    * ESTE METODO E' INALCANCAVEL NO SELECT HOJE. Janus.Command.Selecter.pas
///      :70-71 troca dnFirebird/dnFirebird3 por dnSQLite, entao o SELECT do
///      Firebird roda o gerador do SQLite. A unidade tem de estar certa de
///      qualquer forma; desfazer a troca muda a geracao de TODO SELECT em
///      Firebird e nao cabe nesta issue. </summary>
function TDMLGeneratorFirebird.GuidLiteral(const AGuid: TGUID): String;
begin
  Result := CanonicalGuidLiteral(AGuid);
end;

initialization
  TDriverRegister.RegisterDriver(dnFirebird,
    function: IDMLGeneratorCommand
    begin
      Result := TDMLGeneratorFirebird.Create;
    end);

end.