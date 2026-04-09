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

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)

  ORM Brasil � um ORM simples e descomplicado para quem utiliza Delphi.
}

unit Janus.Objects.Helper;

interface

uses
  DB,
  Rtti,
  Variants,
  SysUtils,
  TypInfo, {Delphi 2010}
  Generics.Collections,
  Janus.Core.Consts,
  Janus.RTTI.Helper,
  MetaDbDiff.Mapping.Popular,
  MetaDbDiff.Mapping.Explorer,
  MetaDbDiff.Mapping.Classes,
  MetaDbDiff.Mapping.Attributes;

type
  TJanusObject = class
  public
    constructor Create; virtual;
  end;

  TObjectHelper = class helper for TObject
  public
    function GetTable: Table;
    function GetResource: Resource;
    function GetNotServerUse: NotServerUse;
    function GetSubResource: SubResource;
    function &GetType(out AType: TRttiType): Boolean;
    function GetSequence: Sequence;
    function MethodCall(const AMethodName: String;
      const AParameters: array of TValue): TValue;
    procedure SetDefaultValue;
  end;

implementation

uses
  Janus.Objects.Utils;

var
  GTableCache: TObjectDictionary<String, Table>;
  GSequenceCache: TObjectDictionary<String, Sequence>;
  GNotServerUseCache: TObjectDictionary<String, NotServerUse>;

{ TObjectHelper }

function TObjectHelper.GetNotServerUse: NotServerUse;
var
  LClassName: String;
begin
  if not Assigned(Self) then
    Exit(nil);

  LClassName := Self.ClassName;
  if GNotServerUseCache.TryGetValue(LClassName, Result) then
    Exit;

  if not TMappingExplorer.GetNotServerUse(Self.ClassType) then
    Exit(nil);

  Result := NotServerUse.Create;
  GNotServerUseCache.Add(LClassName, Result);
end;

function TObjectHelper.GetResource: Resource;
var
  LType: TRttiType;
  LAttribute: TCustomAttribute;
begin
  Result := nil;
  LType := RttiSingleton.GetRttiType(Self.ClassType);
  if Assigned(LType) then
  begin
    for LAttribute in LType.GetAttributes do
    begin
      if LAttribute is Resource then
        Exit(Resource(LAttribute));
    end;
  end;
end;

function TObjectHelper.GetSequence: Sequence;
var
  LClassName: String;
  LSequenceMapping: TSequenceMapping;
begin
  if not Assigned(Self) then
    Exit(nil);

  LClassName := Self.ClassName;
  if GSequenceCache.TryGetValue(LClassName, Result) then
    Exit;

  LSequenceMapping := TMappingExplorer.GetMappingSequence(Self.ClassType);
  if not Assigned(LSequenceMapping) then
    Exit(nil);

  Result := Sequence.Create(LSequenceMapping.Name,
                            LSequenceMapping.Initial,
                            LSequenceMapping.Increment);
  GSequenceCache.Add(LClassName, Result);
end;

function TObjectHelper.GetSubResource: SubResource;
var
  LType: TRttiType;
  LAttribute: TCustomAttribute;
begin
  Result := nil;
  LType := RttiSingleton.GetRttiType(Self.ClassType);
  if Assigned(LType) then
  begin
    for LAttribute in LType.GetAttributes do
    begin
      if LAttribute is SubResource then
        Exit(SubResource(LAttribute));
    end;
  end;
end;

function TObjectHelper.GetTable: Table;
var
  LClassName: String;
  LRttiType: TRttiType;
  LAttribute: TCustomAttribute;
  LHasTableAttribute: Boolean;
  LHasViewAttribute: Boolean;
  LTableMapping: TTableMapping;
begin
  if not Assigned(Self) then
    Exit(nil);

  LRttiType := RttiSingleton.GetRttiType(Self.ClassType);
  LHasTableAttribute := False;
  LHasViewAttribute := False;
  if Assigned(LRttiType) then
  begin
    for LAttribute in LRttiType.GetAttributes do
    begin
      if LAttribute is Table then
        LHasTableAttribute := True
      else if LAttribute is View then
        LHasViewAttribute := True;
    end;
  end;

  if LHasViewAttribute and (not LHasTableAttribute) then
    Exit(nil);

  LClassName := Self.ClassName;
  if GTableCache.TryGetValue(LClassName, Result) then
    Exit;

  LTableMapping := TMappingExplorer.GetMappingTable(Self.ClassType);
  if not Assigned(LTableMapping) then
    Exit(nil);

  Result := Table.Create(LTableMapping.Name, LTableMapping.Description);
  GTableCache.Add(LClassName, Result);
end;

function TObjectHelper.&GetType(out AType: TRttiType): Boolean;
begin
  Result := False;
  if Assigned(Self) then
  begin
    AType  := RttiSingleton.GetRttiType(Self.ClassType);
    Result := Assigned(AType);
  end;
end;

function TObjectHelper.MethodCall(const AMethodName: String;
  const AParameters: array of TValue): TValue;
var
  LRttiType: TRttiType;
  LMethod: TRttiMethod;
begin
  LRttiType := RttiSingleton.GetRttiType(Self.ClassType);
  LMethod   := LRttiType.GetMethod(AMethodName);
  if Assigned(LMethod) then
    Result := LMethod.Invoke(Self, AParameters)
  else
    raise Exception.CreateFmt('Cannot find method "%s" in the object', [AMethodName]);
end;

procedure TObjectHelper.SetDefaultValue;
var
  LColumns: TColumnMappingList;
  LColumn: TColumnMapping;
  LProperty: TRttiProperty;
  LValue: Variant;
begin
  LColumns := TMappingExplorer.GetMappingColumn(Self.ClassType);
  if LColumns = nil then
    Exit;

  for LColumn in LColumns do
  begin
    if Length(LColumn.DefaultValue) = 0 then
      Continue;

    LProperty := LColumn.ColumnProperty;
    LValue := StringReplace(LColumn.DefaultValue, '''', '', [rfReplaceAll]);

    case LProperty.PropertyType.TypeKind of
      tkString, tkWString, tkUString, tkWChar, tkLString, tkChar:
        LProperty.SetValue(Self, TValue.FromVariant(LValue).AsString);
      tkInteger, tkSet, tkInt64:
        LProperty.SetValue(Self, StrToIntDef(LValue, 0));
      tkFloat:
        begin
          if LProperty.PropertyType.Handle = TypeInfo(TDateTime) then // TDateTime
            LProperty.SetValue(Self, TValue.FromVariant(Date).AsType<TDateTime>)
          else
          if LProperty.PropertyType.Handle = TypeInfo(TDate) then // TDate
            LProperty.SetValue(Self, TValue.FromVariant(Date).AsType<TDate>)
          else
          if LProperty.PropertyType.Handle = TypeInfo(TTime) then// TTime
            LProperty.SetValue(Self, TValue.FromVariant(Time).AsType<TTime>)
          else
            LProperty.SetValue(Self, StrToFloatDef(LValue, 0));
        end;
      tkRecord:
        LProperty.SetValueNullable(Self, LProperty.PropertyType.Handle, LValue);
      tkEnumeration:
        begin
          case LColumn.FieldType of
            ftString, ftFixedChar:
              LProperty.SetValue(Self, LProperty.GetEnumStringValue(Self, LValue));
            ftInteger:
              LProperty.SetValue(Self, LProperty.GetEnumIntegerValue(Self, LValue));
            ftBoolean:
              LProperty.SetValue(Self, TValue.FromVariant(LValue).AsBoolean);
          else
            raise Exception.Create(cENUMERATIONSTYPEERROR);
          end;
        end;
    end;
  end;
end;

{ TJanusObject }

constructor TJanusObject.Create;
begin
  Self.SetDefaultValue;
end;

initialization
  GTableCache := TObjectDictionary<String, Table>.Create([doOwnsValues]);
  GSequenceCache := TObjectDictionary<String, Sequence>.Create([doOwnsValues]);
  GNotServerUseCache := TObjectDictionary<String, NotServerUse>.Create([doOwnsValues]);

finalization
  GNotServerUseCache.Free;
  GSequenceCache.Free;
  GTableCache.Free;

end.
