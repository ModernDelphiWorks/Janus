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
  Janus.DML.Insert.Columns,
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
    function _NoIdSupplied(const AID: TValue): Boolean;
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
    /// <summary> THE VALUES AN AID CARRIES - one, or as many as the caller
    ///  supplied. Issue #326.
    ///
    ///  A TValue holds a TArray&lt;TValue&gt; perfectly well, and that is the whole
    ///  mechanism: a caller with a COMPOSITE key hands one value per key
    ///  column and the predicate names them all. A caller that hands a scalar
    ///  gets a one-element array and therefore the exact single-column
    ///  predicate it has always got - which is the point. Refusing a composite
    ///  key, or answering zero rows for one, would break consumers whose first
    ///  key column IS unique and whose code is correct today. </summary>
    function _KeyValues(const AID: TValue): TArray<TValue>;
    /// <summary> ONE key value rendered as this dialect's literal. Lifted out
    ///  of GetGeneratorWhere unchanged so that every term of a composite
    ///  predicate is spelled the same way the single term always was - the
    ///  ordinal arm bare, a date/time arm through the dialect mask, everything
    ///  else quoted. Issue #326. </summary>
    function _KeyLiteral(const AID: TValue): String;
    function _GetGuidValue(AObject: TObject; AProperty: TRttiProperty): TGUID;
    procedure _GuardStoreGUIDAsOctet(AProperty: TRttiProperty);
    /// <summary> THE NAMED BIND MARKER THIS GENERATOR ASKED FOR, PUT BACK OVER
    ///  THE POSITIONAL :pN THAT THE FLUENTSQL VALUE SLOT ALLOCATES. Issue #337.
    ///
    ///  WHAT CHANGED UNDER US. Every SetValue/Values overload of FluentSQL now
    ///  routes the right-hand side of "COLUMN = ..." through
    ///  IFluentSQLParams.Add - FluentSQL.pas:827-849 and
    ///  FluentSQL.Params.pas:109-115 - which names the bind 'p' + ordinal and
    ///  writes ':pN' into the SQL. That was their repair for an injection they
    ///  measured in the value slot, and NO overload of theirs carries a
    ///  fragment through any more. So the two calls this unit makes -
    ///  Values(col, [':'+col]) and SetValue(col, [':'+col]) - stopped
    ///  producing "values (:CLIENT_ID, :CLIENT_NAME)" and started producing
    ///  "values (:p1, :p2)", with the marker TEXT parked as the bind's VALUE.
    ///
    ///  WHY THE MARKER HAS TO COME BACK NAMED AND NOT BE CONSUMED POSITIONALLY.
    ///  Janus binds by NAME: TCommandInserter.GenerateInsert names each TParam
    ///  after its column, and the dataset matches marker to param by that name.
    ///
    ///  THE PARAGRAPH THAT USED TO STAND HERE IS REPLACED RATHER THAN DELETED,
    ///  BECAUSE IT WAS MEASURED FALSE - issue #352. It gave two reasons the
    ///  positional reading was unsafe, and it ranked the damage wrongly:
    ///    (a) it said THE TWO LOOPS DO NOT EMIT THE SAME SET - the generator
    ///        skipping on four tests and the inserter on those four AND on
    ///        IsJoinColumn - and treated the resulting slot shift as something
    ///        only an ORDINAL reading could cause. It happens TODAY, by name,
    ///        and it needs no cache: see below.
    ///    (b) it said the SQL is cached per class while the skip set is per
    ///        instance, which was true and is now closed.
    ///  It then said that BY NAME the wide-first case is "a MARKER WITH NO
    ///  BIND", and that the wrong column quietly receiving another column's
    ///  value was what an ORDINAL reading would cost. THAT IS THE FALSE HALF.
    ///  Measured against SQLite through the public container API:
    ///    TDriverFireDAC._InternalExecuteDirect sets SQL.Text and then calls
    ///    Params.Assign, and Assign REPLACES the collection FireDAC built from
    ///    the text. So a statement carrying MORE markers than the params handed
    ///    to it does not leave the extras unbound - the survivors are filled BY
    ///    POSITION, one column's value lands in ANOTHER COLUMN, and nothing
    ///    raises. "A marker with no bind" was the benign reading of a silent
    ///    corruption. The opposite mismatch - more params than markers - is
    ///    matched by name and the surplus is dropped without a word.
    ///  Both were reproduced on a COLD cache, on a SINGLE object, by a
    ///  [JoinColumn] that was not also NoInsert; the cache only widened the
    ///  population that could reach them.
    ///
    ///  BOTH ARE NOW CLOSED, AND BY THE SAME CHANGE. TInsertColumns.Plan is the
    ///  one function that decides which columns an INSERT carries, and both
    ///  GeneratorInsert and TCommandInserter.GenerateInsert call it, so (a)
    ///  cannot recur; the signature it returns is cached beside the SQL, so (b)
    ///  cannot recur. See Janus.DML.Insert.Columns. What remains true and load
    ///  bearing for THIS method is only the first sentence: the bind is matched
    ///  by NAME, so the marker has to come back named.
    ///  So the adoption is: let FluentSQL allocate the bind, then put OUR name
    ///  back over it. The emitted text is byte-for-byte what this generator
    ///  emitted before FluentSQL changed, which is why no consumer downstream
    ///  had to move.
    ///
    ///  ASQL IS THE VALUE REGION ONLY - NEVER A WHOLE UPDATE. Only ':pN' may
    ///  appear in what this scans, because the value slot takes the marker as a
    ///  bind VALUE and never as text. A whole UPDATE also carries the key
    ///  predicate, which GeneratorUpdate writes VERBATIM, and a key column
    ///  named `p1` is then textually indistinguishable from the bind FluentSQL
    ///  allocated - see the box in GeneratorUpdate for the measured corruption
    ///  and for how the two regions are told apart.
    ///
    ///  IT REFUSES RATHER THAN GUESSES. AMarkers is what this unit handed to the
    ///  value slot, in call order. If the count does not match, or a bind is
    ///  carrying something this unit did not put there, the rewrite raises: a
    ///  bind holding REAL data must keep its :pN, because inlining it into the
    ///  SQL text is the very injection FluentSQL just closed. </summary>
    function _RestoreNamedPlaceholders(const ASQL: String;
      const AParams: IFluentSQLParams;
      const AMarkers: TArray<String>): String;
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
      /// <summary> THE DIALECT THIS GENERATOR HANDS TO FluentSQL. Issue #355.
      ///
      ///  ABSTRACT, AND THAT IS THE WHOLE REPAIR. The dialect used to be set by
      ///  a call in the constructor, which meant a descendant could simply not
      ///  make it - and ten of the fourteen did not. The field they left behind
      ///  is not empty, it is the ZERO VALUE of TFluentSQLDriver, which is
      ///  dbnMSSQL: every one of them was asking FluentSQL to serialize as
      ///  T-SQL without ever saying so.
      ///
      ///  WHAT ACTUALLY HAPPENS TO A DESCENDANT THAT STAYS SILENT, MEASURED AND
      ///  NOT ASSUMED - because "the compiler refuses it" is what an abstract
      ///  member SOUNDS like and it is not what this build does. Deleting the
      ///  NexusDB override and building Janus.Tests.Units: EXIT CODE 0, ZERO
      ///  compile errors, an executable produced. What comes out is one
      ///  W1020 - "Constructing instance of 'TDMLGeneratorNexusDB' containing
      ///  abstract method 'TDMLGeneratorAbstract.SerializationDialect'", on the
      ///  RegisterDriver factory at the foot of that unit - and W1020 is ROUTINE
      ///  NOISE here: the same build already emits 118 of them, one of which is
      ///  TDMLGeneratorAbstract.GuidLiteral, the sibling net this design copies.
      ///  The refusal is at RUNTIME, EAbstractError on the first construction:
      ///  six clauses errored with "Abstract Error", DialectOf_NexusDB among
      ///  them.
      ///
      ///  THAT IS STILL THE WHOLE POINT, AND IT IS STILL BETTER THAN WHAT IT
      ///  REPLACES. A silent dbnMSSQL emits plausible SQL forever and nothing
      ///  says a word; a missing declaration cannot survive one construction,
      ///  and Test.Janus.DML.Dialect.Wiring gives every generator a clause of
      ///  its own so the construction happens in the suite.
      ///
      ///  AND IT CLOSES THE CLASS ONLY INSIDE TDMLGeneratorAbstract. Every route
      ///  from THIS tree to a FluentSQL dialect now passes through here. It is
      ///  not the only route in Janus: Janus.Server.RestView.Manager.pas has a
      ///  second, independent TDriverName-to-TFluentSQLDriver map that
      ///  SerializationDialect does not reach.
      ///
      ///  Asked as a class function, and answered by the descendant with a
      ///  constant it already owns: each generator unit names its TDriverName
      ///  two hundred lines below, at its TDriverRegister.RegisterDriver call.
      ///  Nothing is inverted - the base asks a question the subclass was
      ///  already answering somewhere else.
      ///
      ///  NOT EVERY GENERATOR CAN NAME ITS OWN ENGINE, AND THE ONES THAT CANNOT
      ///  SAY WHY IN THEIR OWN OVERRIDE. TFluentSQLDriver has fifteen members
      ///  and FluentSQL implements seven of them; dbnADS, dbnAbsoluteDB,
      ///  dbnElevateDB, dbnNexusDB and dbnInterbase have no serializer at all
      ///  and raise EFluentSQLDriverNotRegistered when asked, and dbnMySQL has
      ///  one that eats the ':pN' markers Janus depends on. Those overrides
      ///  answer dbnMSSQL and carry the measurement that says so. </summary>
      class function SerializationDialect: TFluentSQLDriver; virtual; abstract;
      class function ResolveFluentSQLDriver(
        const AGeneratorDriver: TDriverName): TFluentSQLDriver; static;
      /// <summary> OVERRIDES THE DECLARED DIALECT AT RUNTIME, AND IS NOT HOW
      ///  GENERATORS ARE WIRED. Issue #355 moved the wiring into the
      ///  constructor above; this stayed because the #337 refusal has to be
      ///  reachable - TDMLGeneratorDialectProbe in
      ///  Test.Janus.DML.Generator.SQLite pulls it to hand a generator the
      ///  MySQL dialect and watch GeneratorInsert refuse. Two mechanisms for
      ///  the same thing is exactly what this issue was about, so this one is
      ///  named as the lever it is instead of being left to look like the
      ///  other half of the wiring. </summary>
      procedure ConfigureFluentSQLDriver(const AGeneratorDriver: TDriverName);
      function CreateFluentSQL: IFluentSQL;
      /// <summary> THE RESTORED VALUE REGION, WITH THE VERBATIM TAIL CARRIED OVER
      ///  UNTOUCHED. Issue #337.
      ///
      ///  AValueRegion is the statement as FluentSQL rendered it BEFORE any
      ///  verbatim clause of ours was added, and AWholeStatement is the finished
      ///  one. Everything past the region is text this generator wrote itself -
      ///  today, the key predicate of GeneratorUpdate - and the rewrite must
      ///  never see it: a key column named `p1` is textually indistinguishable
      ///  from the bind FluentSQL allocated. For an INSERT there is no verbatim
      ///  tail and the two arguments are the same string.
      ///
      ///  PROTECTED SO THE REFUSAL CAN BE MEASURED. The prefix property belongs
      ///  to THEIR serializer, and is pinned separately by
      ///  FluentSQLRendersTheValueRegionAsAPrefixOfTheWholeUpdate. What is pinned
      ///  HERE is that this method REFUSES when the property does not hold -
      ///  which no statement Janus builds can produce, so the only way to reach
      ///  it is to hand it a pair directly. That is what the test descendant in
      ///  Test.Janus.DML.Generator.SQLite does. A guard presented as an active
      ///  net has to have its own clause; an inverted condition or a wrong
      ///  message would otherwise ship unnoticed. </summary>
      function _SpliceRestoredValueRegion(const AValueRegion,
        AWholeStatement: String; const AParams: IFluentSQLParams;
        const AMarkers: TArray<String>): String;
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
    ///  QUEBROU: a issue #326 inseriu linhas acima delas e as guardas andaram.
    ///  NENHUM NUMERO NOVO E ESCRITO AQUI DE PROPOSITO. Uma versao intermediaria
    ///  desta frase dizia "andaram para :289-290 e :352-353", e o proprio commit
    ///  seguinte - que crescia este comentario - moveu as duas OUTRA VEZ. Uma
    ///  auto-citacao por linha e a mais fragil de todas, porque quem cresce o
    ///  arquivo nao vai procurar por ela; substitui-la por uma auto-citacao por
    ///  linha MAIS NOVA e repetir o defeito com numeros melhores.
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
    ///  de comando ja exigem: TCommandInserter._GetParamValue - POR SIMBOLO
    ///  desde a #325, que inseriu linhas naquela unit -,
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
    ///  grava (TCommandInserter._GetParamValue -> TGUID.ToString) e que o
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
  /// Issue #355. FIRST LINE OF THE CONSTRUCTOR, AND NOT A CALL A DESCENDANT
  /// MAKES. SerializationDialect is abstract, so the dispatch here lands on the
  /// override of the class actually being built - which is why the answer is
  /// right even though this runs before the descendant constructor body.
  FFluentSQLDriver := SerializationDialect;
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
  LPlan: TInsertColumnPlan;
  LSQL: IFluentSQL;
  LKey: String;
  LMarker: String;
  LMarkers: TArray<String>;
  LRendered: String;
  LPacked: String;
  LCachedSignature: String;
  LCachedSQL: String;
begin
  Result := '';
  try
    /// Issue #352. THE PLAN IS BUILT BEFORE THE CACHE IS CONSULTED, and that
    /// order is the repair. What is cacheable about an INSERT is not the class
    /// - it is the class TOGETHER WITH the set of columns THIS object
    /// contributes, and the only way to know that set is to ask the object.
    /// The previous version returned on the key alone and handed the second
    /// object the first object's statement.
    if not TInsertColumns.Plan(AObject, LPlan) then
      LPlan.Signature := '';
    LKey := AObject.ClassType.ClassName + '-INSERT';
    if FQueryCache.TryGetValue(LKey, LPacked) then
      if TInsertColumns.Unpack(LPacked, LCachedSignature, LCachedSQL) then
        if LCachedSignature = LPlan.Signature then
          Exit(LCachedSQL);
    LTable := TMappingExplorer.GetMappingTable(AObject.ClassType);
    LSQL := CreateFluentSQL.Insert.Into(LTable.Name);
    LMarkers := nil;
    /// The list is TInsertColumns.Plan's, and TCommandInserter.GenerateInsert
    /// builds its params from the SAME call. That is what keeps the markers and
    /// the binds in step; before #352 each side ran its own loop and the two
    /// did not agree on IsJoinColumn.
    for LColumn in LPlan.Columns do
    begin
      try
        LMarker := ':' + LColumn.ColumnName;
        LSQL.Values(LColumn.ColumnName, [LMarker]);
        LMarkers := LMarkers + [LMarker];
      except
        on E: Exception do
          raise Exception.CreateFmt(
            'DIAG GeneratorInsert column=%s class=%s msg=%s',
            [LColumn.ColumnName, AObject.ClassName, E.Message]);
      end;
    end;
    /// Issue #337. The FluentSQL value slot parameterises; the marker this
    /// generator asked for is put back over the :pN it allocated. See
    /// _RestoreNamedPlaceholders for why the ordinal cannot be read directly.
    /// An INSERT has no verbatim clause of ours, so the value region IS the
    /// whole statement - it goes through the same splice as the UPDATE so that
    /// both carry the same guards rather than two spellings of them.
    LRendered := LSQL.AsString;
    Result := _SpliceRestoredValueRegion(LRendered, LRendered, LSQL.Params, LMarkers);
    /// Signature and statement go in together. One entry per class still - the
    /// pattern rides inside the value, not in the key, so the growth note in
    /// Janus.DML.Cache stays true.
    FQueryCache.AddOrSetValue(LKey, TInsertColumns.Pack(LPlan.Signature, Result));
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
///  THE COMPOSITE KEY WAS TRUNCATED HERE AND IS NOW REPAIRED - issue #326.
///  The loop below used to walk every column of the primary key carrying
///  `if LFor > 0 then Continue`, so from the second column on the key was
///  DISCARDED and the predicate named only the first column. The loop body did
///  not even carry the ' AND ' that a second term would need, which is the
///  honest reading of that Continue - it short-circuited a feature that was
///  never finished rather than optimising anything.
///
///  WHAT WAS SAID TO BLOCK THE REPAIR WAS THE CALLERS, AND THAT HELD UNTIL THE
///  CALLERS WERE WRITTEN. An earlier version of this paragraph first said "AID
///  is ONE TValue and a composite key needs N values" and then corrected
///  itself: a TValue carries a TArray&lt;TValue&gt; perfectly well, so the parameter
///  could hold N without changing its type. What was left blocking it was that
///  NOTHING UPSTREAM EVER BUILT ONE. Something does now -
///  TSessionAbstract&lt;M&gt;.Find(TArray&lt;TValue&gt;) wraps the array into the TValue
///  that FCommandExecutor.Find already took - and the observation that
///  TManagerObjectSet.Find&lt;T&gt; collapses whatever it is handed into
///  `AID.AsType&lt;integer&gt;` or `AID.ToString` remains true of THAT method, which
///  is simply not on the new path.
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
///  AND IF THE FIRST COLUMN HAPPENS TO BE UNIQUE, TODAY'S CODE IS CORRECT.
///  That is what ruled out every candidate repair that CHANGES the scalar
///  answer: refusing a composite key with a named exception would break code
///  that works right now, and answering the zero-rows guard would turn a
///  working read into an empty one.
///
///  THE REPAIR TAKEN COSTS NO SIGNATURE ON THIS PATH - AND THAT IS AS FAR AS
///  THE CLAIM GOES. Emitting the full predicate needs the other N-1 values,
///  and an earlier version of this paragraph said that meant a wider signature
///  and therefore a change to IDMLGeneratorCommand `which third parties
///  implement`. THAT PART WAS WRONG: the values travel inside the TValue this
///  method ALREADY takes, as a TArray<TValue> - the possibility this same
///  comment named four paragraphs above. IDMLGeneratorCommand is untouched
///  (it does not even declare GetGeneratorWhere), and so is every layer
///  between a consumer and here: TSQLCommandExecutor<M>.Find already took a
///  TValue.
///
///  BUT THE REPLACEMENT SENTENCE WAS ALSO WRONG, AND IT SAID `IT COSTS NO
///  SIGNATURE ANYWHERE`. It does. Reaching this from consumer code needed a
///  NEW MEMBER ON TWO PUBLISHED INTERFACES: Find(TArray<TValue>) on
///  IContainerObjectSet<M>, and Find(TArray<TValue>) plus Open(TArray<TValue>)
///  on IContainerDataSet<M>. ADDING A MEMBER TO A PUBLISHED INTERFACE BREAKS A
///  THIRD-PARTY IMPLEMENTER EXACTLY AS WIDENING IDMLGeneratorCommand WOULD -
///  the objection that killed the old design applies to this one too, just one
///  layer out. Inside this repository each interface has exactly ONE
///  implementer, both enumerated and both updated; OUTSIDE it, whether anyone
///  implements them is NOT MEASURABLE FROM HERE AND IS NOT MEASURED. The
///  sibling issue #333 declared that same exposure explicitly, and this one
///  should have said it the first time.
///
///  WHAT DECIDES THE PREDICATE IS HOW MANY VALUES ARRIVE, NOT HOW MANY COLUMNS
///  THE KEY HAS. A scalar aid yields a one-element array and therefore the
///  exact single-column predicate this method has always built, so no existing
///  consumer changes behaviour - the three original composite clauses in
///  Test.Janus.DML.KeyPredicate are still GREEN and now document the scalar
///  path deliberately. A caller that hands one value per key column gets every
///  column named, joined with ' AND '. The new entry point is
///  TSessionAbstract<M>.Find(TArray<TValue>), reached from
///  IContainerObjectSet<M>.Find and IContainerDataSet<M>.Find/Open.
///
///  REST DOES NOT INHERIT IT: TSessionRestFul<M> overrides that overload and
///  refuses, because `resource(ID)` and `$value=ID` have no spelling for N
///  values. Refusing there breaks nothing, because the overload is new.
///
///  ONE THING THAT WAS FIXED: THE DATE LITERAL. See
///  _DialectDateTimeLiteral. </summary>
function TDMLGeneratorAbstract.GetGeneratorWhere(const AClass: TClass;
  const ATableName: String; const AID: TValue): String;
var
  LPrimaryKey: TPrimaryKeyMapping;
  LFor: Integer;
  LScopeWhere: String;
  LValues: TArray<TValue>;
  LTerms: String;
begin
  Result := '';
  LScopeWhere := GetGeneratorQueryScopeWhere(AClass);
  if LScopeWhere <> '' then
    Result := ' WHERE ' + LScopeWhere;
  if _NoIdSupplied(AID) then
    Exit;
  LPrimaryKey := TMappingExplorer.GetMappingPrimaryKey(AClass);
  // ISSUE #361 - AN ID WAS SUPPLIED AND THE CLASS MAPS NO PRIMARY KEY: REFUSE.
  // This is the third mouth of the hole #326 closed twice below, and it was
  // left open because the arm that follows was written as `if LPrimaryKey <>
  // nil then` - so a class with no key mapping fell out of this method with
  // the predicate still EMPTY, and the caller ran its SELECT or DELETE over
  // the whole table for a question about one row. The two guards inside that
  // arm cannot see this shape, because they only run once it is entered.
  // Refusing by name is the form the neighbour already uses, and it is louder
  // than a full-table read that answers 200.
  if LPrimaryKey = nil then
    raise Exception.CreateFmt('An id was supplied for %s, which maps no ' +
      'primary key, so the predicate would be empty and the statement would ' +
      'match EVERY row. To read all records, use the overload that takes no ' +
      'id.', [AClass.ClassName]);
  if LPrimaryKey <> nil then
  begin
    // ISSUE #326 - ONE TERM PER VALUE THE CALLER SUPPLIED, AND NO MORE.
    // This loop used to carry `if LFor > 0 then Continue`, so from the second
    // key column on the key was DISCARDED and the predicate named only the
    // first column - and the body did not even carry the ' AND ' a second
    // term would have needed. It was functionality never finished.
    //
    // THE REPAIR IS DRIVEN BY HOW MANY VALUES ARRIVE, NOT BY HOW MANY COLUMNS
    // THE KEY HAS, and that is what keeps it from breaking anyone. A caller
    // that hands a scalar gets a one-element array, so the loop emits exactly
    // one term and stops: byte for byte the predicate this method has always
    // built. A caller that hands a TArray<TValue> gets one term per value,
    // joined with ' AND '. Nothing refuses a composite key and nothing turns
    // a working read into an empty one - which matters, because where the
    // first key column happens to be UNIQUE the old behaviour was CORRECT.
    LValues := _KeyValues(AID);
    // AN ID WAS SUPPLIED AND NOT ONE TERM CAN BE BUILT FROM IT: REFUSE.
    // Reaching here means _NoIdSupplied already agreed the caller HAS given an
    // id - the method issue #361 renamed from _IsType and rewrote -
    // so answering with no predicate would read the WHOLE TABLE for a question
    // about one row. Two shapes get here and both were MEASURED, not imagined:
    //   * an EMPTY TArray<TValue> from the entry point #326 adds - Find([])
    //     and Open([]) emitted `SELECT keyonly.k1, keyonly.k2 FROM keyonly`
    //     and Open loaded EVERY row of the table;
    //   * a primary key mapping NO COLUMNS, which MetaDbDiff's
    //     PrimaryKey.Create yields from an empty column string because it
    //     wraps its whole parsing block in `if Length(AColumns) > 0`. That one
    //     is caught by the SECOND guard below, not by a third of its own.
    // THE SECOND SHAPE IS A REGRESSION THIS BRANCH INTRODUCED, and these
    // guards are how it is paid back. Before the composite repair the WHERE
    // was appended BEFORE the loop, so a zero-column key left a dangling
    // ' WHERE ' - malformed SQL the database rejects loudly. Appending it
    // after the loop turned that loud failure into a SILENT full-table read.
    // Refusing is louder than either.
    if Length(LValues) = 0 then
      raise Exception.Create('An id was supplied carrying no values, so the ' +
        'predicate would be empty and the statement would match EVERY row. ' +
        'To read all records, use the overload that takes no id.');
    // AND THIS ONE ALSO CATCHES THE ZERO-COLUMN KEY, which is why there is no
    // third guard for it. A separate `Columns.Count = 0` test was written,
    // measured and DELETED: with the empty array already refused above, every
    // surviving call has at least one value, so `Length(LValues) > 0` is
    // exactly the zero-column condition and this line fires first. Removing
    // that third guard with a tripwire the compiler echoed killed ZERO
    // clauses - it was unreachable, not redundant-but-safe.
    if Length(LValues) > LPrimaryKey.Columns.Count then
      raise Exception.Create(Format('%d key value(s) were supplied for a ' +
        'primary key of %d column(s) on %s. Dropping the extra values in ' +
        'silence is the very defect issue #326 repaired, so they are refused.',
        [Length(LValues), LPrimaryKey.Columns.Count, AClass.ClassName]));
    LTerms := '';
    for LFor := 0 to LPrimaryKey.Columns.Count - 1 do
    begin
      // FEWER VALUES THAN COLUMNS IS ALLOWED, AND IS THE WHOLE DESIGN: the
      // predicate follows what the caller SUPPLIED, so one value gives the
      // one-column predicate the scalar path always gave. MORE values than
      // columns is refused above, because those could only be discarded.
      if LFor > High(LValues) then
        Break;
      if LTerms <> '' then
        LTerms := LTerms + ' AND ';
      LTerms := LTerms + ATableName + '.' + LPrimaryKey.Columns[LFor] +
                ' = ' + _KeyLiteral(LValues[LFor]);
    end;
    Result := Result + IfThen(LScopeWhere = '', ' WHERE ', ' AND ') + LTerms;
  end;
end;

function TDMLGeneratorAbstract._KeyValues(const AID: TValue): TArray<TValue>;
begin
  if AID.IsType<TArray<TValue>> then
    Result := AID.AsType<TArray<TValue>>
  else
    Result := [AID];
end;

function TDMLGeneratorAbstract._KeyLiteral(const AID: TValue): String;
var
  LLiteral: String;
begin
  if (AID.IsType<Integer>) or (AID.IsType<Int64>) or (AID.IsType<UInt64>) then
    Result := AID.ToString
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
    Result := LLiteral
  else
    Result := QuotedStr(AID.ToString);
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

/// <summary> ISSUE #361 - "GIVE ME EVERYTHING" AND "GIVE ME THE ROW WITH THIS
///  ID" ARE NOW TWO QUESTIONS, AND THEY ARE NO LONGER TOLD APART BY A VALUE.
///
///  THIS METHOD USED TO BE CALLED _IsType AND ANSWERED True FOR EXACTLY -1 -
///  as UInt64, as Int64, as Integer, AND as the string '-1'. GetGeneratorWhere
///  answers an id it agrees with by discarding the whole predicate, so -1
///  meant "no filter". The trouble is that -1 is ALSO the framework's
///  placeholder for an AutoInc key the generator has not answered yet -
///  cAutoIncNotGenerated, Janus.DataSet.Fields.pas:51 - so a stale placeholder
///  travelling to the server as an id turned a question about ONE row into a
///  statement over EVERY row. MEASURED on develop 0103408, SQLite in a file,
///  through the server alone with raw HTTP and no Janus client: against a
///  table holding a single row, `DELETE resource(-1)` answered 200
///  "delete command executed successfully" and left the table EMPTY, the
///  grandchild going with it by cascade, and `GET resource(-1)` handed back
///  that row. What kept it from emptying a larger table is not this method: it
///  is TRESTObjectManager.Find (Janus.Server.RestObject.Manager.pas:567-586)
///  refusing to build an object unless RecordCount = 1.
///
///  THE REPAIR IS NOT A DIFFERENT MAGIC NUMBER. Any integer chosen to mean
///  "no id" can be reached by an id, so the marker is moved OUT OF BAND: "no
///  id" is now a TYPELESS TValue, and a caller that actually supplies an id
///  hands over a value that carries a type. Every path that carries an id from
///  outside - the REST path segment (Janus.Server.Resource.pas:514 and :802
///  hand AQuery.ID.ToString to TRESTObjectSet.Find), IContainerObjectSet<M>
///  .Find, IContainerDataSet<M>.Find/Open - arrives holding a typed value, so
///  none of them can ever be read as "no filter" again. -1 goes back to being
///  an ordinary key value and builds the predicate any other key would.
///
///  AND THIS REPAIR IS AN INVERSION FOR ONE SHAPE, WHICH IS DECLARED HERE
///  RATHER THAN LEFT TO BE DISCOVERED. A TValue that carries NO TYPE used to
///  be REFUSED and is now served the WHOLE TABLE. Measured base x HEAD through
///  TCommandSelecter.GenerateSelectID, twelve shapes, and only these moved:
///    * typeless TValue (TValue.Empty, Default(TValue)):
///        0103408 RAISED "an id was supplied carrying no values"
///        -> here  SELECT ... FROM keyonly, no predicate
///    * Integer -1 / Int64 -1 / String '-1': whole table -> real predicate
///    * UInt64 High(UInt64):                 whole table -> real predicate
///  The first is the cost, the rest are the repair. The reason the old code
///  refused a typeless value is incidental and worth knowing: TValue.IsType<T>
///  answers True for one, so _KeyValues took the TArray<TValue> arm and handed
///  back an EMPTY array, which the #326 guard then caught.
///  Two things keep the exposure small, and neither is a guard: the REST route
///  always arrives as AQuery.ID.ToString, a typed String and never a typeless
///  value; and this method is reached only from the SELECT family - DELETE
///  does not pass through GetGeneratorWhere at all. It is pinned by
///  Test.Janus.DML.KeyPredicate's TypelessTValue_MeansEveryRow_AndThatIs-
///  Deliberate so it cannot drift back in silence.
///
///  ONE MINE THE OLD DESIGN CARRIED AND THIS ONE DOES NOT. Because the test
///  was BY VALUE, a legitimate 64-bit key could be swallowed: the UInt64 arm
///  asked TryAsType<Int64> = -1, so High(UInt64) - every bit set, an ordinary
///  key - was read as "no id" and returned the whole table. MEASURED on
///  0103408, shape 05 of the board above. With no value test left, the shape
///  cannot recur.
///
///  THE TWO CALLERS THAT REALLY MEAN "EVERYTHING" WERE ENUMERATED AND MOVED,
///  and they are the only two in this repository: TCommandSelecter's
///  GenerateSelectAll (Janus.Command.Selecter.pas:129) and its
///  GenerateNextPacket overload (:175), both now passing TValue.Empty. The
///  third site in the family, GenerateSelectID (:167), passes -1 as PAGE SIZE
///  and a real id, and is untouched. Test.Janus.DML.Dialect.Wiring's SelectOf
///  helper is the only clause that asked the generator for "everything" by
///  hand and it moved with them. WHETHER ANYONE OUTSIDE THIS REPOSITORY CALLS
///  GeneratorSelectAll WITH -1 IS NOT MEASURABLE FROM HERE AND IS NOT
///  MEASURED - the same exposure the composite-key repair declared thirty
///  lines up.
///
///  THE SIBLING SENTINEL WAS FOUND AND MOVED WITH IT: TDMLGeneratorNoSQL
///  spelled the same test as `AID.ToString <> '-1'`
///  (Janus.DML.Generator.NoSQL.pas), an independent copy this issue did not
///  name. It now asks the same question this method does.
///
///  THE TEST IS `TypeInfo = nil` AND NOT `TValue.IsEmpty`, AND THE DIFFERENCE
///  WAS MEASURED, NOT REASONED. The first draft of this method asked
///  AID.IsEmpty, which reads well and is WRONG: the RTL answers True there for
///  an empty DYNAMIC ARRAY and for an empty STRING as well as for a typeless
///  value. That let the two #326 clauses through -
///  Test.Janus.DML.KeyPredicate's EmptyValueArray_IsRefusedInsteadOfMatching-
///  EveryRow and EmptyValueArray_OnTheOpenChain_IsRefusedNotAWholeTableRead
///  both went RED with "Method did not throw any exceptions", because Find([])
///  was being read as "no id" and skipping the very refusal they certify. A
///  typeless TValue is the only shape no caller supplying an id can produce;
///  an empty array and an empty string are ids that name nothing, and those
///  belong to the guards below. </summary>
function TDMLGeneratorAbstract._NoIdSupplied(const AID: TValue): Boolean;
begin
  Result := AID.TypeInfo = nil;
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
         // guardas locais, que a issue #326 empurrou para baixo ao crescer esta
         // unit. A licao estava escrita na mesma frase que a ignorava, e o
         // numero NOVO tambem nao e escrito aqui: ele ja teria apodrecido uma
         // vez dentro desta mesma frente.
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

/// <summary> THE READ SIDE OF ONE REFUSAL THAT NOW HAS FOUR CALL SITES.
///  Issue #294.
///
///  The mechanism, the reason it is a refusal rather than a feature, and the
///  measurement that would lift it all live in ONE place -
///  TGuidOctetRefusal in Janus.DML.Commands - because the three write commands
///  need the same answer and could not reach it here: this method is private,
///  and they hold the generator only as IDMLGeneratorCommand. What stays here
///  is the operation phrase, which is the only thing that differs between the
///  four call sites. </summary>
procedure TDMLGeneratorAbstract._GuardStoreGUIDAsOctet(AProperty: TRttiProperty);
begin
  TGuidOctetRefusal.Check(FConnection, AProperty,
    'num WHERE de associacao (geracao de SELECT)');
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
  LMarker: String;
  LMarkers: TArray<String>;
  LValueRegion: String;
  LWhole: String;
begin
  Result := '';
  if AModifiedFields.Count = 0 then
    Exit;
  // Varre a lista de campos alterados para montar o UPDATE
  LTable := TMappingExplorer.GetMappingTable(AObject.ClassType);
  LSQL := CreateFluentSQL.Update(LTable.Name);
  LMarkers := nil;
  for LColumnName in AModifiedFields.Values do
  begin
    // SET Field=Value alterado
    // <exception cref="oTable.Name + '.'"></exception>
    LMarker := ':' + LColumnName;
    LSQL.SetValue(LColumnName, [LMarker]);
    LMarkers := LMarkers + [LMarker];
  end;
  /// THE STATEMENT IS RENDERED HERE, BEFORE THE KEY PREDICATE EXISTS, AND THAT
  /// IS THE WHOLE POINT. Issue #337.
  ///
  /// Where(String) is the EXPRESSION overload: it allocates no bind and the
  /// text reaches the SQL verbatim - which is right, because the key predicate
  /// is Janus's own marker and has to stay named. But it means the finished
  /// statement carries TWO KINDS of ':' token that are indistinguishable as
  /// text: the ':pN' FluentSQL allocated for the SET slot, and whatever
  /// ':column' this loop wrote. A key column called `p1` collides head-on -
  /// measured, before this split existed:
  ///     UPDATE r337pk SET nm = :nm WHERE p1 = :nm
  /// The key was compared against the NEW VALUE OF ANOTHER COLUMN, the p1 bind
  /// was left orphaned, and nothing raised: the update reaches zero rows, or
  /// the wrong ones. `p1` is a legal identifier in every engine Janus speaks.
  ///
  /// So the rewrite is never allowed to see the predicate. Rendering before
  /// the Where gives the value region EXACTLY as FluentSQL spells it, with no
  /// SQL parsing and no guess about where SET ends: only ':pN' can appear in
  /// it, because SetValue puts the marker in as a bind VALUE and never as
  /// text. The tail is then carried over untouched.
  ///
  /// THAT THE FIRST RENDER IS A PREFIX OF THE SECOND IS MEASURED, NOT ASSUMED
  /// - by FluentSQLRendersTheValueRegionAsAPrefixOfTheWholeUpdate in
  /// Test.Janus.DML.Generator.SQLite - and it is CHECKED again below on every
  /// call, because it is a property of THEIR serializer and not of ours. If it
  /// ever stops holding, this refuses by name rather than splicing two strings
  /// that no longer line up.
  LValueRegion := LSQL.AsString;
  for LFor := 0 to AParams.Count -1 do
    LSQL.Where(AParams.Items[LFor].Name + ' = :' + AParams.Items[LFor].Name);
  LWhole := LSQL.AsString;
  Result := _SpliceRestoredValueRegion(LValueRegion, LWhole, LSQL.Params, LMarkers);
end;

function TDMLGeneratorAbstract._RestoreNamedPlaceholders(const ASQL: String;
  const AParams: IFluentSQLParams;
  const AMarkers: TArray<String>): String;
var
  LMap: TDictionary<String, String>;
  LFor: Integer;
  LWritten: Integer;
  LBound: String;
  LPos: Integer;
  LStart: Integer;
  LStop: Integer;
  LLength: Integer;
  LName: String;
  LMarker: String;
  LBuilder: TStringBuilder;
begin
  Result := ASQL;
  if Length(AMarkers) = 0 then
    Exit;
  if AParams = nil then
    LFor := -1
  else
    LFor := AParams.Count;
  if LFor <> Length(AMarkers) then
    raise Exception.CreateFmt(
      'Janus asked the FluentSQL value slot for %d bind(s) and it allocated %d. ' +
      'Issue #337: the named marker can only be restored over binds this ' +
      'generator itself created. SQL=[%s]',
      [Length(AMarkers), LFor, ASQL]);
  LMap := TDictionary<String, String>.Create;
  try
    for LFor := 0 to AParams.Count - 1 do
    begin
      LBound := VarToStr(AParams[LFor].Value);
      if LBound <> AMarkers[LFor] then
        raise Exception.CreateFmt(
          'Bind [%s] of the FluentSQL value slot carries [%s] and this ' +
          'generator put [%s] there. Issue #337: a bind holding REAL data keeps ' +
          'its :pN - inlining it into the SQL text is the injection FluentSQL ' +
          'closed. SQL=[%s]',
          [AParams[LFor].Name, LBound, AMarkers[LFor], ASQL]);
      LMap.AddOrSetValue(AParams[LFor].Name, AMarkers[LFor]);
    end;
    /// ONE left-to-right pass, never a ReplaceStr sweep. A sweep of ':p1' would
    /// also eat the head of ':p10', and a marker written back could itself be
    /// re-read by a later pass if a column happened to be called P1. Emitting
    /// into a builder means what is written is never scanned again.
    LBuilder := TStringBuilder.Create;
    try
      LLength := Length(ASQL);
      LPos := 1;
      LWritten := 0;
      while LPos <= LLength do
      begin
        if ASQL[LPos] <> ':' then
        begin
          LBuilder.Append(ASQL[LPos]);
          Inc(LPos);
          Continue;
        end;
        LStart := LPos + 1;
        LStop := LStart;
        while (LStop <= LLength) and
              CharInSet(ASQL[LStop], ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
          Inc(LStop);
        LName := Copy(ASQL, LStart, LStop - LStart);
        if (LName <> '') and LMap.TryGetValue(LName, LMarker) then
        begin
          LBuilder.Append(LMarker);
          Inc(LWritten);
        end
        else
          LBuilder.Append(Copy(ASQL, LPos, LStop - LPos));
        LPos := LStop;
      end;
      /// THE REWRITE HAS TO HAVE HAPPENED. Issue #337.
      ///
      /// Counting the binds is not the same as counting the SUBSTITUTIONS, and
      /// the difference is a silent one: if the rendered text carries no ':pN'
      /// at all, every check above still passes - the binds were allocated,
      /// they carry what this generator put there - and the SQL is returned
      /// with no marker any consumer can bind to. The DML would go out with the
      /// value slots empty and nothing would say so.
      ///
      /// THAT IS NOT HYPOTHETICAL, IT IS ONE `IF` AWAY. FluentSQL's MySQL
      /// serializer rewrites every ':pN' to '?' before returning
      /// (FluentSQL.SerializeMySQL.pas:52, a StringReplace over the whole
      /// string), and their UNION merge renumbers ':pN' to ':pM'
      /// (FluentSQL.Serialize.pas:58-62). Neither reaches Janus TODAY.
      ///
      /// THE SENTENCE THAT USED TO FOLLOW IS OUT OF DATE AND IS REPLACED RATHER
      /// THAN DELETED. It said the reason was "itself a defect rather than a
      /// design: only two of the twelve dialect generators call
      /// ConfigureFluentSQLDriver - SQLite and Firebird - so every other one
      /// renders through the enum's zero value, dbnMSSQL", and it predicted
      /// that "the day somebody repairs THAT, the MySQL generator starts
      /// serializing as MySQL, and without this count the DML of MySQL and
      /// MariaDB breaks WITHOUT A WORD".
      ///
      /// THAT DAY WAS ISSUE #355, AND THE PREDICTION WAS RIGHT. The wiring is
      /// now declared per generator by SerializationDialect, and pointing the
      /// MySQL one at dbnMySQL was MEASURED to land exactly here: "allocated 2
      /// bind(s) but only 0 marker(s) could be put back" on GeneratorInsert,
      /// and 1 of 1 on GeneratorUpdate. Which is why the MySQL generator still
      /// answers dbnMSSQL and says so in its own override - the count caught
      /// the repair, the repair did not quietly walk past the count.
      if LWritten <> Length(AMarkers) then
        raise Exception.CreateFmt(
          'The FluentSQL value slot allocated %d bind(s) but only %d marker(s) ' +
          'could be put back: the rendered SQL does not carry the ":pN" this ' +
          'generator was told to expect. Issue #337: a statement whose value ' +
          'slots no consumer can bind to must not be returned. SQL=[%s]',
          [Length(AMarkers), LWritten, ASQL]);
      Result := LBuilder.ToString;
    finally
      LBuilder.Free;
    end;
  finally
    LMap.Free;
  end;
end;

function TDMLGeneratorAbstract._SpliceRestoredValueRegion(const AValueRegion,
  AWholeStatement: String; const AParams: IFluentSQLParams;
  const AMarkers: TArray<String>): String;
begin
  if Copy(AWholeStatement, 1, Length(AValueRegion)) <> AValueRegion then
    raise Exception.CreateFmt(
      'The FluentSQL statement no longer starts with what it rendered before ' +
      'the verbatim clauses were added, so the value region cannot be told ' +
      'from the verbatim one. Issue #337. region=[%s] whole=[%s]',
      [AValueRegion, AWholeStatement]);
  Result := _RestoreNamedPlaceholders(AValueRegion, AParams, AMarkers) +
            Copy(AWholeStatement, Length(AValueRegion) + 1, MaxInt);
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
