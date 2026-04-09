unit TestLazyMapping;

interface

uses
  DUnitX.TestFramework,
  Generics.Collections,
  Janus.Mapping.Lazy,
  MetaDbDiff.Mapping.Classes,
  Model.Exame,
  Model.Procedimento,
  Model.Setor;

type
  [TestFixture]
  TTestLazyMapping = class
  public
    [Test]
    procedure TestGetLazyFields_Exame;
    [Test]
    procedure TestGetLazyFields_Procedimento;
    [Test]
    procedure TestGetLazyFields_NoLazy;
    [Test]
    procedure TestGetLazyFields_CacheHit;
  end;

implementation

{ TTestLazyMapping }

procedure TTestLazyMapping.TestGetLazyFields_Exame;
var
  LFields: TObjectList<TLazyMapping>;
begin
  LFields := LazyMappingExplorer.GetLazyFields(TExame);
  Assert.IsNotNull(LFields, 'Lazy fields list must not be nil');
  Assert.AreEqual(1, LFields.Count, 'TExame must have exactly 1 lazy field (FProcedimento)');
  Assert.AreEqual('FProcedimento', LFields[0].FieldLazy.Name);
end;

procedure TTestLazyMapping.TestGetLazyFields_Procedimento;
var
  LFields: TObjectList<TLazyMapping>;
begin
  LFields := LazyMappingExplorer.GetLazyFields(TProcedimento);
  Assert.IsNotNull(LFields, 'Lazy fields list must not be nil');
  Assert.AreEqual(1, LFields.Count, 'TProcedimento must have exactly 1 lazy field (FSetoresList)');
  Assert.AreEqual('FSetoresList', LFields[0].FieldLazy.Name);
end;

procedure TTestLazyMapping.TestGetLazyFields_NoLazy;
var
  LFields: TObjectList<TLazyMapping>;
begin
  LFields := LazyMappingExplorer.GetLazyFields(TSetor);
  Assert.IsNotNull(LFields, 'Lazy fields list must not be nil even if empty');
  Assert.AreEqual(0, LFields.Count, 'TSetor must have 0 lazy fields');
end;

procedure TTestLazyMapping.TestGetLazyFields_CacheHit;
var
  LFields1: TObjectList<TLazyMapping>;
  LFields2: TObjectList<TLazyMapping>;
begin
  LFields1 := LazyMappingExplorer.GetLazyFields(TExame);
  LFields2 := LazyMappingExplorer.GetLazyFields(TExame);
  Assert.AreSame(TObject(LFields1), TObject(LFields2),
    'Second call must return same list instance (cache hit)');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestLazyMapping);

end.
