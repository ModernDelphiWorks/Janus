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

  ORM Brasil: um ORM simples e descomplicado para quem utiliza Delphi.
}

unit Janus.DataSet.Fields;

interface

uses
  DB,
  Classes,
  SysUtils;

const
  /// <summary> Name of the column TBind.SetInternalInitFieldDefsObjectClass
  ///  adds to every dataset it initialises, to hold the STATE OF THE ROW.
  ///  TDataSetBaseAdapter<M>.DoBeforePost writes
  ///  Integer(dsInsert) whenever the dataset is in dsInsert, and
  ///  Integer(dsEdit) when it is in dsEdit AND the column currently holds -1 -
  ///  so a row still pending insertion keeps its insert marker through any
  ///  number of edits. The ApplyInserter and ApplyUpdater of
  ///  TFDMemTableAdapter<M>, TClientDataSetAdapter<M> and
  ///  TRESTDataSetAdapter<M> write -1 back once the row has been applied.
  ///
  ///  THE -1 IS NOT LOOP BOOKKEEPING, IT IS A RELATIONAL GUARD.
  ///  TDataSetBaseAdapter<M>._IsPendingInsertRow answers True for a row whose
  ///  column holds Integer(dsInsert), and also for a dataset that carries no
  ///  such column at all - that second branch is its fallback, not its normal
  ///  path. Only a row it answers True for may be re-pointed at a key the
  ///  database has just generated. A row at -1 is already saved and, in the
  ///  REST client, may
  ///  belong to a DIFFERENT master - the child dataset there holds the
  ///  children of every master the listing brought back - so stamping the new
  ///  key on it would silently re-parent someone else's data. Pinned by
  ///  Test.Janus.Apply.Loops
  ///  .ApplyInserter_DoesNotRepointAChildRowOfAnotherMaster and by
  ///  Test.Janus.AutoInc.Childs.PersistedChildRow_IsNotRepointed.
  ///
  ///  WHERE IT COMES FROM. TBind.SetInternalInitFieldDefsObjectClass creates
  ///  it after every mapped column and then moves it to position 0, with
  ///  DefaultExpression '-1' and Visible False. TBind.SetFieldToField and
  ///  TDataSetAbstract<M>.DoDataChange exclude it from the bind by NAME;
  ///  TBind.SetFieldToField also starts its walk at index 1.
  ///
  ///  THE COUPLING THE Apply* LOOPS RIDE ON. Six loops - the ApplyInserter and
  ///  ApplyUpdater of the three adapter families above - set Filter on this
  ///  NAME and then read and write FOrmDataSet.Fields[FInternalIndex], where
  ///  FInternalIndex is assigned 0 in TDataSetBaseAdapter<M>.Create: two
  ///  units agreeing by hand, with nothing in the compiler holding them
  ///  together. None of the six calls Next - a row leaves the walk only when
  ///  its own Post pushes it out of the filtered set. Measured, that marker
  ///  survives the Post only because every ApplyInternal calls
  ///  DisableDataSetEvents first, which unhooks DoBeforePost; with that event
  ///  live DoBeforePost rewrites the marker to Integer(dsEdit), which is the
  ///  value ApplyUpdater filters on, and ApplyUpdater never terminates. Both
  ///  halves are pinned by Test.Janus.Apply.Loops - the
  ///  InternalFieldIsFieldZero_* group for the position, the
  ///  WithBeforePostLive group for the event. </summary>
  cInternalField = 'InternalField';

  /// <summary> Name of the column that carries the IDENTITY OF THE ROW, minted
  ///  by TDataSetBaseAdapter<M>.DoNewRecord on every row the framework sees
  ///  created. It is not a key and never reaches the database: nothing in
  ///  TBind.SetPropertyToField or TBind.SetFieldToProperty looks at it, both
  ///  being driven by the column MAPPING rather than by the dataset's fields.
  ///
  ///  WHY IT EXISTS. TDataSetBaseAdapter<M>._AutoIncToChildRows has to answer
  ///  "which pending child rows belong to the master row I am standing on",
  ///  and every other way of asking was measured and failed: the master-detail
  ///  range filters on the master's CURRENT key, which by cascade time is the
  ///  NEW one while the children still hold the old; a bookmark's second dword
  ///  is a position in the view and moves when the first pending row leaves the
  ///  filter; and capturing the child set before the key swap cannot work
  ///  because TBind.SetInternalInitFieldDefsObjectClass gives every autoinc
  ///  primary key DefaultExpression '-1', so every pending row of every level
  ///  sits on -1 at the same instant.
  ///
  ///  IT IS CREATED LAST ON PURPOSE - after the mapped columns, after the
  ///  internal state column that is then moved to index 0, and after the
  ///  calculated fields. The reason is NOT that the nested copiers always
  ///  write to N + 1: TBind._FillADTField and the ADT/Mongo branch of
  ///  TBind._FillDataSetField copy source field N into ATarget.Fields[N + 1],
  ///  but the ordinary branch of TBind._FillDataSetField copies N into N. The
  ///  reason is stronger than that and holds for all THREE loops: every one of
  ///  them is bounded by the SOURCE's FieldCount, so a column appended at the
  ///  END of the target is never reached and is inert. What would NOT be inert
  ///  is an internal column placed BEFORE the mapped ones - it would break the
  ///  + 1 the first two rely on and misalign the N-into-N of the third, and no
  ///  assertion in the suite would notice. Pinned by
  ///  Test.Janus.AutoInc.Distribution
  ///  .MappedColumnsKeepTheOffsetTheNestedFillReliesOn.
  ///  THE NAME IS RESERVED. TBind._AddReservedField refuses to create it over
  ///  a column the entity already mapped under the same name, and says so.
  ///  </summary>
  cRowTokenField = 'RowToken';

  /// <summary> Name of the column that carries the RowToken of the master row
  ///  that was current when this row was created - "whose child am I". Two
  ///  columns are needed and one is not enough: a mid row has to say both who
  ///  it is, for its own children, and whose child it is, for its parent.
  ///
  ///  ZERO MEANS "NO PARENTAGE RECORDED", which is what a row created while the
  ///  adapter's events were unhooked carries, since DoNewRecord is what writes
  ///  it. TDataSetBaseAdapter<M>._IsOwnedByMasterRow answers True for such a
  ///  row against every master, which is exactly the behaviour that shipped
  ///  before this column existed. Pinned by Test.Janus.AutoInc.Distribution
  ///  .UntokenisedRows_KeepTheHistoricalBehaviour. </summary>
  cOwnerTokenField = 'OwnerToken';

type
  IFieldSingleton = interface
    ['{47DDCFB7-6EB9-41A9-A41F-D9474D7A1E85}']
    procedure AddField(const ADataSet: TDataSet;
      const AFieldName: String;
      const AFieldType: TFieldType;
      const APrecision: Integer = 0;
      const ASize: Integer = 0);
    procedure AddCalcField(const ADataSet: TDataSet;
                           const AFieldName: String;
                           const AFieldType: TFieldType;
                           const ASize: Integer = 0);
    procedure AddAggregateField(const ADataSet: TDataSet;
                                const AFieldName, AExpression: String;
                                const AAlignment: TAlignment = taLeftJustify;
                                const ADisplayFormat: String = '');
    procedure AddLookupField(const AFieldName: String;
                             const ADataSet: TDataSet;
                             const AKeyFields: String;
                             const ALookupDataSet: TDataSet;
                             const ALookupKeyFields: String;
                             const ALookupResultField: String;
                             const AFieldType: TFieldType;
                             const ASize: Integer = 0;
                             const ADisplayLabel: String = '');
  end;

  TFieldSingleton = class(TInterfacedObject, IFieldSingleton)
  private
  class var
    FInstance: IFieldSingleton;
  private
    function GetFieldType(ADataSet: TDataSet; AFieldType: TFieldType): TField;
  protected
    constructor Create;
  public
    { Public declarations }
    class function GetInstance: IFieldSingleton;
    procedure AddField(const ADataSet: TDataSet;
      const AFieldName: String;
      const AFieldType: TFieldType;
      const APrecision: Integer = 0;
      const ASize: Integer = 0);
    procedure AddCalcField(const ADataSet: TDataSet;
                           const AFieldName: String;
                           const AFieldType: TFieldType;
                           const ASize: Integer = 0);
    procedure AddAggregateField(const ADataSet: TDataSet;
                                const AFieldName, AExpression: String;
                                const AAlignment: TAlignment = taLeftJustify;
                                const ADisplayFormat: String = '');
    procedure AddLookupField(const AFieldName: String;
                             const ADataSet: TDataSet;
                             const AKeyFields: String;
                             const ALookupDataSet: TDataSet;
                             const ALookupKeyFields: String;
                             const ALookupResultField: String;
                             const AFieldType: TFieldType;
                             const ASize: Integer = 0;
                             const ADisplayLabel: String = '');
  end;

implementation

procedure TFieldSingleton.AddField(const ADataSet: TDataSet;
  const AFieldName: String;
  const AFieldType: TFieldType;
  const APrecision: Integer = 0;
  const ASize: Integer = 0);
var
  LField: TField;
begin
  LField := GetFieldType(ADataSet, AFieldType);
  if LField = nil then
    Exit;

  LField.Name         := ADataSet.Name + AFieldName;
  LField.FieldName    := AFieldName;
  LField.DisplayLabel := AFieldName;
  LField.Calculated   := False;
  LField.DataSet      := ADataSet;
  LField.FieldKind    := fkData;
  //
  case AFieldType of
    ftBytes, ftVarBytes, ftFixedChar, ftString, ftFixedWideChar, ftWideString:
      begin
        if ASize > 0 then
          LField.Size := ASize;
      end;
    ftFMTBcd:
      begin
        if APrecision > 0 then
          TFMTBCDField(LField).Precision := APrecision;
        if ASize > 0 then
          LField.Size := ASize;
      end;
  end;
end;

procedure TFieldSingleton.AddLookupField(const AFieldName: String;
  const ADataSet: TDataSet;
  const AKeyFields: String;
  const ALookupDataSet: TDataSet;
  const ALookupKeyFields: String;
  const ALookupResultField: String;
  const AFieldType: TFieldType;
  const ASize: Integer;
  const ADisplayLabel: String);
var
  LField: TField;
begin
  LField := GetFieldType(ADataSet, AFieldType);
  if LField = nil then
    Exit;

  LField.Name              := ADataSet.Name + '_' + AFieldName;
  LField.FieldName         := AFieldName;
  LField.DataSet           := ADataSet;
  LField.FieldKind         := fkLookup;
  LField.KeyFields         := AKeyFields;
  LField.Lookup            := True;
  LField.LookupDataSet     := ALookupDataSet;
  LField.LookupKeyFields   := ALookupKeyFields;
  LField.LookupResultField := ALookupResultField;
  LField.DisplayLabel      := ADisplayLabel;
  case AFieldType of
    ftLargeint, ftString, ftWideString, ftFixedChar, ftFixedWideChar:
      begin
        if ASize > 0 then
          LField.Size := ASize;
      end;
  end;
end;

constructor TFieldSingleton.Create;
begin

end;

function TFieldSingleton.GetFieldType(ADataSet: TDataSet;
  AFieldType: TFieldType): TField;
begin
  case AFieldType of
//     ftUnknown:         Result := nil;
     ftString:          Result := TStringField.Create(ADataSet);
     ftSmallint:        Result := TSmallintField.Create(ADataSet);
     ftInteger:         Result := TIntegerField.Create(ADataSet);
     ftWord:            Result := TWordField.Create(ADataSet);
     ftBoolean:         Result := TBooleanField.Create(ADataSet);
     ftFloat:           Result := TFloatField.Create(ADataSet);
     ftCurrency:        Result := TCurrencyField.Create(ADataSet);
     ftBCD:             Result := TBCDField.Create(ADataSet);
     ftDate:            Result := TDateField.Create(ADataSet);
     ftTime:            Result := TTimeField.Create(ADataSet);
     ftDateTime:        Result := TDateTimeField.Create(ADataSet);
     ftBytes:           Result := TBytesField.Create(ADataSet);
     ftVarBytes:        Result := TVarBytesField.Create(ADataSet);
     ftAutoInc:         Result := TIntegerField.Create(ADataSet);
     ftBlob:            Result := TBlobField.Create(ADataSet);
     ftMemo:            Result := TMemoField.Create(ADataSet);
     ftGraphic:         Result := TGraphicField.Create(ADataSet);
//     ftFmtMemo:         Result := nil;
//     ftParadoxOle:      Result := nil;
//     ftDBaseOle:        Result := nil;
     ftTypedBinary:     Result := TBinaryField.Create(ADataSet);
//     ftCursor:          Result := nil;
     ftFixedChar:       Result := TStringField.Create(ADataSet);
     ftWideString:      Result := TWideStringField.Create(ADataSet);
     ftLargeint:        Result := TLargeintField.Create(ADataSet);
     ftADT:             Result := TADTField.Create(ADataSet);
     ftArray:           Result := TArrayField.Create(ADataSet);
     ftReference:       Result := TReferenceField.Create(ADataSet);
     ftDataSet:         Result := TDataSetField.Create(ADataSet);
//     ftOraBlob:         Result := nil;
//     ftOraClob:         Result := nil;
     ftVariant:         Result := TVariantField.Create(ADataSet);
     ftInterface:       Result := TInterfaceField.Create(ADataSet);
     ftIDispatch:       Result := TIDispatchField.Create(ADataSet);
     ftGuid:            Result := TGuidField.Create(ADataSet);
     ftTimeStamp:       Result := TDateTimeField.Create(ADataSet);
     ftFMTBcd:          Result := TFMTBCDField.Create(ADataSet);
     ftFixedWideChar:   Result := TStringField.Create(ADataSet);
     ftWideMemo:        Result := TMemoField.Create(ADataSet);
     ftOraTimeStamp:    Result := TDateTimeField.Create(ADataSet);
     ftOraInterval:     Result := nil;
     ftLongWord:        Result := TLongWordField.Create(ADataSet);
     ftShortint:        Result := TShortintField.Create(ADataSet);
     ftByte:            Result := TByteField.Create(ADataSet);
     ftExtended:        Result := TExtendedField.Create(ADataSet);
//     ftConnection:      Result := nil;
//     ftParams:          Result := nil;
//     ftStream:          Result := nil;
     ftTimeStampOffset: Result := TStringField.Create(ADataSet);
     ftObject:          Result := TObjectField.Create(ADataSet);
     ftSingle:          Result := TSingleField.Create(ADataSet);
  else
     Result := TVariantField.Create(ADataSet);
  end;
end;

class function TFieldSingleton.GetInstance: IFieldSingleton;
begin
   if not Assigned(FInstance) then
      FInstance := TFieldSingleton.Create;
   Result := FInstance;
end;

procedure TFieldSingleton.AddCalcField(const ADataSet: TDataSet;
  const AFieldName: String;
  const AFieldType: TFieldType;
  const ASize: Integer);
var
  LField: TField;
begin
  if (ADataSet.FindField(AFieldName) <> nil) then
    raise Exception.Create('O Campo calculado : ' + AFieldName + ' j'#$00E1' existe');

  LField := GetFieldType(ADataSet, AFieldType);
  if LField = nil then
    Exit;

  LField.Name       := ADataSet.Name + AFieldName;
  LField.FieldName  := AFieldName;
  LField.Calculated := True;
  LField.DataSet    := ADataSet;
  LField.FieldKind  := fkInternalCalc;
  //
  case AFieldType of
     ftLargeint, ftString, ftWideString, ftFixedChar, ftFixedWideChar:
      begin
        if ASize > 0 then
          LField.Size := ASize;
      end;
  end;
end;

procedure TFieldSingleton.AddAggregateField(const ADataSet: TDataSet;
  const AFieldName, AExpression: String;
  const AAlignment: TAlignment;
  const ADisplayFormat: String);
var
  LField: TAggregateField;
begin
  if ADataSet.FindField(AFieldName) <> nil then
     raise Exception.Create('O Campo agregado de nome : ' + AFieldName + ' j'#$00E1' existe');

  LField := TAggregateField.Create(ADataSet);
  if LField = nil then
    Exit;

  LField.Name         := ADataSet.Name + AFieldName;
  LField.FieldKind    := fkAggregate;
  LField.FieldName    := AFieldName;
  LField.DisplayLabel := AFieldName;
  LField.DataSet      := ADataSet;
  LField.Expression   := AExpression;
  LField.Active       := True;
  LField.Alignment    := AAlignment;
  //
  if Length(ADisplayFormat) > 0 then
    LField.DisplayFormat := ADisplayFormat;
end;

end.
