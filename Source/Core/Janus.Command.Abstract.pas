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
  Janus.DML.Commands,
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
    ///  WHAT LEAVES JANUS IS INTACT, AND THAT IS THE HALF THAT IS MEASURED.
    ///  Issue #325 guessed three places for the conversion - the parameter
    ///  build, the driver, the type mapping - and the first of the three can
    ///  be ruled out here. A standalone probe built with the same Studio 37.0
    ///  that builds this repository, using nothing but the RTL, answers: a
    ///  UInt64 property read through RTTI arrives as a Variant of
    ///  VType = varUInt64 (21) with every bit intact, and assigning it to a
    ///  TParam whose DataType is ftLargeint KEEPS VType 21. The parameter this
    ///  house hands down still spells 9223372036854775808.
    ///
    ///  WHERE THE FLIP IS ACTUALLY PERFORMED IS **NOT MEASURED**, AND AN
    ///  EARLIER VERSION OF THIS COMMENT SAID IT WAS. It claimed the flip
    ///  happens in Data.DB's TParam.AsLargeInt "before any driver is reached".
    ///  That accessor does answer -9223372036854775808 over this Variant - the
    ///  probe measures it - but the accessor IS NOT ON THIS PATH:
    ///  TFDParam.AssignDlpParam, the routine FireDAC uses to take a TParam and
    ///  read in the FireDAC source shipped with Studio 37.0, anchored by
    ///  METHOD, special-cases only the string and binary labels and copies the
    ///  raw Variant for everything else - ftLargeint included. So the value
    ///  crosses into FireDAC unsigned and complete, and which layer below
    ///  reinterprets it has not been established here.
    ///
    ///  THE REFUSAL DOES NOT REST ON THAT. What it rests on is measured at
    ///  both ends: the row on disk carries -9223372036854775808 (the fixture
    ///  reads it back with SQLite's own typeof), and ftLargeint is a SIGNED
    ///  label - Data.DB gives the unsigned 64-bit case a DIFFERENT label,
    ///  ftLargeUint, with a TLargeUintField of its own, which is what makes
    ///  ftLargeint's signedness explicit rather than assumed. A value above
    ///  High(Int64) has nowhere to sit under that label, wherever the sign is
    ///  finally dropped.
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
    ///  64-bit case, complete with a TLargeUintField.
    ///
    ///  THE SCAN BEHIND THAT, WITH THE DENOMINATOR IT ACTUALLY HAD. An earlier
    ///  version of this paragraph named seven source trees and called them
    ///  "every tree on the unit search path". They were not: the seven .dproj
    ///  of this repository resolve to 54 directories that exist on disk -
    ///  MARS and its ThirdParty subtrees, WiRL and its Libs, and a models
    ///  folder under Examples\ among them. Rebuilt the way the build itself
    ///  builds it, and scanned: on those 54, exactly ONE .pas names
    ///  ftLargeUint, and it is this unit. A recursive sweep of the whole
    ///  worktree finds the same one and nothing else.
    ///
    ///  AND "FINDS NOTHING BUT" WAS LITERALLY FALSE ABOUT THE COMPILER'S OWN
    ///  PATH: the Studio library directories are always searched, and their
    ///  source has FIFTEEN files naming the label, Data.DB - where it is
    ///  declared - and FireDAC.Stan.Param among them. That is the point rather
    ///  than an exception: the label exists, and nothing in Janus, MetaDbDiff
    ///  or DataEngine names it, so no DDL type, no DML branch and no field
    ///  mapping in this house answers to it.
    ///
    ///  WHAT CANNOT BE SAID IS "no column CAN be declared unsigned 64-bit".
    ///  Column.Create - in MetaDbDiff.Mapping.Attributes, by symbol - stores
    ///  the TFieldType it is handed and validates nothing, so a consumer is
    ///  perfectly free to write [Column('x', ftLargeUint)]. What is measured
    ///  is that nobody does, and that nothing downstream would know what to do
    ///  with it. The message this routine raises says the accurate thing -
    ///  "Janus maps no column onto it" - and this comment used to say more.
    ///
    ///  IT READS THE PARAMETER BACK RATHER THAN THE PROPERTY, ON PURPOSE. What
    ///  the driver binds is TParam.Value, so that is what is inspected; an
    ///  intermediate that agrees with it today is not the thing under test.
    ///
    ///  IT GUARDS WRITES AND NOT LOOKUPS, WHICH IS THE ONE ASYMMETRY IN IT.
    ///  TCommandInserter's parameters and TCommandUpdater's MODIFIED-COLUMN
    ///  loop write; TCommandUpdater's primary-key loop and every parameter
    ///  TCommandDeleter builds are the WHERE. The lookup is self-consistent -
    ///  an object loaded out of a row whose key is Low(Int64) updates and
    ///  deletes THAT SAME ROW - and that is measured as an OUTCOME, at 0546a51
    ///  and here, by two clauses in
    ///  Test.Janus.Server.Resource.IntegerKeyWidth; the round trip is not
    ///  argued from a mechanism this branch never established. What IS known
    ///  about the mechanism is the READ half: both clauses die when
    ///  TBind._SetFieldToPropertyInteger's AsLargeInt arm is turned back into
    ///  AsInteger, so both of them do pass through it. Refusing here would
    ///  leave a row that already carries such a key unrepairable and
    ///  unremovable, which is worse than the state this issue found.
    ///
    ///  WHAT IT DOES NOT COVER, SAID RATHER THAN LEFT TO BE FOUND. The SELECT
    ///  side builds its predicate as a LITERAL in
    ///  TDMLGeneratorAbstract.GetGeneratorWhere, which is not touched here: a
    ///  read under such a key returns no row rather than a wrong one, and
    ///  returning nothing corrupts nothing on disk.
    ///
    ///  OTHER DIALECTS ARE NOT MEASURED - there is no non-SQLite database on
    ///  this machine. The reason to expect the same answer is the LABEL and
    ///  not a layer: ftLargeint is the signed one of Data.DB's two 64-bit
    ///  labels, and a column declared with it has no room for the sign in any
    ///  dialect. That is an argument, not a measurement, and it is written
    ///  here as an argument. Whether a dialect with a native unsigned 64-bit
    ///  column could carry the value is a different question again, and this
    ///  refusal does not answer it.
    ///
    ///  WHICH SUITES CAN ANSWER A MUTATION OF THIS ROUTINE, because "the suite
    ///  stayed green" is worth nothing until that is known. Measured the way
    ///  the mutations were, by whether dcc32 echoes a {$MESSAGE WARN} planted
    ///  here: it echoes for Units, RESTHorse, RESTMARS and RESTOracle, and does
    ///  NOT echo for LiveBindings, RESTfulDriver and RESTWiRL - those three do
    ///  not compile this unit at all. Of the four that do, only RESTHorse
    ///  carries clauses that can die: Units and RESTMARS have no entity with an
    ///  unsigned property, and RESTOracle's twelve clauses are already errored
    ///  at 0546a51, so nothing there can move either way.
    ///
    ///  TWO SURVIVORS, DECLARED. Blanking either of the two slots that print
    ///  the limit leaves every clause green, because the message prints
    ///  9223372036854775807 TWICE - once as the bound exceeded and once as the
    ///  advice - and the assertion is satisfied by whichever survives.
    ///  Blanking BOTH kills the clause. That is redundancy in the message
    ///  rather than blindness in the probe, and it is recorded instead of
    ///  engineered away. Every other slot in this Format - the value, the
    ///  property, the entity, the column named in the diagnosis, the signed
    ///  reinterpretation, and the column named in the ADVICE - kills the
    ///  clause when blanked. The last two were survivors until a reviewer
    ///  found them; the advice one mattered most, because the bracketed
    ///  declaration is the part a reader COPIES. </summary>
    procedure _RefuseUnsignedValueTheColumnCannotCarry(const AObject: TObject;
      const AColumnName: String; const AProperty: TRttiProperty;
      const AFieldType: TFieldType; const AValue: Variant);

    /// <summary> ISSUE #294 - THE WRITE HALF OF A REFUSAL THAT USED TO GUARD
    ///  ONLY THE READ.
    ///
    ///  Issues #284 and #290 made the association SELECT refuse when
    ///  IOptions.StoreGUIDAsOctet is on, because the 38-character text of a
    ///  TGUID matches nothing against the 16-byte column that option declares.
    ///  The three write commands below this class emit that SAME text - as a
    ///  bound parameter rather than as a literal, which changes the shape and
    ///  not the outcome - and had no guard at all. A refusal that covers the
    ///  read and not the write is worse than either: the caller stores a row
    ///  and then cannot find it.
    ///
    ///  The reason, and the measurement that would lift the refusal, are
    ///  written once over TGuidOctetRefusal in Janus.DML.Commands. This is a
    ///  three-line delegation on purpose: the connection it asks about is the
    ///  one this command already holds, and AOperation is the only thing each
    ///  call site adds. </summary>
    procedure _GuardStoreGUIDAsOctet(const AProperty: TRttiProperty;
      const AOperation: String);
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
    '"%s" is declared ftLargeint - a SIGNED 64-bit label - so the value ' +
    'reaches the row as %s, and the row would be written, and afterwards ' +
    'looked up, under a key nobody asked for, without a word. Data.DB ' +
    'declares ftLargeUint for the unsigned 64-bit case, with a field class ' +
    'of its own, and Janus maps no column onto it. WHAT TO DO: ' +
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

procedure TDMLCommandAbstract._GuardStoreGUIDAsOctet(
  const AProperty: TRttiProperty; const AOperation: String);
begin
  TGuidOctetRefusal.Check(FConnection, AProperty, AOperation);
end;

end.
