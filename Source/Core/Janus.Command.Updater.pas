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

unit Janus.Command.Updater;

interface

uses
  DB,
  Rtti,
  Math,
  Classes,
  SysUtils,
  StrUtils,
  Variants,
  TypInfo,
  Generics.Collections,
  /// Janus
  Janus.Command.Abstract,
  Janus.Utils,
  Janus.Core.Consts,
  Janus.Types.Blob,
  DataEngine.FactoryInterfaces,
  MetaDbDiff.Rtti.Helper,
  MetaDbDiff.Mapping.Popular,
  MetaDbDiff.Mapping.Classes,
  MetaDbDiff.Mapping.Attributes,
  MetaDbDiff.Mapping.Explorer,
  /// Brings TRttiPropertyHelper_.MustWriteNull into scope. It must come AFTER
  /// MetaDbDiff.Rtti.Helper: the derived helper only extends the ancestor while
  /// the ancestor is already visible.
  Janus.RTTI.Helper;

type
  TCommandUpdater = class(TDMLCommandAbstract)
  private
    function _GetParamValue(AInstance: TObject; AProperty: TRttiProperty;
      AFieldType: TFieldType): Variant;
  public
    constructor Create(AConnection: IDBConnection; ADriverName: TDriverName;
      AObject: TObject); override;
    function GenerateUpdate(AObject: TObject;
      AModifiedFields: TDictionary<String, String>): String;
  end;

implementation

uses
  Janus.Objects.Helper;

{ TCommandUpdater }

constructor TCommandUpdater.Create(AConnection: IDBConnection;
  ADriverName: TDriverName; AObject: TObject);
var
  LColumns: TPrimaryKeyColumnsMapping;
  LColumn: TColumnMapping;
begin
  inherited Create(AConnection, ADriverName, AObject);
  LColumns := TMappingExplorer
                  .GetMappingPrimaryKeyColumns(AObject.ClassType);
  for LColumn in LColumns.Columns do
  begin
    with FParams.Add as TParam do
    begin
      Name := LColumn.ColumnName;
      DataType := LColumn.FieldType;
    end;
  end;
end;

function TCommandUpdater.GenerateUpdate(AObject: TObject;
  AModifiedFields: TDictionary<String, String>): String;
var
  LPrimaryKey: TPrimaryKeyColumnsMapping;
  LFor: Integer;
  LParams: TParams;
  LColumn: TColumnMapping;
  LObjectType: TRttiType;
  LProperty: TRttiProperty;
  LKey: String;
  LFieldType: Column;
  LBooleanValue: Integer;
begin
  Result := '';
  FResultCommand := '';
  if AModifiedFields.Count = 0 then
    Exit;
  // Variavel local usado como parametro para montar o script so com os
  // campos PrimaryKey.
  LParams := TParams.Create(nil);
  try
    LPrimaryKey := TMappingExplorer
                     .GetMappingPrimaryKeyColumns(AObject.ClassType);
    if LPrimaryKey = nil then
      raise Exception.Create(cMESSAGEPKNOTFOUND);

    for LColumn in LPrimaryKey.Columns do
    begin
      with LParams.Add as TParam do
      begin
        Name := LColumn.ColumnName;
        DataType := LColumn.FieldType;
        ParamType := ptUnknown;
        if DataType = ftGuid then
        begin
          /// Issue #294, on the KEY predicate of the UPDATE - and it does NOT
          /// contradict the paragraph below about issue #325. That one leaves
          /// the lookup alone because the lookup is self-consistent: the key
          /// written and the key looked up are the same bits, so the row is
          /// reached. Under StoreGUIDAsOctet it is NOT self-consistent - the
          /// text form matches no row of a 16-byte column, so the UPDATE
          /// touches nothing and reports success. The reason is written out
          /// over TGuidOctetRefusal in Janus.DML.Commands.
          Self._GuardStoreGUIDAsOctet(LColumn.ColumnProperty,
                                      'no WHERE de um UPDATE (parametro de chave)');
          Value := LColumn.ColumnProperty.GetNullableValue(AObject).AsType<TGuid>.ToString;
        end
        else
          Value := LColumn.ColumnProperty.GetNullableValue(AObject).AsVariant;
        /// ISSUE #325 DOES NOT GUARD HERE, AND THE ASYMMETRY IS THE POINT.
        /// These parameters are the WHERE of the update - a lookup, not a
        /// write - and the lookup REACHES THE SAME ROW the read took the key
        /// from. That is measured as an outcome, by a clause that updates a row
        /// whose key is Low(Int64) through an object loaded from it, and NOT
        /// argued from a mechanism: where the write path drops the sign is not
        /// established. The loop below, which writes VALUES, does carry the
        /// guard. Measured in Test.Janus.Server.Resource.IntegerKeyWidth.
      end;
    end;
    FResultCommand := FGeneratorCommand.GeneratorUpdate(AObject, LParams, AModifiedFields);
    Result := FResultCommand;
    // Gera todos os parametros, sendo os campos alterados primeiro e o do
    // PrimaryKey por ultimo, usando LParams criado local.
    AObject.GetType(LObjectType);
    for LKey in AModifiedFields.Keys do
    begin
      LProperty := LObjectType.GetProperty(LKey);
      if LProperty = nil then
        Continue;
      if LProperty.IsNoUpdate then
        Continue;
      LFieldType := LProperty.GetColumn;
      if LFieldType = nil then
        Continue;

      with LParams.Add as TParam do
      begin
        Name := LFieldType.ColumnName;
        DataType := LFieldType.FieldType;
        ParamType := ptInput;
        Value := _GetParamValue(AObject, LProperty, DataType);
        /// Issue #325, on a WRITTEN column of the UPDATE.
        Self._RefuseUnsignedValueTheColumnCannotCarry(AObject,
                                                      LFieldType.ColumnName,
                                                      LProperty,
                                                      DataType,
                                                      Value);
        if FConnection.GetDriver = TDriverName.dnPostgreSQL then
          Continue;
    	  // Tratamento para o tipo ftBoolean nativo, indo como Integer
        // para gravar no banco.
        if DataType in [ftBoolean] then
        begin
          LBooleanValue := IfThen(Boolean(Value), 1, 0);
          DataType := ftInteger;
          Value := LBooleanValue;
        end;
      end;
    end;
    FParams.Clear;
    for LFor := LParams.Count -1 downto 0 do
    begin
      with FParams.Add as TParam do
      begin
        Name := LParams.Items[LFor].Name;
        DataType := LParams.Items[LFor].DataType;
        Value := LParams.Items[LFor].Value;
        ParamType := LParams.Items[LFor].ParamType;
      end;
    end;
  finally
    LParams.Clear;
    LParams.Free;
  end;
end;

function TCommandUpdater._GetParamValue(AInstance: TObject;
  AProperty: TRttiProperty; AFieldType: TFieldType): Variant;
begin
  Result := Null;
  if AProperty.MustWriteNull(AInstance) then
    Exit;

  case AProperty.PropertyType.TypeKind of
    tkEnumeration:
      Result := AProperty.GetEnumToFieldValue(AInstance, AFieldType).AsType<Variant>;
    tkRecord:
      begin
        if AProperty.IsBlob then
          Result := AProperty.GetNullableValue(AInstance).AsType<TBlob>.ToBytes
        else
        /// Issue #384. THE DISPATCH IS ON THE LABEL OF THE COLUMN, NOT ON THE
        /// SHAPE OF THE PROPERTY - which is the same choice TCommandInserter
        /// makes for the same column kind, and it is the difference between the
        /// two commands: a plain TGUID answers no to every question this case
        /// asked before, so the opening Result := Null survived and the UPDATE
        /// bound Null over a stored GUID, in silence.
        ///
        /// IT STANDS BEFORE THE NULLABLE TEST BY INTENT, NOT BY MEASUREMENT.
        /// A Nullable<TGUID> answers IsNullable, so with the two arms swapped
        /// it would reach the AsType<Variant> below - the cast
        /// TRttiPropertyHelper_.GetValueNullable, in Janus.RTTI.Helper.pas,
        /// documents as raising over a TGUID. NO CLAUSE CAN TELL THE TWO ORDERS
        /// APART TODAY, and swapping them was run: the whole suite stays green.
        /// The reason is a neighbouring defect, NOT fixed here: MustWriteNull
        /// above already raises 'Invalid class typecast' for a Nullable<TGUID>
        /// that HOLDS a value, so that shape never reaches this case at all.
        /// Pinned in Test.Janus.DML.Generator.SQLite, over
        /// NullableGuidMustWriteNull. When that neighbour is fixed the order
        /// here starts to matter and a clause can then hold it.
        ///
        /// GetNullableValue and not GetValue: for a plain TGUID the two are the
        /// same call, and for a Nullable<TGUID> that holds a value it hands
        /// over the FValue the cast below cannot read. The empty Nullable never
        /// arrives here - MustWriteNull answered for it above.
        if AFieldType = ftGuid then
        begin
          /// Issue #294, on a WRITTEN column of the UPDATE - a site that did
          /// not exist when #294 was measured, because until now this path
          /// bound Null and rendered no GUID at all. The reason is written out
          /// over TGuidOctetRefusal in Janus.DML.Commands. It stands BEFORE the
          /// value is read, the order TCommandInserter states over its own
          /// call: what is refused is the whole shape of the write.
          Self._GuardStoreGUIDAsOctet(AProperty,
                                      'num UPDATE (parametro de gravacao)');
          Result := AProperty.GetNullableValue(AInstance).AsType<TGuid>.ToString;
        end
        else
        if AProperty.IsNullable then
          Result := AProperty.GetNullableValue(AInstance).AsType<Variant>;
      end
  else
    Result := AProperty.GetValue(AInstance).AsType<Variant>;
  end;
end;

end.
