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
  @abstract(REST Componentes)
  @created(20 Jun 2018)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

{$INCLUDE ..\..\Janus.inc}
//{$DEFINE TRIAL}

unit Janus.Server.Resource;

interface

uses
  Classes,
  SysUtils,
  Variants,
  Rtti,
  Generics.Collections,
  // Janus
  MetaDbDiff.mapping.repository,
  MetaDbDiff.mapping.explorer,
  MetaDbDiff.mapping.popular,
  MetaDbDiff.mapping.register,
  Janus.Server.RestQuery.Parse,
  Janus.Server.RestObjectSet,
  DataEngine.FactoryInterfaces;

type
  TAppResourceBase = class
  private
    FConnection: IDBConnection;
    const
      cRESOURCENOTFOUND    = '{"exception":"Resource T%s not found!"}';
      cRESOURCENOTREGISTER = '{"exception":"Resource [%s] not registered on the server!"}';
      cRESOURCEPERMITION   = '{"exception":"Resource [%s] without access permission by the [NotServerUse] attribute!"}';
      cRESOURCEREADONLY    = '{"exception":"Resource %s is read-only (RESTReadOnly)"}';
      cRESOURCEVERBNOTALLOWED = '{"exception":"HTTP %s not allowed for %s"}';
      cEXCEPTIONJSON       = '{"exception":"There was an error in trying to convert JSON into the class [%s]!"}';
      cRESOURCEDELETE      = '{"result":"Resource %s delete command executed successfully"}';
      /// The %s is now a whole serialised JSON OBJECT, braces included - it
      /// used to be the inside of a pair list, with the braces written here.
      /// The document on the wire is unchanged.
      cRESOURCEINSERT      = '{"result":"Resource %s insert command executed successfully", "params":[%s]}';
      cRESOURCEUPDATE      = '{"result":"Resource %s update command executed successfully"}';
    function ResolverFindToSkip(const AObjectSet: TRESTObjectSet;
      const AQuery: TRESTQueryParse): string;
    function ResolverFindFilter(const AObjectSet: TRESTObjectSet;
      const AQuery: TRESTQueryParse): string;
    function ResolverFindID(const AObjectSet: TRESTObjectSet;
      const AQuery: TRESTQueryParse): string;
    function ResolverFindAll(const AObjectSet: TRESTObjectSet;
      const AQuery: TRESTQueryParse): string;
  protected
    FResultCount: Integer;
    function ParseInsert(const AQuery: TRESTQueryParse; const AValue: string): string;
    function ParseUpdate(const AQuery: TRESTQueryParse; const AValue: string): string;
  public
    constructor Create(const AConnection: IDBConnection); overload; virtual;
    destructor Destroy; override;
    function ParseFind(const AQuery: TRESTQueryParse): string;
    function ParseDelete(const AQuery: TRESTQueryParse): string;
    function select(const AResource: string): string; overload; virtual;
    function insert(const AResource: string; const AValue: string): string; overload; virtual;
    function update(const AResource: string; const AValue: string): string; overload; virtual;
    function delete(const AResource: string): string; overload; virtual;
    function ResultCount: Integer;
  end;

implementation

uses
  JSON,
  DB,
  StrUtils,
  MetaDbDiff.mapping.classes,
  MetaDbDiff.mapping.attributes,
  MetaDbDiff.rtti.helper,
  Janus.Json,
  Janus.Objects.Helper,
  Janus.Core.Consts,
  Janus.Server.RestView.Manager;

/// <summary> The JSON VALUE of one primary key column, BUILT rather than
///  pasted into a string.
///
///  What it replaces emitted the value raw, straight out of VarToStr, next to
///  a hand-quoted name. That is valid JSON only while the value happens to
///  look like a JSON number, which is to say only for an integer key. A
///  textual key came out as a bare token, a generated GUID came out with
///  braces and hyphens, a date came out with slashes, and a fractional key
///  came out with whatever the AMBIENT decimal separator is - a comma on a
///  pt-BR machine. None of those is JSON, and the client discards a document
///  it cannot parse through a bare Exit, silently.
///
///  WHY THIS DISPATCHES ON THE VARIANT AND NOT ON TColumnMapping.FieldType.
///  The argument is about SELECTING a branch, and about nothing else. A
///  FieldType table is a list of enum labels, and a label in the wrong bucket
///  cannot be caught by anything short of one entity per label - drop
///  ftLargeint from the numeric bucket and a 64-bit key silently starts
///  arriving quoted, with the whole suite green. The Variant has FOUR states
///  reachable from a mapped property and the fixture has a clause for each:
///  null, ordinal, float, everything else.
///
///  That says nothing whatsoever about the CONVERSION performed once a branch
///  has been selected, and the first version of this repair learned the
///  difference the hard way: it selected the number branch correctly for an
///  unsigned 64-bit key and then handed the caller the negative
///  reinterpretation of it. Selection and conversion are two surfaces and each
///  needs its own clause, on BOTH numeric branches - see
///  BigIntegerKey_MustNotBeNarrowed and UnsignedKeyAboveHighInt64_MustNotFlipSign
///  for the ordinal one, FractionalKey_MustNotBeTruncatedByANarrowerFloat for
///  this one.
///
///  THE TWO NUMERIC BRANCHES CONVERT DIFFERENTLY, AND THE ASYMMETRY WAS
///  MEASURED RATHER THAN ASSUMED. VarToStr was run over varInteger, varInt64,
///  varUInt64, varDouble, varCurrency and varSingle under four FormatSettings:
///  the ambient pt-BR one, then ThousandSeparator forced to '.', then to '#',
///  then DecimalSeparator forced to '@'. Results:
///
///    - No ORDINAL type took a separator under ANY of the four. That is what
///      makes VarToStr safe above.
///    - varDouble and varSingle follow the ambient DECIMAL separator: under
///      '@' they rendered 1234567@75 and 1234@5. That is what makes VarToStr
///      unsafe here, and why this branch hands an explicit Double to
///      TJSONNumber instead.
///    - ThousandSeparator moved nothing, for any of the six types. The hazard
///      on this path is the decimal separator alone.
///    - varCurrency did not follow the '@' either - it kept the ambient comma.
///      Measured, not explained; it is routed through the same Double here and
///      the clause does not depend on why.
///
///  There is a safety net under the ordinal branch worth knowing about:
///  TJSONNumber.Create(string) runs StrToFloat with JSONFormatSettings, so a
///  string that ever did arrive grouped would RAISE rather than become a
///  silently malformed document.
///
///  The float branch has a ceiling and it is the RTL's, not this code's:
///  FloatToJson prints with JSONFormatSettings, whose Precision is 15.
///  Measured through this very path - 0.123456789 comes back verbatim,
///  12345678.9012345678 comes back as 12345678.9012346. A key needing more
///  than 15 significant digits is therefore rounded here, and no clause in the
///  fixture stands in front of that: pinning it would be pinning RTL
///  formatting, and no mapping in this repository produces such a key.
///
///  The guard above catches TWO Variant states, not one, and they are reached
///  by different shapes. MetaDbDiff's TRttiPropertyHelper.GetNullableValue
///  answers a Variant NULL for a Nullable whose FHasValue is clear, and leaves
///  the Default(TValue) it started with - an EMPTY TValue - by three other
///  routes: a nil instance, a Nullable-shaped record with no FHasValue field,
///  and one with FHasValue set but no FValue field. TValue.AsVariant on an
///  empty value does not raise and does not answer Null; AsTypeInternal takes
///  the branch that zero-fills the result, and a zeroed Variant is varEmpty.
///  So VarIsNull is False there and only VarIsEmpty catches it.
///
///  A nil instance cannot happen at this call site - the caller has just
///  dereferenced that object - but the third route is reachable by a mapping
///  the framework accepts, because IsNullable is a check BY NAME. Measured,
///  not argued: Test.Janus.Model.KeyTypeDecoy declares such a record and
///  NullableShapedKeyWithNoValueField_ComesBackAsJsonNull dies when the
///  VarIsEmpty half of this guard is removed. Both halves are load-bearing,
///  and removing either is not response-neutral: an empty Variant would leave
///  as "" rather than null, and an empty string is something a client writes
///  into a field as if it were the value.
///
///
///  Booleans are deliberately NOT mapped onto a JSON boolean: VarIsOrdinal is
///  true for varBoolean, so the guard below excludes it and a boolean key
///  leaves as the quoted string VarToStr already produced. That is valid JSON
///  and it is what the previous behaviour meant to say; turning it into a JSON
///  literal would be a contract change no clause here measures.
///
///  varDate is excluded from the float branch by VarIsFloat itself, which
///  covers only varSingle, varDouble and varCurrency. A date key therefore
///  reaches the string branch and keeps rendering exactly as it did - what
///  changes is only that it is now QUOTED. Whether that rendering should be
///  ISO-8601 instead of the ambient FormatSettings is a question about what a
///  consumer receives, and it is not this repair's to answer. </summary>
function _PrimaryKeyValueToJson(const AColumn: TColumnMapping;
  const AObject: TObject): TJSONValue;
var
  LValue: Variant;
begin
  LValue := AColumn.ColumnProperty.GetNullableValue(AObject).AsVariant;
  if VarIsNull(LValue) or VarIsEmpty(LValue) then
    Exit(TJSONNull.Create);
  if VarIsOrdinal(LValue) and (VarType(LValue) <> varBoolean) then
    Exit(TJSONNumber.Create(VarToStr(LValue)));
  if VarIsFloat(LValue) then
    Exit(TJSONNumber.Create(Double(VarAsType(LValue, varDouble))));
  Result := TJSONString.Create(VarToStr(LValue));
end;

/// <summary> The SQL LITERAL of one primary key column, RENDERED rather than
///  pasted into a statement. Issue #320.
///
///  What it replaces emitted the value raw, straight out of VarToStr, next to
///  a '='. In SQL a bare token in that position is a COLUMN REFERENCE, so the
///  whole of PUT was broken for any entity whose key is not a bare number:
///  measured through this very path against SQLite, a textual key produced
///  `[FireDAC][Phys][SQLite] ERROR: no such column: ABC`, and a date key
///  produced `(ktdate.ktday=17/03/2026)` - three integers divided, no error
///  raised, no row found, the PUT silently doing nothing.
///
///  AND THE VALUE COMES OUT OF THE REQUEST BODY. Measured at the base commit,
///  through the server's own monitor callback: a body whose key was
///  `kttag) OR (kttext.ktcode='ABC'` produced
///    SELECT ... FROM kttext WHERE (kttext.ktcode=kttag) OR (kttext.ktcode='ABC')
///  which SQLite accepts, and the row named ABC did not survive the request.
///  That is not a hypothesis about a hostile client; it is what concatenating
///  request text into a statement means.
///
///  WHY THIS DISPATCHES ON TColumnMapping.FieldType AND ITS JSON SIBLING
///  DISPATCHES ON THE VARIANT, AND WHY THAT IS NOT A CONTRADICTION.
///  _PrimaryKeyValueToJson, above, argues at length for the Variant, and that
///  argument is sound FOR JSON: JSON has four value kinds and the Variant has
///  four reachable states, so the mapping is total and a wrong bucket is
///  visible. SQL is not like that. The correct literal for a date depends on
///  how the column STORES it, not on the fact that a TDateTime arrived, and
///  varDate, varDouble and a string are three Variant states that need three
///  different literal forms which the Variant alone cannot choose between.
///  The house already answered this exact question on the other side of the
///  same family: TRESTDataSetAdapter<M>._FilterLiteral in
///  Janus.RestDataSet.Adapter builds the literal for a $filter predicate and
///  dispatches on TField.DataType. That is the PRECEDENT this function follows,
///  taking a TColumnMapping and an instance instead of a TField, because that
///  is what the server side has.
///
///  AN EARLIER VERSION OF THIS PARAGRAPH SAID THE TWO WERE "THE SAME TABLE OF
///  BRANCHES" AND THAT "THIS FUNCTION IS THAT TABLE". BOTH ARE FALSE, RELIED
///  ON A READING THAT WAS NEVER MADE, AND THE FALSE HALF IS THE ONE THAT
///  JUSTIFIED THE WHOLE ROUTE. Read at this commit, the two tables diverge in
///  three places:
///
///    - _FilterLiteral has NO ftBoolean branch; this one does.
///    - _FilterLiteral folds ftDateTime and ftDate into ONE case label and
///      picks the mask inside it with an ifThen; this one gives them two.
///    - _FilterLiteral's decimal branch is ftCurrency, ftBCD, ftFMTBcd,
///      ftFloat; this one adds DB.ftSingle and DB.ftExtended. That third
///      divergence was opened BY THIS BRANCH, one commit after the sentence
///      above was corrected - which is exactly how the first one got written.
///
///  The precedent is real and the route stands on it. The word "same" did not.
///
///  AND THE TWO TABLES ALREADY DIVERGED BEFORE THIS BRANCH TOUCHED EITHER OF
///  THEM: the ftDateTime/ftDate split is on the server side of the family and
///  predates all of this. Nothing noticed, because NO TEST ANYWHERE COMPARES
///  THE TWO TABLES - the duplication is defended clause by clause on each side
///  and not against each other. That absence is recorded here and NOT repaired
///  here; closing it is a piece of work of its own.
///
///  ONE OF THOSE DIVERGENCES IS VISIBLE ON THE WIRE AND HAS TO BE SAID OUT
///  LOUD. A boolean key now leaves this side as 1 - measured,
///  WHERE (ktbool.ktflag=1) - while the client side, which has no ftBoolean
///  branch, still renders the bare token True into a $filter. The two ends of
///  the same family now spell the same key differently. No clause on either
///  side sees that, for the reason in the paragraph above.
///
///  A FieldType table is a list of enum labels, and the honest thing to say
///  about it is which labels are DEFENDED. The clauses in
///  Test.Janus.Server.Resource.UpdateWhere reach ftString (plain, quote-bearing,
///  GUID-shaped, aliased, composite and nullable), ftInteger, ftLargeint,
///  ftFloat, DB.ftSingle, ftDate and ftBoolean. ftWideString, ftMemo,
///  ftWideMemo, ftFmtMemo, ftGuid, ftDateTime, ftTime, ftTimeStamp,
///  ftOraTimeStamp, ftCurrency, ftBCD, ftFMTBcd and DB.ftExtended share a
///  branch with a defended label but have no primary key of their own anywhere
///  under Test\, so they are grouped by argument and not by measurement.
///
///  THE TWO LISTS ABOVE HAVE TO ACCOUNT FOR EVERY LABEL THIS FUNCTION NAMES,
///  and the previous version of them did not: DB.ftSingle and DB.ftExtended
///  appeared in neither, because the branch did not name them and nothing
///  forced the question. A label that is in no list is not "grouped by
///  argument" - it is unexamined, and it fell through to the default.
///
///  THE EMPTY RESULT IS A SIGNAL, NOT A LITERAL. A key the request left
///  undetermined - a Nullable the caller did not send - cannot identify a row,
///  and must not be allowed to identify an arbitrary one. It comes back as ''
///  and the caller emits `1 = 0`, the same idiom Janus.DML.Generator uses for
///  an undetermined association value. The PUT then leaves through the
///  `if LObjectOld = nil then Exit` that ParseUpdate already had for a row
///  that is not there, so this is not a new exit - it is an existing one,
///  reached honestly instead of by a SQL syntax error.
///
///  AND THAT TRADE HAS A COST WORTH NAMING. Before this change, a PUT whose
///  key carried no value emitted `WHERE (ktnull.ktopt=)` and the request died
///  loudly - `[FireDAC][Phys][SQLite] ERROR: near ")": syntax error`. It now
///  emits `WHERE (1 = 0)` and the caller gets an EMPTY BODY and no exception.
///  That is consistent with what ParseUpdate already did for a row that is not
///  there, and the alternative - letting a malformed statement decide - was
///  worse. But the "PUT that silently does nothing" this issue was opened
///  against remains the house's answer for a missing row: what changed is that
///  it is now reached BY CONTRACT rather than BY ACCIDENT. Whether a PUT that
///  matches no row should answer 404 instead of an empty 200 is a question
///  about what a consumer receives, and it is not this repair's to settle.
///
///  DATE AND TIME GO OUT IN ISO-8601 AND THE RESIDUE IS DECLARED. The
///  dialect-correct mask lives in TDMLGeneratorAbstract.FDateFormat, which has
///  four distinct values across the thirteen dialects and is unreachable from
///  this layer - the resource holds an IDBConnection and a TRESTObjectSet, and
///  nothing on that path exposes the generator. ISO-8601 is what the sibling
///  _FilterLiteral already speaks, and it happens to be exactly the SQLite
///  generator's own FDateFormat ('yyyy-MM-dd'), which is what the fixture
///  measures. On a dialect whose FDateFormat differs, a date PRIMARY KEY is
///  still not located - it is now a well-formed literal that finds nothing
///  rather than a malformed statement, which is an improvement and not a
///  repair. Fixing it properly means building the predicate inside the
///  generator, which means a new method on IDMLGeneratorCommand: a contract
///  change, and not this issue's to make.
///
///  THE COLONS ARE QUOTED INSIDE THE MASKS because ':' is FormatDateTime's
///  placeholder for TimeSeparator and would come out swapped by the ambient
///  locale. TFormatSettings.Invariant is passed as well, so neither separator
///  nor the ambient calendar can move the text. That is one step stricter than
///  _FilterLiteral, which passes no FormatSettings; the divergence is
///  deliberate and is recorded rather than fixed here, because that unit
///  belongs to the client side of this family.
///
///  ON THE ftDate BRANCH THAT Invariant IS INERT TODAY, AND IT IS KEPT ANYWAY.
///  Measured by mutation: removing it from the ftDate branch kills nothing.
///  The reason is structural rather than lucky - in a FormatDateTime mask only
///  '/' and ':' are separator PLACEHOLDERS, and cISODATE is 'yyyy-mm-dd',
///  whose '-' is a literal. So no locale can move that particular text with or
///  without the argument. It stays because the mask is the only thing making
///  it inert, and a mask is one edit away from carrying a '/'. The clause that
///  would catch it does not exist and cannot be written against this mask.
///
///  ftBoolean HAS A BRANCH OF ITS OWN, AND AN EARLIER DRAFT OF THIS VERY
///  COMMENT SAID IT DID NOT. It was written while the boolean still fell
///  through to the default branch, and the measurement that followed - the row
///  the framework's own INSERT leaves behind carries typeof() = integer under
///  SQLite - moved it. The branch, and the residue it does not remove, are
///  described where the branch is. </summary>
function _PrimaryKeyValueToSql(const AColumn: TColumnMapping;
  const AObject: TObject): String;
const
  /// The colons are quoted: ':' is the TimeSeparator placeholder.
  cISODATE     = 'yyyy-mm-dd';
  cISODATETIME = 'yyyy-mm-dd"T"hh":"nn":"ss';
  cISOTIME     = 'hh":"nn":"ss';
var
  LValue: Variant;
begin
  LValue := AColumn.ColumnProperty.GetNullableValue(AObject).AsVariant;
  if VarIsNull(LValue) or VarIsEmpty(LValue) then
    Exit('');
  case AColumn.FieldType of
    ftString, ftWideString, ftMemo, ftWideMemo, ftFmtMemo, ftGuid:
      Result := QuotedStr(VarToStr(LValue));
    ftDate:
      Result := QuotedStr(FormatDateTime(cISODATE, VarToDateTime(LValue),
                                         TFormatSettings.Invariant));
    ftDateTime:
      Result := QuotedStr(FormatDateTime(cISODATETIME, VarToDateTime(LValue),
                                         TFormatSettings.Invariant));
    ftTime, ftTimeStamp, ftOraTimeStamp:
      Result := QuotedStr(FormatDateTime(cISOTIME, VarToDateTime(LValue),
                                         TFormatSettings.Invariant));
    /// A numeric literal, and the decimal separator has to be the SQL one and
    /// not the machine's. VarToStr follows the ambient DecimalSeparator for
    /// varDouble, varSingle and varCurrency, so the text is normalised here -
    /// the same normalisation TDMLGeneratorAbstract._GetPropertyValue applies
    /// to the very same field types.
    ///
    /// DB.ftSingle AND DB.ftExtended ARE ON THIS LIST BECAUSE LEAVING THEM OFF
    /// REOPENED THE DEFECT INSIDE THE FUNCTION WRITTEN TO CLOSE IT. Measured
    /// on the tree that carried this branch without them, through the server's
    /// own monitor callback:
    ///   SELECT ... FROM ktsingle WHERE (ktsingle.ktsng=10,5)
    ///   [FireDAC][Phys][SQLite] ERROR: near ",": syntax error
    /// They are not exotic labels in this repository: Janus.DataSet.Base.Adapter
    /// declares cBINARYFLOATFIELDKINDS as [ftFloat, DB.ftSingle, DB.ftExtended]
    /// and Janus.DataSet.Fields builds a TSingleField and a TExtendedField for
    /// them - both anchored by SYMBOL. QUALIFIED with DB. because TypInfo
    /// declares an ftSingle of its own, which is the reason
    /// Janus.DataSet.Base.Adapter gives for qualifying the same two labels.
    ftCurrency, ftBCD, ftFMTBcd, ftFloat, DB.ftSingle, DB.ftExtended:
      Result := ReplaceStr(VarToStr(LValue), ',', '.');
    /// VarToStr renders a boolean as the bare token True, which is the very
    /// shape this repair exists to stop emitting. What replaces it is 1 / 0,
    /// and the reason is MEASURED rather than conventional: the row this
    /// framework writes through its own bound-parameter INSERT lands in SQLite
    /// with `typeof(ktflag)` = integer - read back through the fixture's own
    /// connection - so an integer literal is what locates it.
    ///
    /// THE RESIDUE IS THE SAME ONE THE DATE BRANCH HAS, and it is declared
    /// rather than papered over: on a dialect with a native BOOLEAN type that
    /// refuses an integer comparison, this literal is well-formed SQL that
    /// finds nothing. Only the generator knows the dialect, and reaching it
    /// from here is a contract change - see the header. No mapping in this
    /// repository outside the fixture has a boolean primary key.
    ftBoolean:
      Result := IfThen(Boolean(LValue), '1', '0');
  else
    /// Integer, 64-bit and unsigned 64-bit keys leave as bare digits. Measured
    /// by the #311 author over varInteger, varInt64 and varUInt64 under four
    /// FormatSettings: no ORDINAL type takes a separator under any of them,
    /// and VarToStr of a varUInt64 above High(Int64) keeps its unsigned value
    /// rather than the signed reinterpretation of the bit pattern.
    Result := VarToStr(LValue);
  end;
end;

{ TAppResourceBase }

constructor TAppResourceBase.Create(const AConnection: IDBConnection);
begin
  FResultCount := 0;
  FConnection := AConnection;
end;

function TAppResourceBase.delete(const AResource: string): string;
begin
  Result := AResource;
end;

destructor TAppResourceBase.Destroy;
begin

  inherited;
end;

function TAppResourceBase.insert(const AResource, AValue: string): string;
var
  LQuery: TRESTQueryParse;
begin
  LQuery := TRESTQueryParse.Create;
  try
    LQuery.ParseQuery(AResource);
    // Parse da Query passada na URI
    if LQuery.ResourceName = '' then
      raise Exception.CreateFmt(cRESOURCENOTFOUND, [AResource]);
    Result := ParseInsert(LQuery, AValue)
  finally
    LQuery.Free;
  end;
end;

function TAppResourceBase.update(const AResource, AValue: string): string;
var
  LQuery: TRESTQueryParse;
begin
  LQuery := TRESTQueryParse.Create;
  try
    // Parse da Query passada na URI
    LQuery.ParseQuery(AResource);
    if LQuery.ResourceName = '' then
      raise Exception.CreateFmt(cRESOURCENOTFOUND, [AResource]);
    Result := ParseUpdate(LQuery, AValue)
  finally
    LQuery.Free;
  end;
end;

function TAppResourceBase.ParseDelete(const AQuery: TRESTQueryParse): string;
var
  LObject: TObject;
  LClassType: TClass;
  LObjectSet: TRESTObjectSet;
  LAllowVerbs: TRESTAllowVerbCache;

  procedure ExceptionExecute;
  begin
    if LObject = nil then
      raise Exception.Create('{"result":"No records found to delete, with the filter entered!"}');
  end;

  procedure FilterExecuteFind;
  begin
    if Length(AQuery.Filter) > 0  then
      LObject := LObjectSet.FindOne(AQuery.Filter);
  end;

  procedure IDExecuteFind;
  begin
    if LObject <> nil then
      Exit;
    if AQuery.ID.IsEmpty then
      raise Exception.Create('{"exception":"The delete method needs the ID parameter!"}');
    LObject := LObjectSet.Find(AQuery.ID.ToString);
  end;

begin
  Result := '';
  LObject := nil;
  LClassType := TMappingExplorer.GetRepositoryMapping.FindEntityByName(AQuery.ResourceName);
  if LClassType = nil then
    Exit;

  if TMappingExplorer.GetRESTReadOnly(LClassType) then
    raise Exception.CreateFmt(cRESOURCEREADONLY, [AQuery.ResourceName]);

  if TMappingExplorer.GetMappingView(LClassType) <> nil then
    raise Exception.CreateFmt(cRESOURCEREADONLY, [AQuery.ResourceName]);

  LAllowVerbs := TMappingExplorer.GetRESTAllowVerbs(LClassType);
  if LAllowVerbs.HasAllowList then
    if not (rvDELETE in LAllowVerbs.AllowedVerbs) then
      raise Exception.CreateFmt(cRESOURCEVERBNOTALLOWED, ['DELETE', AQuery.ResourceName]);

  try
    LObjectSet := TRESTObjectSet.Create(FConnection, LClassType);
    try
      // Busca o registro pelo filtro
      FilterExecuteFind;
      // Busca o registro pelo ID
      IDExecuteFind;
      // Caso nenhum dos dois metodos encontre um registro, sera gerado uma
      // excecao com uma mensagem de registro nao encontrado para quem requisitou
      ExceptionExecute;
      // Se passar tudo ok, sera executado o metodo do Janus
      LObjectSet.Delete(LObject);
      Result := Format(cRESOURCEDELETE, [AQuery.ResourceName]);
    finally
      if LObject <> nil then
        LObject.Free;
      LObjectSet.Free;
    end;
  except
    on E: Exception do
    begin
      raise Exception.Create(E.Message);
    end;
  end;
end;

function TAppResourceBase.ParseFind(const AQuery: TRESTQueryParse): string;
var
  LClassType: TClass;
  LObjectSet: TRESTObjectSet;
  LNotSeverUse: Boolean;
  LAllowVerbs: TRESTAllowVerbCache;
begin
  LClassType := TMappingExplorer.GetRepositoryMapping
                                .FindEntityByName(AQuery.ResourceName);
  if LClassType = nil then
    raise Exception.CreateFmt(cRESOURCENOTREGISTER, [AQuery.ResourceName]);

  // Verifica se foi negado acesso a classe, pelo atributo NotServerUse
  LNotSeverUse := TMappingExplorer.GetNotServerUse(LClassType);
  if LNotSeverUse then
    raise Exception.CreateFmt(cRESOURCEPERMITION, [AQuery.ResourceName]);

  LAllowVerbs := TMappingExplorer.GetRESTAllowVerbs(LClassType);
  if LAllowVerbs.HasAllowList then
    if not TMappingExplorer.GetRESTReadOnly(LClassType) then
      if not (rvGET in LAllowVerbs.AllowedVerbs) then
        raise Exception.CreateFmt(cRESOURCEVERBNOTALLOWED, ['GET', AQuery.ResourceName]);

  if TMappingExplorer.GetMappingView(LClassType) <> nil then
    TRESTViewManager.EnsureViewLazy(LClassType, FConnection);

  LObjectSet := TRESTObjectSet.Create(FConnection, LClassType);
  try
    if AQuery.Top > 0 then
      Result := ResolverFindToSkip(LObjectSet, AQuery)
    else
    if Length(AQuery.Filter) > 0  then
      Result := ResolverFindFilter(LObjectSet, AQuery)
    else
    if not AQuery.ID.IsEmpty then
      Result := ResolverFindID(LObjectSet, AQuery)
    else
      Result := ResolverFindAll(LObjectSet, AQuery);
  finally
    LObjectSet.Free;
  end;
end;

function TAppResourceBase.ParseInsert(const AQuery: TRESTQueryParse;
  const AValue: string): string;
var
  LPrimaryKey: TPrimaryKeyColumnsMapping;
  LColumn: TColumnMapping;
  LObject: TObject;
  LClassType: TClass;
  LObjectSet: TRESTObjectSet;
  LParams: TJSONObject;
  LAllowVerbs: TRESTAllowVerbCache;
begin
  LClassType := TMappingExplorer.GetRepositoryMapping
                                .FindEntityByName(AQuery.ResourceName);
  if LClassType = nil then
    raise Exception.CreateFmt(cRESOURCENOTREGISTER, [AQuery.ResourceName]);

  if TMappingExplorer.GetRESTReadOnly(LClassType) then
    raise Exception.CreateFmt(cRESOURCEREADONLY, [AQuery.ResourceName]);

  if TMappingExplorer.GetMappingView(LClassType) <> nil then
    raise Exception.CreateFmt(cRESOURCEREADONLY, [AQuery.ResourceName]);

  LAllowVerbs := TMappingExplorer.GetRESTAllowVerbs(LClassType);
  if LAllowVerbs.HasAllowList then
    if not (rvPOST in LAllowVerbs.AllowedVerbs) then
      raise Exception.CreateFmt(cRESOURCEVERBNOTALLOWED, ['POST', AQuery.ResourceName]);

  try
    LObjectSet := TRESTObjectSet.Create(FConnection, LClassType);
    LObject := LClassType.Create;
    LObject.MethodCall('Create', []);

    TJanusJson.JsonToObject(AValue, LObject);
    if LObject = nil then
      Exit;

    try
      LObjectSet.Insert(LObject);
      LPrimaryKey := TMappingExplorer
                       .GetMappingPrimaryKeyColumns(LObject.ClassType);
      if LPrimaryKey = nil then
        raise Exception.Create(cMESSAGEPKNOTFOUND);

      /// The pairs are ADDED to a TJSONObject and serialised by it. Escaping a
      /// quote or a backslash inside the value, and rendering a number with
      /// the decimal separator JSON requires rather than the one the machine's
      /// locale requires, are then the serialiser's job and not this loop's.
      LParams := TJSONObject.Create;
      try
        for LColumn in LPrimaryKey.Columns do
          LParams.AddPair(LColumn.ColumnProperty.Name,
                          _PrimaryKeyValueToJson(LColumn, LObject));
        /// ToJSON and NOT ToString: both run TJSONAncestor.ToChars, so both
        /// escape the quote and the backslash, but ToString passes no options
        /// while ToJSON passes EncodeBelow32 and EncodeAbove127. A control
        /// character raw inside a JSON string is illegal, so ToString is the
        /// one that can still emit a document nobody can parse.
        /// An empty column list now yields {} instead of indexing LValues[0].
        Result := Format(cRESOURCEINSERT, [AQuery.ResourceName,
                                           LParams.ToJSON]);
      finally
        LParams.Free;
      end;
    finally
      LObject.Free;
      LObjectSet.Free;
    end;
  except
    on E: Exception do
    begin
      raise Exception.Create(E.Message);
    end;
  end;
end;

function TAppResourceBase.ParseUpdate(const AQuery: TRESTQueryParse;
  const AValue: string): string;
var
  LObjectOld: TObject;
  LObjectNew: TObject;
  LClassType: TClass;
  LObjectSet: TRESTObjectSet;
  LPrimaryKey: TPrimaryKeyColumnsMapping;
  LColumn: TColumnMapping;
  LWhere: string;
  LLiteral: string;
  LAllowVerbs: TRESTAllowVerbCache;
begin
  LClassType := TMappingExplorer.GetRepositoryMapping
                                .FindEntityByName(AQuery.ResourceName);
  if LClassType = nil then
    Exit;

  if TMappingExplorer.GetRESTReadOnly(LClassType) then
    raise Exception.CreateFmt(cRESOURCEREADONLY, [AQuery.ResourceName]);

  if TMappingExplorer.GetMappingView(LClassType) <> nil then
    raise Exception.CreateFmt(cRESOURCEREADONLY, [AQuery.ResourceName]);

  LAllowVerbs := TMappingExplorer.GetRESTAllowVerbs(LClassType);
  if LAllowVerbs.HasAllowList then
    if not (rvPUT in LAllowVerbs.AllowedVerbs) then
      raise Exception.CreateFmt(cRESOURCEVERBNOTALLOWED, ['PUT', AQuery.ResourceName]);
  try
    LObjectSet := TRESTObjectSet.Create(FConnection, LClassType);
    LObjectNew := LClassType.Create;
    LObjectNew.MethodCall('Create', []);

    TJanusJson.JsonToObject(AValue, LObjectNew);
    if LObjectNew = nil then
      raise Exception.CreateFmt(cEXCEPTIONJSON, [AQuery.ResourceName]);

    try
      LWhere := '';
      LPrimaryKey := TMappingExplorer.GetMappingPrimaryKeyColumns(LObjectNew.ClassType);
      if LPrimaryKey = nil then
        raise Exception.Create(cMESSAGEPKNOTFOUND);

      /// The value is now rendered as a SQL LITERAL instead of being pasted in
      /// raw - see _PrimaryKeyValueToSql. A key the request left undetermined
      /// yields the unsatisfiable predicate rather than `col=`, which is the
      /// same idiom Janus.DML.Generator already uses for an undetermined
      /// association value (GenerateSelectOneToOne / GenerateSelectOneToOneMany,
      /// anchored by METHOD).
      for LColumn in LPrimaryKey.Columns do
      begin
        LLiteral := _PrimaryKeyValueToSql(LColumn, LObjectNew);
        if LLiteral = '' then
          LWhere := LWhere + '(1 = 0) AND '
        else
          LWhere := LWhere + '(' + LObjectNew.GetTable.Name
                           + '.' + LColumn.ColumnName
                           + '=' + LLiteral + ') AND ';
      end;
      LWhere := Copy(LWhere, 1, Length(LWhere) -5);
      LObjectOld := LObjectSet.FindOne(LWhere);
      if LObjectOld = nil then
        Exit;

      try
        LObjectSet.Modify(LObjectOld);
        LObjectSet.Update(LObjectNew);
        Result := Format(cRESOURCEUPDATE, [AQuery.ResourceName]);
      finally
        LObjectOld.Free;
      end;
    finally
      LObjectNew.MethodCall('Destroy', []);
      LObjectSet.Free;
    end;
  except
    on E: Exception do
    begin
      raise Exception.Create(E.Message);
    end;
  end;
end;

function TAppResourceBase.ResolverFindAll(const AObjectSet: TRESTObjectSet;
  const AQuery: TRESTQueryParse): string;
var
  LObjectList: TObjectList<TObject>;
begin
  FResultCount := 0;
  LObjectList := AObjectSet.Find;
  try
    Result := TJanusJson.ObjectListToJsonString(LObjectList);
    if AQuery.Count then
      FResultCount := LObjectList.Count;
  finally
    LObjectList.Clear;
    LObjectList.Free;
  end;
end;

function TAppResourceBase.ResolverFindFilter(const AObjectSet: TRESTObjectSet;
  const AQuery: TRESTQueryParse): string;
var
  LObjectList: TObjectList<TObject>;
begin
  FResultCount := 0;
  LObjectList := AObjectSet.FindWhere(AQuery.Filter, AQuery.OrderBy);
  try
    Result := TJanusJson.ObjectListToJsonString(LObjectList);
    if AQuery.Count then
      FResultCount := LObjectList.Count;
  finally
    LObjectList.Clear;
    LObjectList.Free;
  end;
end;

function TAppResourceBase.ResolverFindID(const AObjectSet: TRESTObjectSet;
  const AQuery: TRESTQueryParse): string;
var
  LObject: TObject;
begin
  FResultCount := 0;
  LObject := AObjectSet.Find(AQuery.ID.ToString);
  try
    Result := TJanusJson.ObjectToJsonString(LObject);
    if AQuery.Count then
      FResultCount := 1;
  finally
    LObject.Free;
  end;
end;

function TAppResourceBase.ResolverFindToSkip(const AObjectSet: TRESTObjectSet;
  const AQuery: TRESTQueryParse): string;
var
  LObjectList: TObjectList<TObject>;
begin
  FResultCount := 0;
  LObjectList := AObjectSet.NextPacket(AQuery.Filter,
                                       AQuery.OrderBy,
                                       AQuery.Top,
                                       AQuery.Skip);
  try
    Result := TJanusJson.ObjectListToJsonString(LObjectList);
    if AQuery.Count then
      FResultCount := LObjectList.Count;
  finally
    LObjectList.Clear;
    LObjectList.Free;
  end;
end;

function TAppResourceBase.ResultCount: Integer;
begin
  Result := FResultCount;
end;

function TAppResourceBase.select(const AResource: string): string;
begin
  Result := AResource;
end;

end.
