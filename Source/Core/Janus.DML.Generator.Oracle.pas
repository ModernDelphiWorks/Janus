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
  @author(Isaque Pinheiro <isaquesp@gmail.com>)
  @author(Skype : ispinheiro)
}

unit Janus.DML.Generator.Oracle;

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
  // Classe de conex�o concreta com dbExpress
  TDMLGeneratorOracle = class(TDMLGeneratorAbstract)
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
    function GeneratorPageNext(const ACommandSelect: String;
      APageSize: Integer; APageNext: Integer): String; override;
  end;

implementation

const
  SELECTROW = 'SELECT * FROM ( ' + sLineBreak +
              '   SELECT T.*, ROWNUM AS ROWINI FROM (%s) T';

{ TDMLGeneratorOracle }

constructor TDMLGeneratorOracle.Create;
begin
  inherited;
  FDateFormat := 'yyyy-MM-dd';
  FTimeFormat := 'HH:MM:SS';
end;

destructor TDMLGeneratorOracle.Destroy;
begin
  inherited;
end;

function TDMLGeneratorOracle.GeneratorPageNext(const ACommandSelect: String;
  APageSize: Integer; APageNext: Integer): String;
begin
  if APageSize > -1 then
    Result := Format(ACommandSelect, [IntToStr(APageNext + APageSize), IntToStr(APageNext)])
  else
    Result := ACommandSelect;
end;

function TDMLGeneratorOracle.GeneratorSelectAll(AClass: TClass;
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
  if APageSize > -1 then
    Result := Format(SELECTROW, [Result]);
  LTable := TMappingExplorer.GetMappingTable(AClass);
  // Where
  Result := Result + GetGeneratorWhere(AClass, LTable.Name, AID);
  // OrderBy
  Result := Result + GetGeneratorOrderBy(AClass, LTable.Name, AID);
  // Monta SQL para pagina��o
  if APageSize > -1 then
    Result := Result + sLineBreak + GetGeneratorSelect(Result);
end;

function TDMLGeneratorOracle.GeneratorSelectWhere(AClass: TClass; AWhere: String;
  AOrderBy: String; APageSize: Integer): String;
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
    if APageSize > -1 then
      Result := Format(SELECTROW, [Result]);
    FQueryCache.AddOrSetValue(LKey, Result);
  end;
  // Scope Where
  LScopeWhere := GetGeneratorQueryScopeWhere(AClass);
  if LScopeWhere <> '' then
    Result := ' WHERE ' + LScopeWhere;
  if Length(AWhere) > 0 then
  begin
    Result := Result + IfThen(LScopeWhere = '', ' WHERE ', ' AND ');
    Result := Result + AWhere;
  end;
  // Scope OrderBy
  LScopeOrderBy := GetGeneratorQueryScopeOrderBy(AClass);
  if LScopeOrderBy <> '' then
    Result := ' ORDER BY ' + LScopeOrderBy;
  if Length(AOrderBy) > 0 then
  begin
    Result := Result + IfThen(LScopeOrderBy = '', ' ORDER BY ', ', ');
    Result := Result + AOrderBy;
  end;
  if APageSize > -1 then
     Result := Result + sLineBreak + GetGeneratorSelect(Result);
end;

function TDMLGeneratorOracle.GetGeneratorSelect(const ASQL: String;
  const AOrderBy: String): String;
begin
  Result := '   WHERE ROWNUM <= %s) ' + sLineBreak +
            'WHERE ROWINI > %s';
end;

function TDMLGeneratorOracle.GeneratorAutoIncCurrentValue(AObject: TObject;
  AAutoInc: TDMLCommandAutoInc): Int64;
begin
  Result := ExecuteSequence(Format('SELECT %s.CURRVAL FROM DUAL',
                                   [AAutoInc.Sequence.Name]));
end;

function TDMLGeneratorOracle.GeneratorAutoIncNextValue(AObject: TObject;
  AAutoInc: TDMLCommandAutoInc): Int64;
begin
  Result := ExecuteSequence(Format('SELECT %s.NEXTVAL FROM DUAL',
                                   [AAutoInc.Sequence.Name]));
end;

initialization
  TDriverRegister.RegisterDriver(dnOracle,
    function: IDMLGeneratorCommand
    begin
      Result := TDMLGeneratorOracle.Create;
    end);

end.

