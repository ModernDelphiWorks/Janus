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

{ TRttiPropertyHelper_.MustWriteNull over the REAL Nullable<T>
  (Janus.RTTI.Helper.pas, over Janus.Types.Nullable.pas).

  MustWriteNull is what the DML consumer asks before deciding whether a column
  takes a value or takes NULL, so every assertion here is a Boolean read off a
  live object - no database, no connection, no mapping registry. The probe class
  is deliberately NOT decorated with [Table]/[Column]: IsNullable is resolved
  from the property TYPE alone, and keeping the class out of the mapping
  registry keeps this fixture from perturbing the cached mapping repository the
  other fixtures share.

  WHY THIS FIXTURE EXISTS SEPARATELY FROM Test.Janus.Types.Nullable. That one
  asks the record about itself. This one asks the DML rule about the record -
  the composition of the [Restrictions([NotNull])] exemption, the [NullIfEmpty]
  opt-in and the type - and it asks it over the record this repository ships,
  not over a structural stand-in shaped like it. The distinction is not
  cosmetic: the shipped record carries a field that a stand-in built from the
  two names the resolver looks up does not have, and the whole point of deciding
  nullity here is that the answer follows the declared type.

  Comments and assertion messages are ASCII-only, matching the rest of this
  suite. }

unit Test.Janus.Nullable.MustWriteNull;

interface

uses
  Rtti,
  SysUtils,
  DUnitX.TestFramework,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Attributes,
  MetaDbDiff.RTTI.Helper,
  /// AFTER MetaDbDiff.RTTI.Helper - the derived helper only extends the
  /// ancestor while the ancestor is visible.
  Janus.RTTI.Helper,
  Janus.Types.Nullable;

type
  /// <summary>
  ///   One property per clause. Nothing is assigned in the constructor: a
  ///   freshly created instance is exactly the "nobody touched it" state that
  ///   must keep resolving to NULL.
  /// </summary>
  TJanusNullableProbe = class
  private
    FCodigo: Nullable<Integer>;
    FValor: Nullable<Double>;
    FPreco: Nullable<Currency>;
    FEmissao: Nullable<TDateTime>;
    FDescricao: Nullable<String>;
    FAtivo: Nullable<Boolean>;
    FCodigoNotNull: Nullable<Integer>;
    FCodigoOptIn: Nullable<Integer>;
    FObservacao: String;
    FQuantidade: Integer;
  public
    // Bare Nullable<T>: nullity is the absence of a value and nothing else.
    property Codigo: Nullable<Integer> read FCodigo write FCodigo;
    property Valor: Nullable<Double> read FValor write FValor;
    property Preco: Nullable<Currency> read FPreco write FPreco;
    property Emissao: Nullable<TDateTime> read FEmissao write FEmissao;
    property Descricao: Nullable<String> read FDescricao write FDescricao;
    // tkEnumeration reaches none of the default-value branches - it is here to
    // pin the asymmetry that motivated this fixture, not to assert the fix.
    property Ativo: Nullable<Boolean> read FAtivo write FAtivo;

    // The existing escape hatch: NotNull exempts before anything else is read.
    [Restrictions([TRestriction.NotNull])]
    property CodigoNotNull: Nullable<Integer> read FCodigoNotNull write FCodigoNotNull;

    // The opt-in asked for explicitly ON a Nullable.
    [NullIfEmpty]
    property CodigoOptIn: Nullable<Integer> read FCodigoOptIn write FCodigoOptIn;

    // The opt-in on a plain (non-Nullable) property - the documented case.
    [NullIfEmpty]
    property Observacao: String read FObservacao write FObservacao;

    // The opt-in on a plain Integer: pins what the attribute does TODAY, which
    // is wider than what the attribute reference advertises for it.
    [NullIfEmpty]
    property Quantidade: Integer read FQuantidade write FQuantidade;
  end;

  [TestFixture]
  TTestJanusMustWriteNull = class
  private
    FContext: TRttiContext;
    FProbe: TJanusNullableProbe;
    function _MustWriteNull(const APropertyName: String): Boolean;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // --- Nullable<Integer> ---------------------------------------------------
    [Test]
    procedure NullableInteger_Unassigned_IsNull;
    [Test]
    procedure NullableInteger_Zero_IsNotNull;
    [Test]
    procedure NullableInteger_One_IsNotNull;

    // --- Nullable<Double> ----------------------------------------------------
    [Test]
    procedure NullableDouble_Unassigned_IsNull;
    [Test]
    procedure NullableDouble_Zero_IsNotNull;
    [Test]
    procedure NullableDouble_NonZero_IsNotNull;

    // --- Nullable<Currency> --------------------------------------------------
    [Test]
    procedure NullableCurrency_Unassigned_IsNull;
    [Test]
    procedure NullableCurrency_Zero_IsNotNull;

    // --- Nullable<TDateTime> -------------------------------------------------
    [Test]
    procedure NullableDateTime_Unassigned_IsNull;
    [Test]
    procedure NullableDateTime_Zero_IsNotNull;
    [Test]
    procedure NullableDateTime_RealDate_IsNotNull;

    // --- Nullable<String> ----------------------------------------------------
    [Test]
    procedure NullableString_Unassigned_IsNull;
    [Test]
    procedure NullableString_Empty_IsNotNull;
    [Test]
    procedure NullableString_NonEmpty_IsNotNull;

    // --- Nullable<Boolean> ---------------------------------------------------
    [Test]
    procedure NullableBoolean_Unassigned_IsNull;
    [Test]
    procedure NullableBoolean_False_IsNotNull;

    // --- escape hatch and opt-in --------------------------------------------
    [Test]
    procedure NotNullRestriction_ExemptsEvenWithoutValue;
    [Test]
    procedure NullIfEmpty_OnNullable_ZeroStillNull;
    [Test]
    procedure NullIfEmpty_OnPlainString_EmptyStillNull;
    [Test]
    procedure NullIfEmpty_OnPlainString_NonEmptyIsNotNull;
    [Test]
    procedure NullIfEmpty_OnPlainInteger_ZeroStillNull;

    // --- the name that must NOT be shadowed ----------------------------------
    [Test]
    procedure MustWriteNull_AgreesWithTheRecordOwnHasValue;
  end;

implementation

{ TTestJanusMustWriteNull }

procedure TTestJanusMustWriteNull.Setup;
begin
  FContext := TRttiContext.Create;
  FProbe := TJanusNullableProbe.Create;
end;

procedure TTestJanusMustWriteNull.TearDown;
begin
  FProbe.Free;
  FContext.Free;
end;

function TTestJanusMustWriteNull._MustWriteNull(const APropertyName: String): Boolean;
var
  LProperty: TRttiProperty;
begin
  LProperty := FContext.GetType(TJanusNullableProbe).GetProperty(APropertyName);
  Assert.IsNotNull(LProperty, 'Propriedade ' + APropertyName + ' sem RTTI');
  Result := LProperty.MustWriteNull(FProbe);
end;

procedure TTestJanusMustWriteNull.NullableInteger_Unassigned_IsNull;
begin
  // O caso mais comum do parque: ninguem atribuiu.
  Assert.IsFalse(FProbe.Codigo.HasValue, 'Pre-condicao: HasValue deveria ser False');
  Assert.IsTrue(_MustWriteNull('Codigo'),
    'Nullable<Integer> sem atribuicao tem de continuar NULL');
end;

procedure TTestJanusMustWriteNull.NullableInteger_Zero_IsNotNull;
begin
  FProbe.Codigo := 0;
  Assert.IsTrue(FProbe.Codigo.HasValue, 'Pre-condicao: HasValue deveria ser True');
  Assert.IsFalse(_MustWriteNull('Codigo'),
    'Nullable<Integer> valendo 0 e ZERO, nao NULL');
end;

procedure TTestJanusMustWriteNull.NullableInteger_One_IsNotNull;
begin
  FProbe.Codigo := 1;
  Assert.IsFalse(_MustWriteNull('Codigo'),
    'Nullable<Integer> valendo 1 nunca foi nulo');
end;

procedure TTestJanusMustWriteNull.NullableDouble_Unassigned_IsNull;
begin
  Assert.IsTrue(_MustWriteNull('Valor'),
    'Nullable<Double> sem atribuicao tem de continuar NULL');
end;

procedure TTestJanusMustWriteNull.NullableDouble_Zero_IsNotNull;
begin
  FProbe.Valor := 0.0;
  Assert.IsFalse(_MustWriteNull('Valor'),
    'Nullable<Double> valendo 0.0 e ZERO, nao NULL');
end;

procedure TTestJanusMustWriteNull.NullableDouble_NonZero_IsNotNull;
begin
  FProbe.Valor := 1.5;
  Assert.IsFalse(_MustWriteNull('Valor'),
    'Nullable<Double> valendo 1.5 nunca foi nulo');
end;

procedure TTestJanusMustWriteNull.NullableCurrency_Unassigned_IsNull;
begin
  Assert.IsTrue(_MustWriteNull('Preco'),
    'Nullable<Currency> sem atribuicao tem de continuar NULL');
end;

procedure TTestJanusMustWriteNull.NullableCurrency_Zero_IsNotNull;
begin
  FProbe.Preco := Currency(0);
  Assert.IsFalse(_MustWriteNull('Preco'),
    'Nullable<Currency> valendo 0 e ZERO, nao NULL');
end;

procedure TTestJanusMustWriteNull.NullableDateTime_Unassigned_IsNull;
begin
  Assert.IsTrue(_MustWriteNull('Emissao'),
    'Nullable<TDateTime> sem atribuicao tem de continuar NULL');
end;

procedure TTestJanusMustWriteNull.NullableDateTime_Zero_IsNotNull;
begin
  // 0 em TDateTime e 30/12/1899 - uma data como qualquer outra para o banco.
  FProbe.Emissao := TDateTime(0);
  Assert.IsFalse(_MustWriteNull('Emissao'),
    'Nullable<TDateTime> valendo zero foi ATRIBUIDO, nao e NULL');
end;

procedure TTestJanusMustWriteNull.NullableDateTime_RealDate_IsNotNull;
begin
  FProbe.Emissao := EncodeDate(2026, 8, 24);
  Assert.IsFalse(_MustWriteNull('Emissao'),
    'Nullable<TDateTime> com data real nunca foi nulo');
end;

procedure TTestJanusMustWriteNull.NullableString_Unassigned_IsNull;
begin
  Assert.IsTrue(_MustWriteNull('Descricao'),
    'Nullable<String> sem atribuicao tem de continuar NULL');
end;

procedure TTestJanusMustWriteNull.NullableString_Empty_IsNotNull;
begin
  FProbe.Descricao := '';
  Assert.IsTrue(FProbe.Descricao.HasValue, 'Pre-condicao: HasValue deveria ser True');
  Assert.IsFalse(_MustWriteNull('Descricao'),
    'Nullable<String> valendo string vazia e '''', nao NULL - quem quer '''' virando NULL pede [NullIfEmpty]');
end;

procedure TTestJanusMustWriteNull.NullableString_NonEmpty_IsNotNull;
begin
  FProbe.Descricao := 'x';
  Assert.IsFalse(_MustWriteNull('Descricao'),
    'Nullable<String> com texto nunca foi nulo');
end;

procedure TTestJanusMustWriteNull.NullableBoolean_Unassigned_IsNull;
begin
  Assert.IsTrue(_MustWriteNull('Ativo'),
    'Nullable<Boolean> sem atribuicao tem de continuar NULL');
end;

procedure TTestJanusMustWriteNull.NullableBoolean_False_IsNotNull;
begin
  FProbe.Ativo := False;
  Assert.IsFalse(_MustWriteNull('Ativo'),
    'Nullable<Boolean> valendo False e FALSE, nao NULL');
end;

procedure TTestJanusMustWriteNull.NotNullRestriction_ExemptsEvenWithoutValue;
begin
  // Escotilha existente: com [Restrictions([NotNull])] o resolvedor nem roda.
  Assert.IsFalse(FProbe.CodigoNotNull.HasValue, 'Pre-condicao: HasValue deveria ser False');
  Assert.IsFalse(_MustWriteNull('CodigoNotNull'),
    'IsNotNull tem de continuar isentando antes de qualquer resolucao');
end;

procedure TTestJanusMustWriteNull.NullIfEmpty_OnNullable_ZeroStillNull;
begin
  FProbe.CodigoOptIn := 0;
  Assert.IsTrue(FProbe.CodigoOptIn.HasValue, 'Pre-condicao: HasValue deveria ser True');
  Assert.IsTrue(_MustWriteNull('CodigoOptIn'),
    'Quem PEDIU [NullIfEmpty] num Nullable continua recebendo NULL no valor default');
end;

procedure TTestJanusMustWriteNull.NullIfEmpty_OnPlainString_EmptyStillNull;
begin
  FProbe.Observacao := '';
  Assert.IsTrue(_MustWriteNull('Observacao'),
    '[NullIfEmpty] sobre String pura com '''' continua nulo - o opt-in nao pode quebrar');
end;

procedure TTestJanusMustWriteNull.NullIfEmpty_OnPlainString_NonEmptyIsNotNull;
begin
  FProbe.Observacao := 'x';
  Assert.IsFalse(_MustWriteNull('Observacao'),
    '[NullIfEmpty] sobre String pura com texto nao e nulo');
end;

procedure TTestJanusMustWriteNull.NullIfEmpty_OnPlainInteger_ZeroStillNull;
begin
  FProbe.Quantidade := 0;
  // Fixa o comportamento de HOJE do atributo, que e mais largo do que a linha
  // da referencia de atributos ("Converts empty string to null"). Esta rodada
  // nao estreita o opt-in; so decide a semantica de quem declara o tipo.
  Assert.IsTrue(_MustWriteNull('Quantidade'),
    '[NullIfEmpty] sobre Integer puro com 0 continua nulo (comportamento vigente)');
end;

procedure TTestJanusMustWriteNull.MustWriteNull_AgreesWithTheRecordOwnHasValue;
var
  LProperty: TRttiProperty;
begin
  // A regra le a presenca por UM caminho; o record expoe a dele por outro.
  // Esta clausula pergunta aos dois sobre o MESMO objeto, nos dois estados, e
  // exige que a resposta seja a mesma. Ela e cega a uma forma de record que
  // nao seja a declarada aqui: quem inventar um Nullable proprio, com outros
  // campos, nao esta coberto por esta comparacao.
  LProperty := FContext.GetType(TJanusNullableProbe).GetProperty('Codigo');
  Assert.IsNotNull(LProperty, 'Propriedade Codigo sem RTTI');

  Assert.AreEqual(not FProbe.Codigo.HasValue, LProperty.MustWriteNull(FProbe),
    'Sem valor: a regra e o HasValue do record tem de concordar');

  FProbe.Codigo := 7;
  Assert.AreEqual(not FProbe.Codigo.HasValue, LProperty.MustWriteNull(FProbe),
    'Com valor: a regra e o HasValue do record tem de concordar');
end;

initialization
  /// Sem esta linha a unit COMPILA, entra no .dpr e no .dproj, e nao roda
  /// clausula nenhuma - a suite fica verde com o mesmo total de antes. O
  /// atributo [TestFixture] sozinho nao registra: quem registra e esta chamada.
  TDUnitX.RegisterTestFixture(TTestJanusMustWriteNull);

end.
