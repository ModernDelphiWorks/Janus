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
  @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
}

unit Janus.Command.Abstract;

interface

uses
  DB,
  Rtti,
  SysUtils,
  Variants,
  DataEngine.FactoryInterfaces,
  Janus.Driver.Register,
  Janus.DML.Interfaces;

type
  TDMLCommandAbstract = class abstract
  protected
    FConnection: IDBConnection;
    FGeneratorCommand: IDMLGeneratorCommand;
    FParams: TParams;
    FResultCommand: String;

    /// <summary> ISSUE #325 - THE MAPPING IS REFUSED, LOUDLY, INSTEAD OF
    ///  WRITING THE ROW UNDER A KEY NOBODY ASKED FOR.
    ///
    ///  A property declared UInt64 carrying a value above High(Int64), bound
    ///  into a ftLargeint column, reaches the row as its SIGNED
    ///  reinterpretation. Nothing raises, nothing is logged, and the value the
    ///  caller sent no longer locates the row the framework just wrote.
    ///
    ///  WHERE THE FLIP HAPPENS, MEASURED, BECAUSE ISSUE #325 GUESSED THREE
    ///  PLACES AND NAMED NONE OF THEM. A standalone probe built with the same
    ///  Studio 37.0 that builds this repository, using nothing but the RTL,
    ///  answers: a UInt64 property read through RTTI arrives as a Variant of
    ///  VType = varUInt64 (21) with every bit intact; assigning it to a TParam
    ///  whose DataType is ftLargeint KEEPS VType 21; and TParam.AsLargeInt -
    ///  Data.DB's own accessor, one layer above any driver - then answers
    ///  -9223372036854775808. So the flip is neither in Janus, nor in the
    ///  driver, nor in SQLite's storage class: it is in the RTL, and it is the
    ///  only thing an accessor typed Largeint COULD answer.
    ///
    ///  THE REFUSAL IS ABOUT THE VALUE AND NOT ABOUT THE TYPE, and that is a
    ///  choice with a count behind it. At 0546a51, the commit this work starts
    ///  from, a scan of every property declared UInt64 anywhere under Source\
    ///  and Test\ of this repository returned exactly ONE: the fixture entity
    ///  Test.Janus.Model.KeyTypes.TKeyTypeUnsigned, added by issue #311's
    ///  branch to ask this very question. (The count is quoted for THAT commit
    ///  and this branch moved it - the same scan here answers three.) Refusing
    ///  the TYPE would therefore have broken nothing HERE while breaking every
    ///  consumer holding a UInt64 key below High(Int64), which works today and
    ///  keeps working: the third test below is strict, so High(Int64) itself
    ///  still writes.
    ///
    ///  WHY ftLargeint AND NOT EVERY INTEGER LABEL. The term is load-bearing
    ///  and its clause exists: the message this routine raises tells the
    ///  caller to declare the column ftString, and TParam.AsString over the
    ///  same varUInt64 renders all twenty digits - measured in the same probe.
    ///  Guarding every integer label would refuse the escape hatch this very
    ///  message recommends. Data.DB does declare ftLargeUint for the unsigned
    ///  64-bit case, complete with a TLargeUintField; a scan for that label
    ///  over every tree this repository's test projects put on the unit search
    ///  path - Source\ here, MetaDbDiff\Source, DataEngine\Source,
    ///  FluentSQL\Source, JsonFlow\Source, Horse\src and ModernSyntax\Source -
    ///  finds nothing but the two mentions in THIS comment and in the message
    ///  below. No column in this framework can be declared unsigned 64-bit,
    ///  which is why the value has nowhere legal to go.
    ///
    ///  IT READS THE PARAMETER BACK RATHER THAN THE PROPERTY, ON PURPOSE. What
    ///  the driver binds is TParam.Value, so that is what is inspected; an
    ///  intermediate that agrees with it today is not the thing under test.
    ///
    ///  IT GUARDS WRITES AND NOT LOOKUPS, WHICH IS THE ONE ASYMMETRY IN IT.
    ///  TCommandInserter's parameters and TCommandUpdater's MODIFIED-COLUMN
    ///  loop write; TCommandUpdater's primary-key loop and every parameter
    ///  TCommandDeleter builds are the WHERE. The lookup is self-consistent:
    ///  what AsLargeInt reinterprets on the way down is exactly what the read
    ///  reinterpreted the other way on the way up, so an object loaded out of
    ///  a row whose key is Low(Int64) updates and deletes that same row. That
    ///  works at 0546a51 and two clauses in
    ///  Test.Janus.Server.Resource.IntegerKeyWidth keep it working; refusing
    ///  there would leave a row that already carries such a key unrepairable
    ///  and unremovable, which is worse than the state this issue found.
    ///
    ///  WHAT IT DOES NOT COVER, SAID RATHER THAN LEFT TO BE FOUND. The SELECT
    ///  side builds its predicate as a LITERAL in
    ///  TDMLGeneratorAbstract.GetGeneratorWhere, which is not touched here: a
    ///  read under such a key returns no row rather than a wrong one, and
    ///  returning nothing corrupts nothing on disk. Other dialects are NOT
    ///  MEASURED - there is no non-SQLite database on this machine - but the
    ///  flip measured above happens in Data.DB before any driver is reached,
    ///  so it cannot be dialect-specific; whether a dialect with a native
    ///  unsigned 64-bit column could carry the value is a different question
    ///  and this refusal does not answer it. </summary>
    procedure _RefuseUnsignedValueTheColumnCannotCarry(const AObject: TObject;
      const AColumnName: String; const AProperty: TRttiProperty;
      const AFieldType: TFieldType; const AValue: Variant);
  public
    constructor Create(AConnection: IDBConnection; ADriverName: TDriverName;
      AObject: TObject); virtual;
    destructor Destroy; override;
    function GetDMLCommand: String;
    function Params: TParams;
  end;

implementation

{ TDMLCommandAbstract }

constructor TDMLCommandAbstract.Create(AConnection: IDBConnection;
  ADriverName: TDriverName; AObject: TObject);
begin
  // Driver de conexao
  FConnection := AConnection;
  // Driver do banco de dados
  FGeneratorCommand := TDriverRegister.GetDriver(ADriverName);
  // Surface a precise error instead of letting a nil factory AV downstream.
  // The historical failure was "offset 0x121421 Read of address 00000008"
  // deep in TDictionary - opaque and nearly undiagnosable. If GetDriver
  // ever hands back nil (e.g., a factory that returned nil without
  // raising), we now fail here with an actionable message.
  if not Assigned(FGeneratorCommand) then
    raise Exception.Create(
      'Janus: o gerador DML para o driver solicitado retornou nil. ' +
      'Verifique se a unit "Janus.DML.Generator.<driver>.pas" est'#$00E1' na ' +
      'cl'#$00E1'usula uses do seu projeto.');
  FGeneratorCommand.SetConnection(AConnection);
  // Lista de parametros
  FParams := TParams.Create;
end;

destructor TDMLCommandAbstract.Destroy;
begin
  // O Create acima pode levantar ANTES de FParams existir -- e o que acontece
  // quando o driver nao esta registrado: GetDriver levanta a mensagem limpa
  // logo na primeira linha. O Delphi chama Destroy do objeto meio-construido
  // assim mesmo, e o FParams.Clear num ponteiro nil trocava aquela mensagem
  // por um Access Violation -- justamente o diagnostico opaco que a guarda do
  // Create dizia estar evitando.
  if Assigned(FParams) then
  begin
    FParams.Clear;
    FParams.Free;
  end;
  inherited;
end;

function TDMLCommandAbstract.GetDMLCommand: String;
begin
  Result := FResultCommand;
end;

function TDMLCommandAbstract.Params: TParams;
begin
  Result := FParams;
end;

procedure TDMLCommandAbstract._RefuseUnsignedValueTheColumnCannotCarry(
  const AObject: TObject; const AColumnName: String;
  const AProperty: TRttiProperty; const AFieldType: TFieldType;
  const AValue: Variant);
begin
  if AFieldType <> ftLargeint then
    Exit;
  if TVarData(AValue).VType <> varUInt64 then
    Exit;
  if TVarData(AValue).VUInt64 <= UInt64(High(Int64)) then
    Exit;
  raise Exception.CreateFmt(
    'Janus refuses the value %s. The property "%s" of entity %s is an ' +
    'unsigned 64-bit integer and this value is above High(Int64) = %s, ' +
    'which is the widest integer any Janus column can carry. The column ' +
    '"%s" is declared ftLargeint - a SIGNED 64-bit column - and Data.DB''s ' +
    'own TParam.AsLargeInt turns this value into %s before any driver sees ' +
    'it, so the row would be written, and afterwards looked up, under a key ' +
    'nobody asked for, without a word. Data.DB declares ftLargeUint for the ' +
    'unsigned 64-bit case and Janus maps no column onto it. WHAT TO DO: ' +
    'either keep the key at or below %s and declare the property Int64, or - ' +
    'if the domain really needs the whole unsigned range - declare the ' +
    'column [Column(''%s'', ftString, 20)], which binds through ' +
    'TParam.AsString and keeps every digit.',
    [UIntToStr(TVarData(AValue).VUInt64),
     AProperty.Name,
     AObject.ClassName,
     IntToStr(High(Int64)),
     AColumnName,
     IntToStr(Int64(TVarData(AValue).VUInt64)),
     IntToStr(High(Int64)),
     AColumnName]);
end;

end.
