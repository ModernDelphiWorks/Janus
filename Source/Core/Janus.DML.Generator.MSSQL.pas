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

unit Janus.DML.Generator.MSSQL;

interface

uses
  Classes,
  SysUtils,
  StrUtils,
  Variants,
  Rtti,
  Janus.DML.Generator,
  MetaDbDiff.Mapping.Classes,
  MetaDbDiff.Mapping.Explorer,
  DataEngine.FactoryInterfaces,
  Janus.Driver.Register,
  Janus.DML.Interfaces,
  Janus.DML.Commands,
  Janus.DML.Cache,
  FluentSQL,
  FluentSQL.Interfaces;

type
  // Classe de conexao concreta com dbExpress
  TDMLGeneratorMSSql = class(TDMLGeneratorAbstract)
  protected
    /// <summary> Issue #355. The only generator whose right answer and the
    ///  enum's zero value are the same value - which is exactly why the defect
    ///  went unnoticed: the dialect the other generators fell into by accident
    ///  is this one's by right. Declared anyway, because "it happened to be
    ///  correct" is not a wiring. </summary>
    class function SerializationDialect: TFluentSQLDriver; override;
    /// Ver TDMLGeneratorAbstract.GuidLiteral: abstract de proposito,
    /// para que um dialeto novo nao herde em silencio o literal de outro.
    function GuidLiteral(const AGuid: TGUID): String; override;
  public
    constructor Create; override;
    destructor Destroy; override;
    function GeneratorSelectAll(AClass: TClass; APageSize: Integer;
      AID: TValue): String; override;
    function GeneratorSelectWhere(AClass: TClass; AWhere: String;
      AOrderBy: String; APageSize: Integer): String; override;
    function GeneratorAutoIncCurrentValue(AObject: TObject;
      AAutoInc: TDMLCommandAutoInc): Int64; override;
    function GeneratorAutoIncNextValue(AObject: TObject;
      AAutoInc: TDMLCommandAutoInc): Int64; override;
    function GeneratorPageNext(const ACommandSelect: String;
      APageSize, APageNext: Integer): String; override;
  end;

implementation

{ TDMLGeneratorMSSql }

class function TDMLGeneratorMSSql.SerializationDialect: TFluentSQLDriver;
begin
  Result := dbnMSSQL;
end;

constructor TDMLGeneratorMSSql.Create;
begin
  inherited;
  FDateFormat := 'dd/MM/yyyy';
  FTimeFormat := 'HH:MM:SS';
end;

destructor TDMLGeneratorMSSql.Destroy;
begin
  inherited;
end;

function TDMLGeneratorMSSql.GeneratorPageNext(const ACommandSelect: String;
  APageSize, APageNext: Integer): String;
begin
  if APageSize > -1 then
    Result := Format(ACommandSelect, [IntToStr(APageNext + APageSize), IntToStr(APageNext)])
  else
    Result := ACommandSelect;
end;

function TDMLGeneratorMSSql.GeneratorSelectAll(AClass: TClass;
  APageSize: Integer; AID: TValue): String;
const
  cSQL = 'SELECT * FROM (%s) AS %s WHERE %s';
  cCOLUMN = 'ROW_NUMBER() OVER(%s) AS ROWNUMBER';
var
  LSQL: IFluentSQL;
  LTable: TTableMapping;
  LOrderBy: string;
  LKey: string;
  LColumn: String;
  LWhere: String;
begin
  LTable := TMappingExplorer.GetMappingTable(AClass);
  LOrderBy := GetGeneratorOrderBy(AClass, LTable.Name, AID);
  LKey := AClass.ClassName + '-SELECT';
  if APageSize > -1 then
    LKey := LKey + '-PAGINATE';
  if not FQueryCache.TryGetValue(LKey, Result) then
  begin
    LSQL := _BuildSelectSQL(AClass, AID);
    if APageSize > -1 then
    begin
      if LOrderBy <> '' then
      begin
        if LOrderBy.Contains('ORDER BY') then
          LColumn := Format(cCOLUMN, [LOrderBy])
        else
          LColumn := Format(cCOLUMN, ['ORDER BY ' + LOrderBy])
      end
      else
        LColumn := Format(cCOLUMN, ['ORDER BY CURRENT_TIMESTAMP']);
      LWhere := '(ROWNUMBER <= %s) AND (ROWNUMBER > %s)';
      LSQL.Column(LColumn);
      Result := Format(cSQL, [LSQL.AsString, LTable.Name, LWhere]);
    end
    else
      Result := LSQL.AsString;
    FQueryCache.AddOrSetValue(LKey, Result);
  end;
  // Where
  Result := Result + GetGeneratorWhere(AClass, LTable.Name, AID);
  // OrderBy
  Result := Result + LOrderBy;
end;

function TDMLGeneratorMSSql.GeneratorSelectWhere(AClass: TClass; AWhere: String;
  AOrderBy: String; APageSize: Integer): String;
const
  cSQL = 'SELECT * FROM (%s) AS %s WHERE %s';
  cCOLUMN = 'ROW_NUMBER() OVER(%s) AS ROWNUMBER';
var
  LSQL: IFluentSQL;
  LTable: TTableMapping;
  LScopeWhere: String;
  LScopeOrderBy: String;
  LKey: string;
  LColumn: String;
  LWhere: String;
begin
  LTable := TMappingExplorer.GetMappingTable(AClass);
  LKey := AClass.ClassName + '-SELECT';
  if APageSize > -1 then
    LKey := LKey + '-PAGINATE';
  if not FQueryCache.TryGetValue(LKey, Result) then
  begin
    LSQL := _BuildSelectSQL(AClass, '-1');
    if APageSize > -1 then
    begin
      if AOrderBy <> '' then
      begin
        if AOrderBy.Contains('ORDER BY') then
          LColumn := Format(cCOLUMN, [AOrderBy])
        else
          LColumn := Format(cCOLUMN, ['ORDER BY ' + AOrderBy])
      end
      else
        LColumn := Format(cCOLUMN, ['ORDER BY CURRENT_TIMESTAMP']);
      LWhere := '(ROWNUMBER <= %s) AND (ROWNUMBER > %s)';
      LSQL.Column(LColumn);
      Result := Format(cSQL, [LSQL.AsString, LTable.Name, LWhere]);
    end
    else
      Result := LSQL.AsString;
    FQueryCache.AddOrSetValue(LKey, Result);
  end;
  // Scope Where
  LScopeWhere := GetGeneratorQueryScopeWhere(AClass);
  if LScopeWhere <> '' then
    Result := Result + ' WHERE ' + LScopeWhere;
  if Length(AWhere) > 0 then
  begin
    Result := Result + IfThen(LScopeWhere = '', ' WHERE ', ' AND ');
    Result := Result + AWhere;
  end;
  // Scope OrderBy
  LScopeOrderBy := GetGeneratorQueryScopeOrderBy(AClass);
  if LScopeOrderBy <> '' then
    Result := Result + ' ORDER BY ' + LScopeOrderBy;
  if Length(AOrderBy) > 0 then
  begin
    Result := Result + IfThen(LScopeOrderBy = '', ' ORDER BY ', ', ');
    Result := Result + AOrderBy;
  end;
end;

function TDMLGeneratorMSSql.GeneratorAutoIncCurrentValue(AObject: TObject;
  AAutoInc: TDMLCommandAutoInc): Int64;
begin
  Result := ExecuteSequence(Format('SELECT CURRENT_VALUE FROM SYS.SEQUENCES WHERE NAME = ''%s''',
                                   [AAutoInc.Sequence.Name]) );
end;

function TDMLGeneratorMSSql.GeneratorAutoIncNextValue(AObject: TObject;
  AAutoInc: TDMLCommandAutoInc): Int64;
begin
  Result := ExecuteSequence(Format('SELECT NEXT VALUE FOR %s ',
                                   [AAutoInc.Sequence.Name]));
end;

/// <summary> O SQL Server TEM tipo nativo `uniqueidentifier`, mas O DDL DESTA
///  CASA NAO O CRIA: dnMSSQL cai no `else` de
///  MetaDbDiff.Metadata.Extract.pas:445, que emite 'GUID'. A comparacao aqui
///  e' texto contra texto e a forma canonica e' a que casa.
///  DUAS ARMADILHAS DOCUMENTADAS, que so' mordem se a coluna FOR mesmo
///  `uniqueidentifier` num schema alheio:
///    * string com mais de 36 caracteres e' TRUNCADA EM SILENCIO na conversao
///      para uniqueidentifier, sem erro
///      (https://learn.microsoft.com/en-us/sql/t-sql/data-types/uniqueidentifier-transact-sql)
///      - e a forma canonica tem 38.
///    * as chaves nao tem aceitacao documentada; a unica mencao oficial diz
///      que a operacao FALHA
///      (https://learn.microsoft.com/en-us/sql/relational-databases/sqlxml-annotated-xsd-schemas-using/data-type-coercions-and-the-sql-datatype-annotation-sqlxml-4-0).
///  NAO MEDIDO: se CAST('{...}' AS uniqueidentifier) aceita chaves em T-SQL
///  puro, e se a caixa dos hex e' irrelevante na comparacao. Enquanto o DDL
///  da casa nao criar o tipo nativo, nenhuma das duas muda o literal. </summary>
function TDMLGeneratorMSSql.GuidLiteral(const AGuid: TGUID): String;
begin
  Result := CanonicalGuidLiteral(AGuid);
end;

initialization
  TDriverRegister.RegisterDriver(dnMSSQL,
    function: IDMLGeneratorCommand
    begin
      Result := TDMLGeneratorMSSql.Create;
    end);

end.