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
  @abstract(REST Componentes)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Janus.RestObjectSet.Adapter;

interface

uses
  DB,
  Rtti,
  TypInfo,
  Classes,
  Variants,
  SysUtils,
  Generics.Collections,
  /// Janus
  Janus.ObjectSet.Base.Adapter,
  Janus.RestFactory.Interfaces,
  MetaDbDiff.mapping.classes,
  MetaDbDiff.types.mapping,
  /// Nullable<...> and the SetValueNullable helper that writes one - issue #317.
  /// Janus.RTTI.Helper's helper DESCENDS from MetaDbDiff's TRttiPropertyHelper,
  /// so bringing it in adds SetValueNullable without hiding anything the unit
  /// already had from the base helper.
  Janus.Types.Nullable,
  Janus.RTTI.Helper,
  Janus.Objects.Helper;

type
  TRESTObjectSetAdapter<M: class, constructor> = class(TObjectSetBaseAdapter<M>)
  private
    FConnection: IRESTConnection;
    /// <summary> Writes onto AObject the value the SERVER generated for
    ///  AColumn, taken from the insert answer.
    ///
    ///  WHY THIS EXISTS - issue #301. Insert POSTed the aggregate and went
    ///  straight to the cascade, so FSession.ResultParams - already parsed and
    ///  filled by TSessionRestFul<M>.Insert - was never read. The root kept the
    ///  AutoInc placeholder and the cascade handed that placeholder to the
    ///  children.
    ///
    ///  WHY IT IS SCOPED TO THE PRIMARY KEY AND MATCHED BY NAME. Because that
    ///  is exactly what the producer emits: Janus.Server.Resource.pas builds
    ///  the answer from a loop over the PRIMARY KEY COLUMNS of the inserted
    ///  entity, naming each one by ColumnProperty.Name. Nothing else is named,
    ///  so an answer carrying any other name must change nothing.
    ///
    ///  THIS IS NOT THE SAME CODE AS THE DATASET FAMILY'S, and the duplication
    ///  is deliberate - see the note over Insert.
    ///
    ///  IT MUST NOT BE ABLE TO RAISE. Before #301 no answer of any shape could
    ///  reach the client, so no answer could make an insert fail; reading the
    ///  answer must not have bought that. Every value arrives as TEXT, so the
    ///  rule is: write only what the declared type provably accepts, and leave
    ///  the property alone otherwise.
    ///
    ///  A KNOWN LIMIT, NOT AN OVERSIGHT. A key whose property is a tkFloat or a
    ///  tkEnumeration falls through the case untouched. Such an entity comes out
    ///  of an insert WITHOUT its generated key reconciled - it keeps the
    ///  placeholder, exactly as it did before #301, so nothing regresses; but
    ///  #301 does not reach it either. That shape needs a follow-up, not a patch
    ///  here.
    ///
    ///  A NULLABLE KEY USED TO BE ON THAT LIST AND IS NOT ANY MORE - issue #317.
    ///  #301 wrote a tkRecord branch for it and REMOVED it, because writing text
    ///  into a Nullable goes through SetValueNullable, which casts to the
    ///  element type and raises on anything that is not one, and because no
    ///  entity under Test/Delphi had a Nullable key to hold the branch honest.
    ///  Both halves have been re-measured; see _SetGeneratedKeyValueNullable
    ///  below for what changed and why the branch can no longer raise.
    ///
    ///  NOT MEASURED against a live server. </summary>
    procedure _SetGeneratedKeyValue(const AObject: TObject;
      const AColumn: TColumnMapping);
    /// <summary> The Nullable arm of the reader above - issue #317.
    ///
    ///  WHAT WAS WRONG. A `Nullable<T>` property is tkRecord, so it matched no
    ///  label of the case above and the object came out of an insert still
    ///  holding the AutoInc placeholder, which the cascade then handed down to
    ///  every child's foreign key. That is the shape the repository SHIPS AS AN
    ///  EXAMPLE: all eight models under Examples\Delphi\Data\Varios Niveis de
    ///  Dados declare their key that way, Orion.Model.Contato spelling it
    ///  [Column('id', ftInteger)] over property id: Nullable&lt;Integer&gt;.
    ///
    ///  WHY IT CAN BE HELD HONEST NOW, AND THE #301 ENUMERATION THAT SAID IT
    ///  COULD NOT. That enumeration read "of the 39 entities carrying a
    ///  [PrimaryKey] under Test/Delphi none has a Nullable key". RE-RUN at
    ///  7e5e51d it is FALSE - Test.Janus.Model.KeyTypes.TKeyTypeNullable and
    ///  Test.Janus.Model.KeyTypeDecoy.TKeyTypeDecoy are both
    ///  Nullable&lt;String&gt; keys, added by #311 after that sentence was
    ///  written. It is still true that NEITHER can hold this arm honest: both
    ///  are TAutoIncType.NotInc with no [Sequence], so ExistSequence answers
    ///  False and Insert never reaches the reader for them at all. What #317
    ///  supplies is the missing combination - a Nullable key AND a [Sequence] -
    ///  in Test.Janus.Model.NullableKey, one root per element type.
    ///
    ///  WHY IT CANNOT RAISE, WHICH IS THE RULE #301 REMOVED THE OLD BRANCH
    ///  UNDER. The text is parsed HERE, and SetValueNullable is called only with
    ///  a variant already of the element's type, so the `Integer(AValue)` and
    ///  `Int64(AValue)` casts inside it cannot fail. The arm that receives the
    ///  value is selected by comparing PropertyType.Handle against
    ///  TypeInfo(Nullable&lt;X&gt;) - THE SAME COMPARISON SetValueNullable uses
    ///  to choose its own arm - so the parse and the write cannot disagree. They
    ///  are not two tables kept in step by hand; they are one question asked
    ///  twice.
    ///
    ///  WHY NOT DISPATCH ON TColumnMapping.FieldType, WHICH THE CALLER ALREADY
    ///  HAS. Because the column type is not the property type, and where they
    ///  differ a FieldType-keyed parse feeds the wrong arm of SetValueNullable -
    ///  which is exactly the raise the rule forbids. Enumerated at 7e5e51d over
    ///  every [PrimaryKey] under Test\ and Examples\ resolved to its [Column],
    ///  the repository ships three keys where the two disagree:
    ///  Test.Janus.Model.KeyTypes' ktut is [Column(..., ftString, 60)] over a
    ///  UInt64 property, and Model.Setor under "Quatro Niveis de Dados" and
    ///  under "Object Lazy" are ftInteger and ftBCD over Double properties.
    ///  Structurally too: TFieldType has some forty labels against
    ///  SetValueNullable's eleven arms, and ftFloat alone cannot say whether the
    ///  property is Nullable&lt;Double&gt; or Nullable&lt;Currency&gt; - so the
    ///  higher-up reader would have to consult the property anyway, at which
    ///  point it IS this method, written twice.
    ///
    ///  SCOPE, AND THE CLAUSE THAT KEEPS IT MEASURED. Three element types are
    ///  written and every other one falls through untouched. That is not a
    ///  comment: Test.Janus.Rest.NullableKeyReconciliation drives a
    ///  Nullable&lt;Double&gt; key - TNdRoot - and requires the placeholder to
    ///  stand. A float arm added without a fixture reddens there.
    ///
    ///  THE EMPTY-TEXT GUARD ON THE STRING ARM IS NOT COSMETIC. Handing an empty
    ///  variant to SetValueNullable reaches Nullable&lt;String&gt;.Create(Variant),
    ///  whose VarIsNullOrEmpty test CLEARS the record - so without the guard an
    ///  object would come out of an insert holding LESS than it went in with.
    ///  Measured by AnEmptyNullableStringKeyLeavesThePlaceholder, which checks
    ///  HasValue and not only the text.
    ///
    ///  NOT MEASURED against a live server. </summary>
    procedure _SetGeneratedKeyValueNullable(const AObject: TObject;
      const AProperty: TRttiProperty; const AText: String);
  public
    constructor Create(const AConnection: IRESTConnection;
      const APageSize: Integer = -1); overload;
    destructor Destroy; override;
    function Find: TObjectList<M>; overload; override;
    function Find(const AID: Int64): M; overload; override;
    function Find(const AID: String): M; overload; override;
    {$IFDEF DRIVERRESTFUL}
    function Find(const AMethodName: String;
      const AParams: array of String): TObjectList<M>; overload; override;
    {$ENDIF}
    function FindWhere(const AWhere: String;
      const AOrderBy: String = ''): TObjectList<M>; overload; override;
    procedure Insert(const AObject: M); override;
    procedure Update(const AObject: M); override;
    procedure Delete(const AObject: M); override;
  end;

implementation

uses
  Janus.Session.RESTful,
  MetaDbDiff.mapping.explorer,
  Janus.Core.Consts;

{ TRESTObjectSetAdapter<M> }

constructor TRESTObjectSetAdapter<M>.Create(const AConnection: IRESTConnection;
  const APageSize: Integer = -1);
begin
  inherited Create;
  FConnection := AConnection;
  FSession := TSessionRestFul<M>.Create(AConnection, nil, APageSize);
end;

procedure TRESTObjectSetAdapter<M>.Delete(const AObject: M);
begin
  inherited;
  try
    // Executa comando delete em cascade
    CascadeActionsExecute(AObject, TCascadeAction.CascadeDelete);
    // Executa comando delete master
    FSession.Delete(AObject);
  except
    on E: Exception do
    begin
      raise Exception.Create(E.Message);
    end;
  end;
end;

destructor TRESTObjectSetAdapter<M>.Destroy;
begin
  FSession.Free;
  inherited;
end;

function TRESTObjectSetAdapter<M>.Find: TObjectList<M>;
begin
  inherited;
  Result := FSession.Find;
end;

function TRESTObjectSetAdapter<M>.Find(const AID: Int64): M;
begin
  inherited;
  Result := FSession.Find(AID);
end;

function TRESTObjectSetAdapter<M>.Find(const AID: String): M;
begin
  inherited;
  Result := FSession.Find(AID);
end;

function TRESTObjectSetAdapter<M>.FindWhere(const AWhere,
  AOrderBy: String): TObjectList<M>;
begin
  inherited;
  Result := FSession.FindWhere(AWhere, AOrderBy);
end;

procedure TRESTObjectSetAdapter<M>._SetGeneratedKeyValueNullable(
  const AObject: TObject; const AProperty: TRttiProperty; const AText: String);
var
  LHandle: PTypeInfo;
  LInteger: Integer;
  LInt64: Int64;
begin
  LHandle := AProperty.PropertyType.Handle;
  // THE SAME COMPARISON SetValueNullable USES TO PICK ITS OWN ARM. Parsing here
  // and dispatching there on two different questions is what would let a text
  // reach `Integer(AValue)`; asking the one question twice is what makes that
  // impossible. See the doc comment over the declaration.
  if LHandle = TypeInfo(Nullable<Integer>) then
  begin
    if TryStrToInt(AText, LInteger) then
      AProperty.SetValueNullable(AObject, LHandle, LInteger);
  end
  else
  if LHandle = TypeInfo(Nullable<Int64>) then
  begin
    if TryStrToInt64(AText, LInt64) then
      AProperty.SetValueNullable(AObject, LHandle, LInt64);
  end
  else
  if LHandle = TypeInfo(Nullable<String>) then
  begin
    // The empty text is refused rather than passed on: Nullable<String>.Create
    // reads an empty variant as "no value" and would CLEAR a key the object
    // already had.
    if AText <> '' then
      AProperty.SetValueNullable(AObject, LHandle, AText);
  end;
end;

procedure TRESTObjectSetAdapter<M>._SetGeneratedKeyValue(const AObject: TObject;
  const AColumn: TColumnMapping);
var
  LProperty: TRttiProperty;
  LParam: TParam;
  LFor: Integer;
  LText: String;
  LInteger: Integer;
  LInt64: Int64;
begin
  LProperty := AColumn.ColumnProperty;
  // Mirrors TBind.SetFieldToProperty, which skips a column whose property is
  // not writable rather than letting SetValue raise on it.
  if not LProperty.IsWritable then
    Exit;
  for LFor := 0 to FSession.ResultParams.Count -1 do
  begin
    LParam := FSession.ResultParams.Items[LFor];
    // The answer names the key by PROPERTY name, which is what the producer
    // wrote. Case-insensitively, for the same reason the DataSet family reads
    // it through FindField: a third party server is not obliged to echo the
    // spelling back.
    if not SameText(LParam.Name, LProperty.Name) then
      Continue;

    // EVERYTHING THAT ARRIVES HERE IS TEXT, and that is not an assumption -
    // Janus.Session.RESTful.pas builds every param with `DataType := ftString`
    // and assigns `JsonValue.Value`. A JSON null arrives as the EMPTY STRING,
    // never as a Null or an Empty variant, so the shape of guard that asks
    // VarIsNull/VarIsEmpty can never fire; it was written here, it never ran,
    // and the empty text went straight on to TParam.AsInteger, which raised
    // `Could not convert variant of type (UnicodeString) into type (Integer)`.
    //
    // BEFORE #301 NOTHING READ THIS ANSWER, so no answer of any shape could
    // make an insert fail. Reading it must not have bought that. The rule is
    // therefore: write only what the property's declared type provably accepts,
    // and otherwise leave the property exactly as it was - which is the
    // behaviour that shipped.
    LText := VarToStr(LParam.Value);
    case LProperty.PropertyType.TypeKind of
      tkInteger:
        if TryStrToInt(LText, LInteger) then
          LProperty.SetValue(AObject, TValue.From<Integer>(LInteger));
      tkInt64:
        if TryStrToInt64(LText, LInt64) then
          LProperty.SetValue(AObject, TValue.From<Int64>(LInt64));
      tkString, tkLString, tkWString, tkUString:
        if LText <> '' then
          LProperty.SetValue(AObject, TValue.From<String>(LText));
      /// A Nullable is a record, and the ONLY record shape this reader writes.
      /// Anything else that lands here - a bare TGUID key, say - falls through
      /// the method below untouched, which is what it did when there was no arm
      /// at all. Issue #317.
      tkRecord:
        _SetGeneratedKeyValueNullable(AObject, LProperty, LText);
    end;
    // The FIRST param that names this key decides, whether or not its value
    // could be used. The shipped contract emits one object per primary key
    // column and so cannot produce a second one naming the same key; pinning
    // the reading here is what keeps a later edit from silently making the
    // LAST one win instead.
    Exit;
  end;
end;

procedure TRESTObjectSetAdapter<M>.Insert(const AObject: M);
var
  LPrimaryKey: TPrimaryKeyColumnsMapping;
  LColumn: TColumnMapping;
begin
  inherited;
  try
    FSession.Insert(AObject);
    if FSession.ExistSequence then
    begin
      LPrimaryKey := TMappingExplorer
                       .GetMappingPrimaryKeyColumns(AObject.ClassType);
      if LPrimaryKey = nil then
        raise Exception.Create(cMESSAGEPKNOTFOUND);

      // ISSUE #301 - READ THE ANSWER BEFORE CASCADING, AND THE ORDER IS THE
      // WHOLE POINT. SetAutoIncValueChilds copies the ROOT's key property into
      // the children's foreign keys; with the root still on the AutoInc
      // placeholder it copied the placeholder, so the client came out of a save
      // holding an aggregate whose every key names a row nobody has - the root
      // included. Two loops rather than one so that no column can be cascaded
      // before every column has been reconciled.
      //
      // THE DATASET FAMILY HAS ITS OWN COPY OF THIS READ, in
      // TRESTDataSetAdapter<M>.ApplyInserter, and the duplication STAYS. The
      // two do not write the same thing: that one sets any FIELD the answer
      // names on the row under the cursor, this one sets a typed PROPERTY and
      // only for a primary key column. The two families share no ancestor -
      // TDataSetAbstract<M> and TObjectSetAbstract<M> are both `class abstract`
      // with nothing above them - so a single point would have to be a new unit
      // parameterised over WHERE to write, which is a branch per family dressed
      // up as sharing. Measured cost of the alternative: three files, one of
      // them Janus.RestDataSet.Adapter.pas, which #309 has just rewritten.
      for LColumn in LPrimaryKey.Columns do
        _SetGeneratedKeyValue(AObject, LColumn);

      for LColumn in LPrimaryKey.Columns do
        SetAutoIncValueChilds(AObject, LColumn);
    end;
  except
    on E: Exception do
    begin
      raise Exception.Create(E.Message);
    end;
  end;
end;

procedure TRESTObjectSetAdapter<M>.Update(const AObject: M);
var
  LObjectList: TObjectList<M>;
begin
  inherited;
  LObjectList := TObjectList<M>.Create;
  try
    LObjectList.Add(AObject);
    FSession.Update(LObjectList);
  finally
    LObjectList.Clear;
    LObjectList.Free;
  end;
end;

{$IFDEF DRIVERRESTFUL}
function TRESTObjectSetAdapter<M>.Find(const AMethodName: String;
  const AParams: array of String): TObjectList<M>;
begin
  inherited;
  Result := FSession.Find(AMethodName, AParams);
end;
{$ENDIF}

end.
