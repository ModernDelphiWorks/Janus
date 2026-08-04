{
  ------------------------------------------------------------------------------
  Janus
  Modern Object-Relational Mapping (ORM) framework for Delphi.

  SPDX-License-Identifier: MIT
  Copyright (c) 2016-2026 Isaque Pinheiro

  Licensed under the MIT License.
  See the LICENSE file in the project root for full license information.
  ------------------------------------------------------------------------------
}

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Test.Janus.FluentSQL.Integration;

interface

uses
  SysUtils,
  Variants,
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
    class function MapDriver(const AGeneratorDriver: TDriverName): TFluentSQLDriver;
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
  strict private
    // FluentSQL binds every scalar as a :pN placeholder instead of inlining the
    // literal into the SQL text (FluentSQL.Params.pas TFluentSQLParams.Add,
    // FluentSQL.Serialize.pas). Asserting the literal in the SQL would assert the
    // injection-prone form. These helpers assert the two halves that together
    // prove the value survived the round trip: the placeholder is in the SQL and
    // the value is bound to that exact placeholder name.
    procedure _AssertParamCount(const AParams: IFluentSQLParams;
      const AExpected: Integer);
    procedure _AssertParamStr(const AParams: IFluentSQLParams;
      const AIndex: Integer; const AName: string; const AValue: string);
    procedure _AssertParamInt(const AParams: IFluentSQLParams;
      const AIndex: Integer; const AName: string; const AValue: Integer);
    procedure _AssertParamFloat(const AParams: IFluentSQLParams;
      const AIndex: Integer; const AName: string; const AValue: Double);
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
    // KNOWN DEFECT, see the implementation of both: these two consecrate the
    // CURRENT (broken) EXISTS serialization. They must be DELETED, not repaired,
    // by whoever fixes FluentSQL.
    [Test] procedure TestWhereExists_CurrentlyBindsSubqueryAsParameter_KNOWN_DEFECT;
    [Test] procedure TestWhereNotExists_CurrentlyBindsSubqueryAsParameter_KNOWN_DEFECT;
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
  const AGeneratorDriver: TDriverName): TFluentSQLDriver;
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

{ TTestFluentSQLIntegration }

procedure TTestFluentSQLIntegration._AssertParamCount(
  const AParams: IFluentSQLParams; const AExpected: Integer);
begin
  Assert.IsNotNull(AParams, 'The statement must expose its bind parameter list');
  Assert.AreEqual(AExpected, AParams.Count,
    Format('Expected %d bound parameter(s), got %d', [AExpected, AParams.Count]));
end;

procedure TTestFluentSQLIntegration._AssertParamStr(
  const AParams: IFluentSQLParams; const AIndex: Integer;
  const AName: string; const AValue: string);
begin
  Assert.AreEqual(AName, AParams[AIndex].Name,
    Format('Bound parameter #%d must be named "%s"', [AIndex, AName]));
  Assert.AreEqual(AValue, VarToStr(AParams[AIndex].Value),
    Format('Parameter ":%s" must carry the value "%s"', [AName, AValue]));
end;

procedure TTestFluentSQLIntegration._AssertParamInt(
  const AParams: IFluentSQLParams; const AIndex: Integer;
  const AName: string; const AValue: Integer);
var
  LActual: Integer;
begin
  Assert.AreEqual(AName, AParams[AIndex].Name,
    Format('Bound parameter #%d must be named "%s"', [AIndex, AName]));
  LActual := AParams[AIndex].Value;
  Assert.AreEqual(AValue, LActual,
    Format('Parameter ":%s" must carry the value %d', [AName, AValue]));
end;

procedure TTestFluentSQLIntegration._AssertParamFloat(
  const AParams: IFluentSQLParams; const AIndex: Integer;
  const AName: string; const AValue: Double);
var
  LActual: Double;
begin
  Assert.AreEqual(AName, AParams[AIndex].Name,
    Format('Bound parameter #%d must be named "%s"', [AIndex, AName]));
  LActual := AParams[AIndex].Value;
  Assert.AreEqual(AValue, LActual, 0.0000001,
    Format('Parameter ":%s" must carry the value %g', [AName, AValue]));
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
  LCQ: IFluentSQL;
  LSQL: string;
begin
  LCQ := TCQ(dbnSQLite).Select('*').From('clientes').Where('status').Equal('ativo');
  LSQL := LCQ.AsString;

  Assert.Contains(LSQL, 'status');
  Assert.Contains(LSQL, 'status = :p1',
    'the predicate must be bound to a placeholder, not to an inlined literal');
  Assert.DoesNotContain(LSQL, 'ativo',
    'the value must never be inlined into the SQL text');

  _AssertParamCount(LCQ.Params, 1);
  _AssertParamStr(LCQ.Params, 0, 'p1', 'ativo');
end;

procedure TTestFluentSQLIntegration.TestWhereEqualInteger_SerializesPredicate;
var
  LCQ: IFluentSQL;
  LSQL: string;
begin
  LCQ := TCQ(dbnSQLite).Select('*').From('clientes').Where('id').Equal(9);
  LSQL := LCQ.AsString;

  Assert.Contains(LSQL, 'id');
  Assert.Contains(LSQL, 'id = :p1',
    'the predicate must be bound to a placeholder, not to an inlined literal');
  Assert.DoesNotContain(LSQL, '9',
    'the value must never be inlined into the SQL text');

  _AssertParamCount(LCQ.Params, 1);
  _AssertParamInt(LCQ.Params, 0, 'p1', 9);
end;

procedure TTestFluentSQLIntegration.TestWhereNotEqualString_SerializesPredicate;
var
  LCQ: IFluentSQL;
  LSQL: string;
begin
  LCQ := TCQ(dbnSQLite).Select('*').From('clientes').Where('status').NotEqual('inativo');
  LSQL := LCQ.AsString;

  Assert.Contains(LSQL, '<>');
  Assert.Contains(LSQL, 'status <> :p1',
    'the predicate must be bound to a placeholder, not to an inlined literal');
  Assert.DoesNotContain(LSQL, 'inativo',
    'the value must never be inlined into the SQL text');

  _AssertParamCount(LCQ.Params, 1);
  _AssertParamStr(LCQ.Params, 0, 'p1', 'inativo');
end;

procedure TTestFluentSQLIntegration.TestWhereGreaterThanInteger_SerializesPredicate;
var
  LCQ: IFluentSQL;
  LSQL: string;
begin
  LCQ := TCQ(dbnSQLite).Select('*').From('clientes').Where('idade').GreaterThan(18);
  LSQL := LCQ.AsString;

  Assert.Contains(LSQL, '>');
  Assert.Contains(LSQL, 'idade > :p1',
    'the predicate must be bound to a placeholder, not to an inlined literal');
  Assert.DoesNotContain(LSQL, '18',
    'the value must never be inlined into the SQL text');

  _AssertParamCount(LCQ.Params, 1);
  _AssertParamInt(LCQ.Params, 0, 'p1', 18);
end;

procedure TTestFluentSQLIntegration.TestWhereGreaterEqThanInteger_SerializesPredicate;
var
  LCQ: IFluentSQL;
  LSQL: string;
begin
  LCQ := TCQ(dbnSQLite).Select('*').From('clientes').Where('idade').GreaterEqThan(18);
  LSQL := LCQ.AsString;

  Assert.Contains(LSQL, '>=');
  Assert.Contains(LSQL, 'idade >= :p1',
    'the predicate must be bound to a placeholder, not to an inlined literal');
  Assert.DoesNotContain(LSQL, '18',
    'the value must never be inlined into the SQL text');

  _AssertParamCount(LCQ.Params, 1);
  _AssertParamInt(LCQ.Params, 0, 'p1', 18);
end;

procedure TTestFluentSQLIntegration.TestWhereLessThanInteger_SerializesPredicate;
var
  LCQ: IFluentSQL;
  LSQL: string;
begin
  LCQ := TCQ(dbnSQLite).Select('*').From('clientes').Where('idade').LessThan(65);
  LSQL := LCQ.AsString;

  Assert.Contains(LSQL, '<');
  Assert.Contains(LSQL, 'idade < :p1',
    'the predicate must be bound to a placeholder, not to an inlined literal');
  Assert.DoesNotContain(LSQL, '65',
    'the value must never be inlined into the SQL text');

  _AssertParamCount(LCQ.Params, 1);
  _AssertParamInt(LCQ.Params, 0, 'p1', 65);
end;

procedure TTestFluentSQLIntegration.TestWhereLessEqThanInteger_SerializesPredicate;
var
  LCQ: IFluentSQL;
  LSQL: string;
begin
  LCQ := TCQ(dbnSQLite).Select('*').From('clientes').Where('idade').LessEqThan(65);
  LSQL := LCQ.AsString;

  Assert.Contains(LSQL, '<=');
  Assert.Contains(LSQL, 'idade <= :p1',
    'the predicate must be bound to a placeholder, not to an inlined literal');
  Assert.DoesNotContain(LSQL, '65',
    'the value must never be inlined into the SQL text');

  _AssertParamCount(LCQ.Params, 1);
  _AssertParamInt(LCQ.Params, 0, 'p1', 65);
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
  LCQ: IFluentSQL;
  LSQL: string;
begin
  LCQ := TCQ(dbnSQLite).Select('*').From('clientes').Where('nome').LikeFull('ana');
  LSQL := LCQ.AsString;

  Assert.Contains(LSQL, 'LIKE');
  Assert.Contains(LSQL, 'nome like :p1',
    'the predicate must be bound to a placeholder, not to an inlined literal');
  Assert.DoesNotContain(LSQL, '%ana%',
    'the wildcard pattern must never be inlined into the SQL text');

  // the LikeFull wildcards belong to the BOUND value, not to the SQL text
  _AssertParamCount(LCQ.Params, 1);
  _AssertParamStr(LCQ.Params, 0, 'p1', '%ana%');
end;

procedure TTestFluentSQLIntegration.TestWhereLikeLeft_SerializesPredicate;
var
  LCQ: IFluentSQL;
  LSQL: string;
begin
  LCQ := TCQ(dbnSQLite).Select('*').From('clientes').Where('nome').LikeLeft('ana');
  LSQL := LCQ.AsString;

  Assert.Contains(LSQL, 'LIKE');
  Assert.Contains(LSQL, 'nome like :p1',
    'the predicate must be bound to a placeholder, not to an inlined literal');
  Assert.DoesNotContain(LSQL, '%ana',
    'the wildcard pattern must never be inlined into the SQL text');

  _AssertParamCount(LCQ.Params, 1);
  _AssertParamStr(LCQ.Params, 0, 'p1', '%ana');
end;

procedure TTestFluentSQLIntegration.TestWhereLikeRight_SerializesPredicate;
var
  LCQ: IFluentSQL;
  LSQL: string;
begin
  LCQ := TCQ(dbnSQLite).Select('*').From('clientes').Where('nome').LikeRight('ana');
  LSQL := LCQ.AsString;

  Assert.Contains(LSQL, 'LIKE');
  Assert.Contains(LSQL, 'nome like :p1',
    'the predicate must be bound to a placeholder, not to an inlined literal');
  Assert.DoesNotContain(LSQL, 'ana%',
    'the wildcard pattern must never be inlined into the SQL text');

  _AssertParamCount(LCQ.Params, 1);
  _AssertParamStr(LCQ.Params, 0, 'p1', 'ana%');
end;

procedure TTestFluentSQLIntegration.TestWhereInValuesStringArray_SerializesPredicate;
var
  LCQ: IFluentSQL;
  LSQL: string;
begin
  LCQ := TCQ(dbnSQLite).Select('*').From('clientes').Where('status')
    .InValues(TArray<String>.Create('ativo', 'pendente'));
  LSQL := LCQ.AsString;

  Assert.Contains(LSQL, 'IN');
  Assert.Contains(LSQL, 'status IN (:p1, :p2)',
    'every element of the IN list must get its own placeholder');
  Assert.DoesNotContain(LSQL, 'ativo',
    'the value must never be inlined into the SQL text');
  Assert.DoesNotContain(LSQL, 'pendente',
    'the value must never be inlined into the SQL text');

  _AssertParamCount(LCQ.Params, 2);
  _AssertParamStr(LCQ.Params, 0, 'p1', 'ativo');
  _AssertParamStr(LCQ.Params, 1, 'p2', 'pendente');
end;

procedure TTestFluentSQLIntegration.TestWhereNotInDoubleArray_SerializesPredicate;
var
  LCQ: IFluentSQL;
  LSQL: string;
begin
  LCQ := TCQ(dbnSQLite).Select('*').From('clientes').Where('nota')
    .NotIn(TArray<Double>.Create(1.5, 2.5));
  LSQL := LCQ.AsString;

  Assert.Contains(LSQL, 'NOT IN');
  Assert.Contains(LSQL, 'nota NOT IN (:p1, :p2)',
    'every element of the NOT IN list must get its own placeholder');
  Assert.DoesNotContain(LSQL, '1.5',
    'the value must never be inlined into the SQL text');
  Assert.DoesNotContain(LSQL, '2.5',
    'the value must never be inlined into the SQL text');

  _AssertParamCount(LCQ.Params, 2);
  _AssertParamFloat(LCQ.Params, 0, 'p1', 1.5);
  _AssertParamFloat(LCQ.Params, 1, 'p2', 2.5);
end;

// ============================================================================
// KNOWN DEFECT -- DELETE THIS TEST WHEN FluentSQL IS FIXED. DO NOT "REPAIR" IT.
//
// FluentSQL binds the EXISTS subquery as a STRING PARAMETER instead of inlining
// it in the SQL text. What it generates today, and what SQLite (the dialect this
// very test asks for) answers when the statement is executed:
//
//   generated : SELECT * FROM clientes WHERE (exists :p1)
//               with p1 = 'SELECT 1 FROM pedidos'
//               -> SQLite: syntax error near ":p1"   (rejected by the parser)
//
//   correct   : SELECT * FROM clientes WHERE (exists (SELECT 1 FROM pedidos))
//               -> SQLite: OK
//
// The assertions below are FAITHFUL to today's behaviour, which is why this test
// is green -- green here means "the defect is still exactly as catalogued", NOT
// "EXISTS works". The name says so out loud so the scoreboard cannot be misread.
//
// When FluentSQL starts inlining the subquery, this test WILL go red. That red is
// the FIX landing, not a regression: whoever fixes FluentSQL must DELETE this
// test (and its NOT EXISTS twin) and write a real one asserting the inlined
// subquery. Repairing the assertions in place would re-consecrate the defect.
// ============================================================================
procedure TTestFluentSQLIntegration.TestWhereExists_CurrentlyBindsSubqueryAsParameter_KNOWN_DEFECT;
var
  LCQ: IFluentSQL;
  LSQL: string;
begin
  LCQ := TCQ(dbnSQLite).Select('*').From('clientes').Where.Exists('SELECT 1 FROM pedidos');
  LSQL := LCQ.AsString;

  Assert.Contains(LSQL, 'EXISTS');
  Assert.Contains(LSQL, 'exists :p1',
    'the EXISTS operand is bound as a parameter by the current FluentSQL AST');
  Assert.DoesNotContain(LSQL, 'FROM pedidos',
    'the operand must not be inlined into the SQL text');

  _AssertParamCount(LCQ.Params, 1);
  _AssertParamStr(LCQ.Params, 0, 'p1', 'SELECT 1 FROM pedidos');
end;

// ============================================================================
// KNOWN DEFECT -- DELETE THIS TEST WHEN FluentSQL IS FIXED. DO NOT "REPAIR" IT.
// Twin of the EXISTS case above; same root cause, same disposal instruction.
//
//   generated : SELECT * FROM clientes WHERE (not exists :p1)
//               with p1 = 'SELECT 1 FROM pedidos'
//               -> SQLite: syntax error near ":p1"   (rejected by the parser)
//
//   correct   : SELECT * FROM clientes WHERE (not exists (SELECT 1 FROM pedidos))
//               -> SQLite: OK
//
// Green here means "the defect is still exactly as catalogued", NOT "NOT EXISTS
// works". When FluentSQL inlines the subquery this test goes red -- that red is
// the fix landing. Delete it then; do not adjust the assertions.
// ============================================================================
procedure TTestFluentSQLIntegration.TestWhereNotExists_CurrentlyBindsSubqueryAsParameter_KNOWN_DEFECT;
var
  LCQ: IFluentSQL;
  LSQL: string;
begin
  LCQ := TCQ(dbnSQLite).Select('*').From('clientes').Where.NotExists('SELECT 1 FROM pedidos');
  LSQL := LCQ.AsString;

  Assert.Contains(LSQL, 'NOT EXISTS');
  Assert.Contains(LSQL, 'not exists :p1',
    'the NOT EXISTS operand is bound as a parameter by the current FluentSQL AST');
  Assert.DoesNotContain(LSQL, 'FROM pedidos',
    'the operand must not be inlined into the SQL text');

  _AssertParamCount(LCQ.Params, 1);
  _AssertParamStr(LCQ.Params, 0, 'p1', 'SELECT 1 FROM pedidos');
end;

procedure TTestFluentSQLIntegration.TestInsertValuesString_SerializesStatement;
var
  LCQ: IFluentSQL;
  LSQL: string;
begin
  LCQ := TCQ(dbnSQLite).Insert.Into('clientes').Values('nome', 'Janus');
  LSQL := LCQ.AsString;

  Assert.Contains(LSQL, 'INSERT INTO clientes');
  Assert.Contains(LSQL, 'nome');
  Assert.Contains(LSQL, 'INSERT INTO clientes (nome) VALUES (:p1)',
    'the inserted value must be bound to a placeholder, not inlined');
  Assert.DoesNotContain(LSQL, 'Janus',
    'the value must never be inlined into the SQL text');

  _AssertParamCount(LCQ.Params, 1);
  _AssertParamStr(LCQ.Params, 0, 'p1', 'Janus');
end;

procedure TTestFluentSQLIntegration.TestInsertValuesArray_SerializesStatement;
var
  LCQ: IFluentSQL;
  LSQL: string;
begin
  LCQ := TCQ(dbnSQLite).Insert.Into('clientes').Values('idade', [21]);
  LSQL := LCQ.AsString;

  Assert.Contains(LSQL, 'INSERT INTO clientes');
  Assert.Contains(LSQL, 'idade');
  Assert.Contains(LSQL, 'INSERT INTO clientes (idade) VALUES (:p1)',
    'the inserted value must be bound to a placeholder, not inlined');
  Assert.DoesNotContain(LSQL, '21',
    'the value must never be inlined into the SQL text');

  _AssertParamCount(LCQ.Params, 1);
  _AssertParamInt(LCQ.Params, 0, 'p1', 21);
end;

procedure TTestFluentSQLIntegration.TestUpdateSetValueString_SerializesStatement;
var
  LCQ: IFluentSQL;
  LSQL: string;
begin
  LCQ := TCQ(dbnSQLite).Update('clientes').SetValue('nome', 'Janus').Where('id').Equal(1);
  LSQL := LCQ.AsString;

  Assert.Contains(LSQL, 'UPDATE clientes SET');
  Assert.Contains(LSQL, 'nome');
  Assert.Contains(LSQL, 'UPDATE clientes SET nome = :p1 WHERE (id = :p2)',
    'both the assigned value and the predicate value must be bound placeholders');
  Assert.DoesNotContain(LSQL, 'Janus',
    'the value must never be inlined into the SQL text');

  // p1 is added while building (SetValue), p2 while serializing (Where/Equal):
  // the ordinal binding must still line up with the placeholders in the SQL.
  _AssertParamCount(LCQ.Params, 2);
  _AssertParamStr(LCQ.Params, 0, 'p1', 'Janus');
  _AssertParamInt(LCQ.Params, 1, 'p2', 1);
end;

procedure TTestFluentSQLIntegration.TestUpdateSetValueInteger_SerializesStatement;
var
  LCQ: IFluentSQL;
  LSQL: string;
begin
  LCQ := TCQ(dbnSQLite).Update('clientes').SetValue('idade', 21).Where('id').Equal(1);
  LSQL := LCQ.AsString;

  Assert.Contains(LSQL, 'idade');
  Assert.Contains(LSQL, 'UPDATE clientes SET idade = :p1 WHERE (id = :p2)',
    'both the assigned value and the predicate value must be bound placeholders');
  Assert.DoesNotContain(LSQL, '21',
    'the value must never be inlined into the SQL text');

  _AssertParamCount(LCQ.Params, 2);
  _AssertParamInt(LCQ.Params, 0, 'p1', 21);
  _AssertParamInt(LCQ.Params, 1, 'p2', 1);
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
