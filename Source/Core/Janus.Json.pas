{
      ORM Brasil � um ORM simples e descomplicado para quem utiliza Delphi

                   Copyright (c) 2016, Isaque Pinheiro
                          All rights reserved.

                    GNU Lesser General Public License
                      Vers�o 3, 29 de junho de 2007

       Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
       A todos � permitido copiar e distribuir c�pias deste documento de
       licen�a, mas mud�-lo n�o � permitido.

       Esta vers�o da GNU Lesser General Public License incorpora
       os termos e condi��es da vers�o 3 da GNU General Public License
       Licen�a, complementado pelas permiss�es adicionais listadas no
       arquivo LICENSE na pasta principal.
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
  FormatSettings := GJsonBrFormatSettings;
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
  // Ao voltar para o m�todo GetValue do JsonFlow, executa o comando Exit e sai,
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
  // Ao voltar para o m�todo SetValue do JsonFlow, executa o comando Exit e sai,
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
  GJsonBrFormatSettings := Value;
end;

class procedure TJanusJson.SetUseISO8601DateFormat(const Value: Boolean);
begin
  FJsonBuilder.UseISO8601DateFormat := Value;
end;

class function TJanusJson.GetFormatSettings: TFormatSettings;
begin
  Result := GJsonBrFormatSettings;
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
