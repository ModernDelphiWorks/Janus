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
  public
//    procedure SetNullableValue(AInstance: Pointer; ATypeInfo:
//      PTypeInfo; AValue: Variant);
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
  ///  and renders it as the SAME text the three command classes write -
  ///  TGUID.ToString: Janus.Command.Inserter.pas:213-217,
  ///  Janus.Command.Updater.pas:118-119, Janus.Command.Deleter.pas:97-98.
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
  ///  side does, so the text is parsed here. StringToGUID is the only parse
  ///  the RTL offers and it REQUIRES the braced 38-character form - which is
  ///  what GetValueNullable emits, so the round trip closes.
  ///
  ///  NULL AND BLANK TEXT ARE THE SAME ANSWER, AND ONE TEST COVERS BOTH.
  ///  A JSON null arrives as varNull; a GUID column that was never written
  ///  arrives as text, and a CHAR(38) one arrives as text made of SPACES.
  ///  None of the three is a GUID and StringToGUID raises on all three, so
  ///  all three leave the Nullable cleared.
  ///
  ///  THE GUARD IS ONE TERM AND NOT TWO, which is a measurement and not a
  ///  preference. Written as the sibling arms are - a varNull test OR a text
  ///  test - the varNull half could be deleted with no test moving, even
  ///  with a test that feeds it a JSON null: VarToStr of Null is already the
  ///  empty string, so the trim answers that case too. Deleting the TRIM,
  ///  by contrast, is caught. A term whose removal moves no answer is dead
  ///  weight, so only the term that carries the answer stayed. </summary>
  if ATypeInfo = TypeInfo(Nullable<TGUID>) then
    if Trim(VarToStr(AValue)) = '' then
      Self.SetValue(AInstance, TValue.From(Nullable<TGUID>.Create(Null)))
    else
      Self.SetValue(AInstance, TValue.From(Nullable<TGUID>
                                     .Create(StringToGUID(VarToStr(AValue)))))
  else
  /// <summary> A BARE TGUID, and why this arm is not Nullable-shaped like
  ///  every other one in this method - issue #314.
  ///
  ///  Janus.Bind.pas:909 - the else of _SetFieldToPropertyRecord, the arm for
  ///  a record property that is neither a Nullable nor a TBlob - calls this
  ///  method with the property's OWN handle. For a TGUID property that handle
  ///  is TypeInfo(TGUID), which matched nothing, so the method fell off its
  ///  end and returned having assigned NOTHING. Measured by calling it the way
  ///  Bind does: the property kept
  ///  '{00000000-0000-0000-0000-000000000000}' with no error raised, so a
  ///  ftGuid column read back from a dataset silently lost its value.
  ///
  ///  It is also the single place the GUID text is parsed: TJanusJson's read
  ///  side routes its bare-TGUID case here instead of repeating the parse.
  ///  StringToGUID accepts only the braced 38-character form, which is what
  ///  the write side emits.
  ///
  ///  A BARE TGUID CANNOT BE ABSENT, so a null has to land somewhere: it lands
  ///  on TGUID.Empty, the value a freshly constructed object already carries.
  ///  The one-term guard is the same measurement as the arm above.
  ///  </summary>
  if ATypeInfo = TypeInfo(TGUID) then
    if Trim(VarToStr(AValue)) = '' then
      Self.SetValue(AInstance, TValue.From<TGUID>(TGUID.Empty))
    else
      Self.SetValue(AInstance, TValue.From<TGUID>(StringToGUID(VarToStr(AValue))));
end;

end.
