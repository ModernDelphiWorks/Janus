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
    constructor Create(AConnection: IDBConnection; ADriverName: TDBEngineDriver;
      AObject: TObject); override;
    destructor Destroy; override;
    function GenerateInsert(AObject: TObject): String;
    function AutoInc: TDMLCommandAutoInc;
  end;

implementation

{ TCommandInserter }

constructor TCommandInserter.Create(AConnection: IDBConnection;
  ADriverName: TDBEngineDriver; AObject: TObject);
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
  LColumns: TColumnMappingList;
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
    LColumns := TMappingExplorer.GetMappingColumn(AObject.ClassType);
    if LColumns = nil then
      raise Exception.CreateFmt(cMESSAGECOLUMNNOTFOUND, [AObject.ClassName]);

    LPrimaryKey := TMappingExplorer.GetMappingPrimaryKey(AObject.ClassType);
    for LColumn in LColumns do
    begin
      try
        if not Assigned(LColumn.ColumnProperty) then
          Continue;
        if LColumn.ColumnProperty.IsNullValue(AObject) then
          Continue;
        if (LColumn.FieldType in [ftBlob, ftGraphic, ftOraBlob, ftOraClob]) and
           (Length(LColumn.ColumnProperty.GetNullableValue(AObject).AsType<TBlob>.ToBytes) = 0) then
          Continue;
        if LColumn.IsNoInsert then
          Continue;
        if LColumn.IsJoinColumn then
          Continue;

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
            LGuidString := _GetParamValue(AObject,
                                         LColumn.ColumnProperty,
                                         LColumn.FieldType);
            AsGuid := StringToGUID(LGuidString);
            Continue;
          end;
          Value := _GetParamValue(AObject,
                                 LColumn.ColumnProperty,
                                 LColumn.FieldType);
          if FConnection.GetDriver = TDBEngineDriver.dnPostgreSQL then
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
