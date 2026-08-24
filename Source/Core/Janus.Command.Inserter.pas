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

unit Janus.Command.Inserter;

interface

uses
  DB,
  Rtti,
  Math,
  StrUtils,
  SysUtils,
  TypInfo,
  Variants,
  Types,
  Janus.Command.Abstract,
  Janus.DML.Commands,
  Janus.DML.Insert.Columns,
  Janus.Core.Consts,
  Janus.Types.Blob,
  Janus.Objects.Helper,
  Janus.Objects.Utils,
  DataEngine.FactoryInterfaces,
  MetaDbDiff.Mapping.Popular,
  MetaDbDiff.Mapping.Classes,
  MetaDbDiff.Rtti.Helper,
  MetaDbDiff.Mapping.Explorer,
  MetaDbDiff.Types.Mapping;

type
  TCommandInserter = class(TDMLCommandAbstract)
  private
    FDMLAutoInc: TDMLCommandAutoInc;
    function _GetParamValue(AInstance: TObject; AProperty: TRttiProperty;
      AFieldType: TFieldType): Variant;
  public
    constructor Create(AConnection: IDBConnection; ADriverName: TDriverName;
      AObject: TObject); override;
    destructor Destroy; override;
    function GenerateInsert(AObject: TObject): String;
    function AutoInc: TDMLCommandAutoInc;
  end;

implementation

{ TCommandInserter }

constructor TCommandInserter.Create(AConnection: IDBConnection;
  ADriverName: TDriverName; AObject: TObject);
begin
  inherited Create(AConnection, ADriverName, AObject);
  FDMLAutoInc := TDMLCommandAutoInc.Create;
end;

destructor TCommandInserter.Destroy;
begin
  FDMLAutoInc.Free;
  inherited;
end;

function TCommandInserter.GenerateInsert(AObject: TObject): String;
var
  LPlan: TInsertColumnPlan;
  LColumn: TColumnMapping;
  LCurrentValue: Variant;
  LPrimaryKey: TPrimaryKeyMapping;
  LBooleanValue: Integer;
  LGuid: TGUID;
  LGuidString: String;
begin
  try
    FResultCommand := FGeneratorCommand.GeneratorInsert(AObject);
    Result := FResultCommand;
    FParams.Clear;
    /// Issue #352. THE SAME CALL THE GENERATOR MADE. This loop used to repeat
    /// the generator's four skip tests and add a fifth of its own
    /// (IsJoinColumn), so the statement above and the params below could - and
    /// did - describe different column sets. A param the statement has no
    /// marker for is dropped in silence; a marker this loop leaves unbound is
    /// filled BY POSITION with the next param's value, which puts a value in
    /// the wrong column. One function now decides for both.
    ///
    /// The order is deliberate: GeneratorInsert runs FIRST, exactly as before,
    /// so an unmapped class still fails there with its own DIAG message rather
    /// than here.
    if not TInsertColumns.Plan(AObject, LPlan) then
      raise Exception.CreateFmt(cMESSAGECOLUMNNOTFOUND, [AObject.ClassName]);

    LPrimaryKey := TMappingExplorer.GetMappingPrimaryKey(AObject.ClassType);
    for LColumn in LPlan.Columns do
    begin
      try
        if LPrimaryKey <> nil then
        begin
          if LPrimaryKey.AutoIncrement then
          begin
            if LPrimaryKey.Columns.IndexOf(LColumn.ColumnName) > -1 then
            begin
              LCurrentValue := LColumn.ColumnProperty.GetNullableValue(AObject).AsVariant;
              if LPrimaryKey.GeneratorType = TGeneratorType.SequenceInc then
              begin
                if VarIsNull(LCurrentValue) or VarIsEmpty(LCurrentValue) or
                   (VarToStr(LCurrentValue) = '') or (VarToStr(LCurrentValue) = '-1') or
                   ((VarIsNumeric(LCurrentValue)) and (VarAsType(LCurrentValue, varInt64) <= 0)) then
                begin
                  FDMLAutoInc.Sequence := TMappingExplorer
                                          .GetMappingSequence(AObject.ClassType);
                  FDMLAutoInc.ExistSequence := (FDMLAutoInc.Sequence <> nil);
                  FDMLAutoInc.PrimaryKey := LPrimaryKey;
                  LColumn.ColumnProperty.SetValue(AObject,
                                                  FGeneratorCommand
                                                    .GeneratorAutoIncNextValue(AObject, FDMLAutoInc));
                end;
              end
              else
              if LPrimaryKey.GeneratorType = TGeneratorType.Guid32Inc then
              begin
                CreateGUID(LGuid);
                LGuidString := GUIDToString(LGuid);
                LGuidString := ReplaceStr(LGuidString, '-', '');
                LGuidString := ReplaceStr(LGuidString, '{', '');
                LGuidString := ReplaceStr(LGuidString, '}', '');
                LColumn.ColumnProperty.SetValue(AObject, LGuidString);
              end
              else
              if LPrimaryKey.GeneratorType = TGeneratorType.Guid36Inc then
              begin
                CreateGUID(LGuid);
                LGuidString := GUIDToString(LGuid);
                LGuidString := ReplaceStr(LGuidString, '-', '');
                LColumn.ColumnProperty.SetValue(AObject, LGuidString);
              end
              else
              if LPrimaryKey.GeneratorType = TGeneratorType.Guid38Inc then
              begin
                CreateGUID(LGuid);
                LGuidString := GUIDToString(LGuid);
                LColumn.ColumnProperty.SetValue(AObject, LGuidString);
              end
            end;
          end;
        end;
        with FParams.Add as TParam do
        begin
          Name := LColumn.ColumnName;
          DataType := LColumn.FieldType;
          ParamType := ptInput;
          if LColumn.FieldType = ftGuid then
          begin
            /// Issue #294. The reason is written out over
            /// TGuidOctetRefusal in Janus.DML.Commands. It stands BEFORE the
            /// value is read, not after: what is refused is the whole shape of
            /// the write, and a StringToGUID that happened to raise first
            /// would report the wrong defect.
            Self._GuardStoreGUIDAsOctet(LColumn.ColumnProperty,
                                        'num INSERT (parametro de gravacao)');
            LGuidString := _GetParamValue(AObject,
                                         LColumn.ColumnProperty,
                                         LColumn.FieldType);
            AsGuid := StringToGUID(LGuidString);
            Continue;
          end;
          Value := _GetParamValue(AObject,
                                 LColumn.ColumnProperty,
                                 LColumn.FieldType);
          /// Issue #325. The reason is written out over
          /// TDMLCommandAbstract._RefuseUnsignedValueTheColumnCannotCarry.
          Self._RefuseUnsignedValueTheColumnCannotCarry(AObject,
                                                        LColumn.ColumnName,
                                                        LColumn.ColumnProperty,
                                                        LColumn.FieldType,
                                                        Value);
          if FConnection.GetDriver = TDriverName.dnPostgreSQL then
            Continue;
          if DataType in [ftBoolean] then
          begin
            LBooleanValue := IfThen(Boolean(Value), 1, 0);
            DataType := ftInteger;
            Value := LBooleanValue;
          end;
        end;
      except
        on E: Exception do
          raise Exception.CreateFmt(
            'DIAG CommandInserter column=%s class=%s msg=%s',
            [LColumn.ColumnName, AObject.ClassName, E.Message]);
      end;
    end;
  except
    on E: Exception do
      raise Exception.CreateFmt('DIAG CommandInserter class=%s msg=%s',
        [AObject.ClassName, E.Message]);
  end;
end;

function TCommandInserter._GetParamValue(AInstance: TObject;
  AProperty: TRttiProperty; AFieldType: TFieldType): Variant;
var
  LValueGuid: TGUID;
begin
  Result := Null;
  case AProperty.PropertyType.TypeKind of
    tkEnumeration:
      Result := AProperty.GetEnumToFieldValue(AInstance, AFieldType).AsVariant;
  else
    if AFieldType = ftBlob then
      Result := AProperty.GetNullableValue(AInstance).AsType<TBlob>.ToBytes
    else if AFieldType = ftGuid then
    begin
     LValueGuid := AProperty.GetValue(AInstance).AsType<TGUID>;
     Result := LValueGuid.ToString;
    end
    else
      Result := AProperty.GetNullableValue(AInstance).AsVariant;
  end;
end;

function TCommandInserter.AutoInc: TDMLCommandAutoInc;
begin
  Result := FDMLAutoInc;
end;

end.
