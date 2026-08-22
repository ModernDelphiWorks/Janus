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
  /// ISSUE #312 - TInsertedEntity, a forma parseada de um elemento de
  /// `entities`. Mora ao lado de FResultParams e nunca dentro dele.
  Janus.Session.Abstract,
  MetaDbDiff.mapping.classes,
  MetaDbDiff.types.mapping,
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
    /// <summary> The reader above with the SOURCE made a parameter - issue
    ///  #312.
    ///
    ///  #312 needed the very same reading against a DIFFERENT list of pairs:
    ///  the `keys` of one element of `entities` rather than the flat
    ///  ResultParams. Everything that makes the reader safe - the IsWritable
    ///  guard, the case-insensitive match, first-match-wins, and above all the
    ///  rule that it may write only what the declared type provably accepts and
    ///  must otherwise leave the property alone - has to hold for both, and the
    ///  cheapest way to guarantee that is for there to be ONE of it.
    ///
    ///  So the body moved here unchanged and _SetGeneratedKeyValue became the
    ///  call that passes FSession.ResultParams. The root's route is therefore
    ///  the same code it always was, and every clause in
    ///  Test.Janus.Rest.ObjectSetInsertKey and
    ///  Test.Janus.Rest.NullableKeyReconciliation now holds BOTH readers
    ///  honest. </summary>
    procedure _SetGeneratedKeyValueFrom(const AObject: TObject;
      const AColumn: TColumnMapping; const AKeys: TParams);
    /// <summary> The object one `path` of the insert answer names, or NIL -
    ///  issue #312.
    ///
    ///  A path is association property names separated by dots, each one
    ///  followed by a bracketed ordinal when the association is to-many:
    ///  `mids[0].leafs[1]`. The EMPTY path is the root and never reaches here.
    ///
    ///  IT NAVIGATES BY THE ASSOCIATION MAPPING AND NOT BY BARE RTTI, and that
    ///  is the whole safety of it. Two things follow:
    ///
    ///    - `entities` can only ever address a MAPPED association. A path
    ///      naming any other published property resolves to nil and writes
    ///      nothing, so a defective - or hostile - answer cannot reach into an
    ///      arbitrary part of the object graph.
    ///    - The MULTIPLICITY decides whether the segment must carry an ordinal,
    ///      which is the same question the producer asked when it wrote the
    ///      segment. Without it the list branch would have to cast whatever the
    ///      property holds to TObjectList&lt;TObject&gt; and read Count off it -
    ///      an unchecked cast on a value that came off the wire. Here a segment
    ///      whose shape disagrees with the mapping simply resolves to nil.
    ///
    ///  EVERY REFUSAL IS NIL AND NOTHING RAISES, for the reason #301 wrote:
    ///  before the answer was read, no answer of any shape could make an insert
    ///  fail, and reading it must not have bought that.
    ///
    ///  NOT MEASURED against a live server. </summary>
    function _ResolveEntityPath(const ARoot: TObject;
      const APath: String): TObject;
    /// <summary> Writes onto the graph the key the server generated for each
    ///  row BELOW the root - issue #312.
    ///
    ///  WHY IT EXISTS. The server writes the whole aggregate and the database
    ///  generates a key for every row, but until #312 the answer named the
    ///  primary key of ONE class - the root. The client kept a graph whose
    ///  every level below the first held the AutoInc placeholder, and the
    ///  symptom arrived later, as an Update or a Delete aimed at a key no row
    ///  has.
    ///
    ///  AND THE PLACEHOLDER WAS NOT EVEN CONFINED TO THE CHILD'S OWN KEY. A
    ///  grandchild had no valid PARENT in memory either: SetAutoIncValueChilds
    ///  walks exactly ONE level, Insert calls it only on the root, and this
    ///  family never calls CascadeActionsExecute for an insert - so nothing
    ///  reached the third level at all. That is why this stamps the key AND
    ///  then walks one level down from the object it just stamped: the first
    ///  write fixes that object's own key, the second hands it to the children
    ///  waiting on it, exactly as the server's own cascade does.
    ///
    ///  IT IS ORDER INDEPENDENT ON PURPOSE. Each entry names its own target and
    ///  carries its own keys, and the one-level walk reads the key off the
    ///  object it has just written. So no entry depends on another having been
    ///  applied first, and the reader does not care what order the array
    ///  arrived in. That is the property a flat ordinal would not have had.
    ///
    ///  THE ROOT'S ENTRY IS SKIPPED. The root already has a reader - the
    ///  `params` route in Insert - and answering one question twice is how two
    ///  ends of a contract drift apart. The producer still emits the root's
    ///  entry, because an `entities` array that describes the whole graph is
    ///  worth more to a third party reader than one with a hole in it.
    ///
    ///  NOT MEASURED against a live server. </summary>
    procedure _ApplyGeneratedKeysToGraph(const AObject: TObject);
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
  /// Nullable<...> and the SetValueNullable helper that writes one - issue #317.
  /// IN THE IMPLEMENTATION and not the interface, deliberately: nothing in this
  /// unit's interface mentions either, and a class helper named in an INTERFACE
  /// uses clause travels to every unit downstream, where the LAST one in scope
  /// wins. Janus.RTTI.Helper's helper descends from MetaDbDiff's
  /// TRttiPropertyHelper so it would add rather than hide - but the way to not
  /// have to make that argument at all is to keep it out of the interface.
  Janus.Types.Nullable,
  Janus.RTTI.Helper,
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
begin
  // ISSUE #312 - o corpo desta leitura virou _SetGeneratedKeyValueFrom, com a
  // FONTE por parametro, para que a leitura de `entities` seja A MESMA e nao
  // uma segunda copia dela. A raiz continua vindo de FResultParams, e nenhuma
  // entrada de `entities` entra ali - ver TInsertedEntity.
  _SetGeneratedKeyValueFrom(AObject, AColumn, FSession.ResultParams);
end;

procedure TRESTObjectSetAdapter<M>._SetGeneratedKeyValueFrom(
  const AObject: TObject; const AColumn: TColumnMapping; const AKeys: TParams);
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
  for LFor := 0 to AKeys.Count -1 do
  begin
    LParam := AKeys.Items[LFor];
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

function TRESTObjectSetAdapter<M>._ResolveEntityPath(const ARoot: TObject;
  const APath: String): TObject;
var
  LSegments: TArray<String>;
  LSegment: String;
  LName: String;
  LIndexText: String;
  LIndex: Integer;
  LOpen: Integer;
  LCurrent: TObject;
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LFound: TAssociationMapping;
  LIsList: Boolean;
  LValue: TValue;
  LList: TObjectList<TObject>;
begin
  Result := nil;
  if APath = '' then
    Exit;
  LCurrent := ARoot;
  LSegments := APath.Split(['.']);
  for LSegment in LSegments do
  begin
    if LCurrent = nil then
      Exit(nil);
    LName := LSegment;
    LIndex := -1;
    LOpen := Pos('[', LSegment);
    if LOpen > 0 then
    begin
      if LSegment[Length(LSegment)] <> ']' then
        Exit(nil);
      LName := Copy(LSegment, 1, LOpen -1);
      LIndexText := Copy(LSegment, LOpen +1, Length(LSegment) - LOpen -1);
      if not TryStrToInt(LIndexText, LIndex) then
        Exit(nil);
      if LIndex < 0 then
        Exit(nil);
    end;
    if LName = '' then
      Exit(nil);
    LAssociations := TMappingExplorer.GetMappingAssociation(LCurrent.ClassType);
    if LAssociations = nil then
      Exit(nil);
    LFound := nil;
    for LAssociation in LAssociations do
    begin
      // Case-insensitively, for the same reason the key name is matched that
      // way: a third party server is not obliged to echo the spelling back.
      if SameText(LAssociation.PropertyRtti.Name, LName) then
      begin
        LFound := LAssociation;
        Break;
      end;
    end;
    if LFound = nil then
      Exit(nil);
    // THE MULTIPLICITY DECIDES THE SHAPE OF THE SEGMENT, and it is the same
    // question the producer asked when it wrote it. A to-many association
    // MUST carry an ordinal and a to-one MUST NOT; anything else is an answer
    // about a graph this client does not have.
    LIsList := LFound.Multiplicity in [TMultiplicity.OneToMany,
                                       TMultiplicity.ManyToMany];
    if LIsList <> (LIndex >= 0) then
      Exit(nil);
    LValue := LFound.PropertyRtti.GetNullableValue(LCurrent);
    if not LValue.IsObject then
      Exit(nil);
    if not LIsList then
      // TValue reports tkClass for a NIL instance too, so this can still be
      // nil - the loop head above catches it on the next turn and the final
      // assignment below cannot answer a dangling one.
      LCurrent := LValue.AsObject
    else
    begin
      LList := TObjectList<TObject>(LValue.AsObject);
      if LList = nil then
        Exit(nil);
      if LIndex >= LList.Count then
        Exit(nil);
      LCurrent := LList.Items[LIndex];
    end;
  end;
  Result := LCurrent;
end;

procedure TRESTObjectSetAdapter<M>._ApplyGeneratedKeysToGraph(
  const AObject: TObject);
var
  LEntity: TInsertedEntity;
  LTarget: TObject;
  LPrimaryKey: TPrimaryKeyColumnsMapping;
  LColumn: TColumnMapping;
begin
  for LEntity in FSession.ResultEntities do
  begin
    // The root has its own reader - see the doc comment over the declaration.
    //
    // THIS GUARD IS REDUNDANT TODAY AND SAYS SO, because a mutation proved it:
    // removed, with a {$MESSAGE WARN} the compiler echoed as W1054, the
    // RESTfulDriver suite stayed at 272/0/0. _ResolveEntityPath refuses the
    // empty path on its own, so the entry would be dropped one line below
    // anyway. It stays because the two refusals answer different questions -
    // that one says "the empty path addresses nothing", this one says "the
    // root is not this reader's to write" - and it would become live the day
    // the resolver learned to answer for the root. It is NOT load-bearing now.
    if LEntity.Path = '' then
      Continue;
    LTarget := _ResolveEntityPath(AObject, LEntity.Path);
    if LTarget = nil then
      Continue;
    // The producer says WHICH CLASS it measured, and when it does the reader
    // checks it. A path that resolves to something else is an answer about a
    // graph this client does not have, and writing a key from it would be
    // writing a real number onto the wrong object - silently, which is exactly
    // the failure a bare ordinal would have had. The check is skipped when the
    // answer omits `class`, so a third party server that does not send it is
    // still read.
    if (LEntity.EntityClassName <> '') and
       (not SameText(LEntity.EntityClassName, LTarget.ClassName)) then
      Continue;
    LPrimaryKey := TMappingExplorer.GetMappingPrimaryKeyColumns(LTarget.ClassType);
    // No `raise` here, unlike Insert's own reading of the root's mapping: an
    // entry for an unmapped branch is a defect in the ANSWER, and an answer
    // must not be able to make an insert that already succeeded fail.
    if LPrimaryKey = nil then
      Continue;
    // Two loops rather than one, for the reason #301 wrote at the root: no
    // column may be cascaded down before every column has been reconciled.
    for LColumn in LPrimaryKey.Columns do
      _SetGeneratedKeyValueFrom(LTarget, LColumn, LEntity.Keys);

    // AND THIS IS THE HALF THE ROOT'S READER ALREADY HAD. Stamping the mid's
    // own key leaves the LEAF still pointing at the placeholder, because
    // nothing on the client copies a mid's key down - SetAutoIncValueChilds
    // walks one level and Insert calls it on the root alone. Walking one level
    // from each reconciled object is what gives the grandchild a valid parent.
    for LColumn in LPrimaryKey.Columns do
      SetAutoIncValueChilds(LTarget, LColumn);
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

      // ISSUE #312 - AND NOW EVERY LEVEL BELOW THE ROOT. The two loops above
      // reconcile the root and hand its key to the level under it, which is
      // all the answer could carry before this issue. `entities` names the key
      // the server generated for each of the other rows, so each of them can
      // be reconciled and can hand ITS key to the level under IT.
      //
      // INSIDE THE ExistSequence GATE, with the two loops above and for the
      // same reason: with no [Sequence] there is no generated key to
      // reconcile, and the client's own values must survive. Pinned by
      // Insert_WithoutASequenceTheEntitiesArrayIsNotRead.
      //
      // AFTER them, not before: the two are independent - the root's entry is
      // skipped by the reader - but keeping the root's whole reconciliation in
      // one place is what makes the order of these three lines readable.
      _ApplyGeneratedKeysToGraph(AObject);
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
