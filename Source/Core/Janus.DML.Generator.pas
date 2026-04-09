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
  @abstract(Janus Framework)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @abstract(Website : http://www.Janus.com.br)
}

{$INCLUDE ..\Janus.inc}

unit Janus.DML.Generator;

interface

uses
  DB,
  Rtti,
  SysUtils,
  Classes,
  StrUtils,
  Variants,
  TypInfo,
  Generics.Collections,
  // Janus
   FluentSQL,
   FluentSQL.Interfaces,
  Janus.DML.Interfaces,
  Janus.DML.Commands,
  Janus.DML.Cache,
  Janus.Types.Blob,
  Janus.Register.Middleware,
  DataEngine.FactoryInterfaces,
  MetaDbDiff.RTTI.Helper,
  MetaDbDiff.Mapping.Popular,
  MetaDbDiff.Mapping.Classes,
  MetaDbDiff.Mapping.Explorer,
  MetaDbDiff.Types.Mapping;

type
  // Classe de conex�es abstract
  TDMLGeneratorAbstract = class abstract(TInterfacedObject, IDMLGeneratorCommand)
  private
    function _GetPropertyValue(AObject: TObject; AProperty: TRttiProperty;
      AFieldType: TFieldType): Variant;
      procedure _GenerateJoinColumn(AClass: TClass; ATable: TTableMapping;
        const ASQL: IFluentSQL);
    function _IsType(const AID: TValue): Boolean;
  protected
    FConnection: IDBConnection;
    FQueryCache: TQueryCache;
    FDateFormat: String;
    FTimeFormat: String;
      FFluentSQLDriver: TFluentSQLDriver;
      class function ResolveFluentSQLDriver(
        const AGeneratorDriver: TDBEngineDriver): TFluentSQLDriver; static;
      procedure ConfigureFluentSQLDriver(const AGeneratorDriver: TDBEngineDriver);
      function CreateFluentSQL: IFluentSQL;
      function _BuildSelectSQL(AClass: TClass; AID: TValue): IFluentSQL; virtual;
      function GetGeneratorSelect(const ASQL: String;
        const AOrderBy: String = ''): String; virtual;
    function GetGeneratorWhere(const AClass: TClass; const ATableName: String;
      const AID: TValue): String;
    function GetGeneratorOrderBy(const AClass: TClass; const ATableName: String;
      const AID: TValue): String;
    function GetGeneratorQueryScopeWhere(const AClass: TClass): String;
    function GetGeneratorQueryScopeOrderBy(const AClass: TClass): String;
    function ExecuteSequence(const ASQL: String): Int64; virtual;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure SetConnection(const AConnaction: IDBConnection); virtual;
    function GeneratorSelectAll(AClass: TClass; APageSize: Integer;
      AID: TValue): String; virtual; abstract;
    function GeneratorSelectWhere(AClass: TClass; AWhere: String;
      AOrderBy: String; APageSize: Integer): String; virtual; abstract;
    function GenerateSelectOneToOne(AOwner: TObject; AClass: TClass;
      AAssociation: TAssociationMapping): String; virtual;
    function GenerateSelectOneToOneMany(AOwner: TObject; AClass: TClass;
      AAssociation: TAssociationMapping): String; virtual;
    function GeneratorUpdate(AObject: TObject; AParams: TParams;
      AModifiedFields: TDictionary<String, String>): String; virtual;
    function GeneratorInsert(AObject: TObject): String; virtual;
    function GeneratorDelete(AObject: TObject;
      AParams: TParams): String; virtual;
    function GeneratorAutoIncCurrentValue(AObject: TObject;
      AAutoInc: TDMLCommandAutoInc): Int64; virtual; abstract;
    function GeneratorAutoIncNextValue(AObject: TObject;
      AAutoInc: TDMLCommandAutoInc): Int64; virtual; abstract;
    function GeneratorPageNext(const ACommandSelect: String;
      APageSize, APageNext: Integer): String; virtual;
  end;

implementation

{ TDMLGeneratorAbstract }

constructor TDMLGeneratorAbstract.Create;
begin
  FQueryCache := TQueryCache.Create;
end;

destructor TDMLGeneratorAbstract.Destroy;
begin
  FQueryCache.Free;
  inherited;
end;

function TDMLGeneratorAbstract.ExecuteSequence(const ASQL: String): Int64;
var
  LDBResultSet: IDBDataSet;
begin
  Result := 0;
  LDBResultSet := FConnection.CreateDataSet(ASQL);
  try
    if LDBResultSet.RecordCount > 0 then
      Result := VarAsType(LDBResultSet.Fields[0].Value, varInt64);
  finally
    LDBResultSet.Close;
  end;
end;

function TDMLGeneratorAbstract.GenerateSelectOneToOne(AOwner: TObject;
  AClass: TClass; AAssociation: TAssociationMapping): String;

  function GetValue(AIndex: Integer): Variant;
  var
    LColumn: TColumnMapping;
    LColumns: TColumnMappingList;
  begin
    Result := Null;
    LColumns := TMappingExplorer.GetMappingColumn(AOwner.ClassType);
    for LColumn in LColumns do
      if LColumn.ColumnName = AAssociation.ColumnsName[AIndex] then
        Exit(_GetPropertyValue(AOwner, LColumn.ColumnProperty, LColumn.FieldType));
  end;

var
  LSQL: IFluentSQL;
  LTable: TTableMapping;
  LOrderBy: TOrderByMapping;
  LOrderByList: TStringList;
  LFor: Integer;
begin
  if not FQueryCache.TryGetValue(AClass.ClassName, Result) then
  begin
    LSQL := _BuildSelectSQL(AClass, '-1');
    Result := LSQL.AsString;
    FQueryCache.AddOrSetValue(AClass.ClassName, Result);
  end;
  LTable := TMappingExplorer.GetMappingTable(AClass);
  // Association Multi-Columns
  for LFor := 0 to AAssociation.ColumnsNameRef.Count -1 do
  begin
    Result := Result + ' WHERE '
                     + LTable.Name + '.' + AAssociation.ColumnsNameRef[LFor]
                     + ' = ' + GetValue(LFor);
  end;
  // OrderBy
  LOrderBy := TMappingExplorer.GetMappingOrderBy(AClass);
  if LOrderBy <> nil then
  begin
    Result := Result + ' ORDER BY ';
    LOrderByList := TStringList.Create;
    try
      LOrderByList.Duplicates := dupError;
      ExtractStrings([',', ';'], [' '], PChar(LOrderBy.ColumnsName), LOrderByList);
      for LFor := 0 to LOrderByList.Count -1 do
      begin
        Result := Result + LTable.Name + '.' + LOrderByList[LFor];
        if LFor < LOrderByList.Count -1 then
          Result := Result + ', ';
      end;
    finally
      LOrderByList.Free;
    end;
  end;
end;

function TDMLGeneratorAbstract.GenerateSelectOneToOneMany(AOwner: TObject;
  AClass: TClass; AAssociation: TAssociationMapping): String;

  function GetValue(Aindex: Integer): Variant;
  var
    LColumn: TColumnMapping;
    LColumns: TColumnMappingList;
  begin
    Result := Null;
    LColumns := TMappingExplorer.GetMappingColumn(AOwner.ClassType);
    for LColumn in LColumns do
      if LColumn.ColumnName = AAssociation.ColumnsName[Aindex] then
        Exit(_GetPropertyValue(AOwner, LColumn.ColumnProperty, LColumn.FieldType));
  end;

var
  LSQL: IFluentSQL;
  LTable: TTableMapping;
  LOrderBy: TOrderByMapping;
  LOrderByList: TStringList;
  LFor: Integer;
begin
  if not FQueryCache.TryGetValue(AClass.ClassName, Result) then
  begin
    LSQL := _BuildSelectSQL(AClass, '-1');
    Result := LSQL.AsString;
    FQueryCache.AddOrSetValue(AClass.ClassName, Result);
  end;
  LTable := TMappingExplorer.GetMappingTable(AClass);
  // Association Multi-Columns
  for LFor := 0 to AAssociation.ColumnsNameRef.Count -1 do
  begin
    Result := Result + ifThen(LFor = 0, ' WHERE ', ' AND ');
    Result := Result + LTable.Name
                     + '.' + AAssociation.ColumnsNameRef[LFor]
                     + ' = ' + GetValue(LFor)
  end;
  // OrderBy
  LOrderBy := TMappingExplorer.GetMappingOrderBy(AClass);
  if LOrderBy <> nil then
  begin
    Result := Result + ' ORDER BY ';
    LOrderByList := TStringList.Create;
    try
      LOrderByList.Duplicates := dupError;
      ExtractStrings([',', ';'], [' '], PChar(LOrderBy.ColumnsName), LOrderByList);
      for LFor := 0 to LOrderByList.Count -1 do
      begin
        Result := Result + LTable.Name + '.' + LOrderByList[LFor];
        if LFor < LOrderByList.Count -1 then
          Result := Result + ', ';
      end;
    finally
      LOrderByList.Free;
    end;
  end;
end;

function TDMLGeneratorAbstract.GeneratorDelete(AObject: TObject;
  AParams: TParams): String;
var
  LFor: Integer;
  LTable: TTableMapping;
  LSQL: IFluentSQL;
begin
  Result := '';
  LTable := TMappingExplorer.GetMappingTable(AObject.ClassType);
  LSQL := CreateFluentSQL.Delete;
  LSQL.From(LTable.Name);
  /// <exception cref="LTable.Name + '.'"></exception>
  for LFor := 0 to AParams.Count -1 do
    LSQL.Where(AParams.Items[LFor].Name + ' = :' +
               AParams.Items[LFor].Name);
  Result := LSQL.AsString;
end;

function TDMLGeneratorAbstract.GeneratorInsert(AObject: TObject): String;
var
  LTable: TTableMapping;
  LColumn: TColumnMapping;
  LColumns: TColumnMappingList;
  LSQL: IFluentSQL;
  LKey: String;
begin
  Result := '';
  try
    LKey := AObject.ClassType.ClassName + '-INSERT';
    if FQueryCache.TryGetValue(LKey, Result) then
      Exit;
    LTable := TMappingExplorer.GetMappingTable(AObject.ClassType);
    LColumns := TMappingExplorer.GetMappingColumn(AObject.ClassType);
    LSQL := CreateFluentSQL.Insert.Into(LTable.Name);
    for LColumn in LColumns do
    begin
      try
        if not Assigned(LColumn.ColumnProperty) then
          Continue;
        if LColumn.ColumnProperty.IsNullValue(AObject) then
          Continue;
        if (LColumn.FieldType in [ftBlob, ftGraphic, ftOraBlob, ftOraClob]) and
           (Length(LColumn.ColumnProperty.GetNullableValue(AObject).AsType<TBlob>.ToBytes) = 0) then
          Continue;
        if LColumn.IsNoInsert then
          Continue;
        LSQL.Values(LColumn.ColumnName, [':' + LColumn.ColumnName]);
      except
        on E: Exception do
          raise Exception.CreateFmt(
            'DIAG GeneratorInsert column=%s class=%s msg=%s',
            [LColumn.ColumnName, AObject.ClassName, E.Message]);
      end;
    end;
    Result := LSQL.AsString;
    FQueryCache.AddOrSetValue(LKey, Result);
  except
    on E: Exception do
      raise Exception.CreateFmt('DIAG GeneratorInsert class=%s msg=%s',
        [AObject.ClassName, E.Message]);
  end;
end;

function TDMLGeneratorAbstract.GeneratorPageNext(const ACommandSelect: String;
  APageSize, APageNext: Integer): String;
begin
  if APageSize > -1 then
    Result := Format(ACommandSelect, [IntToStr(APageSize), IntToStr(APageNext)])
  else
    Result := ACommandSelect;
end;

function TDMLGeneratorAbstract.GetGeneratorOrderBy(const AClass: TClass;
  const ATableName: String; const AID: TValue): String;
var
  LOrderBy: TOrderByMapping;
  LOrderByList: TStringList;
  LFor: Integer;
  LScopeOrderBy: String;
begin
  try
    Result := '';
    LScopeOrderBy := GetGeneratorQueryScopeOrderBy(AClass);
    if LScopeOrderBy <> '' then
      Result := ' ORDER BY ' + LScopeOrderBy;
    LOrderBy := TMappingExplorer.GetMappingOrderBy(AClass);
    if LOrderBy = nil then
      Exit;
    Result := Result + IfThen(LScopeOrderBy = '', ' ORDER BY ', ', ');
    LOrderByList := TStringList.Create;
    try
      LOrderByList.Duplicates := dupError;
      ExtractStrings([',', ';'], [' '], PChar(LOrderBy.ColumnsName), LOrderByList);
      for LFor := 0 to LOrderByList.Count -1 do
      begin
        Result := Result + ATableName + '.' + LOrderByList[LFor];
        if LFor < LOrderByList.Count -1 then
          Result := Result + ', ';
      end;
    finally
      LOrderByList.Free;
    end;
  except
    on E: Exception do
      raise Exception.CreateFmt(
        'DIAG GetGeneratorOrderBy class=%s table=%s scope=%s msg=%s',
        [AClass.ClassName, ATableName, LScopeOrderBy, E.Message]);
  end;
end;

function TDMLGeneratorAbstract.GetGeneratorQueryScopeOrderBy(const AClass: TClass): String;
var
  LFor: Integer;
  LFuncs: TQueryScopeList;
  LFunc: TFunc<String>;
begin
  Result := '';
  LFor := 0;
  LFuncs := TJanusMiddlewares.ExecuteQueryScopeCallback(AClass, 'GetOrderBy');
  if LFuncs = nil then
    Exit;

  for LFunc in LFuncs.Values do
  begin
    Result := Result + LFunc();
    if LFor < LFuncs.Count -1 then
      Result := Result + ', ';
    Inc(LFor);
  end;
end;

function TDMLGeneratorAbstract.GetGeneratorQueryScopeWhere(const AClass: TClass): String;
var
  LFor: Integer;
  LFuncs: TQueryScopeList;
  LFunc: TFunc<String>;
begin
  Result := '';
  LFor := 0;
  LFuncs := TJanusMiddlewares.ExecuteQueryScopeCallback(AClass, 'GetWhere');
  if LFuncs = nil then
    Exit;
  for LFunc in LFuncs.Values do
  begin
    Result := Result + LFunc();
    if LFor < LFuncs.Count -1 then
      Result := Result + ' AND ';
    Inc(LFor);
  end;
end;

function TDMLGeneratorAbstract.GetGeneratorSelect(const ASQL: String;
  const AOrderBy: String): String;
begin
  Result := '';
end;

function TDMLGeneratorAbstract.GetGeneratorWhere(const AClass: TClass;
  const ATableName: String; const AID: TValue): String;
var
  LPrimaryKey: TPrimaryKeyMapping;
  LColumnName: String;
  LFor: Integer;
  LScopeWhere: String;
begin
  Result := '';
  LScopeWhere := GetGeneratorQueryScopeWhere(AClass);
  if LScopeWhere <> '' then
    Result := ' WHERE ' + LScopeWhere;
  if _IsType(AID) then
    Exit;
  LPrimaryKey := TMappingExplorer.GetMappingPrimaryKey(AClass);
  if LPrimaryKey <> nil then
  begin
    Result := Result + IfThen(LScopeWhere = '', ' WHERE ', ' AND ');
    for LFor := 0 to LPrimaryKey.Columns.Count -1 do
    begin
      if LFor > 0 then
       Continue;
      LColumnName := ATableName + '.' + LPrimaryKey.Columns[LFor];
      if (AID.IsType<Integer>) or (AID.IsType<Int64>) or (AID.IsType<UInt64>) then
        Result := Result + LColumnName + ' = ' + AID.ToString
      else
        Result := Result + LColumnName + ' = ' + QuotedStr(AID.ToString);
    end;
  end;
end;

function TDMLGeneratorAbstract._IsType(const AID: TValue): Boolean;
var
  LIntValue: Int64;
begin
  Result := False;
  if AID.IsType<UInt64> then
  begin
    if AID.TryAsType<Int64>(LIntValue) and (LIntValue = -1)  then
      Result := True;
    Exit;
  end;
  if AID.IsType<Int64> then
  begin
    if AID.AsInt64 = -1 then
      Result := True;
    Exit;
  end;
  if AID.IsType<Integer> then
  begin
    if AID.AsInteger = -1 then
      Result := True;
    Exit;
  end;
  if AID.IsType<String> then
    if AID.AsString = '-1' then
      Result := True;
end;

function TDMLGeneratorAbstract._BuildSelectSQL(AClass: TClass;
  AID: TValue): IFluentSQL;
var
  LTable: TTableMapping;
  LColumns: TColumnMappingList;
  LColumn: TColumnMapping;
begin
  try
    LTable := TMappingExplorer.GetMappingTable(AClass);
    Result := CreateFluentSQL.Select.From(LTable.Name);
    LColumns := TMappingExplorer.GetMappingColumn(AClass);
    for LColumn in LColumns do
    begin
      if LColumn.IsVirtualData then
        Continue;
      if LColumn.IsJoinColumn then
        Continue;
      Result.Column(LTable.Name + '.' + LColumn.ColumnName);
    end;
    _GenerateJoinColumn(AClass, LTable, Result);
  except
    on E: Exception do
      raise Exception.CreateFmt('DIAG _BuildSelectSQL class=%s msg=%s',
        [AClass.ClassName, E.Message]);
  end;
end;

function TDMLGeneratorAbstract._GetPropertyValue(AObject: TObject;
  AProperty: TRttiProperty; AFieldType: TFieldType): Variant;
begin
  case AFieldType of
     ftString, ftWideString, ftMemo, ftWideMemo, ftFmtMemo:
        Result := QuotedStr(VarToStr(AProperty.GetNullableValue(AObject).AsVariant));
     ftLargeint:
        Result := VarToStr(AProperty.GetNullableValue(AObject).AsVariant);
     ftInteger, ftWord, ftSmallint:
        Result := VarToStr(AProperty.GetNullableValue(AObject).AsVariant);
     ftVariant:
        Result := VarToStr(AProperty.GetNullableValue(AObject).AsVariant);
     ftDateTime, ftDate:
        Result := QuotedStr(FormatDateTime(FDateFormat,
                             VarToDateTime(AProperty.GetNullableValue(AObject).AsVariant)));
     ftTime, ftTimeStamp, ftOraTimeStamp:
        Result := QuotedStr(FormatDateTime(FTimeFormat,
                             VarToDateTime(AProperty.GetNullableValue(AObject).AsVariant)));
     ftCurrency, ftBCD, ftFMTBcd:
       begin
         Result := VarToStr(AProperty.GetNullableValue(AObject).AsVariant);
         Result := ReplaceStr(Result, ',', '.');
       end;
     ftFloat:
       begin
         Result := VarToStr(AProperty.GetNullableValue(AObject).AsVariant);
         Result := ReplaceStr(Result, ',', '.');
       end;
     ftBlob, ftGraphic, ftOraBlob, ftOraClob:
       Result := AProperty.GetNullableValue(AObject).AsType<TBlob>.ToBytes;
  else
     Result := '';
  end;
end;

procedure TDMLGeneratorAbstract.SetConnection(const AConnaction: IDBConnection);
begin
  FConnection := AConnaction;
end;

procedure TDMLGeneratorAbstract._GenerateJoinColumn(AClass: TClass;
  ATable: TTableMapping; const ASQL: IFluentSQL);
var
  LJoinList: TJoinColumnMappingList;
  LJoin: TJoinColumnMapping;
  LJoinExist: TList<String>;
begin
  LJoinExist := TList<String>.Create;
  try
    LJoinList := TMappingExplorer.GetMappingJoinColumn(AClass);
    if LJoinList = nil then
      Exit;

    for LJoin in LJoinList do
    begin
      try
        if Length(LJoin.AliasColumn) > 0 then
          ASQL.Column(LJoin.AliasRefTable + '.'
                    + LJoin.RefColumnNameSelect).Alias(LJoin.AliasColumn)
        else
          ASQL.Column(LJoin.AliasRefTable + '.'
                    + LJoin.RefColumnNameSelect);
      except
        on E: Exception do
          raise Exception.CreateFmt(
            'DIAG _GenerateJoinColumn select-column join=%s ref=%s alias=%s msg=%s',
            [LJoin.ColumnName, LJoin.RefTableName, LJoin.AliasRefTable, E.Message]);
      end;
    end;
    for LJoin in LJoinList do
    begin
      try
        if LJoinExist.IndexOf(LJoin.AliasRefTable) > -1 then
          Continue;
        LJoinExist.Add(LJoin.RefTableName);
        case LJoin.Join of
          TJoin.InnerJoin:
            ASQL.InnerJoin(LJoin.RefTableName, LJoin.AliasRefTable)
                .OnCond(LJoin.AliasRefTable + '.' + LJoin.RefColumnName
                      + ' = ' + ATable.Name + '.' + LJoin.ColumnName);
          TJoin.LeftJoin:
            ASQL.LeftJoin(LJoin.RefTableName, LJoin.AliasRefTable)
                .OnCond(LJoin.AliasRefTable + '.' + LJoin.RefColumnName
                      + ' = ' + ATable.Name + '.' + LJoin.ColumnName);
          TJoin.RightJoin:
            ASQL.RightJoin(LJoin.RefTableName, LJoin.AliasRefTable)
                .OnCond(LJoin.AliasRefTable + '.' + LJoin.RefColumnName
                      + ' = ' + ATable.Name + '.' + LJoin.ColumnName);
          TJoin.FullJoin:
            ASQL.FullJoin(LJoin.RefTableName, LJoin.AliasRefTable)
                .OnCond(LJoin.AliasRefTable + '.' + LJoin.RefColumnName
                      + ' = ' + ATable.Name + '.' + LJoin.ColumnName);
        end;
      except
        on E: Exception do
          raise Exception.CreateFmt(
            'DIAG _GenerateJoinColumn join=%s ref=%s alias=%s msg=%s',
            [LJoin.ColumnName, LJoin.RefTableName, LJoin.AliasRefTable, E.Message]);
      end;
    end;
  finally
    LJoinExist.Free;
  end;
end;

function TDMLGeneratorAbstract.GeneratorUpdate(AObject: TObject;
  AParams: TParams; AModifiedFields: TDictionary<String, String>): String;
var
  LFor: Integer;
  LTable: TTableMapping;
  LSQL: IFluentSQL;
  LColumnName: String;
begin
  Result := '';
  if AModifiedFields.Count = 0 then
    Exit;
  // Varre a lista de campos alterados para montar o UPDATE
  LTable := TMappingExplorer.GetMappingTable(AObject.ClassType);
  LSQL := CreateFluentSQL.Update(LTable.Name);
  for LColumnName in AModifiedFields.Values do
  begin
    // SET Field=Value alterado
    // <exception cref="oTable.Name + '.'"></exception>
    LSQL.SetValue(LColumnName, [':' + LColumnName]);
  end;
  for LFor := 0 to AParams.Count -1 do
    LSQL.Where(AParams.Items[LFor].Name + ' = :' + AParams.Items[LFor].Name);
  Result := LSQL.AsString;
end;

class function TDMLGeneratorAbstract.ResolveFluentSQLDriver(
  const AGeneratorDriver: TDBEngineDriver): TFluentSQLDriver;
begin
  case AGeneratorDriver of
    dnADS:
      Result := dbnADS;
    dnAbsoluteDB:
      Result := dbnAbsoluteDB;
    dnElevateDB:
      Result := dbnElevateDB;
    dnFirebird,
    dnFirebird3:
      Result := dbnFirebird;
    dnInterbase:
      Result := dbnInterbase;
    dnMSSQL:
      Result := dbnMSSQL;
    dnMySQL:
      Result := dbnMySQL;
    dnNexusDB:
      Result := dbnNexusDB;
    dnOracle:
      Result := dbnOracle;
    dnPostgreSQL:
      Result := dbnPostgreSQL;
    dnSQLite:
      Result := dbnSQLite;
  else
    raise Exception.CreateFmt('FluentSQL driver mapping not found for generator [%s].',
      [GetEnumName(TypeInfo(TDBEngineDriver), Ord(AGeneratorDriver))]);
  end;
end;

procedure TDMLGeneratorAbstract.ConfigureFluentSQLDriver(
  const AGeneratorDriver: TDBEngineDriver);
begin
  FFluentSQLDriver := ResolveFluentSQLDriver(AGeneratorDriver);
end;

function TDMLGeneratorAbstract.CreateFluentSQL: IFluentSQL;
begin
  Result := TCQ(FFluentSQLDriver);
end;

end.
