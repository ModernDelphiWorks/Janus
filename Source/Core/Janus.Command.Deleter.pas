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

unit Janus.Command.Deleter;

interface

uses
  DB,
  Rtti,
  SysUtils,
  Types,
  Janus.Command.Abstract,
  DataEngine.FactoryInterfaces,
  MetaDbDiff.Mapping.Popular,
  MetaDbDiff.Rtti.Helper;

type
  TCommandDeleter = class(TDMLCommandAbstract)
  public
    constructor Create(AConnection: IDBConnection; ADriverName: TDriverName;
      AObject: TObject); override;
    function GenerateDelete(AObject: TObject): String;
  end;

implementation

uses
  Janus.Objects.Helper,
  Janus.Core.Consts,
  MetaDbDiff.mapping.classes,
  MetaDbDiff.mapping.explorer;

{ TCommandDeleter }

constructor TCommandDeleter.Create(AConnection: IDBConnection;
  ADriverName: TDriverName; AObject: TObject);
begin
  inherited Create(AConnection, ADriverName, AObject);
end;

function TCommandDeleter.GenerateDelete(AObject: TObject): String;
var
  LColumn: TColumnMapping;
  LPrimaryKeyCols: TPrimaryKeyColumnsMapping;
  LPrimaryKey: TPrimaryKeyMapping;
begin
  FParams.Clear;
  LPrimaryKeyCols := TMappingExplorer
                     .GetMappingPrimaryKeyColumns(AObject.ClassType);
  if LPrimaryKeyCols = nil then
    raise Exception.Create(cMESSAGECOLUMNNOTFOUND);

  for LColumn in LPrimaryKeyCols.Columns do
  begin
    with FParams.Add as TParam do
    begin
      Name := LColumn.ColumnName;
      DataType := LColumn.FieldType;
      ParamType := ptUnknown;
      if LColumn.IsPrimaryKey then
      begin
        LPrimaryKey := TMappingExplorer.GetMappingPrimaryKey(AObject.ClassType);
        if LPrimaryKey = nil then
          raise Exception.Create(cMESSAGEPKNOTFOUND);
          { TODO -oISAQUE -cREVISAO :
            Se voce sentiu falta desse trecho de codigo, entre em contato,
            precisamos discutir sobre ele, pois ele quebra regras de SOLID
            e fica em um lugar generico o qual nao atende a todos os bancos. }

//        if LPrimaryKey.GuidIncrement then
//        begin
//          AsBytes := StringToGUID(Format('{%s}', [LColumn.ColumnProperty
//                                                         .GetNullableValue(AObject)
//                                                         .AsType<String>.Trim(['{', '}'])]))
//                                                         .ToByteArray(TEndian.Big);
//          Continue;
//        end;
      end;
      if DataType = ftGuid then
      begin
        /// Issue #294, on the KEY predicate of the DELETE - and it does NOT
        /// contradict the paragraph below about issue #325. That one leaves
        /// the lookup alone because the lookup is self-consistent: the key
        /// written and the key looked up are the same bits, so the row is
        /// reached. Under StoreGUIDAsOctet it is NOT self-consistent - the
        /// text form matches no row of a 16-byte column, so the DELETE removes
        /// nothing and reports success. The reason is written out over
        /// TGuidOctetRefusal in Janus.DML.Commands.
        Self._GuardStoreGUIDAsOctet(LColumn.ColumnProperty,
                                    'no WHERE de um DELETE (parametro de chave)');
        Value := LColumn.ColumnProperty.GetNullableValue(AObject).AsType<TGuid>.ToString;
      end
      else
        Value := LColumn.ColumnProperty.GetNullableValue(AObject).AsVariant;
      /// ISSUE #325 STOPS HERE, DELIBERATELY, AND THE MEASUREMENT IS IN
      /// Test.Janus.Server.Resource.IntegerKeyWidth. The refusal introduced by
      /// that issue covers the WRITE of a value the column cannot carry; this
      /// is a LOOKUP, and the lookup is self-consistent: the key goes down as
      /// a bound parameter and REACHES THE SAME ROW the read took it from.
      /// That is measured as an outcome - a clause deletes a row whose key is
      /// Low(Int64) through an object loaded from it - and NOT argued from a
      /// mechanism; where the write path drops the sign is not established.
      /// Refusing here would take away the only way to remove a row that
      /// already carries such a key, which is strictly worse than today.
    end;
  end;
  FResultCommand := FGeneratorCommand.GeneratorDelete(AObject, FParams);
  Result := FResultCommand;
end;

end.
