unit TestCriteriaAdvanced;

interface

uses
  SysUtils,
  DUnitX.TestFramework,
  FluentSQL,
  FluentSQL.Interfaces;

type
  [TestFixture]
  TTestCriteriaAdvanced = class
  public
    [Test]
    procedure TestCriteria_WhereAnd_MultiplePredicates;
    [Test]
    procedure TestCriteria_WhereOr_AlternativePredicates;
    [Test]
    procedure TestCriteria_WhereLike_PatternMatch;
    [Test]
    procedure TestCriteria_WhereIn_ValueSet;
    [Test]
    procedure TestCriteria_WhereBetween_Range;
    [Test]
    procedure TestCriteria_OrderByMultiField;
    [Test]
    procedure TestCriteria_GroupBy_WithColumn;
    [Test]
    procedure TestCriteria_Where_NullCheck;
    [Test]
    procedure TestCriteria_CombinedFilters_ComplexQuery;
    [Test]
    procedure TestCriteria_Serialize_GeneratesValidSQL;
    [Test]
    procedure TestCriteria_EmptyWhere_NoFilter;
  end;

implementation

{ TTestCriteriaAdvanced }

procedure TTestCriteriaAdvanced.TestCriteria_WhereAnd_MultiplePredicates;
var
  LQuery: IFluentSQL;
  LSQL: String;
begin
  LQuery := TCQ(dbnSQLite);
  LQuery.Select('*')
    .From('clientes')
    .Where('status = ''ativo''')
    .AndOpe('idade > 18');
  LSQL := LQuery.AsString;
  Assert.Contains(LSQL, 'WHERE');
  Assert.Contains(LSQL, 'status');
  Assert.Contains(LSQL, 'AND');
  Assert.Contains(LSQL, 'idade');
end;

procedure TTestCriteriaAdvanced.TestCriteria_WhereOr_AlternativePredicates;
var
  LQuery: IFluentSQL;
  LSQL: String;
begin
  LQuery := TCQ(dbnSQLite);
  LQuery.Select('*')
    .From('clientes')
    .Where('tipo = ''PF''')
    .OrOpe('tipo = ''PJ''');
  LSQL := LQuery.AsString;
  Assert.Contains(LSQL, 'WHERE');
  Assert.Contains(LSQL, 'OR');
  Assert.Contains(LSQL, 'tipo');
end;

procedure TTestCriteriaAdvanced.TestCriteria_WhereLike_PatternMatch;
var
  LQuery: IFluentSQL;
  LSQL: String;
begin
  LQuery := TCQ(dbnSQLite);
  LQuery.Select('nome')
    .From('clientes')
    .Where('nome LIKE ''A%''');
  LSQL := LQuery.AsString;
  Assert.Contains(LSQL, 'LIKE');
  Assert.Contains(LSQL, 'A%');
end;

procedure TTestCriteriaAdvanced.TestCriteria_WhereIn_ValueSet;
var
  LQuery: IFluentSQL;
  LSQL: String;
begin
  LQuery := TCQ(dbnSQLite);
  LQuery.Select('*')
    .From('pedidos')
    .Where('status IN (''aberto'', ''pendente'', ''aprovado'')');
  LSQL := LQuery.AsString;
  Assert.Contains(LSQL, 'IN');
  Assert.Contains(LSQL, 'aberto');
  Assert.Contains(LSQL, 'pendente');
  Assert.Contains(LSQL, 'aprovado');
end;

procedure TTestCriteriaAdvanced.TestCriteria_WhereBetween_Range;
var
  LQuery: IFluentSQL;
  LSQL: String;
begin
  LQuery := TCQ(dbnSQLite);
  LQuery.Select('*')
    .From('vendas')
    .Where('valor BETWEEN 100 AND 500');
  LSQL := LQuery.AsString;
  Assert.Contains(LSQL, 'BETWEEN');
  Assert.Contains(LSQL, '100');
  Assert.Contains(LSQL, '500');
end;

procedure TTestCriteriaAdvanced.TestCriteria_OrderByMultiField;
var
  LQuery: IFluentSQL;
  LSQL: String;
begin
  LQuery := TCQ(dbnSQLite);
  LQuery.Select('*')
    .From('clientes')
    .OrderBy('nome')
    .OrderBy('cidade').Desc;
  LSQL := LQuery.AsString;
  Assert.Contains(LSQL, 'ORDER BY');
  Assert.Contains(LSQL, 'nome');
  Assert.Contains(LSQL, 'cidade');
  Assert.Contains(LSQL, 'DESC');
end;

procedure TTestCriteriaAdvanced.TestCriteria_GroupBy_WithColumn;
var
  LQuery: IFluentSQL;
  LSQL: String;
begin
  LQuery := TCQ(dbnSQLite);
  LQuery.Select('cidade').Select(LQuery.AsFun.Count('*'))
    .From('clientes')
    .GroupBy('cidade');
  LSQL := LQuery.AsString;
  Assert.Contains(LSQL, 'GROUP BY');
  Assert.Contains(LSQL, 'cidade');
  Assert.Contains(LSQL, 'Count(*)');
end;

procedure TTestCriteriaAdvanced.TestCriteria_Where_NullCheck;
var
  LQuery: IFluentSQL;
  LSQL: String;
begin
  LQuery := TCQ(dbnSQLite);
  LQuery.Select('*')
    .From('clientes')
    .Where('telefone IS NULL');
  LSQL := LQuery.AsString;
  Assert.Contains(LSQL, 'IS NULL');
end;

procedure TTestCriteriaAdvanced.TestCriteria_CombinedFilters_ComplexQuery;
var
  LQuery: IFluentSQL;
  LSQL: String;
begin
  LQuery := TCQ(dbnSQLite);
  LQuery.Select('*')
    .From('pedidos')
    .Where('status = ''ativo''')
    .AndOpe('valor > 100')
    .OrOpe('prioridade = ''alta''')
    .OrderBy('data_criacao').Desc;
  LSQL := LQuery.AsString;
  Assert.Contains(LSQL, 'WHERE');
  Assert.Contains(LSQL, 'AND');
  Assert.Contains(LSQL, 'OR');
  Assert.Contains(LSQL, 'ORDER BY');
  Assert.Contains(LSQL, 'DESC');
end;

procedure TTestCriteriaAdvanced.TestCriteria_Serialize_GeneratesValidSQL;
var
  LQuery: IFluentSQL;
  LSQL: String;
begin
  LQuery := TCQ(dbnSQLite);
  LQuery.Select('id').Select('nome').Select('email')
    .From('usuarios')
    .Where('ativo = 1')
    .AndOpe('idade >= 18')
    .OrderBy('nome');
  LSQL := LQuery.AsString;
  Assert.Contains(LSQL, 'SELECT');
  Assert.Contains(LSQL, 'id');
  Assert.Contains(LSQL, 'nome');
  Assert.Contains(LSQL, 'email');
  Assert.Contains(LSQL, 'FROM');
  Assert.Contains(LSQL, 'usuarios');
  Assert.Contains(LSQL, 'WHERE');
  Assert.Contains(LSQL, 'ORDER BY');
end;

procedure TTestCriteriaAdvanced.TestCriteria_EmptyWhere_NoFilter;
var
  LQuery: IFluentSQL;
  LSQL: String;
begin
  LQuery := TCQ(dbnSQLite);
  LQuery.Select('*')
    .From('clientes');
  LSQL := LQuery.AsString;
  Assert.Contains(LSQL, 'SELECT');
  Assert.Contains(LSQL, 'FROM');
  Assert.DoesNotContain(LSQL, 'WHERE');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestCriteriaAdvanced);

end.
