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

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

{$INCLUDE ..\Janus.inc}

unit Janus.RTTI.Helper;

interface

uses
  DB,
  Rtti,
  Variants,
  Classes,
  SysUtils,
  StrUtils,
  TypInfo,
  JsonFlow.utils,
  MetaDbDiff.Rtti.Helper,
  Janus.Types.Nullable;

type
  TRttiPropertyHelper_ = class helper (TRttiPropertyHelper) for TRttiProperty
  private
    function _ResolveNullFromNullableValue(const AObject: TObject;
      const ADefaultValueIsNull: Boolean): Boolean;
  public
//    procedure SetNullableValue(AInstance: Pointer; ATypeInfo:
//      PTypeInfo; AValue: Variant);
    /// <summary> Answers whether the DML consumer must write NULL for this
    ///  property instead of writing its value.
    ///
    ///  WHY THE ANSWER IS DECIDED HERE. Nullable&lt;T&gt; is declared in this
    ///  repository (Janus.Types.Nullable.pas), so what "no value" MEANS for it
    ///  is this repository's word. The mapping layer keeps the two things it
    ///  owns - the [Restrictions([NotNull])] exemption and the [NullIfEmpty]
    ///  opt-in - and this method composes them with the type.
    ///
    ///  THE THREE RULES, IN THIS ORDER:
    ///  1. [Restrictions([TRestriction.NotNull])] exempts the property, and
    ///     exempts it BEFORE anything is read off the instance.
    ///  2. For a bare Nullable&lt;T&gt;, nullity is the absence of a value and
    ///     nothing else. A property nobody assigned resolves to NULL; a
    ///     property assigned the default of its type (0, an empty string, a
    ///     zero date) resolves to that VALUE.
    ///  3. [NullIfEmpty] is the opt-in that maps the default of the type onto
    ///     NULL, on a Nullable&lt;T&gt; property or on a plain one. It is the
    ///     only switch for that behaviour.
    ///
    ///  THE NAME IS DELIBERATELY NOT IsNullValue. A member repeating the
    ///  ancestor helper's name would SHADOW it, and then which of the two
    ///  answers a call site gets would be decided by that unit's uses clause -
    ///  two answers selected by an import. A distinct name has no such state.
    ///
    ///  ONE READ, ONE ANSWER. Presence and value both come from the SAME
    ///  GetNullableValue call: it yields Variant Null exactly for the record
    ///  that carries no value, and the stored value otherwise. Asking a
    ///  HasValue property for the presence and this function for the value
    ///  would be two reads of two different field sets, which can disagree the
    ///  moment a record shaped like a Nullable does not carry every field the
    ///  property reads.
    ///
    ///  CONDITION - the consumer's INSERT and UPDATE paths do not agree on what
    ///  a True means. An INSERT that reacts to it by OMITTING the column lets
    ///  the database apply the column DEFAULT, which need not be NULL, while an
    ///  UPDATE binds an explicit NULL parameter. The same property can
    ///  therefore land two different values in the same column depending on
    ///  which path ran.
    ///
    ///  CONDITION - on a NOT NULL column with no default, answering False where
    ///  this once answered True swaps the failure mode: the column stops being
    ///  omitted, so the database stops refusing the statement and the default
    ///  of the type is written silently instead. Whoever leaned on that refusal
    ///  as a guard no longer has it. </summary>
    function MustWriteNull(const AObject: TObject): Boolean;
    function GetValueNullable(const AInstance: Pointer; const ATypeInfo:
      PTypeInfo): TValue;
    procedure SetValueNullable(const AInstance: Pointer;
      const ATypeInfo: PTypeInfo; const AValue: Variant;
      const AUseISO8601DateFormat: Boolean = True); overload;
  end;

implementation

uses
  Janus.Utils;

{ TRttiPropertyHelper_ }

function TRttiPropertyHelper_.GetValueNullable(const AInstance: Pointer;
  const ATypeInfo: PTypeInfo): TValue;
var
  LNullableGuid: Nullable<TGUID>;
begin
  /// <summary> Nullable&lt;TGUID&gt; CANNOT reach the ToVariant of the other
  ///  arms - issue #314.
  ///
  ///  Nullable&lt;T&gt;.ToVariant (Janus.Types.Nullable.pas:217-227) ends in
  ///  TValue.AsVariant, and AsVariant over a TGUID is exactly the cast that
  ///  raises 'Invalid class typecast'. So this arm renders the GUID itself,
  ///  and renders it as the SAME text every rendering site of this repo writes
  ///  - TGUID.ToString: TCommandInserter._GetParamValue, in
  ///  Janus.Command.Inserter.pas - BY SYMBOL since issue #325 inserted lines
  ///  into that unit -,
  ///  Janus.Command.Updater.pas:134 (the WHERE) and :254 (a written column,
  ///  added by issue #384), Janus.Command.Deleter.pas:109 and
  ///  TDMLGeneratorAbstract.CanonicalGuidLiteral, in Janus.DML.Generator.pas.
  ///  The doctrine behind them is written out in the doc comment over
  ///  TDMLGeneratorAbstract.GuidLiteral, in the same unit.
  ///  BOTH ANCHORS ARE BY SYMBOL BECAUSE THE LINE FORM ROTTED: they read
  ///  :766-768 and :115-136 until issue #326 inserted lines into that unit.
  ///
  ///  MISSING IS NOT HARMLESS HERE. Without an arm the function falls off the
  ///  end with Result = Default(TValue), and the caller
  ///  (Janus.Json.pas:133) turns an EMPTY TValue into an EMPTY variant, which
  ///  the JSON writer renders as NOTHING AT ALL. Measured at ea0208f:
  ///  ObjectToJsonString over a class with one Nullable&lt;TGUID&gt; produced
  ///  the whole document as {"ngid":4,"ngopt":} - a key with no value, i.e.
  ///  JSON that no parser accepts - and produced that same text whether the
  ///  Nullable held a value or not. That is why the empty case is spelled out
  ///  as Null instead of being left to the fall-through. </summary>
  if ATypeInfo = TypeInfo(Nullable<TGUID>) then
  begin
    LNullableGuid := Self.GetValue(AInstance).AsType<Nullable<TGUID>>;
    if LNullableGuid.HasValue then
      Result := TValue.From<Variant>(LNullableGuid.Value.ToString)
    else
      Result := TValue.From<Variant>(Null);
  end
  else
  if ATypeInfo = TypeInfo(Nullable<Integer>) then
    Result := TValue.From(Self.GetValue(AInstance).AsType<Nullable<Integer>>.ToVariant)
  else
  if ATypeInfo = TypeInfo(Nullable<Int64>) then
    Result := TValue.From(Self.GetValue(AInstance).AsType<Nullable<Int64>>.ToVariant)
  else
  if ATypeInfo = TypeInfo(Nullable<String>) then
    Result := TValue.From(Self.GetValue(AInstance).AsType<Nullable<String>>.ToVariant)
  else
  if ATypeInfo = TypeInfo(Nullable<TDateTime>) then
    Result := TValue.From(Self.GetValue(AInstance).AsType<Nullable<TDateTime>>.ToVariant)
  else
  if ATypeInfo = TypeInfo(Nullable<TDate>) then
    Result := TValue.From(Self.GetValue(AInstance).AsType<Nullable<TDate>>.ToVariant)
  else
  if ATypeInfo = TypeInfo(Nullable<TTime>) then
    Result := TValue.From(Self.GetValue(AInstance).AsType<Nullable<TTime>>.ToVariant)
  else
  if ATypeInfo = TypeInfo(Nullable<Currency>) then
    Result := TValue.From(Self.GetValue(AInstance).AsType<Nullable<Currency>>.ToVariant)
  else
  if ATypeInfo = TypeInfo(Nullable<Double>) then
    Result := TValue.From(Self.GetValue(AInstance).AsType<Nullable<Double>>.ToVariant)
  else
  if ATypeInfo = TypeInfo(Nullable<Boolean>) then
    Result := TValue.From(Self.GetValue(AInstance).AsType<Nullable<Boolean>>.ToVariant)
end;

function TRttiPropertyHelper_.MustWriteNull(const AObject: TObject): Boolean;
begin
  Result := False;
  /// The restriction answers first and answers alone: nothing is read off the
  /// instance for a property the schema forbids from being null.
  if Self.IsNotNull then
    Exit(False);

  if (Self.IsNullable) or (Self.IsNullIfEmpty) then
    Exit(_ResolveNullFromNullableValue(AObject, Self.IsNullIfEmpty));
end;

/// <summary> Resolves the nullity of one property value from a SINGLE read.
///
///  ADefaultValueIsNull = False: the only thing that answers True is the
///  absence of a value - GetNullableValue renders that as Variant Null.
///  ADefaultValueIsNull = True: the default of the type ('', zero, a zero date)
///  is ALSO reported as null. That widening is the [NullIfEmpty] opt-in, and
///  nothing else turns it on. </summary>
function TRttiPropertyHelper_._ResolveNullFromNullableValue(
  const AObject: TObject; const ADefaultValueIsNull: Boolean): Boolean;
var
  LValue: TValue;
begin
  Result := False;
  /// PRESENCE AND VALUE COME FROM THIS ONE CALL. Reading the presence
  /// somewhere else would be a second read, and a second read is a second
  /// answer whenever the two readers do not look at the same fields.
  LValue := Self.GetNullableValue(AObject);
  if LValue.AsVariant = Null then
    Exit(True);

  if not ADefaultValueIsNull then
    Exit(False);

  if LValue.Kind in [tkString, tkUString, tkLString, tkWString
                    {$IFDEF DELPHI22_UP}
                    , tkAnsiChar, tkWideChar, tkAnsiString, tkWideString
                    , tkShortString, tkUnicodeString
                    {$ENDIF}] then
  begin
    if LValue.AsType<String> = '' then
      Exit(True);
  end
  else
  if LValue.Kind in [tkInteger, tkInt64] then
  begin
    if LValue.AsType<Integer> = 0 then
      Exit(True);
  end
  else
  if LValue.Kind in [tkFloat] then
  begin
    if LValue.TypeInfo = TypeInfo(TDateTime) then
    begin
      if LValue.AsType<TDateTime> = 0 then
        Exit(True);
    end
    else
    if LValue.TypeInfo = TypeInfo(TDate) then
    begin
      if LValue.AsType<TDate> = 0 then
        Exit(True);
    end
    else
    if LValue.TypeInfo = TypeInfo(TTime) then
    begin
      if LValue.AsType<TTime> = 0 then
        Exit(True);
    end
    else
    begin
      if LValue.AsType<Double> = 0 then
        Exit(True);
    end;
  end;
end;

//procedure TRttiPropertyHelper_.SetNullableValue(AInstance: Pointer;
//  ATypeInfo: PTypeInfo; AValue: Variant);
//begin
//  SetValueNullable(AInstance, ATypeInfo, AValue);
//end;

procedure TRttiPropertyHelper_.SetValueNullable(const AInstance: Pointer;
  const ATypeInfo: PTypeInfo; const AValue: Variant;
  const AUseISO8601DateFormat: Boolean);
begin
  if ATypeInfo = TypeInfo(Nullable<Integer>) then
    if TVarData(AValue).VType <= varNull then
      Self.SetValue(AInstance, TValue.From(Nullable<Integer>.Create(AValue)))
    else
      Self.SetValue(AInstance, TValue.From(Nullable<Integer>.Create(Integer(AValue))))
  else
  if ATypeInfo = TypeInfo(Nullable<Int64>) then
    if TVarData(AValue).VType <= varNull then
      Self.SetValue(AInstance, TValue.From(Nullable<Int64>.Create(AValue)))
    else
      Self.SetValue(AInstance, TValue.From(Nullable<Int64>.Create(Int64(AValue))))
  else
  if ATypeInfo = TypeInfo(Nullable<String>) then
    Self.SetValue(AInstance, TValue.From(Nullable<String>
                                   .Create(AValue)))
  else
  if ATypeInfo = TypeInfo(Nullable<Currency>) then
    if TVarData(AValue).VType <= varNull then
      Self.SetValue(AInstance, TValue.From(Nullable<Currency>
                                     .Create(AValue)))
    else
      Self.SetValue(AInstance, TValue.From(Nullable<Currency>
                                     .Create(Currency(AValue))))
  else
  if ATypeInfo = TypeInfo(Nullable<Double>) then
    if TVarData(AValue).VType <= varNull then
      Self.SetValue(AInstance, TValue.From(Nullable<Double>
                                     .Create(AValue)))
    else
      Self.SetValue(AInstance, TValue.From(Nullable<Double>
                                     .Create(Double(AValue))))
  else
  if ATypeInfo = TypeInfo(Nullable<Boolean>) then
    Self.SetValue(AInstance, TValue.From(Nullable<Boolean>
                                   .Create(AValue)))
  else
  if ATypeInfo = TypeInfo(Nullable<TDateTime>) then
    if TVarData(AValue).VType <= varNull then
      Self.SetValue(AInstance, TValue.From(Nullable<TDateTime>
                                     .Create(AValue)))
    else
      Self.SetValue(AInstance, TValue.From(Nullable<TDateTime>
                                     .Create(Iso8601ToDateTime(AValue, AUseISO8601DateFormat))))
  else
  if ATypeInfo = TypeInfo(Nullable<TDate>) then
    if TVarData(AValue).VType <= varNull then
      Self.SetValue(AInstance, TValue.From(Nullable<TDate>
                                     .Create(AValue)))
    else
      Self.SetValue(AInstance, TValue.From(Nullable<TDate>
                                     .Create(Iso8601ToDateTime(AValue, AUseISO8601DateFormat))))
  else
  if ATypeInfo = TypeInfo(Nullable<TTime>) then
    if TVarData(AValue).VType <= varNull then
      Self.SetValue(AInstance, TValue.From(Nullable<TTime>
                                     .Create(AValue)))
    else
      Self.SetValue(AInstance, TValue.From(Nullable<TTime>
                                     .Create(Iso8601ToDateTime(AValue, AUseISO8601DateFormat))))
  else
  /// <summary> The write side of the arm above - issue #314.
  ///
  ///  Nullable&lt;T&gt;.Create(Variant) would go through TValue.AsType&lt;T&gt;
  ///  (Janus.Types.Nullable.pas:84-96) and fail for the same reason the read
  ///  side does, so the text is parsed here. StringToGUID REQUIRES the braced
  ///  38-character form - System.SysUtils.pas:6025-6028 rejects any other
  ///  length or a misplaced brace or hyphen - which is what GetValueNullable
  ///  emits, so the round trip closes. It does NOT require the upper case
  ///  (:6036-6037 accepts 'a'..'f'); the case is this repo's convention.
  ///
  ///  NULL AND BLANK TEXT ARE THE SAME ANSWER, AND THE GUARD NEEDS BOTH
  ///  TERMS TO SAY SO. A JSON null arrives as varNull; a GUID column that
  ///  was never written arrives as text, and a fixed-width CHAR one arrives
  ///  as text made of SPACES. None is a GUID, StringToGUID raises on all of
  ///  them, and all of them leave the Nullable cleared.
  ///
  ///  THE varNull TERM IS NOT REDUNDANT WITH THE TRIM, and believing it was
  ///  cost a regression that had to be measured out again. VarToStr is not a
  ///  function of the variant alone: System.Variants.pas:5401-5403 defines it
  ///  as VarToStrDef(V, NullAsStringValue), and NullAsStringValue is declared
  ///  in a var block at System.Variants.pas:322-344 - a MUTABLE GLOBAL whose
  ///  own comment there says other environments return 'NULL' instead of
  ///  Delphi's default ''. Set it to 'NULL' and a trim-only guard sends a
  ///  genuine NULL into StringToGUID: measured, 'NULL is not a valid GUID
  ///  value', on BOTH arms - the very EConvertError the text term exists to
  ///  prevent. Deleting the varNull term survived mutation only because no
  ///  test moved that global; that survival measured the PROBE's blindness,
  ///  not the code. The two ClearsGuidWhenNullRendersAsText tests move it,
  ///  and both halves are now killed when removed.
  ///
  ///  It also keeps these two arms shaped like the eight above them and like
  ///  Janus.Bind.pas:845, which all test VType <= varNull first. </summary>
  if ATypeInfo = TypeInfo(Nullable<TGUID>) then
    if (TVarData(AValue).VType <= varNull) or (Trim(VarToStr(AValue)) = '') then
      Self.SetValue(AInstance, TValue.From(Nullable<TGUID>.Create(Null)))
    else
      Self.SetValue(AInstance, TValue.From(Nullable<TGUID>
                                     .Create(StringToGUID(VarToStr(AValue)))))
  else
  /// <summary> A BARE TGUID, and why this arm is not Nullable-shaped like
  ///  every other one in this method - issue #314.
  ///
  ///  The FINAL else of TBind._SetFieldToPropertyRecord - the arm for
  ///  a record property that is neither a Nullable nor a TBlob - calls this
  ///  method with the property's OWN handle. For a TGUID property that handle
  ///  is TypeInfo(TGUID), which matched nothing, so the method fell off its
  ///  end and returned having assigned NOTHING. Measured by calling it the way
  ///  Bind does: the property kept
  ///  '{00000000-0000-0000-0000-000000000000}' with no error raised, so a
  ///  ftGuid column read back from a dataset silently lost its value.
  ///
  ///  It is also the single place the GUID text is parsed ON THE WAY IN:
  ///  TJanusJson's read side routes its bare-TGUID case here instead of
  ///  repeating the parse. Only on the way in - the INSERT parses too, in
  ///  TCommandInserter.GenerateInsert, turning the text it just built back into
  ///  a TGUID for the param. ANCHORED BY METHOD SINCE #352: the citation used
  ///  to read `Janus.Command.Inserter.pas:172`, which was CORRECT at 349407e -
  ///  that line was exactly `AsGuid := StringToGUID(LGuidString);` - and the
  ///  #352 repair is what moved it to 171. Not rot; a neighbour's edit. The
  ///  twin note in Janus.Json carries the full version. StringToGUID accepts
  ///  only the braced 38-character form, which is what the write side emits.
  ///
  ///  A BARE TGUID CANNOT BE ABSENT, so a null has to land somewhere: it lands
  ///  on TGUID.Empty, the value a freshly constructed object already carries.
  ///  The guard is the same two terms as the arm above, for the same measured
  ///  reason. </summary>
  if ATypeInfo = TypeInfo(TGUID) then
    if (TVarData(AValue).VType <= varNull) or (Trim(VarToStr(AValue)) = '') then
      Self.SetValue(AInstance, TValue.From<TGUID>(TGUID.Empty))
    else
      Self.SetValue(AInstance, TValue.From<TGUID>(StringToGUID(VarToStr(AValue))));
end;

end.
