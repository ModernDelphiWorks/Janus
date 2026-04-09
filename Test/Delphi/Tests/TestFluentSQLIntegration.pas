unit TestFluentSQLIntegration;

interface

uses
  SysUtils,
  System.RTTI,
  DUnitX.TestFramework,
  FluentSQL,
  FluentSQL.Interfaces,
  DataEngine.FactoryInterfaces,
  Janus.DML.Commands,
  Janus.DML.Generator;

type
  TDMLGeneratorAccess = class(TDMLGeneratorAbstract)
  public
    class function MapDriver(const AGeneratorDriver: TDBEngineDriver): TFluentSQLDriver;
    function GeneratorSelectAll(AClass: TClass; APageSize: Integer;
      AID: TValue): String; override;
    function GeneratorSelectWhere(AClass: TClass; AWhere: String;
      AOrderBy: String; APageSize: Integer): String; override;
    function GeneratorAutoIncCurrentValue(AObject: TObject;
      AAutoInc: TDMLCommandAutoInc): Int64; override;
    function GeneratorAutoIncNextValue(AObject: TObject;
      AAutoInc: TDMLCommandAutoInc): Int64; override;
  end;

  [TestFixture]
  TTestFluentSQLIntegration = class
  public
    [Test] procedure TestSelectAll_BuildsSelectAndFrom;
    [Test] procedure TestSelectDistinct_AddsQualifier;
    [Test] procedure TestSelectColumnAlias_SerializesAlias;
    [Test] procedure TestFromAlias_SerializesAlias;
    [Test] procedure TestWhereEqualString_SerializesPredicate;
    [Test] procedure TestWhereEqualInteger_SerializesPredicate;
    [Test] procedure TestWhereNotEqualString_SerializesPredicate;
    [Test] procedure TestWhereGreaterThanInteger_SerializesPredicate;
    [Test] procedure TestWhereGreaterEqThanInteger_SerializesPredicate;
    [Test] procedure TestWhereLessThanInteger_SerializesPredicate;
    [Test] procedure TestWhereLessEqThanInteger_SerializesPredicate;
    [Test] procedure TestWhereIsNull_SerializesPredicate;
    [Test] procedure TestWhereIsNotNull_SerializesPredicate;
    [Test] procedure TestWhereLikeFull_SerializesPredicate;
    [Test] procedure TestWhereLikeLeft_SerializesPredicate;
    [Test] procedure TestWhereLikeRight_SerializesPredicate;
    [Test] procedure TestWhereInValuesStringArray_SerializesPredicate;
    [Test] procedure TestWhereNotInDoubleArray_SerializesPredicate;
    [Test] procedure TestWhereExists_SerializesPredicate;
    [Test] procedure TestWhereNotExists_SerializesPredicate;
    [Test] procedure TestInsertValuesString_SerializesStatement;
    [Test] procedure TestInsertValuesArray_SerializesStatement;
    [Test] procedure TestUpdateSetValueString_SerializesStatement;
    [Test] procedure TestUpdateSetValueInteger_SerializesStatement;
    [Test] procedure TestDeleteWhere_SerializesStatement;
    [Test] procedure TestInnerJoinAlias_SerializesJoin;
    [Test] procedure TestLeftJoinAlias_SerializesJoin;
    [Test] procedure TestGroupByHavingCount_SerializesClauses;
    [Test] procedure TestPaginationFirstSkip_SerializesQualifiers;
    [Test] procedure TestUpperAlias_SerializesFunction;
    [Test] procedure TestResolveFluentDriver_Firebird_MapsToFirebird;
    [Test] procedure TestResolveFluentDriver_Firebird3_MapsToFirebird;
    [Test] procedure TestResolveFluentDriver_Interbase_MapsToInterbase;
    [Test] procedure TestResolveFluentDriver_SQLite_MapsToSQLite;
    [Test] procedure TestResolveFluentDriver_MySQL_MapsToMySQL;
    [Test] procedure TestResolveFluentDriver_PostgreSQL_MapsToPostgreSQL;
    [Test] procedure TestResolveFluentDriver_MSSQL_MapsToMSSQL;
    [Test] procedure TestResolveFluentDriver_Oracle_MapsToOracle;
    [Test] procedure TestResolveFluentDriver_MongoDB_RaisesError;
  end;

implementation

{ TDMLGeneratorAccess }

class function TDMLGeneratorAccess.MapDriver(
  const AGeneratorDriver: TDBEngineDriver): TFluentSQLDriver;
begin
  Result := ResolveFluentSQLDriver(AGeneratorDriver);
end;

function TDMLGeneratorAccess.GeneratorAutoIncCurrentValue(AObject: TObject;
  AAutoInc: TDMLCommandAutoInc): Int64;
begin
  Result := 0;
end;

function TDMLGeneratorAccess.GeneratorAutoIncNextValue(AObject: TObject;
  AAutoInc: TDMLCommandAutoInc): Int64;
begin
  Result := 0;
end;

function TDMLGeneratorAccess.GeneratorSelectAll(AClass: TClass;
  APageSize: Integer; AID: TValue): String;
begin
  Result := '';
end;

function TDMLGeneratorAccess.GeneratorSelectWhere(AClass: TClass;
  AWhere, AOrderBy: String; APageSize: Integer): String;
begin
  Result := '';
end;

procedure TTestFluentSQLIntegration.TestSelectAll_BuildsSelectAndFrom;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Select('*').From('clientes').AsString;
  Assert.Contains(LSQL, 'SELECT');
  Assert.Contains(LSQL, 'FROM clientes');
end;

procedure TTestFluentSQLIntegration.TestSelectDistinct_AddsQualifier;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Select('nome').Distinct.From('clientes').AsString;
  Assert.Contains(LSQL, 'DISTINCT');
end;

procedure TTestFluentSQLIntegration.TestSelectColumnAlias_SerializesAlias;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Select('nome').Alias('nm').From('clientes').AsString;
  Assert.Contains(LSQL, 'AS nm');
end;

procedure TTestFluentSQLIntegration.TestFromAlias_SerializesAlias;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Select('*').From('clientes', 'c').AsString;
  Assert.Contains(LSQL, 'clientes');
  Assert.Contains(LSQL, 'c');
end;

procedure TTestFluentSQLIntegration.TestWhereEqualString_SerializesPredicate;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Select('*').From('clientes').Where('status').Equal('ativo').AsString;
  Assert.Contains(LSQL, 'status');
  Assert.Contains(LSQL, 'ativo');
end;

procedure TTestFluentSQLIntegration.TestWhereEqualInteger_SerializesPredicate;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Select('*').From('clientes').Where('id').Equal(9).AsString;
  Assert.Contains(LSQL, 'id');
  Assert.Contains(LSQL, '9');
end;

procedure TTestFluentSQLIntegration.TestWhereNotEqualString_SerializesPredicate;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Select('*').From('clientes').Where('status').NotEqual('inativo').AsString;
  Assert.Contains(LSQL, '<>');
  Assert.Contains(LSQL, 'inativo');
end;

procedure TTestFluentSQLIntegration.TestWhereGreaterThanInteger_SerializesPredicate;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Select('*').From('clientes').Where('idade').GreaterThan(18).AsString;
  Assert.Contains(LSQL, '>');
  Assert.Contains(LSQL, '18');
end;

procedure TTestFluentSQLIntegration.TestWhereGreaterEqThanInteger_SerializesPredicate;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Select('*').From('clientes').Where('idade').GreaterEqThan(18).AsString;
  Assert.Contains(LSQL, '>=');
  Assert.Contains(LSQL, '18');
end;

procedure TTestFluentSQLIntegration.TestWhereLessThanInteger_SerializesPredicate;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Select('*').From('clientes').Where('idade').LessThan(65).AsString;
  Assert.Contains(LSQL, '<');
  Assert.Contains(LSQL, '65');
end;

procedure TTestFluentSQLIntegration.TestWhereLessEqThanInteger_SerializesPredicate;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Select('*').From('clientes').Where('idade').LessEqThan(65).AsString;
  Assert.Contains(LSQL, '<=');
  Assert.Contains(LSQL, '65');
end;

procedure TTestFluentSQLIntegration.TestWhereIsNull_SerializesPredicate;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Select('*').From('clientes').Where('telefone').IsNull.AsString;
  Assert.Contains(LSQL, 'IS NULL');
end;

procedure TTestFluentSQLIntegration.TestWhereIsNotNull_SerializesPredicate;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Select('*').From('clientes').Where('telefone').IsNotNull.AsString;
  Assert.Contains(LSQL, 'IS NOT NULL');
end;

procedure TTestFluentSQLIntegration.TestWhereLikeFull_SerializesPredicate;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Select('*').From('clientes').Where('nome').LikeFull('ana').AsString;
  Assert.Contains(LSQL, 'LIKE');
  Assert.Contains(LSQL, '%ana%');
end;

procedure TTestFluentSQLIntegration.TestWhereLikeLeft_SerializesPredicate;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Select('*').From('clientes').Where('nome').LikeLeft('ana').AsString;
  Assert.Contains(LSQL, 'LIKE');
  Assert.Contains(LSQL, '%ana');
end;

procedure TTestFluentSQLIntegration.TestWhereLikeRight_SerializesPredicate;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Select('*').From('clientes').Where('nome').LikeRight('ana').AsString;
  Assert.Contains(LSQL, 'LIKE');
  Assert.Contains(LSQL, 'ana%');
end;

procedure TTestFluentSQLIntegration.TestWhereInValuesStringArray_SerializesPredicate;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Select('*').From('clientes').Where('status')
    .InValues(TArray<String>.Create('ativo', 'pendente')).AsString;
  Assert.Contains(LSQL, 'IN');
  Assert.Contains(LSQL, 'ativo');
  Assert.Contains(LSQL, 'pendente');
end;

procedure TTestFluentSQLIntegration.TestWhereNotInDoubleArray_SerializesPredicate;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Select('*').From('clientes').Where('nota')
    .NotIn(TArray<Double>.Create(1.5, 2.5)).AsString;
  Assert.Contains(LSQL, 'NOT IN');
  Assert.Contains(LSQL, '1.5');
  Assert.Contains(LSQL, '2.5');
end;

procedure TTestFluentSQLIntegration.TestWhereExists_SerializesPredicate;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Select('*').From('clientes').Where.Exists('SELECT 1 FROM pedidos').AsString;
  Assert.Contains(LSQL, 'EXISTS');
  Assert.Contains(LSQL, 'SELECT 1 FROM pedidos');
end;

procedure TTestFluentSQLIntegration.TestWhereNotExists_SerializesPredicate;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Select('*').From('clientes').Where.NotExists('SELECT 1 FROM pedidos').AsString;
  Assert.Contains(LSQL, 'NOT EXISTS');
  Assert.Contains(LSQL, 'SELECT 1 FROM pedidos');
end;

procedure TTestFluentSQLIntegration.TestInsertValuesString_SerializesStatement;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Insert.Into('clientes').Values('nome', 'Janus').AsString;
  Assert.Contains(LSQL, 'INSERT INTO clientes');
  Assert.Contains(LSQL, 'nome');
  Assert.Contains(LSQL, 'Janus');
end;

procedure TTestFluentSQLIntegration.TestInsertValuesArray_SerializesStatement;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Insert.Into('clientes').Values('idade', [21]).AsString;
  Assert.Contains(LSQL, 'INSERT INTO clientes');
  Assert.Contains(LSQL, 'idade');
  Assert.Contains(LSQL, '21');
end;

procedure TTestFluentSQLIntegration.TestUpdateSetValueString_SerializesStatement;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Update('clientes').SetValue('nome', 'Janus').Where('id').Equal(1).AsString;
  Assert.Contains(LSQL, 'UPDATE clientes SET');
  Assert.Contains(LSQL, 'nome');
  Assert.Contains(LSQL, 'Janus');
end;

procedure TTestFluentSQLIntegration.TestUpdateSetValueInteger_SerializesStatement;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Update('clientes').SetValue('idade', 21).Where('id').Equal(1).AsString;
  Assert.Contains(LSQL, 'idade');
  Assert.Contains(LSQL, '21');
end;

procedure TTestFluentSQLIntegration.TestDeleteWhere_SerializesStatement;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Delete.From('clientes').Where('id').Equal(1).AsString;
  Assert.Contains(LSQL, 'DELETE FROM clientes');
  Assert.Contains(LSQL, 'WHERE');
end;

procedure TTestFluentSQLIntegration.TestInnerJoinAlias_SerializesJoin;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Select('c.nome').From('clientes', 'c')
    .InnerJoin('pedidos', 'p').OnCond('p.cliente_id = c.id').AsString;
  Assert.Contains(LSQL, 'INNER JOIN pedidos');
  Assert.Contains(LSQL, 'p.cliente_id = c.id');
end;

procedure TTestFluentSQLIntegration.TestLeftJoinAlias_SerializesJoin;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Select('c.nome').From('clientes', 'c')
    .LeftJoin('enderecos', 'e').OnCond('e.cliente_id = c.id').AsString;
  Assert.Contains(LSQL, 'LEFT JOIN enderecos');
  Assert.Contains(LSQL, 'e.cliente_id = c.id');
end;

procedure TTestFluentSQLIntegration.TestGroupByHavingCount_SerializesClauses;
var
  LSQL: String;
  LCQ: IFluentSQL;
begin
  LCQ := TCQ(dbnSQLite);
  LSQL := LCQ.Select('cidade').Select(LCQ.AsFun.Count('*')).From('clientes')
    .GroupBy('cidade').Having('Count(*) > 1').AsString;
  Assert.Contains(LSQL, 'GROUP BY');
  Assert.Contains(LSQL, 'HAVING');
  Assert.Contains(LSQL, 'Count(*) > 1');
end;

procedure TTestFluentSQLIntegration.TestPaginationFirstSkip_SerializesQualifiers;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Select('*').From('clientes').First(10).Skip(20).AsString;
  Assert.Contains(LowerCase(LSQL), 'limit 10');
  Assert.Contains(LowerCase(LSQL), 'offset 20');
end;

procedure TTestFluentSQLIntegration.TestUpperAlias_SerializesFunction;
var
  LSQL: String;
begin
  LSQL := TCQ(dbnSQLite).Select('nome').Upper.Alias('nome_upper').From('clientes').AsString;
  Assert.Contains(LSQL, 'Upper(');
  Assert.Contains(LSQL, 'AS nome_upper');
end;

procedure TTestFluentSQLIntegration.TestResolveFluentDriver_Firebird_MapsToFirebird;
begin
  Assert.AreEqual(Ord(dbnFirebird),
    Ord(TDMLGeneratorAccess.MapDriver(dnFirebird)));
end;

procedure TTestFluentSQLIntegration.TestResolveFluentDriver_Firebird3_MapsToFirebird;
begin
  Assert.AreEqual(Ord(dbnFirebird),
    Ord(TDMLGeneratorAccess.MapDriver(dnFirebird3)));
end;

procedure TTestFluentSQLIntegration.TestResolveFluentDriver_Interbase_MapsToInterbase;
begin
  Assert.AreEqual(Ord(dbnInterbase),
    Ord(TDMLGeneratorAccess.MapDriver(dnInterbase)));
end;

procedure TTestFluentSQLIntegration.TestResolveFluentDriver_SQLite_MapsToSQLite;
begin
  Assert.AreEqual(Ord(dbnSQLite),
    Ord(TDMLGeneratorAccess.MapDriver(dnSQLite)));
end;

procedure TTestFluentSQLIntegration.TestResolveFluentDriver_MySQL_MapsToMySQL;
begin
  Assert.AreEqual(Ord(dbnMySQL),
    Ord(TDMLGeneratorAccess.MapDriver(dnMySQL)));
end;

procedure TTestFluentSQLIntegration.TestResolveFluentDriver_PostgreSQL_MapsToPostgreSQL;
begin
  Assert.AreEqual(Ord(dbnPostgreSQL),
    Ord(TDMLGeneratorAccess.MapDriver(dnPostgreSQL)));
end;

procedure TTestFluentSQLIntegration.TestResolveFluentDriver_MSSQL_MapsToMSSQL;
begin
  Assert.AreEqual(Ord(dbnMSSQL),
    Ord(TDMLGeneratorAccess.MapDriver(dnMSSQL)));
end;

procedure TTestFluentSQLIntegration.TestResolveFluentDriver_Oracle_MapsToOracle;
begin
  Assert.AreEqual(Ord(dbnOracle),
    Ord(TDMLGeneratorAccess.MapDriver(dnOracle)));
end;

procedure TTestFluentSQLIntegration.TestResolveFluentDriver_MongoDB_RaisesError;
var
  LErrorRaised: Boolean;
begin
  LErrorRaised := False;
  try
    TDMLGeneratorAccess.MapDriver(dnMongoDB);
  except
    on E: Exception do
      LErrorRaised := True;
  end;

  Assert.IsTrue(LErrorRaised);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestFluentSQLIntegration);

end.