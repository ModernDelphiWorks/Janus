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

initialization
  TDriverRegister.RegisterDriver(dnMSSQL,
    function: IDMLGeneratorCommand
    begin
      Result := TDMLGeneratorMSSql.Create;
    end);

end.