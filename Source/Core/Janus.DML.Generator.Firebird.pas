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

initialization
  TDriverRegister.RegisterDriver(dnFirebird,
    function: IDMLGeneratorCommand
    begin
      Result := TDMLGeneratorFirebird.Create;
    end);

end.