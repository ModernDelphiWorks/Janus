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

{ @abstract(Janus Framework - the width of the by-id API. Issue #333.)

  THE DATASET AND REST BY-ID API TOOK AN Integer WHILE EVERYTHING BELOW IT
  ALREADY TOOK Int64. TSessionAbstract<M>.Find has taken Int64 since #324, and
  TDataSetBaseAdapter<M>.Find(Integer) did nothing but `Result :=
  FSession.Find(AID)` - so the 32-bit limit lived ONLY in the public entry
  point. Same for the Open chain: OpenIDInternal takes a TValue and
  TSessionAbstract<M>.OpenID takes a TValue, and TContainerDataSet<M>.Open
  narrowed to Integer on the way in.

  WHAT THAT COST, MEASURED ON 0546a51 - AND THE FIRST VERSION OF THIS
  PARAGRAPH WAS WRONG, WHICH IS WHY IT IS SPELLED OUT. It predicted that
  Delphi would accept the Int64 argument into the Integer parameter and
  TRUNCATE it silently, putting `WHERE bigkey.bkid = 704906752` - the low 32
  bits of 5000000000 - into the SQL. THE RUN SAID OTHERWISE. All three wide
  clauses ERRORED on the unwidened tree with

    Range check error

  and none of them ever reached an assertion, so no truncated literal was ever
  observed and this fixture does not claim one. The reason is in the .dproj:
  every test project here builds Debug with DCC_RangeChecking true, so the
  narrowing conversion is checked and raises. What the truncation does with
  range checking OFF - the configuration a consumer's own release build uses -
  was NOT MEASURED and is not asserted anywhere below.

  EITHER WAY THE API COULD NOT EXPRESS A 64-BIT KEY, which is the claim that
  survives and the one the clauses hold: on the unwidened tree the three wide
  clauses were red (Error), and the Integer control was green. After the
  widening all four are green.

  WHY Int64 AND NOT AN OVERLOAD. An overload pair Find(Integer)/Find(Int64) is
  AMBIGUOUS at every untyped call site in Delphi - `Find(10)` cannot pick one -
  so the existing consumers that pass a literal would stop compiling, which is
  the opposite of the intent. Widening the single parameter keeps every one of
  them compiling: an Integer argument promotes to Int64 losslessly. That is
  what IntegerLiteral_StillCompilesAndIsUnchanged holds down, and it is not
  decoration - it is the clause that would have caught the overload design.

  TWO VALUES, NOT ONE. A single wide constant would pass against a body that
  hard-coded it, so both wide clauses use a different constant and each one is
  chosen so that its low 32 bits differ from the whole - a value whose
  truncation happened to equal itself would measure nothing.

  THE OTHER HALF: A GUARD THAT ADMITS 64 BITS AND A BODY THAT READS 32.
  TDataSetBaseAdapter<M>._AutoIncKeyIsGenerated and
  TRESTDataSetAdapter<M>._RowKeyIsUngenerated both admit ftLargeint through
  cINTEGERKINDS and then compared `LField.AsInteger = cAutoIncNotGenerated`,
  where cAutoIncNotGenerated is -1. On a 64-bit key column that is a false
  positive waiting to happen: the perfectly ordinary key 4294967295
  ($FFFFFFFF) reads back as -1 and the row is declared `key not generated`,
  so a key that EXISTS is silently not cascaded to the children. Both now read
  AsLargeInt. The third narrowing, TSessionRestFul<M>.Delete(const AObject: M),
  took the first primary key column's value with .AsInteger and now takes
  .AsInt64.

  AND HERE TRUNCATION REALLY IS SILENT, WHICH IS NOT A CONTRADICTION OF THE
  PARAGRAPH ABOVE. Two different narrowings behave differently and both were
  measured. Passing an Int64 ARGUMENT into an Integer PARAMETER is a
  compiler-inserted conversion, and DCC_RangeChecking is true in these Debug
  builds, so it RAISES - that is the three wide clauses. Reading
  TLargeintField.AsInteger is an RTL cast: GetAsInteger returns `Integer(L)`,
  read in the Studio 37.0 RTL source and written up over
  TBind._SetFieldToPropertyInteger under #324, and NOTHING checks it. So the
  guard's truncation is silent even with range checking on, which is why
  WideAutoIncKey_ThatTruncatesToThePlaceholder_IsStillPropagated fails on a
  value assertion rather than erroring.

  THE SIBLING GUARD IS A DECLARED SURVIVOR. The same revert applied to
  TRESTDataSetAdapter<M>._RowKeyIsUngenerated, tripwire echoed as W1054, left
  Janus.Tests.RESTfulDriver at 134/0/0 - nothing dies. It is reachable only
  from a REST adapter over a model with an autoinc ftLargeint PRIMARY KEY, and
  a fixture for that has to be registered in Janus.Tests.RESTfulDriver.dpr,
  which the #323 frontier is editing. Left alone deliberately, not overlooked.
}

unit Test.Janus.KeyWidth.ByIdApi;

interface

uses
  DB,
  Rtti,
  Classes,
  SysUtils,
  Generics.Collections,
  DUnitX.TestFramework,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Param,
  FireDAC.Stan.Error,
  FireDAC.DatS,
  FireDAC.Phys.Intf,
  FireDAC.DApt.Intf,
  FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,
  DataEngine.FactoryInterfaces,
  MetaDbDiff.Mapping.Attributes,
  MetaDbDiff.Mapping.Register,
  MetaDbDiff.Types.Mapping,
  Janus.Container.FDMemTable,
  Janus.Container.DataSet.Interfaces,
  Janus.DataSet.Base.Adapter,
  Janus.DataSet.FDMemTable,
  Test.Janus.Cursor.Double;

type
  /// A primary key that does not fit in 32 bits. ftLargeint is already in
  /// cINTEGERKINDS, so the guards that gate the placeholder check let this
  /// column through - which is the point of the second half of this fixture.
  [Entity]
  [Table('bigkey', '')]
  [PrimaryKey('bkid', TAutoIncType.NotInc, TGeneratorType.NoneInc,
              TSortingOrder.NoSort, True, 'Wide primary key')]
  TBigKeyRow = class
  private
    Fbkid: Int64;
    Fbktag: String;
  public
    [Column('bkid', ftLargeint)]
    property bkid: Int64 read Fbkid write Fbkid;
    [Column('bktag', ftString, 20)]
    property bktag: String read Fbktag write Fbktag;
  end;

  /// THE CASCADE SHAPE, and it exists for one clause. To reach
  /// TDataSetBaseAdapter<M>._AutoIncKeyIsGenerated - which is private, so no
  /// descendant can call it - the key must be an AUTOINC ftLargeint column
  /// carried by an association the cascade walks. No model in the tree had
  /// that combination, which is exactly why the narrowing survived unnoticed.
  [Entity]
  [Table('wkchild', '')]
  [PrimaryKey('wc_id', TAutoIncType.NotInc, TGeneratorType.NoneInc,
              TSortingOrder.NoSort, True, 'Primary key')]
  TWkChild = class
  private
    Fwc_id: Integer;
    Fwk_id: Int64;
  public
    [Column('wc_id', ftInteger)]
    property wc_id: Integer read Fwc_id write Fwc_id;
    [Column('wk_id', ftLargeint)]
    property wk_id: Int64 read Fwk_id write Fwk_id;
  end;

  [Entity]
  [Table('wkroot', '')]
  /// AUTOINC, so the placeholder reading applies - and ftLargeint, so
  /// cINTEGERKINDS admits it and the body has to read all 64 bits back.
  [PrimaryKey('wk_id', TAutoIncType.AutoInc, TGeneratorType.NoneInc,
              TSortingOrder.NoSort, True, 'Wide autoinc primary key')]
  TWkRoot = class
  private
    Fwk_id: Int64;
    Fchilds: TObjectList<TWkChild>;
  public
    constructor Create;
    destructor Destroy; override;
    [Column('wk_id', ftLargeint)]
    property wk_id: Int64 read Fwk_id write Fwk_id;
    [Association(TMultiplicity.OneToMany, 'wk_id', 'wkchild', 'wk_id')]
    [CascadeActions([TCascadeAction.CascadeAutoInc,
                     TCascadeAction.CascadeInsert,
                     TCascadeAction.CascadeUpdate,
                     TCascadeAction.CascadeDelete])]
    property childs: TObjectList<TWkChild> read Fchilds write Fchilds;
  end;

  /// <summary> The usual protected-access descendant: SetAutoIncValueChilds
  /// is protected and is the ONLY caller of the private
  /// _AutoIncKeyIsGenerated, so this is how the guard is reached at all.
  /// Same shape as TCascadeAccess in Test.Janus.AutoInc.Distribution. </summary>
  TWideCascadeAccess<M: class, constructor> = class(TDataSetBaseAdapter<M>)
  public
    class procedure Propagate(const A: TDataSetBaseAdapter<M>);
  end;

  [TestFixture]
  TTestKeyWidthByIdApi = class
  private
    FRows: TRowsConnection;
    FConn: IDBConnection;
    FTable: TFDMemTable;
    function NewContainer(const AKey: Int64): IContainerDataSet<TBigKeyRow>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// THE Find CHAIN. 5000000000 is $12A05F200; truncated to 32 bits it is
    /// 704906752, which is what the unwidened tree emitted.
    [Test]
    procedure Find_WithAKeyBeyond32Bits_ReachesTheWhereIntact;
    /// THE Open CHAIN, which is a different path entirely - OpenIDInternal
    /// and TSessionDataSet<M>.OpenID, not TSessionAbstract<M>.Find - and it
    /// narrowed in the same place. A SECOND wide constant: 8589934591 is
    /// $1FFFFFFFF, whose low 32 bits are 4294967295.
    [Test]
    procedure Open_WithAKeyBeyond32Bits_ReachesTheWhereIntact;
    /// THE CONTROL, AND THE CLAUSE THAT REJECTS THE OVERLOAD DESIGN. An
    /// Integer literal must still compile at the call site and must still
    /// produce the same predicate it always did. With Find(Integer) and
    /// Find(Int64) both present this line is ambiguous and does not compile.
    [Test]
    procedure IntegerLiteral_StillCompilesAndIsUnchanged;
    /// A NEGATIVE wide key, because Int64 is signed and the -1 placeholder
    /// lives in the same space. -5000000000 must reach the predicate whole
    /// and must NOT be mistaken for the -1 the generator treats as `no id`.
    [Test]
    procedure NegativeWideKey_ReachesTheWhereIntact;
    /// THE GUARD THAT ADMITTED 64 BITS AND READ 32.
    /// _AutoIncKeyIsGenerated gates the cascade on `is this key real yet?`
    /// and answered it with AsInteger against the -1 placeholder. On an
    /// ftLargeint key - which its own cINTEGERKINDS lets through - the
    /// perfectly ordinary value 4294967295 ($FFFFFFFF) truncates to exactly
    /// -1, so the guard declared a REAL key ungenerated and refused to
    /// propagate it. Nothing in the suite held this: reverting the body to
    /// AsInteger killed ZERO clauses before this one existed.
    [Test]
    procedure WideAutoIncKey_ThatTruncatesToThePlaceholder_IsStillPropagated;
  end;

implementation

const
  /// $12A05F200 - low 32 bits are 704906752, so truncation is visible.
  cWIDE_FIND = Int64(5000000000);
  /// $1FFFFFFFF - low 32 bits are 4294967295 (-1 as a signed Integer), so
  /// truncation is visible AND lands on the placeholder value, which is the
  /// nastiest shape this defect had.
  cWIDE_OPEN = Int64(8589934591);
  cWIDE_NEG  = Int64(-5000000000);
  /// $FFFFFFFF. A perfectly ordinary 64-bit key whose low 32 bits ARE the -1
  /// placeholder cAutoIncNotGenerated - the exact value that made the
  /// narrowed guard call a real key ungenerated.
  cWIDE_TRUNCATES_TO_MINUS1 = Int64(4294967295);
  cCHILD_SEED               = Int64(7);

{ TTestKeyWidthByIdApi }

procedure TTestKeyWidthByIdApi.Setup;
begin
  FRows := TRowsConnection.Create(dnSQLite, 1,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add('bkid', ftLargeint);
      ADataSet.FieldDefs.Add('bktag', ftString, 20);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName('bkid').AsLargeInt := cWIDE_FIND;
      ADataSet.FieldByName('bktag').AsString := 'W';
    end,
    'keywidth');
  FConn := FRows;
  FTable := TFDMemTable.Create(nil);
end;

procedure TTestKeyWidthByIdApi.TearDown;
begin
  FreeAndNil(FTable);
  FConn := nil;
  FRows := nil;
end;

function TTestKeyWidthByIdApi.NewContainer(
  const AKey: Int64): IContainerDataSet<TBigKeyRow>;
begin
  Result := TContainerFDMemTable<TBigKeyRow>.Create(FConn, FTable);
end;

procedure TTestKeyWidthByIdApi.Find_WithAKeyBeyond32Bits_ReachesTheWhereIntact;
var
  LContainer: IContainerDataSet<TBigKeyRow>;
  LFound: TBigKeyRow;
begin
  LContainer := NewContainer(cWIDE_FIND);
  LFound := LContainer.Find(cWIDE_FIND);
  try
    Assert.Contains(FRows.LastSQL, '5000000000', True,
      'ISSUE #333: the id the consumer asked for must reach the predicate ' +
      'whole. On the unwidened tree this clause never got here - the call ' +
      'itself raised Range check error. Emitted: ' + FRows.LastSQL);
    Assert.DoesNotContain(FRows.LastSQL, '704906752', True,
      'and the low 32 bits of this constant - what a truncating conversion ' +
      'would leave with range checking off - must not appear: ' +
      FRows.LastSQL);
  finally
    LFound.Free;
    LContainer := nil;
  end;
end;

procedure TTestKeyWidthByIdApi.Open_WithAKeyBeyond32Bits_ReachesTheWhereIntact;
var
  LContainer: IContainerDataSet<TBigKeyRow>;
begin
  LContainer := NewContainer(cWIDE_OPEN);
  LContainer.Open(cWIDE_OPEN);
  Assert.Contains(FRows.LastSQL, '8589934591', True,
    'ISSUE #333, the OTHER chain: Open goes through OpenIDInternal and ' +
    'TSessionDataSet<M>.OpenID, both of which already took a TValue - the ' +
    'narrowing was in TContainerDataSet<M>.Open alone. Emitted: ' +
    FRows.LastSQL);
  Assert.DoesNotContain(FRows.LastSQL, '4294967295', True,
    'the low 32 bits of this constant are 4294967295, which as a signed ' +
    'Integer is the -1 the generator reads as `no id at all` - the nastiest ' +
    'shape a truncating conversion could take here: ' + FRows.LastSQL);
  LContainer := nil;
end;

procedure TTestKeyWidthByIdApi.IntegerLiteral_StillCompilesAndIsUnchanged;
var
  LContainer: IContainerDataSet<TBigKeyRow>;
  LFound: TBigKeyRow;
begin
  LContainer := NewContainer(10);
  // A BARE INTEGER LITERAL. With an overload pair Find(Integer)/Find(Int64)
  // this line is `E2251 Ambiguous overloaded call`; with one Int64 parameter
  // it promotes and compiles. The clause is here to fail the design, not just
  // the value.
  LFound := LContainer.Find(10);
  try
    Assert.Contains(FRows.LastSQL, 'bigkey.bkid = 10', True,
      'an ordinary Integer key must be untouched by the widening: ' +
      FRows.LastSQL);
  finally
    LFound.Free;
    LContainer := nil;
  end;
end;

procedure TTestKeyWidthByIdApi.NegativeWideKey_ReachesTheWhereIntact;
var
  LContainer: IContainerDataSet<TBigKeyRow>;
  LFound: TBigKeyRow;
begin
  LContainer := NewContainer(cWIDE_NEG);
  LFound := LContainer.Find(cWIDE_NEG);
  try
    Assert.Contains(FRows.LastSQL, '-5000000000', True,
      'Int64 is signed and the generator treats -1 as `no id`; a negative ' +
      'WIDE key is neither of those and must survive: ' + FRows.LastSQL);
  finally
    LFound.Free;
    LContainer := nil;
  end;
end;

{ TWkRoot }

constructor TWkRoot.Create;
begin
  Fchilds := TObjectList<TWkChild>.Create;
end;

destructor TWkRoot.Destroy;
begin
  Fchilds.Free;
  inherited;
end;

{ TWideCascadeAccess<M> }

class procedure TWideCascadeAccess<M>.Propagate(
  const A: TDataSetBaseAdapter<M>);
begin
  TWideCascadeAccess<M>(A).SetAutoIncValueChilds;
end;

procedure TTestKeyWidthByIdApi.
  WideAutoIncKey_ThatTruncatesToThePlaceholder_IsStillPropagated;
var
  LRootTable: TFDMemTable;
  LChildTable: TFDMemTable;
  LRoot: TFDMemTableAdapter<TWkRoot>;
  LChild: TFDMemTableAdapter<TWkChild>;
begin
  LRootTable := TFDMemTable.Create(nil);
  LChildTable := TFDMemTable.Create(nil);
  try
    LRoot := TFDMemTableAdapter<TWkRoot>.Create(FConn, LRootTable, -1, nil);
    LChild := TFDMemTableAdapter<TWkChild>.Create(FConn, LChildTable, -1,
                LRoot);
    try
      LRootTable.Append;
      LRootTable.FieldByName('wk_id').AsLargeInt := cWIDE_TRUNCATES_TO_MINUS1;
      LRootTable.Post;
      LChildTable.Append;
      LChildTable.FieldByName('wc_id').AsInteger := 1;
      LChildTable.FieldByName('wk_id').AsLargeInt := cCHILD_SEED;
      LChildTable.Post;

      // PREMISE, and it is the whole reason this clause bites: the master
      // really carries a key whose LOW 32 BITS are the -1 placeholder.
      Assert.AreEqual(cWIDE_TRUNCATES_TO_MINUS1,
        LRootTable.FieldByName('wk_id').AsLargeInt,
        'PREMISE: the master must be sitting on 4294967295');
      Assert.AreEqual(Integer(-1),
        Integer(cWIDE_TRUNCATES_TO_MINUS1 and $FFFFFFFF),
        'PREMISE: and its low 32 bits must really be the -1 the guard ' +
        'compares against - otherwise this clause measures nothing');
      Assert.AreEqual(cCHILD_SEED, LChildTable.FieldByName('wk_id').AsLargeInt,
        'PREMISE: the child must start on the sentinel');

      TWideCascadeAccess<TWkRoot>.Propagate(LRoot);

      Assert.AreEqual(cWIDE_TRUNCATES_TO_MINUS1,
        LChildTable.FieldByName('wk_id').AsLargeInt,
        'ISSUE #333: 4294967295 is a real, generated key. The guard admits ' +
        'ftLargeint through cINTEGERKINDS and must read it back at full ' +
        'width - reading AsInteger truncates it to the -1 placeholder, ' +
        'declares a key that EXISTS to be ungenerated, and silently refuses ' +
        'to cascade it to the children.');
    finally
      LChild.Free;
      LRoot.Free;
    end;
  finally
    LChildTable.Free;
    LRootTable.Free;
  end;
end;

initialization
  TRegisterClass.RegisterEntity(TWkChild);
  TRegisterClass.RegisterEntity(TWkRoot);
  TRegisterClass.RegisterEntity(TBigKeyRow);
  TDUnitX.RegisterTestFixture(TTestKeyWidthByIdApi);

end.
