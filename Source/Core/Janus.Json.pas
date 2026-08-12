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
}

{$INCLUDE ..\Janus.inc}

unit Janus.Json;

interface

uses
  Rtti,
  DB,
  SysUtils,
  StrUtils,
  Classes,
  Variants,
  TypInfo,
  Generics.Collections,
  {$IFDEF DELPHI15_UP}
  JSON,
  {$ELSE}
  DBXJSON,
  {$ENDIF}
  // Janus
  MetaDbDiff.Mapping.Attributes,
  Janus.Core.Consts,
  Janus.Types.Blob,
  //
  JsonFlow.Utils,
  JsonFlow.Builders;

type
  TJanusJson = class
  strict private
    class var FJsonBuilder: TJsonBuilder;
    class procedure DoGetValue(const AInstance: TObject;
                               const AProperty: TRttiProperty;
                               var AResult: Variant;
                               var ABreak: Boolean);
    class procedure DoSetValue(const AInstance: TObject;
                               const AProperty: TRttiProperty;
                               const AValue: Variant;
                               var ABreak: Boolean);
    class function GetFormatSettings: TFormatSettings; static;
    class procedure SetFormatSettings(const Value: TFormatSettings); static;
    class function GetUseISO8601DateFormat: Boolean; static;
    class procedure SetUseISO8601DateFormat(const Value: Boolean); static;
  public
    class constructor Create;
    class destructor Destroy;
    class function ObjectToJsonString(AObject: TObject;
      AStoreClassName: Boolean = False): String;
    class function ObjectListToJsonString(AObjectList: TObjectList<TObject>;
      AStoreClassName: Boolean = False): String; overload;
    class function ObjectListToJsonString<T: class, constructor>(AObjectList: TObjectList<T>;
      AStoreClassName: Boolean = False): String; overload;
    class function JsonToObject<T: class, constructor>(const AJson: String): T; overload;
    class function JsonToObject<T: class>(AObject: T;
      const AJson: String): Boolean; overload;
    class function JsonToObjectList<T: class, constructor>(const AJson: String): TObjectList<T>;
    class procedure JsonToObject(const AJson: String; AObject: TObject); overload;
    //
    class function JSONStringToJSONValue(const AJson: String): TJSONValue;
    class function JSONObjectToJSONValue(const AObject: TObject): TJSONValue;
    class function JSONStringToJSONArray(const AJson: String): TJSONArray;
    class function JSONObjectListToJSONArray<T: class>(const AObjectList: TObjectList<T>): TJSONArray;
    class function JSONStringToJSONObject(const AJson: String): TJSONObject;
    class property FormatSettings: TFormatSettings read GetFormatSettings write SetFormatSettings;
    class property UseISO8601DateFormat: Boolean read GetUseISO8601DateFormat write SetUseISO8601DateFormat;
  end;

implementation

uses
  Janus.RTTI.Helper;

{ TJson }

class constructor TJanusJson.Create;
begin
  FJsonBuilder := TJsonBuilder.Create;
  FJsonBuilder.OnGetValue := DoGetValue;
  FJsonBuilder.OnSetValue := DoSetValue;
  FJsonBuilder.UseISO8601DateFormat := True;
  FormatSettings := GJsonFlowFormatSettings;
end;

class destructor TJanusJson.Destroy;
begin
  FJsonBuilder.Free;
  inherited;
end;

class procedure TJanusJson.DoGetValue({const Sender: TJsonFlowObject;}
  const AInstance: TObject; const AProperty: TRttiProperty;
  var AResult: Variant; var ABreak: Boolean);
var
  LColumn: Column;
begin
  // Ao voltar para o metodo GetValue do JsonFlow, executa o comando Exit e sai,
  // se ABreak = True;
  ABreak := False;
  VarClear(AResult);
  try
    case AProperty.PropertyType.TypeKind of
      tkRecord:
        begin
          if AProperty.IsBlob then
          begin
            ABreak := True;
            AResult := AProperty.GetNullableValue(AInstance).AsType<TBlob>.ToBytesString;
          end
          else
          if AProperty.IsNullable then
          begin
            ABreak := True;
            AResult := AProperty.GetValueNullable(AInstance, AProperty.PropertyType.Handle).AsVariant;
            if AResult = Null then
              Exit;
            if (AProperty.IsDateTime) then
              AResult := DateTimeToIso8601(AResult, UseISO8601DateFormat)
            else
            if AProperty.IsDate then
              AResult := DateTimeToIso8601(AResult, UseISO8601DateFormat)
            else
            if AProperty.IsTime then
              AResult := DateTimeToIso8601(AResult, UseISO8601DateFormat)
          end
          else
          /// <summary> A bare TGUID - issue #314.
          ///
          ///  WHY IT NEEDS AN ARM OF ITS OWN. TGUID is tkRecord, is not a
          ///  TBlob and is not a Nullable, so before this arm it reached the
          ///  else below, where GetNullableValue(...).AsVariant is a cast the
          ///  RTL refuses. Measured at ea0208f over a class with one TGUID
          ///  property: ObjectToJsonString raised 'Erro no SetValue() da
          ///  propriedade [gjkey] / Invalid class typecast' - the same text
          ///  issue #314 reports, and in the REST client it escapes
          ///  TSessionRestFul.Insert before any request is sent.
          ///
          ///  WHY NOT A GENERIC tkRecord FALLBACK. The population was
          ///  enumerated, not guessed: every record type declared under
          ///  Source\ and Test\ was listed, and each was counted as a PROPERTY
          ///  type across Source\, Test\ and Examples\. SIX records appear as
          ///  a property. Three are answered here - Nullable&lt;T&gt; 99 times,
          ///  TBlob 18, TGUID 4. The other three cannot arrive, because the
          ///  writer skips properties that are not writable
          ///  (JsonFlow.Builders.pas:915-916) and all three are read-only on
          ///  classes that are not entities: TValue once
          ///  (Janus.Server.RestQuery.Parse.pas:102), TRestCallRecord once on
          ///  a test double (Test.Janus.RestConnection.Double.pas:114), and
          ///  TFormatSettings twice, one of them a CLASS property of TJanusJson
          ///  itself. Lazy&lt;T&gt; is a record too but never appears as a
          ///  property at all - it is declared as a field, and in one test even
          ///  as a local variable (Test.Janus.Types.Lazy.pas:62).
          ///
          ///  A generic arm would therefore buy no case that exists today while
          ///  giving every future record a silent, wrong rendering instead of a
          ///  loud failure.
          ///
          ///  THE TEXT IS NOT A FREE CHOICE, and the choice was not made here.
          ///  The doc comment over TDMLGeneratorAbstract.GuidLiteral, in
          ///  Janus.DML.Generator.pas, already writes the doctrine down - a
          ///  ftGuid column means TGUID, and the Guid32Inc/36/38 generators
          ///  belong to the ftString world, which is what dissolves the
          ///  apparent conflict between issues #284 and #311 - and the same
          ///  comment names the canonical form. FOUR sites already render it:
          ///  TCommandInserter._GetParamValue - by symbol since #325 -,
          ///  Updater:118-119,
          ///  Deleter:97-98 and TDMLGeneratorAbstract.CanonicalGuidLiteral,
          ///  all TGUID.ToString.
          ///  BY SYMBOL, AND THE REASON IS A MEASUREMENT. This paragraph used
          ///  to anchor those two places as :115-120, :124-136 and :766-768.
          ///  They were right until issue #326 inserted lines into that
          ///  unit, after which all three pointed at other code. A symbol
          ///  survives an insertion above it; a line number does not.
          ///  StrToGUID then demands exactly that shape back:
          ///  System.SysUtils.pas:6025-6028 rejects anything whose length is
          ///  not 38 or whose braces and hyphens are not in place. It does NOT
          ///  demand the case - :6036-6037 accepts 'a'..'f' as well - so the
          ///  upper case is convention here, held by the four sites above and
          ///  by the tests, not by the parser. </summary>
          if AProperty.PropertyType.Handle = TypeInfo(TGUID) then
          begin
            ABreak := True;
            AResult := AProperty.GetValue(AInstance).AsType<TGUID>.ToString;
          end
          else
            AResult := AProperty.GetNullableValue(AInstance).AsVariant;
        end;
      tkEnumeration:
        begin
          LColumn := AProperty.GetColumn;
          if LColumn <> nil then
          begin
            ABreak := True;
            if LColumn.FieldType in [ftBoolean] then
              AResult := AProperty.GetEnumToFieldValue(AInstance, LColumn.FieldType).AsBoolean
            else
            if LColumn.FieldType in [ftFixedChar, ftString] then
              AResult := AProperty.GetEnumToFieldValue(AInstance, LColumn.FieldType).AsString
            else
            if LColumn.FieldType in [ftInteger] then
              AResult := AProperty.GetEnumToFieldValue(AInstance, LColumn.FieldType).AsInteger
            else
              raise Exception.Create(cENUMERATIONSTYPEERROR);
          end;
      end;
    end;
  except
    on E: Exception do
      raise Exception.Create('Erro no SetValue() da propriedade [' + AProperty.Name + ']' + sLineBreak + E.Message);
  end;
end;

class procedure TJanusJson.DoSetValue(const AInstance: TObject;
  const AProperty: TRttiProperty; const AValue: Variant; var ABreak: Boolean);
var
  LBlob: TBlob;
  LColumn: Column;
begin
  // Ao voltar para o metodo SetValue do JsonFlow, executa o comando Exit e sai,
  // se ABreak = True;
  ABreak := False;
  if (AProperty <> nil) and (AInstance <> nil) then
  begin
    try
      case AProperty.PropertyType.TypeKind of
        tkRecord:
          begin
            if AProperty.IsBlob then
            begin
              ABreak := True;
              LBlob.ToStringBytes(AValue);
              AProperty.SetValue(AInstance, TValue.From<TBlob>(LBlob));
            end
            else
            if AProperty.IsNullable then
            begin
              ABreak := True;
               AProperty.SetValueNullable(AInstance,
                                          AProperty.PropertyType.Handle,
                                          AValue,
                                          UseISO8601DateFormat);
            end
            else
            /// <summary> The way back for a bare TGUID - issue #314.
            ///
            ///  Serialising without being able to deserialise trades one
            ///  defect for another, so the arm added to DoGetValue needs this
            ///  one. Without it ABreak stays False and the JSON reader falls
            ///  to its own tkRecord case,
            ///  TValue.FromVariant(LValue) into a TGUID property
            ///  (JsonFlow.Builders.pas:497-498) - the mirror image of the cast
            ///  that broke the write side.
            ///
            ///  The parse is NOT repeated here. SetValueNullable already owns
            ///  the arm the FINAL else of TBind._SetFieldToPropertyRecord needs
            ///  - the arm for a record property that is neither a Nullable nor
            ///  a TBlob - for the same property shape
            ///  read out of a dataset, so both READERS land on one
            ///  StringToGUID - which accepts only the braced 38-character form
            ///  DoGetValue emits. Only the readers: the write direction parses
            ///  too, at Janus.Command.Inserter.pas:172, where the text built
            ///  from the property is turned back into a TGUID for the param.
            ///  A JSON null, or a member absent from the payload, is not a
            ///  GUID and must not raise: it leaves the property at TGUID.Empty,
            ///  the same value a freshly constructed object already carries.
            ///  </summary>
            if AProperty.PropertyType.Handle = TypeInfo(TGUID) then
            begin
              ABreak := True;
              AProperty.SetValueNullable(AInstance,
                                         AProperty.PropertyType.Handle,
                                         AValue,
                                         UseISO8601DateFormat);
            end;
          end;
        tkEnumeration:
          begin
            LColumn := AProperty.GetColumn;
            if LColumn <> nil then
            begin
              ABreak := True;
              if LColumn.FieldType in [ftBoolean] then
                AProperty.SetValue(AInstance, Boolean(AValue))
              else
              if LColumn.FieldType in [ftFixedChar, ftString] then
                AProperty.SetValue(AInstance, AProperty.GetEnumStringValue(AInstance, AValue))
              else
              if LColumn.FieldType in [ftInteger] then
                AProperty.SetValue(AInstance, AProperty.GetEnumIntegerValue(AInstance, AValue))
              else
                raise Exception.Create(cENUMERATIONSTYPEERROR);
            end;
          end;
      end;
    except
      on E: Exception do
        raise Exception.Create('Erro no SetValue() da propriedade [' + AProperty.Name + ']' + sLineBreak + E.Message);
    end;
  end;
end;

class function TJanusJson.JSONObjectListToJSONArray<T>(const AObjectList: TObjectList<T>): TJSONArray;
var
  LItem: T;
begin
  Result := TJSONArray.Create;
  for LItem in AObjectList do
    Result.Add(JSONStringToJSONObject(TJanusJson.ObjectToJsonString(LItem)));
end;

class function TJanusJson.JSONObjectToJSONValue(const AObject: TObject): TJSONValue;
begin
  Result := JSONStringToJSONValue(TJanusJson.ObjectToJsonString(AObject));
end;

class function TJanusJson.JSONStringToJSONArray(const AJson: String): TJSONArray;
begin
  Result := TJSONObject.ParseJSONValue(TEncoding.UTF8.GetBytes(AJson), 0) as TJSONArray;
end;

class function TJanusJson.JSONStringToJSONObject(const AJson: String): TJSONObject;
begin
  Result := JSONStringToJSONValue(AJson) as TJSONObject;
end;

class function TJanusJson.JSONStringToJSONValue(const AJson: String): TJSONValue;
begin
  Result := TJSONObject.ParseJSONValue(TEncoding.UTF8.GetBytes(AJson), 0);
end;

class procedure TJanusJson.JsonToObject(const AJson: String; AObject: TObject);
begin
  FJsonBuilder.JSONToObject(AObject, AJson);
end;

class function TJanusJson.JsonToObject<T>(AObject: T;
  const AJson: String): Boolean;
begin
  Result := FJsonBuilder.JSONToObject(TObject(AObject), AJson);
end;

class function TJanusJson.JsonToObject<T>(const AJson: String): T;
begin
  Result := FJsonBuilder.JSONToObject<T>(AJson);
end;

class function TJanusJson.ObjectListToJsonString(AObjectList: TObjectList<TObject>;
  AStoreClassName: Boolean): String;
var
  LFor: Integer;
begin
  Result := '[';
  for LFor := 0 to AObjectList.Count -1 do
  begin
    Result := Result + ObjectToJsonString(AObjectList.Items[LFor], AStoreClassName);
    if LFor < AObjectList.Count -1 then
      Result := Result + ', ';
  end;
  Result := Result + ']';
end;

class function TJanusJson.ObjectListToJsonString<T>(AObjectList: TObjectList<T>;
  AStoreClassName: Boolean): String;
var
  LFor: Integer;
begin
  Result := '[';
  for LFor := 0 to AObjectList.Count -1 do
  begin
    Result := Result + ObjectToJsonString(T(AObjectList.Items[LFor]), AStoreClassName);
    if LFor < AObjectList.Count -1 then
      Result := Result + ', ';
  end;
  Result := Result + ']';
end;

class function TJanusJson.ObjectToJsonString(AObject: TObject;
  AStoreClassName: Boolean): String;
begin
  Result := FJsonBuilder.ObjectToJSON(AObject, AStoreClassName);
end;

class procedure TJanusJson.SetFormatSettings(const Value: TFormatSettings);
begin
  GJsonFlowFormatSettings := Value;
end;

class procedure TJanusJson.SetUseISO8601DateFormat(const Value: Boolean);
begin
  FJsonBuilder.UseISO8601DateFormat := Value;
end;

class function TJanusJson.GetFormatSettings: TFormatSettings;
begin
  Result := GJsonFlowFormatSettings;
end;

class function TJanusJson.GetUseISO8601DateFormat: Boolean;
begin
  Result := FJsonBuilder.UseISO8601DateFormat;
end;

class function TJanusJson.JsonToObjectList<T>(const AJson: String): TObjectList<T>;
begin
  Result := FJsonBuilder.JSONToObjectList<T>(AJson);
end;

end.
