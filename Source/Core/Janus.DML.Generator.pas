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
  // Classe de conexoes abstract
  TDMLGeneratorAbstract = class abstract(TInterfacedObject, IDMLGeneratorCommand)
  private
    function _GetPropertyValue(AObject: TObject; AProperty: TRttiProperty;
      AFieldType: TFieldType): Variant;
      procedure _GenerateJoinColumn(AClass: TClass; ATable: TTableMapping;
        const ASQL: IFluentSQL);
    function _IsType(const AID: TValue): Boolean;
    /// <summary> THE LITERAL OF A DATE, TIME OR TIMESTAMP AID, IN THIS
    ///  DIALECT'S OWN MASK. False when AID is not one of those three, so the
    ///  caller falls through to the arm it always had. Issue #326.
    ///
    ///  IT DISPATCHES ON THE TYPE OF THE VALUE AND NOT ON THE COLUMN'S
    ///  FieldType, and that is what makes the repair additive: only a TValue
    ///  that really holds a TDateTime / TDate / TTime takes this path, so a
    ///  String or an ordinal AID reaches the same code it reached before, byte
    ///  for byte. TDate and TTime are DISTINCT type infos - System declares
    ///  them as `type TDateTime` - so the three have to be named.
    ///
    ///  THE MASK IS FDateFormat / FTimeFormat AND THE SETTINGS ARE
    ///  FFormatSettings, which is not a new decision: _GetPropertyValue has
    ///  formatted every ftDate / ftDateTime column that way since the dialect
    ///  masks existed, and a ftDateTime column takes FDateFormat there too -
    ///  the date only, no time part. Answering differently HERE would put two
    ///  spellings of one date inside one generator. </summary>
    function _DialectDateTimeLiteral(const AID: TValue;
      out ALiteral: String): Boolean;
    function _GetGuidValue(AObject: TObject; AProperty: TRttiProperty): TGUID;
    function _StoreGUIDAsOctet: Boolean;
    procedure _GuardStoreGUIDAsOctet(AProperty: TRttiProperty);
  protected
    FConnection: IDBConnection;
    FQueryCache: TQueryCache;
    FDateFormat: String;
    FTimeFormat: String;
    // O FormatDateTime troca '/' pelo DateSeparator e ':' pelo TimeSeparator da
    // maquina. Como as mascaras dos dialetos usam esses dois caracteres, a
    // sobrecarga que le o FormatSettings GLOBAL fazia o MESMO codigo gerar
    // literais diferentes em maquinas diferentes. Medido com DateSeparator '.'
    // e TimeSeparator '-': 'dd/MM/yyyy' -> '15.03.2027', 'HH:MM:SS' ->
    // '14-07-53'. Este record e passado explicitamente nas duas chamadas de
    // _GetPropertyValue para que a literal nao dependa do locale do cliente.
    //
    // THE SENTENCE THAT USED TO END THIS PARAGRAPH IS NOW OUT OF DATE AND IS
    // REPLACED RATHER THAN DELETED. It said these were "as unicas duas chamadas
    // de FormatDateTime da cadeia de geracao de DML" and pointed at the finding
    // registered in GetGeneratorWhere as a site with the same defect that a
    // TOKEN sweep could not reach. There is now a THIRD call - see
    // _DialectDateTimeLiteral - and that finding is CLOSED (issue #326). Both
    // halves of the old sentence were true when written; the count was the half
    // that rotted, which is why a count is a bad thing to write down.
    FFormatSettings: TFormatSettings;
      FFluentSQLDriver: TFluentSQLDriver;
      class function ResolveFluentSQLDriver(
        const AGeneratorDriver: TDriverName): TFluentSQLDriver; static;
      procedure ConfigureFluentSQLDriver(const AGeneratorDriver: TDriverName);
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

    /// <summary> O LITERAL DE UMA COLUNA ftGuid, NA FORMA DESTE DIALETO.
    ///
    ///  ABSTRACT DE PROPOSITO, e essa e' a decisao de desenho da issue #284.
    ///  O defeito que este metodo conserta E' UM SILENCIO: ftGuid nao tinha
    ///  ramo em _GetPropertyValue, caia no `else`, virava '' e a guarda de
    ///  FK nula de GenerateSelectOneToOne e a de GenerateSelectOneToOneMany -
    ///  ANCORADAS POR METODO, cada uma com a sua propria copia do
    ///  `if VarIsNull(LValue) or VarIsEmpty(LValue) or (VarToStr(LValue) = '')`
    ///  - emitiam '1 = 0': um master COM filhos no banco devolvendo
    ///  NENHUM, sem excecao, sem log e sem SQL malformado.
    ///  AS DUAS ANCORAS ERAM (:265-266) E (:328-329), E FOI ESTA UNIT QUE AS
    ///  QUEBROU: a issue #326 inseriu 97 linhas acima delas e as guardas
    ///  andaram para :289-290 e :352-353. Uma auto-citacao por linha e a mais
    ///  fragil de todas, porque quem cresce o arquivo nao vai procurar por ela.
    ///
    ///  Por que nao um campo FGuidFormat no molde do FDateFormat/FTimeFormat:
    ///  esse molde e' DADO, nao comportamento, e um dialeto novo nasceria com
    ///  o campo em '' - o literal sairia vazio, a guarda dispararia e o
    ///  '1 = 0' VOLTARIA. A cura teria a mesma doenca. Um metodo abstract
    ///  falha CEDO e ALTO: W1020 ("Constructing instance of X containing
    ///  abstract method") na lambda de fabrica do initialization daquela
    ///  unidade, e EAbstractError na primeira chamada - o
    ///  mesmo estilo de Janus.Driver.Register.pas:64-66, que levanta excecao
    ///  nomeada em vez de devolver nil.
    ///
    ///  O CONTRATO DO VALOR E' TGUID, E NAO String. E' o que as tres familias
    ///  de comando ja exigem: Janus.Command.Inserter.pas:213-217,
    ///  Janus.Command.Updater.pas:118-119 e Janus.Command.Deleter.pas:97-98
    ///  fazem AsType<TGUID>.ToString. Os geradores Guid32Inc/Guid36Inc/
    ///  Guid38Inc (Inserter:135-158) escrevem String via SetValue e pertencem
    ///  ao mundo ftString - NAO sao a fonte do formato de uma coluna ftGuid.
    /// </summary>
    function GuidLiteral(const AGuid: TGUID): String; virtual; abstract;

    /// <summary> A FORMA CANONICA - e por que os 12 dialetos SQL convergem.
    ///
    ///  QuotedStr(TGUID.ToString) = '{8-4-4-4-12}': 38 caracteres, chaves,
    ///  hifens, hex MAIUSCULO. E' exatamente o texto que o INSERT desta casa
    ///  grava (Janus.Command.Inserter.pas:213-217 -> TGUID.ToString) e que o
    ///  UPDATE/DELETE usam no WHERE (Updater:118-119, Deleter:97-98).
    ///
    ///  E O DDL DESTA CASA PRETENDE GUARDAR ESSE TEXTO NUMA COLUNA DE TEXTO:
    ///  MetaDbDiff.Metadata.Extract.pas:429-445 escolhe CHAR(%l) para
    ///  PostgreSQL, Firebird, InterBase e MySQL, NCHAR2(%l) para Oracle e
    ///  'GUID' no else - NUNCA `uuid` do PostgreSQL nem `uniqueidentifier` do
    ///  SQL Server. Logo a comparacao e' TEXTO CONTRA TEXTO em todos eles, e a
    ///  forma correta do literal CONVERGE.
    ///
    ///  PRETENDE, e a palavra e' medida: aquelas linhas escrevem o placeholder
    ///  como '%1' (digito um), e quem substitui tamanho e'
    ///  MetaDbDiff.DDL.Generator.pas:484-486, que troca '%l', '%p' e '%s' -
    ///  '%1' nao e' substituido por ninguem, em lugar nenhum do ecossistema.
    ///  Ou seja o DDL que sai hoje para ftGuid carrega o placeholder literal.
    ///  Isso e' defeito de OUTRO repositorio e nao muda nada aqui - a coluna
    ///  continua sendo de texto por intencao, e o literal canonico continua
    ///  sendo o certo -, mas a frase honesta e' "pretende", nao "emite".
    ///
    ///  Isto esta escrito porque e' o que foi MEDIDO, e nao para justificar o
    ///  desenho: a diferenca por dialeto que a doc oficial registra (SQLite
    ///  compara sensivel a caixa via BINARY/memcmp; MySQL CHAR compara
    ///  insensivel no collation padrao utf8mb4_0900_ai_ci; SQL Server trunca
    ///  em silencio acima de 36 caracteres AO CONVERTER PARA uniqueidentifier)
    ///  nao muda a forma do literal enquanto a coluna for a de texto que este
    ///  ecossistema pretende criar - emitir exatamente o texto gravado e' o
    ///  que casa em todos os tres casos.
    ///
    ///  O VALOR DO DESPACHO POR DIALETO, ENTAO, E' O MECANISMO: quando um
    ///  dialeto novo nascer - ou quando o DDL passar a emitir tipo nativo,
    ///  ou quando IOptions.StoreGUIDAsOctet virar o armazenamento em OCTETS
    ///  (Firebird CHAR(16) CHARACTER SET OCTETS, que exige CHAR_TO_UUID(...)
    ///  ou x'...' e NAO string aspada) - o compilador exige que aquele dialeto
    ///  RESPONDA, em vez de herdar em silencio o literal de outro banco.
    ///  O SUPORTE a StoreGUIDAsOctet nao esta implementado: e' outro eixo e
    ///  mede-se contra banco vivo. Mas ele tambem nao passa em silencio - ver
    ///  _GuardStoreGUIDAsOctet, que levanta erro nomeado quando a opcao esta
    ///  ligada, em vez de emitir um literal de texto contra coluna binaria.
    /// </summary>
    function CanonicalGuidLiteral(const AGuid: TGUID): String;
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
  // Invariant traz DateSeparator '/' e TimeSeparator ':', que sao exatamente os
  // caracteres que as mascaras dos dialetos ja pressupoem -- por isso o conserto
  // e invisivel numa maquina de locale padrao e so muda o resultado onde antes
  // ele estava errado.
  FFormatSettings := TFormatSettings.Invariant;
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
  LValue: Variant;
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
    LValue := GetValue(LFor);
    Result := Result + ifThen(LFor = 0, ' WHERE ', ' AND ');
    // Guard de FK nula (associacao OneToOne/ManyToOne opcional): um RHS vazio
    // gerava '... col = ' e estourava o Firebird (-104, fim inesperado de
    // comando). '1 = 0' e SQL valido que casa zero linhas (sem pai/sem dono).
    if VarIsNull(LValue) or VarIsEmpty(LValue) or (VarToStr(LValue) = '') then
      Result := Result + '1 = 0'
    else
      Result := Result + LTable.Name + '.' + AAssociation.ColumnsNameRef[LFor]
                       + ' = ' + VarToStr(LValue);
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
  LValue: Variant;
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
    LValue := GetValue(LFor);
    Result := Result + ifThen(LFor = 0, ' WHERE ', ' AND ');
    // Guard de FK nula (associacao opcional): evita '... col = ' (FB -104).
    if VarIsNull(LValue) or VarIsEmpty(LValue) or (VarToStr(LValue) = '') then
      Result := Result + '1 = 0'
    else
      Result := Result + LTable.Name
                       + '.' + AAssociation.ColumnsNameRef[LFor]
                       + ' = ' + VarToStr(LValue);
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

/// <summary> THE PREDICATE THAT LOCATES ONE ROW BY ITS KEY.
///
///  THE COMPOSITE KEY IS TRUNCATED HERE AND THIS COMMIT DOES NOT REPAIR IT -
///  issue #326, and the reason is a CONTRACT and not an oversight. The loop
///  below walks every column of the primary key and carries `if LFor > 0 then
///  Continue`, so from the second column on the key is DISCARDED and the
///  predicate names only the first column. The loop
///  body does not even carry the ' AND ' that a second term would need, which
///  is the honest reading of the Continue - it short-circuits a feature that
///  was never finished rather than optimising anything.
///
///  WHAT BLOCKS THE REPAIR IS THE CALLERS, NOT THIS SIGNATURE. An earlier
///  version of this paragraph said "AID is ONE TValue and a composite key needs
///  N values", and that overstates it: a TValue carries a TArray&lt;TValue&gt; per-
///  fectly well, so the parameter could hold N without changing its type. What
///  actually blocks it is that NOTHING UPSTREAM EVER BUILDS ONE, and one caller
///  goes out of its way not to: TManagerObjectSet.Find&lt;T&gt;(const AID: TValue)
///  collapses whatever it is given into `AID.AsType&lt;integer&gt;` or `AID.ToString`
///  before the value gets anywhere near here. Widening the contract therefore
///  means changing the CALLERS, up to and including the two public
///  Find(Int64)/Find(String) overloads that a consumer actually holds - which
///  is a consumer-visible change, and the conclusion below survives the
///  correction even though the sentence did not.
///
///  WHO IS AFFECTED, ENUMERATED AND NOT SAMPLED - and the previous version of
///  this list was neither, so here it is again, counted.
///
///  TWELVE OF THE THIRTEEN DIALECT GENERATORS REACH IT, NOT ALL THIRTEEN. Ten
///  declare a GeneratorSelectAll that calls GetGeneratorWhere (ADS, AbsoluteDB,
///  ElevateDB, Firebird, MSSQL, MySQL, NexusDB, Oracle, PostgreSQL, SQLite) and
///  two more inherit Firebird's (Firebird3, InterBase). The thirteenth,
///  MongoDB, does NOT: TDMLGeneratorMongoDB descends from TDMLGeneratorNoSQL,
///  whose GeneratorSelectAll answers GetCriteriaSelectNoSQL and never builds a
///  WHERE at all.
///
///  THE CONSUMER ENTRY POINTS, ALL OF THEM. Local object side:
///  TContainerObjectSet&lt;M&gt;.Find(Int64) and Find(String) - the pair a consumer
///  actually holds - over TObjectSetAdapter&lt;M&gt;.Find(Int64)/Find(String), plus
///  TManagerObjectSet.Find&lt;T&gt;(TValue); they all land on
///  TSQLCommandExecutor&lt;M&gt;.Find(AID). Local DataSet side:
///  TContainerDataSet&lt;M&gt;.Find(Integer)/Find(String) over
///  TDataSetBaseAdapter&lt;M&gt;.Find(Integer)/Find(String), and separately
///  TContainerDataSet&lt;M&gt;.Open(Integer)/Open(String) over
///  TDataSetBaseAdapter&lt;M&gt;.OpenIDInternal - which is the OTHER chain, through
///  TSessionDataSet&lt;M&gt;.OpenID. REST server side: TRESTObjectManager.Find(AID),
///  reached from TAppResourceBase.ResolverFindID and from ParseDelete's
///  IDExecuteFind.
///
///  WHAT THE CONSUMER SEES TODAY, AND IT IS NOT ONE ANSWER BUT TWO. THE Find
///  CHAIN gives a FALSE NEGATIVE: both Find implementations demand
///  `LResultSet.RecordCount = 1` and answer nil otherwise, so on an entity
///  whose first key column is NOT unique the predicate matches several rows and
///  Find answers NIL - the row is in the store and the caller is told it is
///  not. ParseDelete turns that nil into "No records found to delete, with the
///  filter entered!".
///
///  THE OpenID CHAIN HAS NO SUCH GUARD, AND THERE THE ISSUE'S ORIGINAL WORDING
///  IS LITERALLY WHAT HAPPENS. TSessionDataSet&lt;M&gt;._PopularDataSet walks the
///  result set to Eof and Appends EVERY row it finds; nothing anywhere on that
///  path counts them. So Open(AID) over a composite key whose first column
///  repeats loads MORE THAN ONE ROW into the consumer's dataset, which is
///  exactly "localiza por PARTE da chave e casa mais de uma linha". An earlier
///  version of this comment said "the failure is a false NEGATIVE, not the
///  wrong row" without qualification, and the OpenID chain - which the same
///  comment enumerated two paragraphs above - falsifies it. The absolute
///  sentence is gone; the carve-out is the measurement.
///
///  Both halves are pinned in Test.Janus.DML.KeyPredicate:
///  CompositeKey_TheWhereNamesOnlyTheFirstColumn (the predicate itself),
///  CompositeKey_FindOverMoreThanOneMatchingRow_AnswersNil (the Find chain) and
///  CompositeKey_OpenIdLoadsEveryMatchingRow (the OpenID chain).
///
///  AND IF THE FIRST COLUMN HAPPENS TO BE UNIQUE, TODAY'S CODE IS CORRECT. That
///  is what makes every candidate repair a consumer-visible change rather than
///  a fix: refusing a composite key with a named exception would break code
///  that works right now, and answering the zero-rows guard would turn a
///  working read into an empty one. Emitting the full predicate needs the other
///  N-1 values, which means a wider signature - a change to
///  IDMLGeneratorCommand, which third parties implement. The decision belongs
///  to the owner and is NOT taken here.
///
///  ONE THING THAT WAS FIXED: THE DATE LITERAL. See
///  _DialectDateTimeLiteral. </summary>
function TDMLGeneratorAbstract.GetGeneratorWhere(const AClass: TClass;
  const ATableName: String; const AID: TValue): String;
var
  LPrimaryKey: TPrimaryKeyMapping;
  LColumnName: String;
  LFor: Integer;
  LScopeWhere: String;
  LLiteral: String;
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
      if _DialectDateTimeLiteral(AID, LLiteral) then
        // ISSUE #326 - A DATE KEY USED TO LEAVE IN THE MACHINE'S LOCALE.
        // The arm below spells every remaining AID as QuotedStr(AID.ToString),
        // and for a TValue holding a TDateTime that goes through DateTimeToStr,
        // which reads the GLOBAL FormatSettings. Measured on b66b04b:
        // TValue.From<TDateTime>(15/03/2027 14:07:53) came out as
        // '15/03/2027 14:07:53' on the default locale and as
        // '15.03.2027 14-07-53' with DateSeparator '.' / TimeSeparator '-',
        // and a TValue.From<TTime> of the same instant came out as '14-07-53'.
        // Neither was ever the DIALECT's date literal.
        //
        // A PREVIOUS VERSION OF THIS COMMENT SAID THE REPAIR NEEDED A DECISION
        // - "consertar aqui exige decidir qual formato uma PK de data deve ter
        // por dialeto" - AND THAT WAS FALSE. The decision was already taken and
        // is FDateFormat / FTimeFormat, the very fields _GetPropertyValue uses
        // for an ftDate / ftDateTime / ftTime COLUMN. This arm just stops
        // answering differently from its neighbour.
        Result := Result + LColumnName + ' = ' + LLiteral
      else
        Result := Result + LColumnName + ' = ' + QuotedStr(AID.ToString);
    end;
  end;
end;

function TDMLGeneratorAbstract._DialectDateTimeLiteral(const AID: TValue;
  out ALiteral: String): Boolean;
var
  LMask: String;
begin
  Result := False;
  ALiteral := '';
  if AID.TypeInfo = nil then
    Exit;
  if (AID.TypeInfo = System.TypeInfo(TDateTime)) or
     (AID.TypeInfo = System.TypeInfo(TDate)) then
    LMask := FDateFormat
  else
  if AID.TypeInfo = System.TypeInfo(TTime) then
    LMask := FTimeFormat
  else
    Exit;
  ALiteral := QuotedStr(FormatDateTime(LMask, TDateTime(AID.AsExtended),
                                       FFormatSettings));
  Result := True;
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
var
  LGuid: TGUID;
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
                             VarToDateTime(AProperty.GetNullableValue(AObject).AsVariant),
                             FFormatSettings));
     ftTime, ftTimeStamp, ftOraTimeStamp:
        Result := QuotedStr(FormatDateTime(FTimeFormat,
                             VarToDateTime(AProperty.GetNullableValue(AObject).AsVariant),
                             FFormatSettings));
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
     ftGuid:
       begin
         LGuid := _GetGuidValue(AObject, AProperty);
         // FK GUID nao preenchida: o TGUID chega zerado (ou Nullable sem
         // valor, ver _GetGuidValue). Devolver '' faz a guarda de FK nula de
         // GenerateSelectOneToOne e a de GenerateSelectOneToOneMany emitirem
         // '1 = 0' - o mesmo contrato de FK nula que o irmao REST pratica em
         // TRESTDataSetAdapter<M>._WhereAssociation. Emitir o literal do
         // GUID zerado casaria zero linhas, por acidente e nao por contrato.
         // A ANCORA POR METODO AGORA VALE PARA AS TRES: este comentario ja
         // dizia "ancora por METODO: a de linha apodreceu duas vezes" sobre a
         // do irmao REST e mantinha :265-266 e :328-329 por LINHA para as duas
         // guardas locais - que a issue #326 empurrou para :289-290 e :352-353
         // ao inserir 97 linhas nesta unit. A licao estava escrita na mesma
         // frase que a ignorava.
         if LGuid = TGUID.Empty then
           Result := ''
         else
         begin
           _GuardStoreGUIDAsOctet(AProperty);
           Result := GuidLiteral(LGuid);
         end;
       end;
  else
     Result := '';
  end;
end;

function TDMLGeneratorAbstract._GetGuidValue(AObject: TObject;
  AProperty: TRttiProperty): TGUID;
var
  LValue: TValue;
begin
  LValue := AProperty.GetNullableValue(AObject);
  // Nullable<TGUID> SEM VALOR chega aqui como Variant Null
  // (MetaDbDiff.RTTI.Helper.pas:356-359). Vira GUID vazio, que o chamador
  // converte na guarda '1 = 0' - uma FK opcional nao preenchida nao e' erro.
  // Sem esta linha o TryAsType abaixo falha e o codigo levanta o erro NOMEADO
  // de tipo errado sobre uma FK legitimamente nula; e' o que a mutacao de
  // Test.Janus.DML.Generator.SQLite prova ao matar
  // TestGuid_ANullableGuidWithNoValue_BecomesTheZeroRowsGuard.
  //
  // NAO ha' guarda de LValue.IsEmpty aqui, e o que autoriza tira-la e'
  // NEUTRALIDADE DE RESPOSTA - nao inalcancabilidade. A distincao importa
  // porque a versao anterior deste comentario afirmava que nenhum caminho
  // produzia TValue vazio, e isso era FALSO:
  //   IsNullable e' checagem POR NOME (MetaDbDiff.RTTI.Helper.pas:620-629):
  //   basta o record se chamar "Nullable<...>". Um record assim COM FHasValue
  //   (True) e SEM FValue passa pela checagem, chega em
  //   MetaDbDiff.RTTI.Helper.pas:362-364, nao acha o campo, e sai com o
  //   Result que veio de :345 - Default(TValue), ou seja VAZIO. Medido:
  //   IsEmpty devolve True nessa forma.
  // O caminho existe. O que NAO existe e' diferenca de resposta. Medido sobre
  // um TValue vazio: IsType<Variant> devolve True, VarIsNull(AsVariant)
  // devolve False SEM levantar, e TryAsType<TGUID> devolve True com
  // TGUID.Empty - exatamente o que a guarda removida devolvia. Fim a fim, com
  // essa forma exata, o gerador emite 'WHERE 1 = 0' com e sem a guarda.
  // Uma linha cuja remocao nao move nenhuma resposta e' peso morto, e saiu.
  if LValue.IsType<Variant> and VarIsNull(LValue.AsVariant) then
    Exit(TGUID.Empty);
  // Erro NOMEADO em vez do EInvalidCast cru de AsType<TGUID>. Uma coluna
  // ftGuid sobre propriedade String e' o defeito latente que a issue #284
  // descobriu no proprio repositorio (o modelo mergeado no PR #286 declarava
  // [Column('cck3', ftGuid, 38)] property cck3: String) - e ele so' aparecia
  // no INSERT, tarde e sem dizer o nome da coluna.
  if not LValue.TryAsType<TGUID>(Result) then
    raise Exception.CreateFmt(
      'A coluna ftGuid mapeada na propriedade "%s" e do tipo "%s". ' +
      'Uma coluna ftGuid exige propriedade TGUID (ou Nullable<TGUID>) - e o ' +
      'contrato que Janus.Command.Inserter/Updater/Deleter ja praticam via ' +
      'AsType<TGUID>.ToString. Para chave GUID guardada como TEXTO, declare a ' +
      'coluna como ftString e use TGeneratorType.Guid32Inc/Guid36Inc/Guid38Inc.',
      [AProperty.Name, AProperty.PropertyType.Name]);
end;

function TDMLGeneratorAbstract._StoreGUIDAsOctet: Boolean;
var
  LOptions: IOptions;
begin
  // Nil-safe nos DOIS niveis de proposito: um gerador pode ser criado sem
  // SetConnection (o registro por fabrica nao a exige), e uma IDBConnection
  // pode devolver Options nil - e' o que o duble de teste faz. Nenhum dos
  // dois casos e' "octeto"; ambos sao "nao sei", e nao saber nao pode
  // levantar excecao num caminho que hoje funciona.
  Result := False;
  if FConnection = nil then
    Exit;
  LOptions := FConnection.Options;
  if LOptions = nil then
    Exit;
  Result := LOptions.StoreGUIDAsOctet;
end;

/// <summary> O EIXO QUE DIVERGE DE VERDADE, E QUE ESTE PR NAO IMPLEMENTA.
///
///  IOptions.StoreGUIDAsOctet NAO e' hipotese futura: e' setter publico, vivo
///  hoje (DataEngine.DriverConnection.pas:123, default False em :1904). Com
///  ela ligada o DDL desta casa deixa de guardar TEXTO e passa a guardar
///  BINARIO de 16 bytes - MetaDbDiff.Metadata.Extract.pas:509-526 emite
///  CHAR(16) CHARACTER SET OCTETS no Firebird e BYTE(16) no PostgreSQL.
///
///  O literal que este ramo emite e' texto de 38 caracteres. Contra uma coluna
///  de 16 bytes ele casa ZERO LINHAS, EM SILENCIO - que e' exatamente o
///  defeito da #284 entrando por outra porta. O desenho inteiro deste conserto
///  se justifica em "falhar cedo e alto em vez de emitir '1 = 0' de novo";
///  deixar este eixo sem guarda seria contradizer a propria justificativa.
///
///  Por que ERRO e nao suporte: a forma correta no modo octeto e' por dialeto
///  e exige medicao contra banco vivo - Firebird quer CHAR_TO_UUID('36 com
///  hifen') ou x'32hex'; PostgreSQL emite 'BYTE(%1)', tipo que o PostgreSQL
///  nao tem (o binario dele e' bytea), ou seja o proprio DDL do modo octeto
///  esta' em disputa. Escolher uma forma sem medir seria inventar. O erro
///  nomeado transforma um silencio em uma conversa, e nao custa nada a quem
///  nao usa a opcao - que e' o default. </summary>
procedure TDMLGeneratorAbstract._GuardStoreGUIDAsOctet(AProperty: TRttiProperty);
begin
  if _StoreGUIDAsOctet then
    raise Exception.CreateFmt(
      'A conexao esta com IOptions.StoreGUIDAsOctet ligada, e a coluna ftGuid ' +
      'mapeada na propriedade "%s" entra num WHERE de associacao. Nesse modo o ' +
      'schema guarda o GUID como BINARIO de 16 bytes (Firebird: CHAR(16) ' +
      'CHARACTER SET OCTETS; PostgreSQL: BYTE(16)), e o literal de texto que ' +
      'este gerador emite casaria ZERO LINHAS em silencio. A geracao de SELECT ' +
      'por associacao ainda NAO suporta GUID em octeto - ou desligue ' +
      'StoreGUIDAsOctet para esta conexao, ou implemente GuidLiteral do ' +
      'dialeto para o modo octeto e remova esta guarda.',
      [AProperty.Name]);
end;

function TDMLGeneratorAbstract.CanonicalGuidLiteral(const AGuid: TGUID): String;
begin
  Result := QuotedStr(AGuid.ToString);
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
  const AGeneratorDriver: TDriverName): TFluentSQLDriver;
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
      [GetEnumName(TypeInfo(TDriverName), Ord(AGeneratorDriver))]);
  end;
end;

procedure TDMLGeneratorAbstract.ConfigureFluentSQLDriver(
  const AGeneratorDriver: TDriverName);
begin
  FFluentSQLDriver := ResolveFluentSQLDriver(AGeneratorDriver);
end;

function TDMLGeneratorAbstract.CreateFluentSQL: IFluentSQL;
begin
  Result := TCQ(FFluentSQLDriver);
end;

end.
