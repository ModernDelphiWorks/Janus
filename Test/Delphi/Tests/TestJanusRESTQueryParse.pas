unit TestJanusRESTQueryParse;

interface

uses
  SysUtils,
  DUnitX.TestFramework,
  Janus.Server.RestQuery.Parse;

type
  [TestFixture]
  TTestRESTQueryParse = class
  private
    FParser: TRESTQueryParse;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // --- ParseResourceNameAndID ---
    [Test]
    procedure ParseResourceName_Simple;
    [Test]
    procedure ParseResourceName_WithID;
    [Test]
    procedure ParseResourceName_WithQueryString;
    [Test]
    procedure ParseResourceName_IDIsEmpty_WhenNoParens;
    [Test]
    procedure ParseResourceName_PrefixedWithT;

    // --- ParseOperator: comparison operators (word-boundary safe) ---
    [Test]
    procedure ParseOperator_Eq_Converted;
    [Test]
    procedure ParseOperator_Ne_Converted;
    [Test]
    procedure ParseOperator_Gt_Converted;
    [Test]
    procedure ParseOperator_Ge_Converted;
    [Test]
    procedure ParseOperator_Lt_Converted;
    [Test]
    procedure ParseOperator_Le_Converted;
    [Test]
    procedure ParseOperator_Add_Converted;
    [Test]
    procedure ParseOperator_Sub_Converted;
    [Test]
    procedure ParseOperator_Mul_Converted;
    [Test]
    procedure ParseOperator_Div_Converted;

    // --- ParseOperator: field names containing operator substrings (regression) ---
    [Test]
    procedure ParseOperator_FieldNameWithEqSubstring_NotCorrupted;
    [Test]
    procedure ParseOperator_FieldNameWithLeSubstring_NotCorrupted;
    [Test]
    procedure ParseOperator_FieldNameWithAddSubstring_NotCorrupted;

    // --- ParseOperator: logical operators ---
    [Test]
    procedure ParseOperator_And_Converted;
    [Test]
    procedure ParseOperator_Or_Converted;
    [Test]
    procedure ParseOperator_Not_Converted;
    [Test]
    procedure ParseOperator_CombinedAndOr;

    // --- ParseOperator: OData functions ---
    [Test]
    procedure ParseOperator_Contains_Converted;
    [Test]
    procedure ParseOperator_Startswith_Converted;
    [Test]
    procedure ParseOperator_Endswith_Converted;
    [Test]
    procedure ParseOperator_Tolower_Converted;
    [Test]
    procedure ParseOperator_Toupper_Converted;

    // --- ParseOperator: string literals pass through unchanged ---
    [Test]
    procedure ParseOperator_StringLiteral_NotAltered;
    [Test]
    procedure ParseOperator_StringLiteralWithOperatorWord_NotAltered;

    // --- ParseOperator: parentheses pass through ---
    [Test]
    procedure ParseOperator_ParenthesesPassThrough;

    // --- ParseQuery: full URI tokenization ---
    [Test]
    procedure ParseQuery_ExtractsFilter;
    [Test]
    procedure ParseQuery_ExtractsTop;
    [Test]
    procedure ParseQuery_ExtractsSkip;
    [Test]
    procedure ParseQuery_ExtractsOrderBy;
    [Test]
    procedure ParseQuery_ExtractsCount;
    [Test]
    procedure ParseQuery_ExtractsExpand;
    [Test]
    procedure ParseQuery_NoQueryString;

    // --- Setters ---
    [Test]
    procedure SetFilter_AppliesOperatorConversion;
    [Test]
    procedure SetTop_StoresValue;
    [Test]
    procedure SetSkip_StoresValue;
    [Test]
    procedure SetCount_StoresValue;
    [Test]
    procedure SetOrderBy_StoresValue;
    [Test]
    procedure SetExpand_StoresValue;
    [Test]
    procedure SetSelect_StoresValue;
  end;

implementation

procedure TTestRESTQueryParse.Setup;
begin
  FParser := TRESTQueryParse.Create;
end;

procedure TTestRESTQueryParse.TearDown;
begin
  FParser.Free;
end;

// --- ParseResourceNameAndID ---

procedure TTestRESTQueryParse.ParseResourceName_Simple;
begin
  FParser.ParseQuery('/api/Janus/Customer');
  Assert.AreEqual('TCustomer', FParser.ResourceName);
end;

procedure TTestRESTQueryParse.ParseResourceName_WithID;
begin
  FParser.ParseQuery('/api/Janus/Customer(42)');
  Assert.AreEqual('TCustomer', FParser.ResourceName);
  Assert.AreEqual('42', FParser.ID.ToString);
end;

procedure TTestRESTQueryParse.ParseResourceName_WithQueryString;
begin
  FParser.ParseQuery('/api/Janus/Customer?$top=10');
  Assert.AreEqual('TCustomer', FParser.ResourceName);
end;

procedure TTestRESTQueryParse.ParseResourceName_IDIsEmpty_WhenNoParens;
begin
  FParser.ParseQuery('/api/Janus/Customer');
  Assert.IsTrue(FParser.ID.IsEmpty);
end;

procedure TTestRESTQueryParse.ParseResourceName_PrefixedWithT;
begin
  FParser.ParseQuery('Order');
  Assert.AreEqual('TOrder', FParser.ResourceName);
end;

// --- Comparison operators ---

procedure TTestRESTQueryParse.ParseOperator_Eq_Converted;
begin
  FParser.ParseQuery('/api/Janus/Customer?$filter=name eq ''Alice''');
  Assert.Contains(FParser.Filter, '=');
  Assert.IsFalse(FParser.Filter.Contains(' eq '));
end;

procedure TTestRESTQueryParse.ParseOperator_Ne_Converted;
begin
  FParser.SetFilter('status ne ''active''');
  Assert.Contains(FParser.Filter, '<>');
end;

procedure TTestRESTQueryParse.ParseOperator_Gt_Converted;
begin
  FParser.SetFilter('age gt 18');
  Assert.Contains(FParser.Filter, '>');
  Assert.IsFalse(FParser.Filter.Contains(' gt '));
end;

procedure TTestRESTQueryParse.ParseOperator_Ge_Converted;
begin
  FParser.SetFilter('score ge 90');
  Assert.Contains(FParser.Filter, '>=');
end;

procedure TTestRESTQueryParse.ParseOperator_Lt_Converted;
begin
  FParser.SetFilter('price lt 100');
  Assert.Contains(FParser.Filter, '<');
  Assert.IsFalse(FParser.Filter.Contains(' lt '));
end;

procedure TTestRESTQueryParse.ParseOperator_Le_Converted;
begin
  FParser.SetFilter('price le 100');
  Assert.Contains(FParser.Filter, '<=');
end;

procedure TTestRESTQueryParse.ParseOperator_Add_Converted;
begin
  FParser.SetFilter('qty add 1');
  Assert.Contains(FParser.Filter, '+');
  Assert.IsFalse(FParser.Filter.Contains(' add '));
end;

procedure TTestRESTQueryParse.ParseOperator_Sub_Converted;
begin
  FParser.SetFilter('qty sub 1');
  Assert.Contains(FParser.Filter, '-');
end;

procedure TTestRESTQueryParse.ParseOperator_Mul_Converted;
begin
  FParser.SetFilter('qty mul price');
  Assert.Contains(FParser.Filter, '*');
end;

procedure TTestRESTQueryParse.ParseOperator_Div_Converted;
begin
  FParser.SetFilter('total div qty');
  Assert.Contains(FParser.Filter, '/');
end;

// --- Field-name regression tests ---

procedure TTestRESTQueryParse.ParseOperator_FieldNameWithEqSubstring_NotCorrupted;
begin
  // "sequence" contains no "eq" as standalone token — must not be altered
  FParser.SetFilter('sequence eq 5');
  Assert.AreEqual('sequence = 5', FParser.Filter);
end;

procedure TTestRESTQueryParse.ParseOperator_FieldNameWithLeSubstring_NotCorrupted;
begin
  // "delete_date" contains "le" inside "delete" — must not be altered
  FParser.SetFilter('delete_date lt ''2025-01-01''');
  Assert.AreEqual('delete_date < ''2025-01-01''', FParser.Filter);
end;

procedure TTestRESTQueryParse.ParseOperator_FieldNameWithAddSubstring_NotCorrupted;
begin
  // "address" contains "add" inside it — must not be replaced
  FParser.SetFilter('address eq ''Main St''');
  Assert.AreEqual('address = ''Main St''', FParser.Filter);
end;

// --- Logical operators ---

procedure TTestRESTQueryParse.ParseOperator_And_Converted;
begin
  FParser.SetFilter('name eq ''Alice'' and age gt 18');
  Assert.Contains(FParser.Filter, 'AND');
  Assert.IsFalse(FParser.Filter.Contains(' and '));
end;

procedure TTestRESTQueryParse.ParseOperator_Or_Converted;
begin
  FParser.SetFilter('status eq ''active'' or status eq ''pending''');
  Assert.Contains(FParser.Filter, 'OR');
  Assert.IsFalse(FParser.Filter.Contains(' or '));
end;

procedure TTestRESTQueryParse.ParseOperator_Not_Converted;
begin
  FParser.SetFilter('not (active eq false)');
  Assert.Contains(FParser.Filter, 'NOT');
end;

procedure TTestRESTQueryParse.ParseOperator_CombinedAndOr;
begin
  FParser.SetFilter('(a eq 1 and b gt 2) or (c lt 10)');
  Assert.Contains(FParser.Filter, 'AND');
  Assert.Contains(FParser.Filter, 'OR');
  Assert.Contains(FParser.Filter, '=');
  Assert.Contains(FParser.Filter, '>');
  Assert.Contains(FParser.Filter, '<');
end;

// --- OData functions ---

procedure TTestRESTQueryParse.ParseOperator_Contains_Converted;
begin
  FParser.SetFilter('contains(name,''Alice'')');
  Assert.Contains(FParser.Filter, 'LIKE');
  Assert.Contains(FParser.Filter, '%Alice%');
end;

procedure TTestRESTQueryParse.ParseOperator_Startswith_Converted;
begin
  FParser.SetFilter('startswith(name,''Al'')');
  Assert.Contains(FParser.Filter, 'LIKE');
  Assert.Contains(FParser.Filter, 'Al%');
  Assert.IsFalse(FParser.Filter.Contains('%Al%'));
end;

procedure TTestRESTQueryParse.ParseOperator_Endswith_Converted;
begin
  FParser.SetFilter('endswith(name,''ice'')');
  Assert.Contains(FParser.Filter, 'LIKE');
  Assert.Contains(FParser.Filter, '%ice');
  // Must not start with % before 'ice%' (that would be contains)
  Assert.IsFalse(FParser.Filter.Contains('%ice%'));
end;

procedure TTestRESTQueryParse.ParseOperator_Tolower_Converted;
begin
  FParser.SetFilter('tolower(name) eq ''alice''');
  Assert.Contains(FParser.Filter, 'LOWER(name)');
end;

procedure TTestRESTQueryParse.ParseOperator_Toupper_Converted;
begin
  FParser.SetFilter('toupper(status) eq ''ACTIVE''');
  Assert.Contains(FParser.Filter, 'UPPER(status)');
end;

// --- String literals ---

procedure TTestRESTQueryParse.ParseOperator_StringLiteral_NotAltered;
begin
  // Operator words inside string literals must not be transformed
  FParser.SetFilter('note eq ''add more eq content''');
  // The string 'add more eq content' should appear verbatim
  Assert.Contains(FParser.Filter, '''add more eq content''');
end;

procedure TTestRESTQueryParse.ParseOperator_StringLiteralWithOperatorWord_NotAltered;
begin
  FParser.SetFilter('code eq ''eq-001''');
  Assert.Contains(FParser.Filter, '''eq-001''');
end;

// --- Parentheses ---

procedure TTestRESTQueryParse.ParseOperator_ParenthesesPassThrough;
begin
  FParser.SetFilter('(name eq ''Alice'') and (age gt 18)');
  Assert.StartsWith('(', FParser.Filter);
  Assert.Contains(FParser.Filter, 'AND');
end;

// --- ParseQuery full URI ---

procedure TTestRESTQueryParse.ParseQuery_ExtractsFilter;
begin
  FParser.ParseQuery('/api/Janus/Customer?$filter=name eq ''Alice''&$top=5');
  Assert.AreNotEqual('', FParser.Filter);
  Assert.Contains(FParser.Filter, '=');
end;

procedure TTestRESTQueryParse.ParseQuery_ExtractsTop;
begin
  FParser.ParseQuery('/api/Janus/Customer?$top=25');
  Assert.AreEqual(25, FParser.Top);
end;

procedure TTestRESTQueryParse.ParseQuery_ExtractsSkip;
begin
  FParser.ParseQuery('/api/Janus/Customer?$top=10&$skip=20');
  Assert.AreEqual(20, FParser.Skip);
end;

procedure TTestRESTQueryParse.ParseQuery_ExtractsOrderBy;
begin
  FParser.ParseQuery('/api/Janus/Customer?$orderby=name asc');
  Assert.AreEqual('name asc', FParser.OrderBy);
end;

procedure TTestRESTQueryParse.ParseQuery_ExtractsCount;
begin
  FParser.ParseQuery('/api/Janus/Customer?$count=true');
  Assert.IsTrue(FParser.Count);
end;

procedure TTestRESTQueryParse.ParseQuery_ExtractsExpand;
begin
  FParser.ParseQuery('/api/Janus/Customer?$expand=Orders');
  Assert.AreEqual('Orders', FParser.Expand);
end;

procedure TTestRESTQueryParse.ParseQuery_NoQueryString;
begin
  FParser.ParseQuery('/api/Janus/Customer');
  Assert.AreEqual('', FParser.Filter);
  Assert.AreEqual(0, FParser.Top);
  Assert.AreEqual(0, FParser.Skip);
  Assert.IsFalse(FParser.Count);
end;

// --- Setters ---

procedure TTestRESTQueryParse.SetFilter_AppliesOperatorConversion;
begin
  FParser.SetFilter('qty gt 0');
  Assert.Contains(FParser.Filter, '>');
end;

procedure TTestRESTQueryParse.SetTop_StoresValue;
begin
  FParser.SetTop(TValue.From<Integer>(50));
  Assert.AreEqual(50, FParser.Top);
end;

procedure TTestRESTQueryParse.SetSkip_StoresValue;
begin
  FParser.SetSkip(TValue.From<Integer>(10));
  Assert.AreEqual(10, FParser.Skip);
end;

procedure TTestRESTQueryParse.SetCount_StoresValue;
begin
  FParser.SetCount(TValue.From<String>('true'));
  Assert.IsTrue(FParser.Count);
end;

procedure TTestRESTQueryParse.SetOrderBy_StoresValue;
begin
  FParser.SetOrderBy('name desc');
  Assert.AreEqual('name desc', FParser.OrderBy);
end;

procedure TTestRESTQueryParse.SetExpand_StoresValue;
begin
  FParser.SetExpand('Orders');
  Assert.AreEqual('Orders', FParser.Expand);
end;

procedure TTestRESTQueryParse.SetSelect_StoresValue;
begin
  FParser.SetSelect('id,name,email');
  Assert.AreEqual('id,name,email', FParser.Select);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRESTQueryParse);

end.
