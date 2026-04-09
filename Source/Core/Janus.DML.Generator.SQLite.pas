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
}

unit Janus.DML.Generator.SQLite;

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
  DataEngine.FactoryInterfaces,
  MetaDbDiff.mapping.popular,
  MetaDbDiff.mapping.classes,
  MetaDbDiff.mapping.explorer;

type
  // Classe de conex�o concreta com dbExpress
  TDMLGeneratorSQLite = class(TDMLGeneratorAbstract)
  protected
    function GetGeneratorSelect(const ASQL: String; const AOrderBy: String = ''): String; override;
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

{ TDMLGeneratorSQLite }

constructor TDMLGeneratorSQLite.Create;
begin
  inherited;
  ConfigureFluentSQLDriver(dnSQLite);
  FDateFormat := 'yyyy-MM-dd';
  FTimeFormat := 'HH:MM:SS';
end;

destructor TDMLGeneratorSQLite.Destroy;
begin
  inherited;
end;

function TDMLGeneratorSQLite.GeneratorSelectAll(AClass: TClass;
  APageSize: Integer; AID: TValue): String;
var
  LSQL: IFluentSQL;
  LTable: TTableMapping;
  LKey: string;
begin
  LKey := AClass.ClassName + '-SELECT';
  if APageSize > -1 then
    LKey := LKey + '-PAGINATE';
  if not FQueryCache.TryGetValue(LKey, Result) then
  begin
    LSQL := _BuildSelectSQL(AClass, AID);
    Result := LSQL.AsString;
    FQueryCache.AddOrSetValue(LKey, Result);
  end;
  LTable := TMappingExplorer.GetMappingTable(AClass);
  // Where
  Result := Result + GetGeneratorWhere(AClass, LTable.Name, AID);
  // OrderBy
  Result := Result + GetGeneratorOrderBy(AClass, LTable.Name, AID);
  // Monta SQL para pagina��o
  if APageSize > -1 then
    Result := Result + GetGeneratorSelect(Result);
end;

function TDMLGeneratorSQLite.GeneratorSelectWhere(AClass: TClass;
  AWhere: String; AOrderBy: String; APageSize: Integer): String;
var
  LSQL: IFluentSQL;
  LScopeWhere: String;
  LScopeOrderBy: String;
  LKey: string;
begin
  LKey := AClass.ClassName + '-SELECT';
  if APageSize > -1 then
    LKey := LKey + '-PAGINATE';
  if not FQueryCache.TryGetValue(LKey, Result) then
  begin
    LSQL := _BuildSelectSQL(AClass, '-1');
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
  // Scope Where OrderBy
  LScopeOrderBy := GetGeneratorQueryScopeOrderBy(AClass);
  if LScopeOrderBy <> '' then
    Result := Result + ' ORDER BY ' + LScopeOrderBy;
  if Length(AOrderBy) > 0 then
  begin
    Result := Result + IfThen(LScopeOrderBy = '', ' ORDER BY ', ', ');
    Result := Result + AOrderBy;
  end;
  // Monta SQL para pagina��o
  if APageSize > -1 then
    Result := Result + GetGeneratorSelect(Result);
end;

function TDMLGeneratorSQLite.GetGeneratorSelect(const ASQL: String;
  const AOrderBy: String): String;
begin
  Result := ' LIMIT %s OFFSET %s';
end;

function TDMLGeneratorSQLite.GeneratorAutoIncCurrentValue(AObject: TObject;
  AAutoInc: TDMLCommandAutoInc): Int64;
var
  LSQL: String;
begin
  Result := ExecuteSequence(Format('SELECT SEQ AS SEQUENCE FROM SQLITE_SEQUENCE ' +
                                   'WHERE NAME = ''%s''', [AAutoInc.Sequence.Name]));
  if Result = 0 then
  begin
    LSQL := Format('INSERT INTO SQLITE_SEQUENCE (NAME, SEQ) VALUES (''%s'', 0)',
                   [AAutoInc.Sequence.Name]);
    FConnection.ExecuteDirect(LSQL);
  end;
end;

function TDMLGeneratorSQLite.GeneratorAutoIncNextValue(AObject: TObject;
  AAutoInc: TDMLCommandAutoInc): Int64;
var
  LSQL: String;
begin
  Result := GeneratorAutoIncCurrentValue(AObject, AAutoInc);
  LSQL := Format('UPDATE SQLITE_SEQUENCE SET SEQ = SEQ + %s WHERE NAME = ''%s''',
                 [IntToStr(AAutoInc.Sequence.Increment), AAutoInc.Sequence.Name]);
  FConnection.ExecuteDirect(LSQL);
  Result := Result + AAutoInc.Sequence.Increment;
end;

initialization
  TDriverRegister.RegisterDriver(TDBEngineDriver.dnSQLite,
    function: IDMLGeneratorCommand
    begin
      Result := TDMLGeneratorSQLite.Create;
    end);

end.
