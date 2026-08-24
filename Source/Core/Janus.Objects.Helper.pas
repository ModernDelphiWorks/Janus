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
  @author(Skype : ispinheiro)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)

  ORM Brasil: um ORM simples e descomplicado para quem utiliza Delphi.
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
    function GetRESTReadOnly: Boolean;
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
  GRESTReadOnlyCache: TDictionary<String, Boolean>;

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

function TObjectHelper.GetRESTReadOnly: Boolean;
var
  LClassName: String;
begin
  Result := False;
  if not Assigned(Self) then
    Exit;

  LClassName := Self.ClassName;
  if GRESTReadOnlyCache.TryGetValue(LClassName, Result) then
    Exit;

  Result := TMappingExplorer.GetRESTReadOnly(Self.ClassType);
  GRESTReadOnlyCache.Add(LClassName, Result);
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

{ CANONICAL NOTE - THE MethodCall('Create', []) IDIOM.
  DO NOT "CLEAN UP" THE CALLERS.

  This note explains the MECHANISM and the RISK. It deliberately does NOT say
  how many sites apply the idiom, nor that all of them link back here. Three
  hand counts of this same territory produced three different partitions, so
  any number written here would be false by the next reading, and the sites
  that merely CARRY the idiom are not the same set as the sites ANNOTATED with
  a pointer to this note. What holds without rotting is the CONDITION:
  wherever you meet the pair below, the second line is load-bearing unless you
  have measured otherwise AT THAT SITE - and "the suite is still green" is not
  that measurement.

  Across the framework you meet this pair:

      LObject := <class-reference expression>.Create;  // allocates only
      LObject.MethodCall('Create', []);                // runs the MODEL ctor

  The second line reads as a duplicate of the first. It is not. Removing it
  compiles clean, and at one measured site leaves the whole unit suite green,
  while every field the model assigns in its own constructor silently arrives
  empty and every sub-object it builds arrives nil.

  WHY THE FIRST LINE DOES NOT RUN THE MODEL CONSTRUCTOR

  The reason is NOT virtual versus non-virtual dispatch. It is which type the
  COMPILER can see at the call site. A constructor reached through a class
  reference is bound to the constructor visible on the type that reference is
  DECLARED to hold - never on the class it happens to carry at run time. Where
  the idiom appears, the reference is a plain TClass, either directly or as
  TRttiInstanceType.MetaclassType, whose static type is also TClass. TClass is
  `class of TObject`, so the compiler binds `<expr>.Create` to TObject.Create,
  which allocates and zero-fills and nothing else.

  The consequence that settles the "it is just virtual dispatch" reading:
  making the model's own Create virtual does NOT rescue it. Measured below,
  row 7. What DOES work is any form where the compiler already knows the
  concrete type: generic code declared `<M: class, constructor>` calling
  M.Create, and a TYPED class reference whose declared base itself declares
  Create virtual (that is why Janus.Types.Blob can call LGraphicClass.Create
  with no workaround - Vcl.Graphics declares TGraphicClass = class of TGraphic
  at line 357 and TGraphic.Create virtual at line 995).

  MEASURED AT 8f5864f - a disposable console probe over this very method, on a
  model whose constructor assigns an 8-character String and builds a sub-object
  (Delphi 37.0, Win32/Debug):

    1 TClass.Create                                  Tag len 0   Child nil
    2 MetaclassType.Create                           Tag len 0   Child nil
    3 MetaclassType.Create + MethodCall('Create',[])  Tag len 8   Child built
    4 T.Create, generic <M: class, constructor>       Tag len 8   Child built
    5 idem, model ctor declared VIRTUAL               Tag len 8   Child built
    6 idem, model ctor declared OVERRIDE              Tag len 8   Child built
    7 TClass.Create over that same VIRTUAL ctor       Tag len 0   Child nil
    8 typed `class of` whose base ctor is virtual     Tag len 8   Child built

  AND ON THREE REAL SITES, by deleting only the MethodCall line and rerunning
  Janus.Tests.Units (baseline 715/715). Each mutation was confirmed to have
  reached the binary by the generated code size moving, so a green result here
  means "unnoticed", never "not compiled":

    Janus.DataSet.Base.Adapter.FillMastersClass  -> 704 passed, 1 failed,
      10 errored (access violations). The suite defends that one.
    Janus.Mapping.Lazy.CreateLazyManyAssociationLoadFunc -> code size moved,
      suite STAYS 715/715 GREEN.
    Janus.Server.RestObject.Manager.NextPacketList -> code size moved by -116
      bytes, suite STAYS 715/715 GREEN. This unit IS linked into that suite;
      an earlier reading of this measurement called it unlinked, which was
      wrong - the byte-identical build that suggested it came from
      Janus.Tests.RESTfulDriver, which is the suite that really does not
      compile this unit at all.

  Read those two green rows as the reason this note exists: "the tests still
  pass" is NOT evidence that an occurrence of the idiom was redundant. Do not
  quote absolute code sizes from here as reproducible - only the DIFFERENCE
  within one build environment carries the argument, the same lesson already
  recorded for module offsets in Janus.DataSet.Base.Adapter.FillMastersClass.

  PRECEDENT - the fact was already written down once, but only in one place,
  far from the sites that depend on it: see the block inside
  Janus.Mapping.Lazy.CreateLazyManyAssociationLoadFunc.

  KNOWN HAZARD OF THE IDIOM ITSELF - MethodCall resolves the name through
  TRttiType.GetMethod, which answers the FIRST declared method carrying that
  name, not an overload matched against the arguments passed. On TObjectList<T>
  that is the parameterless constructor, and handing it an argument raises
  'Parameter count mismatch' before anything else runs - the bite is recorded
  in Janus.Mapping.Lazy, which is why the list there is built by invoking the
  TRttiMethod over the metaclass instead. Anyone applying this idiom at a NEW
  site must first check which constructor GetMethod actually returns for that
  class. }
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
  GRESTReadOnlyCache := TDictionary<String, Boolean>.Create;

finalization
  GNotServerUseCache.Free;
  GSequenceCache.Free;
  GTableCache.Free;
  GRESTReadOnlyCache.Free;

end.
