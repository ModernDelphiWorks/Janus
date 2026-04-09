unit TestLazyWrapper;

interface

uses
  SysUtils,
  DUnitX.TestFramework,
  Janus.Types.Lazy,
  Model.Procedimento;

type
  [TestFixture]
  TTestLazyWrapper = class
  public
    [Test]
    procedure TestLazy_ImplicitOperator_WithFactory;
    [Test]
    procedure TestLazy_DefaultValue_IsCreatedByRtti;
  end;

implementation

{ TTestLazyWrapper }

procedure TTestLazyWrapper.TestLazy_ImplicitOperator_WithFactory;
var
  LFactory: TFunc<TProcedimento>;
  LLazy: Lazy<TProcedimento>;
  LLazyValue: ILazy<TProcedimento>;
  LValue: TProcedimento;
begin
  LFactory := function: TProcedimento
    begin
      Result := TProcedimento.Create;
    end;
  LLazy := LFactory;
  LLazyValue := LLazy;
  LValue := LLazyValue.Value;
  Assert.IsNotNull(LValue, 'Lazy value must not be nil after factory call');
end;

procedure TTestLazyWrapper.TestLazy_DefaultValue_IsCreatedByRtti;
var
  LLazy: Lazy<TProcedimento>;
  LLazyValue: ILazy<TProcedimento>;
  LValue: TProcedimento;
begin
  LLazyValue := LLazy;
  LValue := LLazyValue.Value;
  Assert.IsNotNull(LValue, 'Default lazy value should be created by RTTI');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestLazyWrapper);

end.
