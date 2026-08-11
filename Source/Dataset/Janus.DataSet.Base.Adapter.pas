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
  @abstract(Website : http://www.Janus.com.br)
}

{$INCLUDE ..\Janus.inc}

unit Janus.DataSet.Base.Adapter;

interface

uses
  DB,
  Rtti,
  TypInfo,
  Classes,
  SysUtils,
  StrUtils,
  Variants,
  Generics.Collections,
  Janus.DataSet.Events,
  Janus.DataSet.Abstract,
  Janus.Session.Abstract,
  MetaDbDiff.mapping.classes;

type
 TDataSetBaseAdapter<M: class, constructor> = class(TDataSetAbstract<M>)
  private
  class var
    /// <summary> Source of row identities for cRowTokenField. Monotonic, and
    ///  never compared across entity types: a child copies the token out of
    ///  its master's own row, so both sides of every comparison
    ///  _IsOwnedByMasterRow makes were minted by the SAME instantiation of
    ///  this counter. Two adapters over the same entity - which is the REST
    ///  client's normal shape - therefore cannot hand out the same identity,
    ///  which is the only collision that would matter.
    ///
    ///  SINCE ISSUE #265 A SECOND INSTANTIATION WRITES INTO THAT COLUMN, and
    ///  the invariant above survives only because of how. A master row read
    ///  from the store has no identity, and _EnsureMasterRowToken gives it one
    ///  from the CHILD's DoBeforeInsert - that is, with Self being the child
    ///  adapter, whose counter is a different one. Taking the value from there
    ///  hands the master a number out of the child entity's sequence, and a
    ///  later master row eventually receives the same number: measured at
    ///  [live M1=27] [minted M2=125] [live M3=28], and issue #261 comes back
    ///  as a collision. The value is therefore taken through _MintRowToken,
    ///  which is VIRTUAL, so the call lands on the master's own instantiation
    ///  and the column keeps receiving values from one sequence only.
    ///
    ///  THAT RESTS ON AN ASSUMPTION THE COMPILER DOES NOT CHECK. The master is
    ///  reached through a cast that lies - TDataSetBaseAdapter<M of the master>
    ///  held as TDataSetBaseAdapter<M of the child> - so the virtual call is
    ///  dispatched through a VMT slot index resolved against the CHILD's
    ///  instantiation and executed against the MASTER's. It works because both
    ///  instantiations are generated from the same declaration and so lay out
    ///  the same slots; nothing enforces that, and inserting a virtual method
    ///  in the middle of a section moves every slot after it. Pinned
    ///  behaviourally by Test.Janus.AutoInc.Distribution
    ///  .MintedMasterIdentity_ComesFromTheMasterOwnSequence, which is the only
    ///  thing standing between that assumption and silence. </summary>
    FRowTokenSeq: Integer;
  private
    FOrmDataSetEvents: TDataSetLocal;
    FPageSize: Integer;
    procedure _ExecuteOneToOne(AObject: M; AProperty: TRttiProperty;
      ADatasetBase: TDataSetBaseAdapter<M>);
    procedure _ExecuteOneToMany(AObject: M; AProperty: TRttiProperty;
      ADatasetBase: TDataSetBaseAdapter<M>; ARttiType: TRttiType);
    procedure _GetMasterValues;
    function _FindEvents(AEventName: String): Boolean;
    function _GetAutoNextPacket: Boolean;
    procedure _SetAutoNextPacket(const Value: Boolean);
    procedure _ValideFieldEvents(const AFieldEvents: TFieldEventsMappingList);
    function _DetachMasterLink(const ADataSet: TDataSet): TObject;
    procedure _RestoreMasterLink(const ADataSet: TDataSet; const ASource: TObject);
    function _IsPendingInsertRow(const ADataSet: TDataSet): Boolean;
    procedure _StampRowTokens;
    function _IsOwnedByMasterRow(const AChild: TDataSet;
      const AMasterToken: Integer): Boolean;
    function _MasterRowToken(const AMaster: TDataSet): Integer;
    function _AnyDetailRowOpen(
      const AAdapter: TDataSetBaseAdapter<M>): Boolean;
    procedure _RecurseOverChildRows(
      const AChildAdapter: TDataSetBaseAdapter<M>;
      const AMasterToken: Integer);
    procedure _AutoIncToChildRows(const AMaster, AChild: TDataSet;
      const AAssociation: TAssociationMapping);
    function _AutoIncKeyIsGenerated(
      const AAssociation: TAssociationMapping): Boolean;
    function _HasPendingRows(const AAdapter: TDataSetBaseAdapter<M>): Boolean;
    function _PendingChilds: TArray<TDataSet>;
    procedure _ForeignKeyFieldPairs(
      const AChildAdapter: TDataSetBaseAdapter<M>;
      const AProperty: TRttiProperty;
      const AMasterFields, AChildFields: TList<TField>);
    function _ChildRowIsUnderTheCurrentMasterRow(
      const AMasterFields, AChildFields: TList<TField>): Boolean;
    function _FieldValuesMatch(const AMasterField,
      AChildField: TField): Boolean;
  protected
    FBeforeScrollPendingChilds: TBeforeScrollPendingChildsEvent;
    FDataSetEvents: TDataSetEvents;
    FOwnerMasterObject: TObject;
    FCurrentInternal: M;
    FMasterObject: TDictionary<String, TDataSetBaseAdapter<M>>;
    FLookupsField: TList<TDataSetBaseAdapter<M>>;
    FInternalIndex: Integer;
    FAutoNextPacket: Boolean;
    FCheckedFieldEvents: Boolean;
    FLastPKValue: String;
    FProxiesInjectedForCurrentRow: Boolean;
    /// <summary> Greater than zero while THIS adapter's cursor is being walked
    ///  by a READ that only materialises objects, and therefore must cost
    ///  nothing. Read by TDataSetAdapter<M>.DoAfterScroll, which is the only
    ///  family whose OpenDataSetChilds really re-queries - issue #276.
    ///
    ///  RAISED BY BOTH HALVES OF THE READ WALK - _ExecuteOneToMany and
    ///  _ExecuteOneToOne. FillMastersClass routes an association to one or the
    ///  other by multiplicity and both walk this cursor the same way; the
    ///  amount of exposure differs, not the need for the guard.
    ///
    ///  WHY A COUNTER AND NOT A BOOLEAN: both of those recurse into the
    ///  children of what they read, and a hierarchy may bring the same adapter
    ///  back into a walk that is already running. A Boolean cleared by the
    ///  inner walk would leave the outer one unprotected for the rest of its
    ///  rows, which is precisely the shape of the defect being repaired.
    ///
    ///  WHY NOT DisableDataSetEvents, WHICH IS WHAT _HasPendingRows AND
    ///  SetAutoIncValueChilds USE FOR THE SAME TRAP: muting takes the whole
    ///  event set down, including the paging in DoAfterScroll (NextPacket) and
    ///  the consumer's own AfterScroll. This suppresses ONE call and leaves
    ///  every other effect of the scroll exactly where it was. </summary>
    FChildReopenSuppressed: Integer;
    /// <summary> How many master rows the cascade that is running RIGHT NOW is
    ///  going to walk at THIS level, established by whoever starts the walk and
    ///  read by _IsOwnedByMasterRow, which is its only reader - issue #261.
    ///
    ///  ZERO MEANS NOBODY ESTABLISHED IT, and zero reads as "no ambiguity", so
    ///  every entry point that does not set it leaves the historical behaviour
    ///  exactly where it was. That is deliberate: this field narrows a decision
    ///  in one shape and must not silently change the others.
    ///
    ///  WHY IT IS CAPTURED AND NOT COUNTED ON DEMAND, which is the trap anyone
    ///  reworking this will walk into first. The obvious reading of "how many
    ///  masters are pending" is to count the master rows carrying
    ///  Integer(dsInsert) at the moment the question is asked. It cannot be
    ///  done there: ApplyInserter runs with the master dataset FILTERED to
    ///  exactly those rows and clears each row's marker as it finishes with it,
    ///  so the count DECAYS - the first master would see P and the last one
    ///  would see 1. The last master would then be the one master that still
    ///  claims the unparented row, which is precisely the last-one-wins the
    ///  issue is about, restored under a new name. The number therefore has to
    ///  be taken ONCE, before the loop starts consuming it.
    ///
    ///  SET BY TWO KINDS OF CALLER, and the two agree on the meaning:
    ///  - the ApplyInserter of each family, from the filtered RecordCount, for
    ///    the top of a cascade. THERE ARE THREE of those and each was measured
    ///    on its own - see the mutation table in the header of
    ///    Test.Janus.AutoInc.Distribution;
    ///  - _RecurseOverChildRows, from the number of rows it is about to ride,
    ///    for every level below the top, which is the ONLY place that number
    ///    exists once the top-level loop is over.
    ///
    ///  ONE SIDE SAVES AND RESTORES AND THE OTHER RESETS TO ZERO, and the
    ///  asymmetry is deliberate rather than an oversight. _RecurseOverChildRows
    ///  writes into ANOTHER adapter's field and must therefore put back what it
    ///  found; ApplyInserter writes into its own and is never reached from
    ///  inside a cascade - SetAutoIncValueChilds does not call it - so there is
    ///  nothing to put back and zero, "not established", is the honest value.
    ///
    ///  READ THROUGH A CAST THAT LIES, exactly like FOrmDataSet and
    ///  FMasterObject a few lines away in _RecurseOverChildRows: the child
    ///  adapter is held as TDataSetBaseAdapter<M of the master>. Field access
    ///  resolves an OFFSET against the declared instantiation and executes
    ///  against the real one, which works because both are generated from this
    ///  declaration and lay out the same fields. That is the field-level twin
    ///  of the VMT assumption the comment on FRowTokenSeq spells out.
    ///
    ///  DECLARED AT THE END OF THE FIELD BLOCK for the reason the comment on
    ///  _MintRowToken gives for methods, weakened to what is actually true of
    ///  data: a field inserted in the MIDDLE moves the offset of every field
    ///  after it, and a descendant compiled earlier would read the wrong ones.
    ///  Adding one at the end moves nothing that already exists here, and it
    ///  moves no VMT slot at all - a field is not a virtual method. A
    ///  descendant still has to be recompiled, as it does for any field
    ///  addition. </summary>
    FCascadeMasterRows: Integer;
    function _GetCurrentPKAsString: String;
    procedure DoBeforeScroll(DataSet: TDataSet); virtual;
    procedure DoBeforeScrollPendingChilds; virtual;
    procedure DoAfterScroll(DataSet: TDataSet); virtual;
    procedure DoBeforeOpen(DataSet: TDataSet); virtual;
    procedure DoAfterOpen(DataSet: TDataSet); virtual;
    procedure DoBeforeClose(DataSet: TDataSet); virtual;
    procedure DoAfterClose(DataSet: TDataSet); virtual;
    procedure DoBeforeDelete(DataSet: TDataSet); virtual;
    procedure DoAfterDelete(DataSet: TDataSet); virtual;
    procedure DoBeforeInsert(DataSet: TDataSet); virtual;
    procedure DoAfterInsert(DataSet: TDataSet); virtual;
    procedure DoBeforeEdit(DataSet: TDataSet); virtual;
    procedure DoAfterEdit(DataSet: TDataSet); virtual;
    procedure DoBeforePost(DataSet: TDataSet); virtual;
    procedure DoAfterPost(DataSet: TDataSet); virtual;
    procedure DoBeforeCancel(DataSet: TDataSet); virtual;
    procedure DoAfterCancel(DataSet: TDataSet); virtual;
    procedure DoNewRecord(DataSet: TDataSet); virtual;
    procedure _EnsureMasterRowToken(
      const AMaster: TDataSetBaseAdapter<M>);
    procedure GetDataSetEvents; virtual;
    procedure SetDataSetEvents; virtual;
    procedure DisableDataSetEvents; virtual;
    procedure EnableDataSetEvents; virtual;
    procedure Insert; virtual;
    procedure Append; virtual;
    procedure Post; virtual;
    procedure Edit; virtual;
    procedure Delete; virtual;
    procedure Close; virtual;
    procedure EnsureOpen;
    procedure Cancel; virtual;
    procedure SetAutoIncValueChilds; virtual;
    procedure SetMasterObject(const AValue: TObject); virtual;
    procedure FillMastersClass(const ADatasetBase: TDataSetBaseAdapter<M>; AObject: M); virtual;
    function IsAssociationUpdateCascade(ADataSetChild: TDataSetBaseAdapter<M>;
      AColumnsNameRef: String): Boolean; virtual;
    /// <summary> DECLARADO NO FIM DA SECAO DE PROPOSITO. Acrescentar um metodo
    ///  virtual no MEIO de uma secao desloca o slot de VMT de todos os
    ///  virtuais seguintes, o que e inocuo numa recompilacao total e nao e
    ///  inocuo para um descendente compilado antes. Alem disso este metodo e
    ///  chamado por despacho virtual atraves de um cast entre instanciacoes -
    ///  ver o comentario de FRowTokenSeq - de modo que a estabilidade do slot
    ///  e exatamente a premissa de que ele depende. </summary>
    function _MintRowToken: Integer; virtual;
  public
    constructor Create(ADataSet: TDataSet; APageSize: Integer;
      AMasterObject: TObject); overload; override;
    destructor Destroy; override;
    procedure RefreshRecordInternal(const AObject: TObject); virtual;
    procedure RefreshRecord; virtual;
    procedure RefreshRecordWhere(const AWhere: String); virtual;
    procedure NextPacket; overload; virtual; abstract;
    procedure Save(AObject: M); virtual;
    procedure CancelUpdates; virtual;
    procedure AddLookupField(const AFieldName: String;
                             const AKeyFields: String;
                             const ALookupDataSet: TObject;
                             const ALookupKeyFields: String;
                             const ALookupResultField: String;
                             const ADisplayLabel: String = '');
    function Current: M;
    // ObjectSet
    function Find: TObjectList<M>; overload; virtual;
    function Find(const AID: Integer): M; overload; virtual;
    function Find(const AID: String): M; overload; virtual;
    function FindWhere(const AWhere: String; const AOrderBy: String = ''): TObjectList<M>; virtual;
    // Property
    property AutoNextPacket: Boolean read _GetAutoNextPacket write _SetAutoNextPacket;
    /// <summary> Says what must happen to child rows that are typed in and not
    ///  yet saved when the master is about to scroll. LEAVE IT UNASSIGNED AND
    ///  NOTHING CHANGES: DoBeforeScrollPendingChilds returns on its first line,
    ///  so not one child dataset is even inspected and the historical discard
    ///  stands. Assign it and the discard stops being a side effect of the
    ///  re-query inside TDataSetAdapter<M>.DoAfterScroll and becomes something
    ///  somebody chose - see TPendingChildsAction.
    ///  Reached from a consumer as IContainerDataSet<M>.This.
    ///  FIRED ONLY BY THE TDataSetAdapter<M> FAMILY (TFDMemTableAdapter,
    ///  TClientDataSetAdapter). TRESTDataSetAdapter<M> inherits the property
    ///  and never fires it, because its own OpenDataSetChilds has an empty body
    ///  and therefore discards nothing - there is no loss there to decide
    ///  about. Measured by Test.Janus.Scroll.PendingChilds. </summary>
    property OnBeforeScrollPendingChilds: TBeforeScrollPendingChildsEvent
      read FBeforeScrollPendingChilds write FBeforeScrollPendingChilds;
  end;

const
  /// <summary> O PREFIXO DE ClassName DE TODA INSTANCIACAO DO ADAPTER BASE.
  ///  ClassName de uma instanciacao generica carrega o nome do template
  ///  seguido de `&lt;`, e todo adapter de dataset desce de
  ///  TDataSetBaseAdapter&lt;M&gt; - TDataSetAdapter, TFDMemTableAdapter,
  ///  TClientDataSetAdapter, TRESTDataSetAdapter, TRESTFDMemTableAdapter e
  ///  TRESTClientDataSetAdapter - de modo que subir por ClassParent chega
  ///  sempre aqui.
  ///  O `&lt;` FINAL E CARGA, NAO ENFEITE: e a unica coisa que separa
  ///  `instanciacao deste template` de `qualquer classe cujo nome comece
  ///  assim`. Encurtar a string passa despercebido pelo compilador, entao o
  ///  CONTEUDO e ancorado - e nao so a direcao de rename - por
  ///  Test.Janus.Manager.AddAdapter
  ///  .Recognition_TheAncestorNameIsWhatTheGuardHangsOn, que deriva o valor
  ///  esperado do nome que o Delphi realmente emite e o compara com ESTA
  ///  constante. Por isso ela e declarada na interface: para o teste ler a de
  ///  Source em vez de uma copia sua.
  ///  UMA HEURISTICA DE NOME, E DECLARADA COMO TAL. Nao existe ancestral
  ///  nao-generico nem interface que ambas as instanciacoes compartilhem, e
  ///  criar um mexe em declaracao publica - decisao do dono, nao do
  ///  implementador (issue #255). </summary>
  cBaseAdapterPrefix = 'TDataSetBaseAdapter<';

/// <summary> Responde se AValue e um adapter de dataset de QUALQUER
///  instanciacao - a pergunta que o sistema de tipos do Delphi nao sabe fazer,
///  porque TDataSetBaseAdapter&lt;A&gt; e TDataSetBaseAdapter&lt;B&gt; sao
///  tipos sem parentesco e `is` recusaria justamente o master legitimo.
///  DECLARADA NA INTERFACE CONTRA A VONTADE, e a razao vale registrar:
///  SetMasterObject e metodo de tipo parametrizado declarado na interface, e o
///  compilador recusa (E2506) que um metodo assim use simbolo local da
///  implementacao. Nao ha, portanto, como deixa-la privada sem transforma-la
///  em membro de TDataSetBaseAdapter&lt;M&gt;, o que alargaria a declaracao
///  publica da classe - exatamente o que a issue #255 reserva ao dono. Uma
///  funcao solta e a alternativa mais estreita.
///  Percorre a cadeia de ancestrais porque o objeto quase nunca e um
///  TDataSetBaseAdapter&lt;M&gt; puro: o que o manager constroi e
///  TFDMemTableAdapter ou TClientDataSetAdapter, dois niveis abaixo. </summary>
function _IsBaseAdapterInstance(const AValue: TObject): Boolean;

implementation

uses
  Janus.Bind,
  Janus.DataSet.Fields,
  Janus.DataSet.Consts,
  Janus.Objects.Helper,
  Janus.Objects.Utils,
  Janus.RTTI.Helper,
  MetaDbDiff.mapping.explorer,
  MetaDbDiff.mapping.attributes,
  MetaDbDiff.types.mapping;

const
  /// <summary> The value cRowTokenField and cOwnerTokenField carry when the
  ///  framework never saw the row created - a row appended while the adapter's
  ///  events were unhooked, or read back from a store that has no such column.
  ///  It is the zero a TField answers for a NULL integer, so it costs no
  ///  default expression and no migration.
  ///  DECLARED HERE, in the implementation, and not beside the two column
  ///  names: nothing outside this unit needs it, and the public surface of a
  ///  framework the community consumes is not the place to put a private
  ///  convention. </summary>
  cNoRowToken = 0;

function _IsBaseAdapterInstance(const AValue: TObject): Boolean;
var
  LClass: TClass;
begin
  Result := False;
  if AValue = nil then
    Exit;
  LClass := AValue.ClassType;
  while LClass <> nil do
  begin
    if Copy(LClass.ClassName, 1, Length(cBaseAdapterPrefix)) = cBaseAdapterPrefix then
      Exit(True);
    LClass := LClass.ClassParent;
  end;
end;

{ TDataSetBaseAdapter<M> }

constructor TDataSetBaseAdapter<M>.Create(ADataSet: TDataSet;
  APageSize: Integer; AMasterObject: TObject);
begin
  FOrmDataSet := ADataSet;
  FPageSize := APageSize;
  FLastPKValue := '';
  FProxiesInjectedForCurrentRow := False;
  FBeforeScrollPendingChilds := nil;
  FOrmDataSetEvents := TDataSetLocal.Create(nil);
  FMasterObject := TDictionary<String, TDataSetBaseAdapter<M>>.Create;
  FLookupsField := TList<TDataSetBaseAdapter<M>>.Create;
  FCurrentInternal := M.Create;
  Bind.SetInternalInitFieldDefsObjectClass(ADataSet, FCurrentInternal);
  Bind.SetDataDictionary(ADataSet, FCurrentInternal);
  FDataSetEvents := TDataSetEvents.Create;
  FAutoNextPacket := True;
  // Variavel que identifica o campo que armazena o estado do registro.
  FInternalIndex := 0;
  FCheckedFieldEvents := False;
  if AMasterObject <> nil then
    SetMasterObject(AMasterObject);
  inherited Create(ADataSet, APageSize, AMasterObject);
end;

/// <summary> IT DOES NOT UNREGISTER Self FROM ITS OWNER, and that is a known
///  exposure rather than an oversight. FOwnerMasterObject is nilled here, but
///  the owner's FMasterObject keeps the entry SetMasterObject added, so freeing
///  a child adapter while its master is still alive leaves the master holding a
///  pointer to freed memory - which _AnyDetailRowOpen and SetAutoIncValueChilds
///  both dereference, and which no `= nil` test can catch, because a freed
///  object is not nil.
///  WHY THE OBVIOUS FIX IS NOT MADE HERE. Calling SetMasterObject(nil) would
///  remove the entry, but it would do it by WRITING into the owner's
///  dictionary, and there is no order that guarantees the owner is still there
///  to be written to: TManagerDataSet holds its adapters in a TObjectDictionary
///  created with doOwnsValues, so Free releases them in hash order and a master
///  can go first. That trades a stale read for a stale write, which is worse.
///  The exposure is older than issue #265 - RemoveAdapter has always been able
///  to free one adapter out of a live tree - and is widened, not created, by
///  _AnyDetailRowOpen walking every edge instead of the CascadeAutoInc ones.
///  NO FIXTURE PINS IT: a test for it would have to assert on freed memory,
///  which is undefined behaviour, so it is written down instead. </summary>
destructor TDataSetBaseAdapter<M>.Destroy;
begin
  FOrmDataSet := nil;
  FOwnerMasterObject := nil;
  FDataSetEvents.Free;
  FOrmDataSetEvents.Free;
  FCurrentInternal.Free;
  FMasterObject.Clear;
  FMasterObject.Free;
  FLookupsField.Clear;
  FLookupsField.Free;
  inherited;
end;

procedure TDataSetBaseAdapter<M>.Save(AObject: M);
begin
  // Aualiza o DataSet com os dados a variavel interna
  FOrmDataSet.Edit;
  Bind.SetPropertyToField(AObject, FOrmDataSet);
  FOrmDataSet.Post;
end;

procedure TDataSetBaseAdapter<M>.Cancel;
begin
  FOrmDataSet.Cancel;
end;

procedure TDataSetBaseAdapter<M>.CancelUpdates;
begin
  FSession.ModifiedFields.Items[M.ClassName].Clear;
end;

procedure TDataSetBaseAdapter<M>.Close;
begin
  FOrmDataSet.Close;
end;

/// <summary> Gives the adapter back the one thing it could not do: come back
///  from a closed dataset. It is called at the head of every Open*Internal of
///  the four dataset adapters, AHEAD of the EmptyDataSet that opens them -
///  EmptyDataSet goes through CheckBrowseMode, and on a closed dataset that
///  raises "Cannot perform this operation on a closed dataset".
///  A BARE Open IS THE WHOLE FIX, and it was measured to be enough on each of
///  the four separately - Test.Janus.Reopen.Lazy has one Reopen_* per adapter
///  and infers nothing from one family to another.
///  WHAT A GENUINE CLOSE COSTS IS NOT A RESOURCE THE ADAPTER HAS TO REBUILD.
///  The runtime TFields survive it because TFieldSingleton.AddField names them
///  and binds them to the dataset, which makes them persistent, so
///  DestroyFields - which only clears the automatic ones - leaves them alone.
///  Measured on both the FDMemTable and the ClientDataSet family, and it is the
///  SAME TField objects before the close, after it and after the reopen:
///  Test.Janus.Reopen.Lazy
///  .Fields_TheSameObjectsSurviveCloseAndReopen_BothFamilies.
///  WHAT THE REOPEN DOES NOT BRING BACK IS THE ROWS, and the two families do
///  not agree: a reopened TFDMemTable comes back with 0 records, a reopened
///  TClientDataSet comes back with the records it had - measured by
///  Test.Janus.Reopen.Lazy
///  .Rows_ABareReopenBringsBackNothingOnFDMemTableAndEverythingOnClientDataSet.
///  It costs the callers nothing because every one of them clears the dataset
///  on the very next line, but it is the reason this is not a way to preserve
///  data across a close.
///  HOW EACH ADAPTER USED TO REPORT THE FAILED REOPEN IS NOT PINNED ANYWHERE,
///  because with this method in place none of them fails. What can be read
///  without running anything is that TFDMemTableAdapter and TClientDataSetAdapter
///  wrap their whole open block in `on E: Exception do raise
///  Exception.Create(E.Message)` while the two REST adapters have no except
///  block at all; the only runtime datum that survives is #246's, on
///  TFDMemTableAdapter, where the failure arrived already re-wrapped as a plain
///  Exception.
///  Not virtual on purpose: no family was found to need anything else.
///  Pinned by Test.Janus.Reopen.Lazy - every Reopen_* test there fails without
///  this method. </summary>
procedure TDataSetBaseAdapter<M>.EnsureOpen;
begin
  if FOrmDataSet = nil then
    Exit;
  if FOrmDataSet.Active then
    Exit;
  FOrmDataSet.Open;
end;

procedure TDataSetBaseAdapter<M>.AddLookupField(const AFieldName: String;
                                                const AKeyFields: String;
                                                const ALookupDataSet: TObject;
                                                const ALookupKeyFields: String;
                                                const ALookupResultField: String;
                                                const ADisplayLabel: String);
var
  LColumn: TColumnMapping;
  LColumns: TColumnMappingList;
begin
  // Guarda o datasetlookup em uma lista para controle interno
  FLookupsField.Add(TDataSetBaseAdapter<M>(ALookupDataSet));
  LColumns := TMappingExplorer.GetMappingColumn(FLookupsField.Last.FCurrentInternal.ClassType);
  if LColumns = nil then
    Exit;

  for LColumn in LColumns do
  begin
    if LColumn.ColumnName <> ALookupResultField then
      Continue;

    DisableDataSetEvents;
    FOrmDataSet.Close;
    try
      TFieldSingleton.GetInstance
                     .AddLookupField(AFieldName,
                                     FOrmDataSet,
                                     AKeyFields,
                                     FLookupsField.Last.FOrmDataSet,
                                     ALookupKeyFields,
                                     ALookupResultField,
                                     LColumn.FieldType,
                                     LColumn.Size,
                                     ADisplayLabel);
    finally
      FOrmDataSet.Open;
      EnableDataSetEvents;
    end;
    // Abre a tabela do TLookupField
    FLookupsField.Last.OpenSQLInternal('');
  end;
end;

procedure TDataSetBaseAdapter<M>.Append;
begin
  FOrmDataSet.Append;
end;

procedure TDataSetBaseAdapter<M>.EnableDataSetEvents;
var
  LClassType: TRttiType;
  LProperty: TRttiProperty;
  LPropInfo: PPropInfo;
  LMethod: TMethod;
  LMethodNil: TMethod;
begin
  LClassType := RttiSingleton.GetRttiType(FOrmDataSet.ClassType);
  for LProperty in LClassType.GetProperties do
  begin
    if LProperty.PropertyType.TypeKind <> tkMethod then
      Continue;
    if not _FindEvents(LProperty.Name) then
      Continue;
    LPropInfo := GetPropInfo(FOrmDataSet, LProperty.Name);
    if LPropInfo = nil then
      Continue;
    LMethod := GetMethodProp(FOrmDataSetEvents, LPropInfo);
    if not Assigned(LMethod.Code) then
      Continue;
    LMethodNil.Code := nil;
    SetMethodProp(FOrmDataSet, LPropInfo, LMethod);
    SetMethodProp(FOrmDataSetEvents, LPropInfo, LMethodNil);
  end;
end;

procedure TDataSetBaseAdapter<M>.FillMastersClass(
  const ADatasetBase: TDataSetBaseAdapter<M>; AObject: M);
var
  LRttiType: TRttiType;
  LProperty: TRttiProperty;
  LAssociation: Association;
begin
  LRttiType := RttiSingleton.GetRttiType(AObject.ClassType);
  for LProperty in LRttiType.GetProperties do
  begin
    for LAssociation in LProperty.GetAssociation do
    begin
      if LAssociation = nil then
        Continue;
      if LAssociation.Multiplicity in [TMultiplicity.OneToOne,
                                       TMultiplicity.ManyToOne] then
        _ExecuteOneToOne(AObject, LProperty, ADatasetBase)
      else
      if LAssociation.Multiplicity in [TMultiplicity.OneToMany,
                                       TMultiplicity.ManyToMany] then
        _ExecuteOneToMany(AObject, LProperty, ADatasetBase, LRttiType);
    end;
  end;
end;

procedure TDataSetBaseAdapter<M>._ExecuteOneToOne(AObject: M;
  AProperty: TRttiProperty; ADatasetBase: TDataSetBaseAdapter<M>);
var
  LBookMark: TBookmark;
  LValue: TValue;
  LObject: TObject;
  LDataSetChild: TDataSetBaseAdapter<M>;
begin
  if ADatasetBase.FCurrentInternal.ClassType <>
     AProperty.PropertyType.AsInstance.MetaclassType then
    Exit;
  LValue := AProperty.GetNullableValue(TObject(AObject));
  if not LValue.IsObject then
    Exit;
  LObject := LValue.AsObject;
  // ISSUE #296 - AN UNFILLED ASSOCIATION IS "NO DATA", NOT A CRASH.
  // The guard above does NOT cover this one and cannot: TValue.IsObject
  // classifies the KIND of the value, and a nil class reference is still of
  // object kind, so it answers True. What got through was a nil TObject, and
  // it was handed on TWICE - to Bind.SetFieldToProperty, which opens with
  // TMappingExplorer.GetMappingColumn(AObject.ClassType), and to the
  // FillMastersClass recursion at the end, which opens the same way. The first
  // of the two dereferenced address zero and a plain read of .Current raised
  // EAccessViolation - not an exception a consumer's try..except can name, on
  // a path ApplyInserter takes by itself.
  //
  // NOT A HYPOTHETICAL STATE: TAsymTreeOneRoot ships in this repository with
  // its OneToOne property left nil on purpose and its model header says so. A
  // consumer that declares a single-object association and does not construct
  // it in the constructor - the Delphi default - is in exactly that state.
  //
  // LEAVING IN SILENCE IS THE DECISION, and the other two candidates were
  // refused for named reasons. INSTANTIATING the object here changes
  // OWNERSHIP: nothing in this walk would be responsible for freeing what it
  // created. RAISING A NAMED EXCEPTION would break the shape the shipped model
  // hands over deliberately. An association nobody filled in is "no data", and
  // the consumer gets back the branch it had - nil.
  //
  // THE SIBLING IS _ExecuteOneToMany AND IT IS NOT REPAIRED BY THIS. It has a
  // nil hazard of its own at a different line - LObjectList.MethodCall('Add',
  // ...) over a list property no constructor created - reached only for a
  // child row that survives the foreign-key filter, and it is not what issue
  // #296 names. Measured, not assumed: on commit 221899a, with the guard below
  // removed and a throwaway clause added over a TAsymTreeRoot whose `mids` was
  // set to nil, ONE run raised both - the walk here at module offset 89F831 and
  // the sibling at 7FB9B9. Two offsets in a single build, so they are two code
  // sites and not one site seen twice. Recorded so the next reader does not
  // take this guard for cover it does not give.
  //
  // NO CLAUSE IN THE SUITE DRIVES THAT SIBLING HAZARD, measured from the other
  // side on commit 219ebcd: adding the equivalent nil guard to
  // _ExecuteOneToMany with everything else intact turned NOTHING red - 567
  // found, 0 failures, 0 errors, exactly as without it. Every model
  // Janus.Tests.Units compiles builds its list in its own constructor.
  //
  // THAT SENTENCE IS ABOUT ONE PROJECT AND IT DOES NOT GENERALISE TO THE
  // REPOSITORY. TLazyBranchRoot has no constructor at all - both of its
  // OneToMany properties are Lazy<TObjectList<...>> and the list is
  // materialised on first read by Lazy<T>.GetValue through CreateDefaultValue,
  // not by the owner. It is compiled ONLY by Janus.Tests.RESTHorse, so it is
  // outside the run the numbers above come from, and the conclusion survives
  // it either way: materialised is not nil, so that model's list is never nil
  // when the walk reads it.
  //
  // ONLY TWO PROJECTS COMPILE THIS FILE - Janus.Tests.Units and
  // Janus.Tests.RESTfulDriver - AND A PER-PROJECT NUMBER QUOTED ABOUT IT IS
  // EMPTY UNLESS IT COMES FROM ONE OF THEM. Measured, because a green from a
  // project that never reads the source is indistinguishable from a green that
  // means something: a hard {$MESSAGE ERROR} placed in this method fails the
  // build of those two and of NO other - RESTHorse, LiveBindings, RESTMARS,
  // RESTWiRL and RESTOracle all build and run clean straight through it.
  // RESTHorse is the trap, because it is the project TLazyBranchRoot lives in:
  // it returns the same 92 with this guard, without it, or with this file made
  // impossible to compile.
  //
  // THE SECOND MEASUREMENT THEREFORE COMES FROM Janus.Tests.RESTfulDriver -
  // the sibling guard added there reads 62 found, 0 failures, 0 errors, that
  // project's basal exactly, with dcc32 echoing a marker from the added line
  // itself so the run is known to have compiled it.
  //
  // AND THE `IsObject` GUARD ABOVE IS ITSELF UNCOVERED. Deleting it outright
  // leaves the project at 567 found, 0 failures, 0 errors - nothing in the
  // suite holds it up. It is PRE-EXISTING and this change neither measures it
  // nor claims it earns its place; what is measured is only that it cannot
  // catch a nil, which is why the exit below had to be added rather than the
  // guard above widened.
  //
  // THE POSITION OF THE EXIT IS NOT PINNED BY ANY CLAUSE EITHER, and the
  // measurement is worse than that sentence sounds. Moved to just after the
  // First - so past the bookmark, past the scroll, and skipping the restore
  // and the FreeBookmark in the inner `finally` - the project still reads 567
  // found, 0 failures, 0 errors. That placement LEAKS A BOOKMARK and leaves
  // the child cursor parked on its first row, and nothing in the suite
  // notices, because the #276 suppression makes the movement unobservable.
  // Where it sits now is strictly better - it does no work it will throw away
  // and takes no bookmark it will not give back - and nothing defends it.
  // Declared as a surviving mutation rather than repaired with a clause:
  // pinning it would mean asserting on cursor state no consumer can see.
  //
  // Measured by Test.Janus.OneToOne.NilAssociation.
  if LObject = nil then
    Exit;
  LBookMark := ADatasetBase.FOrmDataSet.Bookmark;
  // ISSUE #276 - SAME DEFECT AS _ExecuteOneToMany, AND NOT THE SAME SIZE.
  // This walk moves the same child cursor for the same reason, so its First
  // fires the child's AfterScroll and re-opens - that is, empties - the
  // GRANDCHILDREN. What differs is the way out: the restore below runs BEFORE
  // BlockReadSize goes back to zero, so it happens in dsBlockRead and
  // TDataSetAdapter<M>.DoAfterScroll turns it away on its dsBrowse guard. Only
  // the First is exposed here, where _ExecuteOneToMany has two. The two
  // branches were measured one at a time and neither was inferred from the
  // other. Measured by
  // Test.Janus.Grandchild.Read.OneToOneTop_ReadingCurrentOnTheGrandparent...
  //
  // The recursion into the next level stays OUTSIDE the suppression: it walks
  // a DIFFERENT adapter's cursor, and that adapter raises its own.
  Inc(ADatasetBase.FChildReopenSuppressed);
  try
    ADatasetBase.FOrmDataSet.First;
    ADatasetBase.FOrmDataSet.BlockReadSize := MaxInt;
    try
      while not ADatasetBase.FOrmDataSet.Eof do
      begin
        // Popula o objeto M e o adiciona na lista e objetos com o registro do DataSet.
        Bind.SetFieldToProperty(ADatasetBase.FOrmDataSet, LObject);
        // Proximo registro
        ADatasetBase.FOrmDataSet.Next;
      end;
    finally
      ADatasetBase.FOrmDataSet.GotoBookmark(LBookMark);
      ADatasetBase.FOrmDataSet.FreeBookmark(LBookMark);
      ADatasetBase.FOrmDataSet.BlockReadSize := 0;
    end;
  finally
    Dec(ADatasetBase.FChildReopenSuppressed);
  end;
  // Populando em hierarquia de varios niveis
  for LDataSetChild in ADatasetBase.FMasterObject.Values do
    LDataSetChild.FillMastersClass(LDataSetChild, LObject);
end;

procedure TDataSetBaseAdapter<M>._ExecuteOneToMany(AObject: M;
  AProperty: TRttiProperty; ADatasetBase: TDataSetBaseAdapter<M>;
  ARttiType: TRttiType);
var
  LBookMark: TBookmark;
  LPropertyType: TRttiType;
  LObjectType: TObject;
  LObjectList: TObject;
  LDataSetChild: TDataSetBaseAdapter<M>;
  LDataSet: TDataSet;
  LMasterFields: TList<TField>;
  LChildFields: TList<TField>;
begin
  LPropertyType := AProperty.PropertyType;
  LPropertyType := AProperty.GetTypeValue(LPropertyType);
  if not LPropertyType.IsInstance then
    raise Exception
            .Create('Not in instance ' + LPropertyType.Parent.ClassName + ' - '
                                       + LPropertyType.Name);
  //
  if ADatasetBase.FCurrentInternal.ClassType <>
     LPropertyType.AsInstance.MetaclassType then
    Exit;
  LDataSet := ADatasetBase.FOrmDataSet;
  LBookMark := LDataSet.Bookmark;
  // ISSUE #276 - A READ MUST NOT DESTROY ROWS.
  // What follows walks the child's cursor from the first row to Eof and puts
  // it back, only to build objects. Every one of those moves fires the child's
  // own AfterScroll, and in the TDataSetAdapter<M> family that calls
  // OpenDataSetChilds, which re-opens the GRANDchild dataset from the database
  // - OpenSQLInternal starts with EmptyDataSet. So one read of the
  // grandparent's Current threw away every grandchild row the operator had
  // typed and not saved, with no exception and no trace.
  //
  // TWO of the moves below reach that, and only two: First, and the
  // GotoBookmark in the finally. The ones in between do not, because
  // BlockReadSize > 0 puts the dataset in dsBlockRead and DoAfterScroll asks
  // for dsBrowse before it re-opens anything. That is why the suppression has
  // to span the WHOLE block including the restore - protecting the First alone
  // leaves the bookmark restore destroying the same rows a moment later.
  //
  // NOT A CHANGE TO THE SCROLL CONTRACT. When the OPERATOR moves the master
  // the re-query still runs and still discards; that is the decision pinned by
  // Test.Janus.Scroll.PendingChilds. What separates the two is who moved the
  // cursor, not the state of the row - the master rows in that fixture's
  // premise are pending inserts exactly like the ones here, so a guard phrased
  // as "do not re-open under an unsaved master row" was measured and refused.
  //
  // THE SIBLING IS _ExecuteOneToOne, AND IT NEEDED LESS. It walks the same
  // cursor for the same reason and its First is exposed the same way, but its
  // bookmark restore runs while BlockReadSize is still MaxInt, so that one is
  // already turned away by the dsBrowse guard. Both are repaired; each was
  // measured on its own and neither was inferred from the other.
  //
  // Measured by Test.Janus.Grandchild.Read.
  //
  // ISSUE #295 - AND THE ROWS THIS CURSOR HOLDS ARE NOT ALL THIS MASTER'S.
  // What the suppression above buys is that the child dataset is NOT
  // re-consulted between one master row and the next. The price is that this
  // walk then runs over the SAME content on every pass: with two middle rows
  // and one leaf under each, every middle object came back carrying both
  // leaves, its own AND its sibling's. Nobody's list was right - before #276
  // every one of them was EMPTY, after it every one of them was WHOLE.
  //
  // So the list is filtered HERE, in memory, by the association's own foreign
  // key, instead of asking the store again. Asking again is what #276 removed,
  // and it removed it because the re-open DESTROYS the grandchildren.
  //
  // THE PAIRS ARE RESOLVED ONCE, BEFORE THE WALK, and the reason is COST and
  // nothing else. The pairs are TField references, which do not move while a
  // dataset stays open, so resolving them per row would re-walk the
  // association's RTTI attributes once per child row for an answer that cannot
  // have changed.
  // AN EARLIER VERSION OF THIS COMMENT GAVE A SECOND REASON AND IT WAS FALSE:
  // that LMaster.RecordCount had to be read before the walk started because
  // the walk moves that cursor. It does not. The walk moves LDataSet, the
  // CHILD's cursor; LMaster is the master's dataset and nothing in this method
  // touches it. Left recorded rather than quietly deleted, because a reason
  // that is not true is worse than no reason and the next reader deserves to
  // know which of the two this was.
  //
  // AN EMPTY PAIR LIST MEANS "NO QUESTION TO ASK" and every row is admitted -
  // no master adapter, no columns in common, or a master holding a single row.
  // That last one is not an optimisation, it is the same slack
  // _IsOwnedByMasterRow already grants on FCascadeMasterRows <= 1: with one
  // master row there is no ambiguity to resolve, and a child row that names no
  // parent - a pending insert still on the AutoInc placeholder, which is the
  // ordinary state of a typed row - must not be dropped on the floor. With TWO
  // it is refused by both, which is the answer the house already took for the
  // same question one layer down - see
  // UntokenisedRow_WithTwoPendingMasters_IsClaimedByNeither. A row given to
  // the wrong parent is invisible; a row given to nobody is not.
  LMasterFields := TList<TField>.Create;
  LChildFields := TList<TField>.Create;
  try
    _ForeignKeyFieldPairs(ADatasetBase, AProperty, LMasterFields, LChildFields);
    Inc(ADatasetBase.FChildReopenSuppressed);
    try
      LDataSet.First;
      LDataSet.BlockReadSize := MaxInt;
      try
        while not LDataSet.Eof do
        begin
          if not _ChildRowIsUnderTheCurrentMasterRow(LMasterFields,
                                                     LChildFields) then
          begin
            LDataSet.Next;
            Continue;
          end;
          LObjectType := LPropertyType.AsInstance.MetaclassType.Create;
          LObjectType.MethodCall('Create', []);
          // Popula o objeto M e o adiciona na lista e objetos com o registro do DataSet.
          Bind.SetFieldToProperty(LDataSet, LObjectType);

          LObjectList := AProperty.GetNullableValue(TObject(AObject)).AsObject;
          LObjectList.MethodCall('Add', [LObjectType]);
          // Populando em hierarquia de varios niveis
          for LDataSetChild in ADatasetBase.FMasterObject.Values do
            LDataSetChild.FillMastersClass(LDataSetChild, LObjectType);

          // Proximo registro
          LDataSet.Next;
        end;
      finally
        LDataSet.BlockReadSize := 0;
        LDataSet.GotoBookmark(LBookMark);
        LDataSet.FreeBookmark(LBookMark);
      end;
    finally
      Dec(ADatasetBase.FChildReopenSuppressed);
    end;
  finally
    LChildFields.Free;
    LMasterFields.Free;
  end;
end;

/// <summary> Os pares de TField que a associacao junta: a coluna da chave na
///  linha do MASTER sobre a qual a caminhada esta parada, e a coluna da chave
///  estrangeira na linha do FILHO - issue #295.
///
///  DEVOLVE LISTA VAZIA QUANDO NAO HA PERGUNTA A FAZER, e cada saida cedo e uma
///  pergunta diferente que nao tem resposta:
///  - sem adapter de master registrado nao existe "a linha do master";
///  - com o dataset do master fechado tambem nao;
///  - com UMA linha de master so nao ha ambiguidade nenhuma a resolver, e essa
///    e a folga que _IsOwnedByMasterRow ja concede em FCascadeMasterRows <= 1,
///    escrita aqui pelo mesmo motivo: um filho pendente cuja FK ainda e o
///    placeholder de AutoInc nao pode sumir da lista do unico pai possivel;
///  - coluna que nao existe num dos dois datasets nao compara nada, e o par e
///    simplesmente omitido - as outras colunas da chave composta continuam
///    valendo.
///
///  O DATASET DO MASTER E LIDO POR FOwnerMasterObject, e nao pelo objeto
///  AObject que a caminhada esta preenchendo, pela mesma razao que
///  _GetMasterValues e _AutoIncToChildRows fazem o mesmo: a associacao nomeia
///  COLUNAS, e colunas vivem no dataset. Ir pelo objeto obrigaria a resolver
///  nome de coluna para nome de propriedade, que e uma traducao a mais para
///  errar. O cast e o mesmo que aqueles dois metodos usam e esta coberto pela
///  checagem unica de SetMasterObject. </summary>
procedure TDataSetBaseAdapter<M>._ForeignKeyFieldPairs(
  const AChildAdapter: TDataSetBaseAdapter<M>;
  const AProperty: TRttiProperty;
  const AMasterFields, AChildFields: TList<TField>);
var
  LAssociation: Association;
  LMaster: TDataSet;
  LChild: TDataSet;
  LMasterField: TField;
  LChildField: TField;
  LFor: Integer;
begin
  if AChildAdapter.FOwnerMasterObject = nil then
    Exit;
  LMaster := TDataSetBaseAdapter<M>(AChildAdapter.FOwnerMasterObject).FOrmDataSet;
  if LMaster = nil then
    Exit;
  if not LMaster.Active then
    Exit;
  if LMaster.RecordCount <= 1 then
    Exit;
  LChild := AChildAdapter.FOrmDataSet;
  if LChild = nil then
    Exit;
  for LAssociation in AProperty.GetAssociation do
  begin
    if LAssociation = nil then
      Continue;
    for LFor := 0 to Length(LAssociation.ColumnsName) -1 do
    begin
      if LFor > High(LAssociation.ColumnsNameRef) then
        Break;
      LMasterField := LMaster.FindField(LAssociation.ColumnsName[LFor]);
      LChildField := LChild.FindField(LAssociation.ColumnsNameRef[LFor]);
      if (LMasterField = nil) or (LChildField = nil) then
        Continue;
      AMasterFields.Add(LMasterField);
      AChildFields.Add(LChildField);
    end;
  end;
end;

/// <summary> Se a linha corrente do dataset filho e filha da linha corrente do
///  dataset master - issue #295. Sem par nenhum responde True: ver
///  _ForeignKeyFieldPairs, que e quem decide se ha pergunta.
///
///  TODAS as colunas da chave tem de casar: uma chave composta so identifica
///  uma linha inteira. Medido por
///  CompositeKey_EveryColumnOfTheKeyDecidesWhichRowsTheMasterCarries. </summary>
function TDataSetBaseAdapter<M>._ChildRowIsUnderTheCurrentMasterRow(
  const AMasterFields, AChildFields: TList<TField>): Boolean;
var
  LFor: Integer;
begin
  Result := True;
  for LFor := 0 to AMasterFields.Count -1 do
    if not _FieldValuesMatch(AMasterFields[LFor], AChildFields[LFor]) then
      Exit(False);
end;

/// <summary> Se uma coluna da chave casa dos dois lados - issue #295.
///
///  NULO DE QUALQUER DOS LADOS RESPONDE False, e o que essa clausula DECIDE
///  sozinha e menos do que ela parece dizer - medido, e nao suposto. Nulo do
///  lado do filho contra um master COM chave ja e recusado pela comparacao de
///  valor, porque '' nao e '11', de modo que apagar a clausula nao muda nada
///  ali. O unico caso que ela decide e NULO CONTRA NULO: duas linhas de master
///  que nao carregam chave nenhuma nao sao dois candidatos, sao ZERO
///  candidatos, e le-las como iguais faria as duas reivindicarem o mesmo filho
///  - o defeito desta issue reproduzido pelo conserto dela. Medido por
///  Test.Janus.Grandchild.Read.TwoMastersWithNoKeyAtAll_ClaimNoChildRow, que e
///  o unico sitio onde a forma e construivel: so a associacao composta junta
///  colunas que nao sao a chave primaria e portanto podem ser nulas.
///  Nao entregar deixa a linha visivel onde ela esta; entregar ao pai errado
///  nao. Nada disto e alcancado com UM master so, porque ai nao ha par nenhum.
///
///  COMPARA POR VALOR ONDE O TEXTO E MAIS ESTREITO QUE O VALOR, E ESSA E A
///  UNICA RAZAO DOS RAMOS. Uma versao anterior comparava TUDO por AsString, e
///  isso foi MEDIDO como um buraco por onde o defeito desta issue volta inteiro
///  e em silencio, em dados que ninguem chamaria de exoticos:
///
///  - data/hora: TDateTimeField.AsString passa por DateTimeToStr, que NAO
///    carrega o milissegundo. Duas linhas de master separadas por 1 ms davam
///    o mesmo texto, o filtro nao distinguia nada, e cada master recebia a
///    lista inteira. Medido por
///    CompositeKey_TwoMasterRowsThatDifferByOneMillisecond_AreStillTwoParents.
///  - Currency: FloatToStr rende QUINZE digitos significativos e uma Currency
///    guarda ate dezenove. Duas quantias que diferem no decimo sexto digito
///    davam o mesmo texto. Medido por
///    CompositeKey_TwoMasterRowsThatDifferInTheSixteenthDigit_AreStillTwoParents.
///
///  Os dois ramos foram medidos SEPARADAMENTE de proposito: "a familia de data
///  e cega" nao diz nada sobre a familia numerica, e vice-versa. O ramo de
///  ponto flutuante binario (ftFloat/ftSingle/ftExtended) acompanha o de
///  Currency pelo mesmo argumento de largura - AsExtended nao perde o que
///  FloatToStr perde - e esta DECLARADO COMO NAO MEDIDO: nenhum modelo do
///  repositorio declara uma associacao sobre coluna de ponto flutuante, e
///  inventar uma para pinar o ramo seria alargar esta issue.
///
///  ftBCD e ftFMTBcd FICAM NO AsString DE PROPOSITO, e isto e o oposto de um
///  esquecimento: para BCD o TEXTO E a representacao exata - TFMTBCDField
///  responde por BcdToStr - enquanto qualquer conversao para ponto flutuante
///  perderia digitos que o BCD guarda. Aqui o ramo tipado seria o buraco.
///  NAO MEDIDO tambem: nenhum modelo do repositorio declara essa associacao.
///
///  AsString CONTINUA SENDO O FUNDO, e continua sendo total: qualquer par que
///  nao caia num ramo - inteiro, string, GUID, booleano, memo - le pela MESMA
///  rotina dos dois lados e nao tem conversao a falhar.
///
///  O RAMO SO VALE COM OS DOIS LADOS NA MESMA FAMILIA. Par de tipos DIFERENTES
///  cai no fundo, o que e a resposta conservadora e NAO ESTA MEDIDO - nao se
///  procurou um modelo assim, e por isso aqui nao se afirma que nao existe.
///
///  BRANCOS A DIREITA SAO SIGNIFICATIVOS, e isto e uma DIFERENCA DE SEMANTICA
///  em relacao a um JOIN de banco, declarada aqui porque ninguem a escolheu.
///  MEDIDO sobre o codigo de 63f6825, com clausulas TEMPORARIAS que NAO ficaram
///  na arvore. O arranjo: duas linhas de TCompMaster iguais em tudo menos
///  `cmk2` e UMA linha de TCompChild com 'CC'; o campo guarda mesmo os brancos.
///
///    masters 'CC' e 'CC   '    -> parado em 'CC' o filho E reivindicado;
///                                 parado em 'CC   ' NAO e.
///    masters 'CC   ' e 'DD   ' -> nenhum dos dois reivindica.
///
///  Quem reivindica e o pai EXATO; quem perde e o candidato que um join de CHAR
///  teria casado. O custo e MAIS ESTREITO do que uma versao anterior deste
///  comentario dizia: ela afirmava que NENHUM pai reivindica, e a receita que
///  ela mesma imprimia desmente isso ja na primeira linha. O filho fica ORFAO -
///  e portanto nunca e enviado no caminho que GRAVA - so no segundo arranjo,
///  onde TODO candidato carrega brancos. Com o filtro desligado - mutacao n1,
///  o estado anterior a este conserto - os quatro casos reivindicam.
///
///  Um join sobre CHAR num Firebird casaria 'CC' com 'CC   ', e isto nao e
///  hipotese distante: o comentario de TDMLGeneratorAbstract.CanonicalGuidLiteral
///  registra que o DDL desta casa PRETENDE CHAR para chave ftGuid em
///  PostgreSQL, Firebird, InterBase e MySQL - e e' exatamente CHAR o tipo onde
///  o enchimento de brancos decide um join.
///  A regra aqui e mais ESTRITA que a do banco. Qual semantica de dialeto
///  emular NAO e decisao deste conserto e por isso nao ha clausula pinando-a; a
///  regra "quem nao nomeia pai nao e de ninguem" ja esta pinada, sem depender
///  de dialeto, por
///  Test.Janus.Grandchild.Read.TwoMastersWithNoKeyAtAll_ClaimNoChildRow.
///  Aqui fica so a medicao, para quem decidir. </summary>
function TDataSetBaseAdapter<M>._FieldValuesMatch(const AMasterField,
  AChildField: TField): Boolean;
/// DECLARADOS DENTRO DO METODO, e nao ao lado de cNoRowToken na secao de
/// implementacao: um metodo de tipo PARAMETRIZADO declarado na interface nao
/// pode usar simbolo da implementacao - E2506, medido. cNoRowToken escapa
/// disso por ser constante inteira sem tipo, que o compilador resolve como
/// literal; um conjunto tipado nao escapa.
/// DB.ftSingle e DB.ftExtended QUALIFICADOS, e nao por estilo: TypInfo declara
/// TFloatType com membros de nome IDENTICO e vem depois de DB no uses desta
/// unit, de modo que o nome curto resolve para o enumerado ERRADO. Medido:
/// E2010 'TFieldType' e 'TFloatType'.
const
  cDATETIMEFIELDKINDS = [ftDate, ftTime, ftDateTime, ftTimeStamp,
                         ftTimeStampOffset, ftOraTimeStamp];
  cCURRENCYFIELDKINDS = [ftCurrency];
  cBINARYFLOATFIELDKINDS = [ftFloat, DB.ftSingle, DB.ftExtended];
begin
  if AMasterField.IsNull or AChildField.IsNull then
    Exit(False);
  if (AMasterField.DataType in cDATETIMEFIELDKINDS) and
     (AChildField.DataType in cDATETIMEFIELDKINDS) then
    Exit(AMasterField.AsDateTime = AChildField.AsDateTime);
  if (AMasterField.DataType in cCURRENCYFIELDKINDS) and
     (AChildField.DataType in cCURRENCYFIELDKINDS) then
    Exit(AMasterField.AsCurrency = AChildField.AsCurrency);
  if (AMasterField.DataType in cBINARYFLOATFIELDKINDS) and
     (AChildField.DataType in cBINARYFLOATFIELDKINDS) then
    Exit(AMasterField.AsExtended = AChildField.AsExtended);
  Result := AMasterField.AsString = AChildField.AsString;
end;

procedure TDataSetBaseAdapter<M>.DisableDataSetEvents;
var
  LClassType: TRttiType;
  LProperty: TRttiProperty;
  LPropInfo: PPropInfo;
  LMethod: TMethod;
  LMethodNil: TMethod;
begin
  LClassType := RttiSingleton.GetRttiType(FOrmDataSet.ClassType);
  for LProperty in LClassType.GetProperties do
  begin
    if LProperty.PropertyType.TypeKind <> tkMethod then
      Continue;
    if not _FindEvents(LProperty.Name) then
      Continue;
    LPropInfo := GetPropInfo(FOrmDataSet, LProperty.Name);
    if LPropInfo = nil then
      Continue;
    LMethod := GetMethodProp(FOrmDataSet, LPropInfo);
    if not Assigned(LMethod.Code) then
      Continue;
    LMethodNil.Code := nil;
    SetMethodProp(FOrmDataSet, LPropInfo, LMethodNil);
    SetMethodProp(FOrmDataSetEvents, LPropInfo, LMethod);
  end;
end;

function TDataSetBaseAdapter<M>.Find: TObjectList<M>;
begin
  Result := FSession.Find;
end;

function TDataSetBaseAdapter<M>.Find(const AID: Integer): M;
begin
  Result := FSession.Find(AID);
end;

function TDataSetBaseAdapter<M>._FindEvents(AEventName: String): Boolean;
begin
  Result := MatchStr(AEventName, ['AfterCancel'   ,'AfterClose'   ,'AfterDelete' ,
                                  'AfterEdit'     ,'AfterInsert'  ,'AfterOpen'   ,
                                  'AfterPost'     ,'AfterRefresh' ,'AfterScroll' ,
                                  'BeforeCancel'  ,'BeforeClose'  ,'BeforeDelete',
                                  'BeforeEdit'    ,'BeforeInsert' ,'BeforeOpen'  ,
                                  'BeforePost'    ,'BeforeRefresh','BeforeScroll',
                                  'OnCalcFields'  ,'OnDeleteError','OnEditError' ,
                                  'OnFilterRecord','OnNewRecord'  ,'OnPostError']);
end;

function TDataSetBaseAdapter<M>.FindWhere(const AWhere,
  AOrderBy: String): TObjectList<M>;
begin
  Result := FSession.FindWhere(AWhere, AOrderBy);
end;

procedure TDataSetBaseAdapter<M>.DoAfterClose(DataSet: TDataSet);
begin
  if Assigned(FDataSetEvents.AfterClose) then
    FDataSetEvents.AfterClose(DataSet);
end;

procedure TDataSetBaseAdapter<M>.DoAfterDelete(DataSet: TDataSet);
begin
  if Assigned(FDataSetEvents.AfterDelete) then
    FDataSetEvents.AfterDelete(DataSet);
end;

procedure TDataSetBaseAdapter<M>.DoAfterEdit(DataSet: TDataSet);
begin
  if Assigned(FDataSetEvents.AfterEdit) then
    FDataSetEvents.AfterEdit(DataSet);
end;

procedure TDataSetBaseAdapter<M>.DoAfterInsert(DataSet: TDataSet);
begin
  if Assigned(FDataSetEvents.AfterInsert) then
    FDataSetEvents.AfterInsert(DataSet);
end;

procedure TDataSetBaseAdapter<M>.DoAfterOpen(DataSet: TDataSet);
begin
  if Assigned(FDataSetEvents.AfterOpen) then
    FDataSetEvents.AfterOpen(DataSet);
end;

procedure TDataSetBaseAdapter<M>.DoAfterPost(DataSet: TDataSet);
begin
  if Assigned(FDataSetEvents.AfterPost) then
    FDataSetEvents.AfterPost(DataSet);
end;

procedure TDataSetBaseAdapter<M>.DoAfterScroll(DataSet: TDataSet);
begin
  if Assigned(FDataSetEvents.AfterScroll) then
    FDataSetEvents.AfterScroll(DataSet);
  if FPageSize = -1 then
    Exit;
  if not (FOrmDataSet.State in [dsBrowse]) then
    Exit;
  if not FOrmDataSet.Eof then
    Exit;
  if FOrmDataSet.IsEmpty then
    Exit;
  if not FAutoNextPacket then
    Exit;
  // Controle de paginacao de registros retornados do banco de dados
  NextPacket;
end;

procedure TDataSetBaseAdapter<M>.Insert;
begin
  FOrmDataSet.Insert;
end;

procedure TDataSetBaseAdapter<M>.DoBeforeCancel(DataSet: TDataSet);
var
  LChild: TDataSetBaseAdapter<M>;
  LLookup: TDataSetBaseAdapter<M>;
begin
  if Assigned(FDataSetEvents.BeforeCancel) then
    FDataSetEvents.BeforeCancel(DataSet);
  // Executa comando Cancel em cascata
  if not Assigned(FMasterObject) then
    Exit;

  if FMasterObject.Count = 0 then
    Exit;

  for LChild in FMasterObject.Values do
  begin
    if not (LChild.FOrmDataSet.State in [dsInsert, dsEdit]) then
      Continue;

    LChild.Cancel;
  end;
end;

procedure TDataSetBaseAdapter<M>.DoAfterCancel(DataSet: TDataSet);
begin
  if Assigned(FDataSetEvents.AfterCancel) then
    FDataSetEvents.AfterCancel(DataSet);
end;

procedure TDataSetBaseAdapter<M>.DoBeforeClose(DataSet: TDataSet);
var
  LChild: TDataSetBaseAdapter<M>;
  LLookup: TDataSetBaseAdapter<M>;
begin
  if Assigned(FDataSetEvents.BeforeClose) then
    FDataSetEvents.BeforeClose(DataSet);
  // Executa o comando Close em cascata
  if Assigned(FLookupsField) then
    if FLookupsField.Count > 0 then
      for LChild in FLookupsField do
        LChild.Close;

  if Assigned(FMasterObject) then
    if FMasterObject.Count > 0 then
      for LChild in FMasterObject.Values do
        LChild.Close;
end;

procedure TDataSetBaseAdapter<M>.DoBeforeDelete(DataSet: TDataSet);
begin
  if Assigned(FDataSetEvents.BeforeDelete) then
    FDataSetEvents.BeforeDelete(DataSet);
end;

procedure TDataSetBaseAdapter<M>.DoBeforeEdit(DataSet: TDataSet);
var
  LFieldEvents: TFieldEventsMappingList;
begin
  if Assigned(FDataSetEvents.BeforeEdit) then
    FDataSetEvents.BeforeEdit(DataSet);

  // Checa o Attributo "FieldEvents" nos TFields somente uma vez
  if FCheckedFieldEvents then
    Exit;

  // ForeingnKey da Child
  LFieldEvents := TMappingExplorer.GetMappingFieldEvents(FCurrentInternal.ClassType);
  if LFieldEvents = nil then
    Exit;

  _ValideFieldEvents(LFieldEvents);
  FCheckedFieldEvents := True;
end;

procedure TDataSetBaseAdapter<M>.DoBeforeInsert(DataSet: TDataSet);
var
  LFieldEvents: TFieldEventsMappingList;
begin
  if Assigned(FDataSetEvents.BeforeInsert) then
    FDataSetEvents.BeforeInsert(DataSet);
  if Assigned(FOwnerMasterObject) then
    _EnsureMasterRowToken(TDataSetBaseAdapter<M>(FOwnerMasterObject));
  // A identidade do master e garantida AQUI, e nao no DoNewRecord, e o lugar e
  // o conserto. Data.DB.pas, TDataSet.BeginInsertAppend, chama CheckBrowseMode,
  // CheckCanModify e so entao DoBeforeInsert - de modo que ESTA linha ainda
  // esta em dsBrowse e ainda nao esta Modified quando o master e escrito.
  // Escrever no master reentra no detalhe pelo deDataSetChange do Post, que
  // chega a TCustomClientDataSet.MasterChanged e la a PRIMEIRA instrucao e
  // CheckBrowseMode; de dsBrowse isso nao faz nada, de dsInsert e Modified -
  // que e o estado que o DoNewRecord oferecia, porque _StampRowTokens grava o
  // RowToken proprio antes - postava a linha pela metade. Ver o cabecalho de
  // _EnsureMasterRowToken.
  // Checa o Attributo "FieldEvents()" nos TFields somente uma vez
  if FCheckedFieldEvents then
    Exit;
  // ForeingnKey da Child
  LFieldEvents := TMappingExplorer.GetMappingFieldEvents(FCurrentInternal.ClassType);
  if LFieldEvents = nil then
    Exit;
  _ValideFieldEvents(LFieldEvents);
  FCheckedFieldEvents := True;
end;

procedure TDataSetBaseAdapter<M>.DoBeforeOpen(DataSet: TDataSet);
begin
  if Assigned(FDataSetEvents.BeforeOpen) then
    FDataSetEvents.BeforeOpen(DataSet);
end;

procedure TDataSetBaseAdapter<M>.DoBeforePost(DataSet: TDataSet);
var
  LDataSetChild: TDataSetBaseAdapter<M>;
  LField: TField;
begin
  // Muda o Status do registro, para identificacao do Janus dos registros que
  // sofreram alteracoes.
  LField := FOrmDataSet.Fields[FInternalIndex];
  case FOrmDataSet.State of
    dsInsert:
      begin
        LField.AsInteger := Integer(FOrmDataSet.State);
      end;
    dsEdit:
      begin
        if LField.AsInteger = -1 then
          LField.AsInteger := Integer(FOrmDataSet.State);
      end;
  end;
  // Dispara o evento do componente
  if Assigned(FDataSetEvents.BeforePost) then
    FDataSetEvents.BeforePost(DataSet);

  if not FOrmDataSet.Active then
    Exit;

  // Tratamento dos datasets filhos.
  for LDataSetChild in FMasterObject.Values do
  begin
    if LDataSetChild.FOrmDataSet = nil then
      Continue;
    if not LDataSetChild.FOrmDataSet.Active then
      Continue;
    if not (LDataSetChild.FOrmDataSet.State in [dsInsert, dsEdit]) then
      Continue;
    LDataSetChild.FOrmDataSet.Post;
  end;
end;

procedure TDataSetBaseAdapter<M>.DoBeforeScroll(DataSet: TDataSet);
begin
  if Assigned(FDataSetEvents.BeforeScroll) then
    FDataSetEvents.BeforeScroll(DataSet);
end;

/// <summary> Says whether AAdapter is holding rows the operator typed and did
///  not save. TWO markers are needed and neither one alone is enough, which is
///  a measurement and not a reading:
///  - the row being typed RIGHT NOW never reached DoBeforePost, so the internal
///    column still carries its default of -1. That default is written by
///    TBind.SetInternalInitFieldDefsObjectClass, which creates the column -
///    NOT by Bind.SetDataDictionary, which only walks columns that are MAPPED
///    and carry a Dictionary attribute, and the internal column is neither.
///    Measured by Test.Janus.Apply.Loops
///    .InternalFieldCarriesTheMinusOneDefault, over an entity that declares no
///    Dictionary at all. Only State shows it;
///  - rows already posted into the in-memory table carry Integer(dsInsert) or
///    Integer(dsEdit) in that column, written by DoBeforePost and reset to -1
///    by ApplyInserter/ApplyUpdater once the row reaches the database; State is
///    dsBrowse by then and shows nothing.
///  Modified is not usable: Post clears it, so it answers False on exactly the
///  posted-but-unsaved rows this has to find - measured by
///  Marker_APostedButUnsavedRowCarriesTheInsertMarker. ChangeCount is not
///  usable either:
///  TFDMemTableAdapter<M>.Create sets CachedUpdates := False and
///  LogChanges := False, so FireDAC's own change log is empty by construction -
///  pinned by Marker_ChangeCountIsBlindToPendingRows.
///  THE WALK MUTES THE CHILD'S EVENTS ON PURPOSE. Advancing a child dataset
///  fires its own AfterScroll, which calls OpenDataSetChilds and re-reads the
///  GRANDCHILDREN from the database - merely asking whether a child is dirty
///  would destroy its unsaved children. Same reason SetAutoIncValueChilds mutes
///  them. Pinned by Detecting_DoesNotDestroyTheGrandchildren. </summary>
function TDataSetBaseAdapter<M>._HasPendingRows(
  const AAdapter: TDataSetBaseAdapter<M>): Boolean;
var
  LDataSet: TDataSet;
  LField: TField;
  LMark: TBookmark;
begin
  Result := False;
  if AAdapter = nil then
    Exit;
  LDataSet := AAdapter.FOrmDataSet;
  if LDataSet = nil then
    Exit;
  if not LDataSet.Active then
    Exit;
  if LDataSet.State in [dsInsert, dsEdit] then
    Exit(True);
  LField := LDataSet.FindField(cInternalField);
  if LField = nil then
    Exit;
  if LDataSet.IsEmpty then
    Exit;
  AAdapter.DisableDataSetEvents;
  LMark := LDataSet.GetBookmark;
  try
    LDataSet.First;
    while not LDataSet.Eof do
    begin
      if (LField.AsInteger = Integer(dsInsert)) or
         (LField.AsInteger = Integer(dsEdit)) then
        Exit(True);
      LDataSet.Next;
    end;
  finally
    if LDataSet.BookmarkValid(LMark) then
      LDataSet.GotoBookmark(LMark);
    LDataSet.FreeBookmark(LMark);
    AAdapter.EnableDataSetEvents;
  end;
end;

/// <summary> The child datasets that would lose rows if the master scrolled
///  now. Empty array when there is nothing to lose - which is the normal case
///  and the reason the caller can leave without doing anything. </summary>
function TDataSetBaseAdapter<M>._PendingChilds: TArray<TDataSet>;
var
  LChild: TDataSetBaseAdapter<M>;
  LCount: Integer;
begin
  SetLength(Result, 0);
  if not Assigned(FMasterObject) then
    Exit;
  LCount := 0;
  for LChild in FMasterObject.Values do
  begin
    if not _HasPendingRows(LChild) then
      Continue;
    SetLength(Result, LCount + 1);
    Result[LCount] := LChild.FOrmDataSet;
    Inc(LCount);
  end;
end;

/// <summary> Turns the discard into a decision. WITH NO HANDLER ASSIGNED THIS
///  IS A SINGLE COMPARISON AND A RETURN - no child is inspected, no cursor is
///  moved, no event is muted - so the default path is exactly the code that
///  shipped before this method existed. Called from
///  TDataSetAdapter<M>.DoBeforeScroll, the only family whose OpenDataSetChilds
///  really re-queries. </summary>
procedure TDataSetBaseAdapter<M>.DoBeforeScrollPendingChilds;
var
  LPendings: TArray<TDataSet>;
  LAction: TPendingChildsAction;
  LChild: TDataSetBaseAdapter<M>;
begin
  if not Assigned(FBeforeScrollPendingChilds) then
    Exit;
  LPendings := _PendingChilds;
  if Length(LPendings) = 0 then
    Exit;
  // Pre-seeded with the historical behaviour: a handler that reads nothing and
  // writes nothing leaves the framework doing what it always did.
  LAction := pcaDiscard;
  FBeforeScrollPendingChilds(Self, LPendings, LAction);
  case LAction of
    pcaPost:
      for LChild in FMasterObject.Values do
      begin
        if not _HasPendingRows(LChild) then
          Continue;
        if LChild.FOrmDataSet.State in [dsInsert, dsEdit] then
          LChild.FOrmDataSet.Post;
        LChild.ApplyUpdates(0);
      end;
    pcaCancel:
      // Abort, not a named exception: EAbort is the signal TDataSet already
      // understands for "this move is not happening", it unwinds MoveBy before
      // the cursor leaves the row, and a VCL application swallows it silently
      // instead of showing a dialog nobody asked for.
      Abort;
  end;
end;

procedure TDataSetBaseAdapter<M>.DoNewRecord(DataSet: TDataSet);
begin
  if Assigned(FDataSetEvents.OnNewRecord) then
    FDataSetEvents.OnNewRecord(DataSet);
  // Registra QUEM E esta linha e DE QUEM ela e filha. Fora do teste
  // FMasterObject.Count > 0 abaixo de proposito: aquele teste pergunta "eu
  // tenho filhos", e o ultimo nivel da hierarquia - justamente o que mais
  // precisa dizer de quem e filho - responde nao.
  _StampRowTokens;
  // Busca valor da tabela master, caso aqui seja uma tabela detalhe.
  if FMasterObject.Count > 0 then
    _GetMasterValues;
end;

procedure TDataSetBaseAdapter<M>.Delete;
begin
  FOrmDataSet.Delete;
end;

procedure TDataSetBaseAdapter<M>.Edit;
begin
  FOrmDataSet.Edit;
end;

procedure TDataSetBaseAdapter<M>.GetDataSetEvents;
begin
  // Scroll Events
  if Assigned(FOrmDataSet.BeforeScroll) then
    FDataSetEvents.BeforeScroll := FOrmDataSet.BeforeScroll;
  if Assigned(FOrmDataSet.AfterScroll) then
    FDataSetEvents.AfterScroll := FOrmDataSet.AfterScroll;
  // Open Events
  if Assigned(FOrmDataSet.BeforeOpen) then
    FDataSetEvents.BeforeOpen := FOrmDataSet.BeforeOpen;
  if Assigned(FOrmDataSet.AfterOpen) then
    FDataSetEvents.AfterOpen := FOrmDataSet.AfterOpen;
  // Close Events
  if Assigned(FOrmDataSet.BeforeClose) then
    FDataSetEvents.BeforeClose := FOrmDataSet.BeforeClose;
  if Assigned(FOrmDataSet.AfterClose) then
    FDataSetEvents.AfterClose := FOrmDataSet.AfterClose;
  // Delete Events
  if Assigned(FOrmDataSet.BeforeDelete) then
    FDataSetEvents.BeforeDelete := FOrmDataSet.BeforeDelete;
  if Assigned(FOrmDataSet.AfterDelete) then
    FDataSetEvents.AfterDelete := FOrmDataSet.AfterDelete;
  // Post Events
  if Assigned(FOrmDataSet.BeforePost) then
    FDataSetEvents.BeforePost := FOrmDataSet.BeforePost;
  if Assigned(FOrmDataSet.AfterPost) then
    FDataSetEvents.AfterPost := FOrmDataSet.AfterPost;
  // Cancel Events
  if Assigned(FOrmDataSet.BeforeCancel) then
    FDataSetEvents.BeforeCancel := FOrmDataSet.BeforeCancel;
  if Assigned(FOrmDataSet.AfterCancel) then
    FDataSetEvents.AfterCancel := FOrmDataSet.AfterCancel;
  // Insert Events
  if Assigned(FOrmDataSet.BeforeInsert) then
    FDataSetEvents.BeforeInsert := FOrmDataSet.BeforeInsert;
  if Assigned(FOrmDataSet.AfterInsert) then
    FDataSetEvents.AfterInsert := FOrmDataSet.AfterInsert;
  // Edit Events
  if Assigned(FOrmDataSet.BeforeEdit) then
    FDataSetEvents.BeforeEdit := FOrmDataSet.BeforeEdit;
  if Assigned(FOrmDataSet.AfterEdit) then
    FDataSetEvents.AfterEdit := FOrmDataSet.AfterEdit;
  // NewRecord Events
  if Assigned(FOrmDataSet.OnNewRecord) then
    FDataSetEvents.OnNewRecord := FOrmDataSet.OnNewRecord
end;

function TDataSetBaseAdapter<M>.IsAssociationUpdateCascade(
  ADataSetChild: TDataSetBaseAdapter<M>; AColumnsNameRef: String): Boolean;
var
  LForeignKey: TForeignKeyMapping;
  LForeignKeys: TForeignKeyMappingList;
begin
  Result := False;
  LForeignKeys := TMappingExplorer.GetMappingForeignKey(ADataSetChild.FCurrentInternal.ClassType);
  if LForeignKeys = nil then
    Exit;
  for LForeignKey in LForeignKeys do
  begin
    if not LForeignKey.FromColumns.Contains(AColumnsNameRef) then
      Continue;

    if LForeignKey.RuleUpdate = TRuleAction.Cascade then
      Exit(True);
  end;
end;

function TDataSetBaseAdapter<M>._GetAutoNextPacket: Boolean;
begin
  Result := FAutoNextPacket;
end;

function TDataSetBaseAdapter<M>.Current: M;
var
  LDataSetChild: TDataSetBaseAdapter<M>;
begin
  if not FOrmDataSet.Active then
    Exit(FCurrentInternal);

  if FOrmDataSet.RecordCount = 0 then
    Exit(FCurrentInternal);

  Bind.SetFieldToProperty(FOrmDataSet, TObject(FCurrentInternal));

  if not FProxiesInjectedForCurrentRow then
  begin
    if Assigned(FSession) then
      FSession.InjectLazyProxies(TObject(FCurrentInternal));
    FProxiesInjectedForCurrentRow := True;
  end;

  for LDataSetChild in FMasterObject.Values do
    LDataSetChild.FillMastersClass(LDataSetChild, FCurrentInternal);

  Result := FCurrentInternal;
end;

procedure TDataSetBaseAdapter<M>.Post;
begin
  FOrmDataSet.Post;
end;

procedure TDataSetBaseAdapter<M>.RefreshRecord;
var
  LPrimaryKey: TPrimaryKeyMapping;
  LParams: TParams;
  LFor: Integer;
begin
  inherited;
  if FOrmDataSet.RecordCount = 0 then
    Exit;
  LPrimaryKey := TMappingExplorer
                   .GetMappingPrimaryKey(FCurrentInternal.ClassType);
  if LPrimaryKey = nil then
    Exit;
  FOrmDataSet.DisableControls;
  DisableDataSetEvents;
  LParams := TParams.Create(nil);
  try
    for LFor := 0 to LPrimaryKey.Columns.Count -1 do
    begin
      with LParams.Add as TParam do
      begin
        Name := LPrimaryKey.Columns.Items[LFor];
        ParamType := ptInput;
        DataType := FOrmDataSet.FieldByName(LPrimaryKey.Columns
                                                       .Items[LFor]).DataType;
        Value := FOrmDataSet.FieldByName(LPrimaryKey.Columns
                                                    .Items[LFor]).Value;
      end;
    end;
    if LParams.Count > 0 then
      FSession.RefreshRecord(LParams);
  finally
    LParams.Clear;
    LParams.Free;
    FOrmDataSet.EnableControls;
    EnableDataSetEvents;
  end;
end;

procedure TDataSetBaseAdapter<M>.RefreshRecordInternal(const AObject: TObject);
begin

end;

procedure TDataSetBaseAdapter<M>.RefreshRecordWhere(const AWhere: String);
begin
  FOrmDataSet.DisableControls;
  DisableDataSetEvents;
  try
    FSession.RefreshRecordWhere(AWhere);
  finally
    FOrmDataSet.EnableControls;
    EnableDataSetEvents;
  end
end;

/// <summary> Desliga o vinculo master-detail do dataset filho e devolve o
///  TDataSource que estava la, para ser restaurado depois.
///  POR QUE ISTO EXISTE: o vinculo restringe o filho as linhas cuja FK e igual
///  a chave CORRENTE do master. Quando SetAutoIncValueChilds roda, o master ja
///  carrega a chave NOVA e os filhos ainda carregam a ANTIGA, de modo que o
///  conjunto filho fica com ZERO linhas visiveis: o metodo cujo trabalho e
///  atualizar os filhos nao enxerga nenhum. Medido em TFDMemTable e em
///  TClientDataSet. A propriedade e publicada nos dois, e e por ela que
///  TRESTFDMemTableAdapter<M>._FilterDataSetChilds e
///  TRESTClientDataSetAdapter<M>.FilterDataSetChilds amarram cada filho ao seu
///  master. </summary>
function TDataSetBaseAdapter<M>._DetachMasterLink(
  const ADataSet: TDataSet): TObject;
const
  cMASTERSOURCEPROP = 'MasterSource';
begin
  Result := nil;
  if ADataSet = nil then
    Exit;
  if not IsPublishedProp(ADataSet, cMASTERSOURCEPROP) then
    Exit;
  Result := GetObjectProp(ADataSet, cMASTERSOURCEPROP);
  if Result <> nil then
    SetObjectProp(ADataSet, cMASTERSOURCEPROP, nil);
end;

procedure TDataSetBaseAdapter<M>._RestoreMasterLink(const ADataSet: TDataSet;
  const ASource: TObject);
const
  cMASTERSOURCEPROP = 'MasterSource';
begin
  if (ADataSet = nil) or (ASource = nil) then
    Exit;
  if not IsPublishedProp(ADataSet, cMASTERSOURCEPROP) then
    Exit;
  SetObjectProp(ADataSet, cMASTERSOURCEPROP, ASource);
end;

/// <summary> Diz se a linha corrente do dataset filho esta PENDENTE DE
///  INSERCAO. Somente essas podem ser reapontadas para a chave nova: uma linha
///  ja gravada pertence a outro master - no cliente REST o dataset filho guarda
///  os filhos de TODOS os masters que a listagem trouxe - e carimbar nela a
///  chave recem-gerada re-parentaria dado alheio em silencio. O marcador e o
///  mesmo campo interno que ApplyInserter filtra. </summary>
function TDataSetBaseAdapter<M>._IsPendingInsertRow(
  const ADataSet: TDataSet): Boolean;
var
  LField: TField;
begin
  LField := ADataSet.FindField(cInternalField);
  Result := (LField = nil) or (LField.AsInteger = Integer(dsInsert));
end;

/// <summary> Grava a proveniencia da linha que esta sendo criada: uma
///  identidade PROPRIA, nova a cada linha, e a identidade da linha do master
///  que estava corrente neste instante. As duas sao necessarias e uma so nao
///  serve: uma linha de nivel intermediario precisa dizer QUEM ELA E, para os
///  seus proprios filhos, e DE QUEM ELA E FILHA, para o seu pai.
///  ESTE E O UNICO MOMENTO EM QUE A RESPOSTA EXISTE. Depois que a insercao
///  comeca, o master ja carrega a chave NOVA e os filhos ainda carregam a
///  ANTIGA, e nenhuma comparacao de chave consegue separa-los - foi assim que
///  o range master-detail, o bookmark e a captura previa do conjunto filho
///  falharam, cada um medido. Aqui ninguem precisa comparar nada: o cursor do
///  master esta, por construcao, sobre a linha sob a qual o usuario esta
///  digitando.
///  Chamado de DoNewRecord, isto e, so quando os eventos do adapter estao
///  ligados. Uma linha criada com eles desligados fica em cNoRowToken e cai no
///  comportamento historico - ver _IsOwnedByMasterRow.
///  A identidade do master vem de _EnsureMasterRowToken e nao de
///  _MasterRowToken: uma linha de master que nao se identifica - toda linha
///  lida do banco e uma - ganha identidade AQUI, para que o filho nomeie um pai
///  concreto em vez de um "nenhum" que qualquer master interpreta a seu
///  favor. Issue #265. </summary>
procedure TDataSetBaseAdapter<M>._StampRowTokens;
var
  LRowToken: TField;
  LOwnerToken: TField;
  LMaster: TDataSetBaseAdapter<M>;
begin
  if FOrmDataSet = nil then
    Exit;
  LRowToken := FOrmDataSet.FindField(cRowTokenField);
  if LRowToken = nil then
    Exit;
  LRowToken.AsInteger := AtomicIncrement(FRowTokenSeq);
  LOwnerToken := FOrmDataSet.FindField(cOwnerTokenField);
  if LOwnerToken = nil then
    Exit;
  LOwnerToken.AsInteger := cNoRowToken;
  if not Assigned(FOwnerMasterObject) then
    Exit;
  LMaster := TDataSetBaseAdapter<M>(FOwnerMasterObject);
  LOwnerToken.AsInteger := _MasterRowToken(LMaster.FOrmDataSet);
end;

/// <summary> Consome a sequencia de identidades DESTA instanciacao.
///  VIRTUAL, e e a virtualidade que e o conserto. FRowTokenSeq e class var de
///  uma classe GENERICA, portanto ha um contador por instanciacao, e
///  _EnsureMasterRowToken roda com Self sendo o adapter do FILHO - de modo que
///  um AtomicIncrement escrito la dentro consome a sequencia da entidade
///  ERRADA e grava numa coluna que so recebia valores da sequencia do master.
///  Medido: com o master parado em 27 e o filho la adiante, a identidade
///  cunhada para o master saiu 125. Dois masters podem entao receber o MESMO
///  numero em momentos diferentes, e o issue #261 volta por colisao em vez de
///  por zero.
///  O acesso ao master e feito por um cast que MENTE - FOwnerMasterObject e
///  TDataSetBaseAdapter<M do master> visto como TDataSetBaseAdapter<M do
///  filho> - e por isso um class var resolvido estaticamente cai na
///  instanciacao errada, enquanto uma chamada VIRTUAL cai na VMT do objeto
///  real, que e a do master. Medido por Test.Janus.AutoInc.Distribution
///  .MintedMasterIdentity_ComesFromTheMasterOwnSequence. </summary>
function TDataSetBaseAdapter<M>._MintRowToken: Integer;
begin
  Result := AtomicIncrement(FRowTokenSeq);
end;

/// <summary> Says whether ANY detail of AAdapter, at ANY depth, is sitting on
///  a row the operator has open. It ASKS and moves nothing: no cursor is
///  advanced, no event is muted, no buffer is written.
///  THE CASCADE IS RECURSIVE, SO THE REFUSAL HAS TO BE. Data.DB.pas,
///  TDataSet.CheckBrowseMode, emits deCheckBrowseMode to its data sources
///  FIRST and inspects its own state AFTER - so a detail sitting in dsBrowse
///  stops nothing: its own CheckBrowseMode still emits the event onwards,
///  reaching TMasterDataLink.CheckBrowseMode of ITS details, where
///  "if Modified then Post" commits a row TWO levels below the master being
///  written. Measured: with the middle level in dsBrowse and the leaf in
///  dsInsert and Modified, a refusal that inspected only the direct children
///  let the write through and the leaf came back dsBrowse - posted half typed.
///  Pinned by MintingWithAGrandchildRowOpen_DoesNotPostThatGrandchild and, in
///  the family that was once said to be out of reach, by
///  FDMemTable_MintingWithAGrandchildRowOpen_DoesNotPostThatGrandchild - drop
///  the descent and BOTH report "Measured state: dsBrowse".
///  THE OPEN-ROW TEST ITSELF - the only clause here that ever answers True - is
///  pinned in BOTH families at BOTH depths, and dropping it reddens FIVE:
///  MintingWithASiblingChildMidInsert_DoesNotPostThatSibling and
///  FDMemTable_MintingWithASiblingChildMidInsert_DoesNotPostThatSibling at one
///  level, the two grandchild fixtures at three, and
///  MintingWithAnUntouchedGrandchildInEdit_IsRefusedAndThatIsThePrice on the
///  price it charges.
///  IT ASKS ABOUT STATE, NOT ABOUT Modified, and that is deliberate and
///  measured - see the item 2 of the header of _EnsureMasterRowToken and
///  MintingWithAnUntouchedGrandchildInEdit_IsRefusedAndThatIsThePrice, which
///  is where the price of the wider question is asserted.
///  NOT BUILT ON _RecurseOverChildRows, and the difference is not stylistic.
///  That method walks the ROWS of ONE child adapter - First, Next and
///  GotoBookmark - and runs SetAutoIncValueChilds on each of them, which
///  WRITES. Both halves disqualify it here: advancing a detail's cursor is
///  itself a CheckBrowseMode and would POST the very row this exists to
///  protect, and the answer is needed BEFORE anything is written at all. The
///  tree is a different one too - the ADAPTER tree that SetMasterObject builds
///  in FMasterObject, not the rows of one level of it.
///  NO CYCLE GUARD, and the guardian is NOT SetMasterObject. That method
///  checks nothing: it removes Self from a previous owner and adds it to the
///  new one, which keeps a child to ONE parent but does nothing to stop
///  A.SetMasterObject(B) followed by B.SetMasterObject(A). What makes
///  FMasterObject a tree is TManagerDataSet.AddAdapter<T, M> - it exits early
///  when T is ALREADY registered and exits early when M is NOT, so every node
///  is given a parent that already existed and no cycle can be built - plus,
///  for an adapter constructed directly, the fourth argument of Create, which
///  is the caller's to get right. SetAutoIncValueChilds rests on the same
///  assumption; what differs is REACH. That one follows only the edges whose
///  association carries CascadeAutoInc, this one reads FMasterObject.Values
///  raw, at every depth - so it is a strict superset and every note about the
///  shape of that dictionary binds harder here.
///  NOTHING UNREGISTERS AN ADAPTER FROM ITS OWNER. Destroy nils its own
///  FOwnerMasterObject and leaves the OWNER's FMasterObject holding the
///  pointer, so freeing a child adapter while its master lives leaves a stale
///  entry that this walk dereferences - and the LChild = nil test does not
///  catch it, because a freed object is not nil. The exposure is older than
///  this method, SetAutoIncValueChilds reads the same dictionary, but this
///  method WIDENS it from the CascadeAutoInc edges to all of them and at every
///  depth. Recorded rather than fixed - see the note on Destroy for why
///  unregistering there is not free.
///  PRIVATE AND NOT VIRTUAL on purpose - a new virtual moves the VMT slot of
///  every virtual after it, and _MintRowToken is dispatched through a slot
///  index resolved against another instantiation. See the comment on
///  FRowTokenSeq.
///  THREE TESTS IN THE LOOP THAT NO FIXTURE REACHES, and they are NOT all
///  unreachable for the same reason. LChild = nil and Active change no answer:
///  SetMasterObject only ever adds Self, never nil, and a closed dataset
///  answers dsInactive, which is not in dsEditModes. FOrmDataSet <> nil is a
///  DIFFERENT sentence and must not be read as that one - deleting it does not
///  change an answer, it dereferences nil. What puts it out of reach is that
///  FOrmDataSet is assigned in Create and cleared only in Destroy, so no live
///  adapter carries nil there. All three are kept because the loop they came
///  from had them.
///  THE DESCENT SITS OUTSIDE ALL THREE, and that is conservatism, not
///  reachability. Data.DB.pas, TMasterDataLink.CheckBrowseMode, is
///  "if FDataSet.Active then FDataSet.CheckBrowseMode" - so the RTL cascade
///  STOPS at a closed level and nothing under it can be posted through that
///  link. Descending anyway can only produce a false positive, which refuses a
///  mint that was safe, and that is the harmless direction. We do not try to
///  prove the level below is unreachable: the adapter tree walked here and the
///  MasterSource tree the RTL walks are wired by different code, and only one
///  of them is ours. </summary>
function TDataSetBaseAdapter<M>._AnyDetailRowOpen(
  const AAdapter: TDataSetBaseAdapter<M>): Boolean;
var
  LChild: TDataSetBaseAdapter<M>;
begin
  Result := False;
  for LChild in AAdapter.FMasterObject.Values do
  begin
    if LChild = nil then
      Continue;
    if (LChild.FOrmDataSet <> nil) and LChild.FOrmDataSet.Active and
       (LChild.FOrmDataSet.State in dsEditModes) then
      Exit(True);
    if _AnyDetailRowOpen(LChild) then
      Exit(True);
  end;
end;

/// <summary> A identidade da linha de master sob a qual um filho esta sendo
///  criado, CRIANDO-A se ela ainda nao existe.
///  POR QUE CRIAR EM VEZ DE MARCAR - issue #265. Uma linha de master lida do
///  armazenamento nao tem identidade: TSessionDataSet<M>._PopularDataSet anexa
///  com os eventos do adapter desligados, entao DoNewRecord nao roda, e
///  TBind.SetFieldToField pula as duas colunas de proveniencia pelo nome. Como
///  a folga de _IsOwnedByMasterRow, NAQUELE ESTADO DO CODIGO, deixava passar
///  todo filho sem proveniencia para qualquer master que perguntasse, os filhos
///  digitados sob esse master eram reivindicaveis por qualquer outro master
///  pendente - que era o #261 na forma que o cliente encontra.
///  O TEMPO VERBAL E O RECADO: a #261 esta fechada, e por DOIS consertos que
///  nao se substituem. Este metodo tira o caso da origem, dando identidade a
///  linha do master, de modo que o filho nomeia um pai concreto e nunca chega a
///  folga; a folga em si ganhou uma fronteira, e nao passa mais um filho sem
///  proveniencia quando ha mais de um master pendente. Tirar qualquer um dos
///  dois reabre uma metade diferente - ver _IsOwnedByMasterRow e
///  FCascadeMasterRows.
///  A alternativa medida foi carimbar no FILHO um valor dizendo "meu master
///  nao se identificava" e recusar quem se identifica. Ela ESTREITA o buraco
///  em vez de fechar: dois masters sem identidade continuam indistinguiveis
///  entre si, e o primeiro deles escreve nos filhos do segundo. Medido por
///  TwoUnidentifiedPendingMasters_ChildOfTheFirstIsNotClaimedByTheSecond.
///
///  AS GUARDAS DA ESCRITA, cada uma com o seu motivo medido.
///
///  1. O LUGAR DA CHAMADA. _EnsureMasterRowToken e chamado de DoBeforeInsert e
///  nao de DoNewRecord. Data.DB.pas, TDataSet.BeginInsertAppend, faz
///  CheckBrowseMode, CheckCanModify e so entao DoBeforeInsert - de modo que a
///  linha do filho ainda esta em dsBrowse e ainda nao esta Modified quando o
///  master e escrito.
///  QUAL E A PERNA DE REENTRADA, corrigido: nao e o deCheckBrowseMode do Edit.
///  E o deDataSetChange, emitido pelo Post do master (e pelo EnableControls,
///  quando ha um par de controles), que desce por TDataLink.DataEvent ->
///  DataSetChanged -> RecordChanged(nil) -> TMasterDataLink.RecordChanged ->
///  FOnMasterChange -> TCustomClientDataSet.MasterChanged, cuja PRIMEIRA
///  instrucao e CheckBrowseMode (Datasnap.DBClient.pas). Um detalhe em
///  dsInsert e Modified alcancado por ai e POSTADO pela metade.
///  MEDIDO NA FAMILIA CERTA, e a familia importa PARA ESTA PERNA: TFDDataSet
///  .MasterChanged chama CheckMasterRange e NAO CheckBrowseMode, entao o
///  deDataSetChange morre ali e a fixture FireDAC nao distingue as duas
///  posicoes da chamada. O TClientDataSet chega. Voltar a chamada para o
///  DoNewRecord derruba
///  ClientDataSetLinkedAsTheRestClientDoes_MintingDoesNotPostTheChild - e so
///  ela - com "Dataset not in edit or insert mode". Os filhos do cliente REST
///  tem MasterSource por construcao, nas duas familias.
///  E NAO SE LEIA ISSO COMO "A FAMILIA FIREDAC ESTA FORA DE ALCANCE", que e
///  uma generalizacao falsa que este cabecalho ja carregou. A frase acima vale
///  para UMA das duas pernas. A outra - Edit -> CheckBrowseMode ->
///  deCheckBrowseMode - chega a familia FireDAC igualzinho: o
///  TFDMasterDataLink.DataEvent so sai cedo naquele evento quando o detalhe E
///  o master dele estao AMBOS em dsEditModes, o que um nivel do meio em
///  dsBrowse nao satisfaz. Medido em arvore de tres niveis por
///  FDMemTable_MintingWithAGrandchildRowOpen_DoesNotPostThatGrandchild.
///  E NAO PRECISA DE NIVEL DO MEIO, o que corrige uma leitura estreita: quem
///  teria de estar em dsEditModes para o desvio valer e o MASTER, e Data.DB
///  .pas, TDataSet.Edit, roda o CheckBrowseMode ANTES do SetState(dsEdit) - de
///  modo que naquele instante o master esta em dsBrowse e um IRMAO DIRETO e
///  alcancado com UM salto so. Medido por
///  FDMemTable_MintingWithASiblingChildMidInsert_DoesNotPostThatSibling.
///  SAO DUAS AS MITIGACOES PROPRIAS DA FAMILIA FIREDAC, E NAO UMA - correcao de
///  uma frase estritamente otimista demais que este cabecalho carregou, a de
///  que a isolacao daquela familia tem "uma perna de largura". A primeira e a
///  de cima, o TFDDataSet.MasterChanged que chama CheckMasterRange e nao
///  CheckBrowseMode, e que mata a perna do deDataSetChange. A SEGUNDA e o
///  proprio desvio do TFDMasterDataLink.DataEvent, na OUTRA METADE da escrita
///  daqui: a escrita e Edit, atribuicao e Post, e o Data.DB.pas, TDataSet.Post,
///  roda UpdateRecord e emite o deCheckBrowseMode de DENTRO do ramo
///  dsEdit/dsInsert, antes do SetState(dsBrowse) - de modo que naquele instante
///  o MASTER esta em dsEdit. As duas metades do teste passam a valer para
///  qualquer detalhe ainda em dsEditModes, o desvio DISPARA e aquele detalhe e
///  poupado. O TClientDataSet nao tem equivalente: o TMasterDataLink do
///  Data.DB.pas nao sobrescreve DataEvent, entao o evento chega ao
///  TDataLink.DataEvent e vira CheckBrowseMode sem excecao nenhuma.
///  E ISSO NAO SALVA NADA AQUI, que e por que a correcao nao muda veredito
///  algum: o estrago ja entrou pela perna do Edit uma linha antes, onde o
///  master ainda esta em dsBrowse e o desvio nao dispara. Quando o Post chega
///  com o desvio armado, nao ha mais linha aberta para poupar. A afirmacao que
///  as fixtures medem esta corretamente escopada ao TDataSet.Edit.
///
///  2. NENHUM DETALHE COM LINHA ABERTA, EM NIVEL NENHUM - ver
///  _AnyDetailRowOpen.
///  A perna de reentrada acima alcanca os OUTROS filhos do mesmo master, que
///  nao estao em dsBrowse so porque este esta, E TAMBEM OS FILHOS DELES: o
///  CheckBrowseMode de um detalhe emite o deCheckBrowseMode para as fontes
///  dele antes de olhar o proprio estado, de modo que um nivel intermediario
///  em dsBrowse nao interrompe a descida. Nao ha guarda que a cale e ainda
///  deixe a escrita acontecer: DisableControls cala o deCheckBrowseMode mas e
///  o proprio EnableControls que reemite o deDataSetChange, e o Post o emite
///  de qualquer jeito. Medido nos dois sentidos: com um irmao em dsInsert e
///  Modified ele era postado COM e SEM DisableControls. Por isso a escrita e
///  recusada em vez de blindada, e por isso NAO ha DisableControls aqui -
///  acrescenta-lo de volta hoje nao muda teste nenhum, medido, e uma clausula
///  que nada defende nao entra. Medido por
///  MintingWithASiblingChildMidInsert_DoesNotPostThatSibling, para um nivel, e
///  por MintingWithAGrandchildRowOpen_DoesNotPostThatGrandchild, para dois.
///  A DUAS FAMILIAS, E NAO SO A DO TClientDataSet - ver a correcao no item 1.
///  Medido tambem por
///  FDMemTable_MintingWithAGrandchildRowOpen_DoesNotPostThatGrandchild:
///  removida a descida recursiva, os DOIS gemeos de tres niveis medem
///  "dsBrowse" para o neto, o do FireDAC junto com o do ClientDataSet.
///  E A UM NIVEL TAMBEM NAS DUAS, que era a forma que faltava medir:
///  FDMemTable_MintingWithASiblingChildMidInsert_DoesNotPostThatSibling poe um
///  irmao DIRETO em dsInsert e Modified, e removido o teste de linha aberta ele
///  reporta "Measured state: dsBrowse" - o irmao foi POSTADO pela metade.
///  "ABERTA" QUER DIZER "State in dsEditModes" E NAO "Modified", E ISSO TEM UM
///  PRECO QUE ESTA MEDIDO. Uma linha ja gravada, posta em dsEdit e nao tocada,
///  seria CANCELADA e nao postada pelo CheckBrowseMode - nada se perderia - e
///  a cunhagem e recusada assim mesmo, de modo que o filho que esta sendo
///  digitado fica sem proveniencia a troco de nada visivel. Medido: com o neto
///  nesse estado, estreitar o predicado com "and Modified" faz o OwnerToken do
///  filho do outro ramo sair uma identidade real - 33 naquela corrida, um
///  valor de sequencia e portanto dependente da ordem - onde hoje sai zero.
///  POR QUE O PREDICADO NAO E ESTREITADO ASSIM MESMO, medido e nao suposto.
///  Data.DB.pas, TDataSet.CheckBrowseMode, roda "UpdateRecord" ANTES de ler
///  "Modified", e UpdateRecord emite deUpdateRecord para todo link e todo
///  TDataSource ligado - que e exatamente o instante em que um controle
///  data-aware escreve no campo o que o operador digitou. Essa escrita torna a
///  linha Modified DENTRO do CheckBrowseMode, de modo que o Modified que um
///  observador leria ANTES nao e o Modified que decide. Medido por
///  MintingWithAnUntouchedGrandchildInEdit_IsRefusedAndThatIsThePrice, que
///  instala um OnUpdateData no lugar do controle: estreitado o predicado, o
///  neto intocado volta com o valor do CONTROLE gravado, isto e, POSTADO.
///  Segundo motivo, aritmetico em vez de temporal: dsSetKey esta em
///  dsEditModes e o CheckBrowseMode POSTA um dataset em dsSetKey sem perguntar
///  nada, onde "Modified" nao quer dizer coisa alguma - o estreitamento
///  precisaria da sua propria excecao.
///
///  3. SO EM dsBrowse. Nao e sinonimo de "nao esta em dsEdit": cobre tambem o
///  master ainda em INSERCAO, e os dois casos sao recusados pelo mesmo motivo -
///  escrever num buffer que o chamador nao comitou faz o valor sair no Post
///  dele ou sumir no Cancel dele. Medido por
///  ChildTypedWhileTheMasterRowIsBeingEdited_DoesNotCommitThatEdit e por
///  ChildTypedUnderAMutedMasterStillInserting_RecordsNoParentage.
///
///  4. IsEmpty. A RTL defende esta sozinha: Data.DB.pas, TDataSet.Edit ->
///  "if FRecordCount = 0 then Insert". Sem a guarda, cunhar num master vazio
///  escreveria num buffer de INSERCAO e o Post FABRICARIA uma linha de master
///  que ninguem pediu. Medido por
///  ChildTypedUnderAnEmptyMaster_MintsNothingAndFabricatesNoRow.
///
///  SETE SAIDAS EM cNoRowToken, e a conta importa porque e o que sustenta o
///  "Refs" em vez do "Closes": AMaster nulo, dataset nulo, dataset fechado,
///  dataset vazio, coluna ausente, linha fora de dsBrowse, e detalhe com linha
///  aberta em qualquer nivel. ESTA E A ENUMERACAO MANTIDA - o comentario de
///  cOwnerTokenField em Janus.DataSet.Fields aponta para ca e nao repete a
///  lista, porque duas listas fechadas em duas unidades ja discordaram uma vez.
///  Em todas o filho fica sem proveniencia e cai no comportamento historico.
///  E O COMPORTAMENTO HISTORICO GANHOU UMA FRONTEIRA - issue #261, e a frase e
///  atualizada AQUI porque esta lista e a MANTIDA e o comentario de
///  cOwnerTokenField delega a ela: se as duas unidades voltarem a discordar, a
///  delegacao deixa de valer alguma coisa. "Reivindicavel por qualquer master
///  pendente" foi verdade ate o #261 e nao e mais. Hoje o filho sem
///  proveniencia e escrito pelo master pendente quando ha UM, e por NENHUM
///  quando ha mais de um - a folga passou a ser pesada contra a contagem de
///  masters daquela passagem. Ver _IsOwnedByMasterRow e FCascadeMasterRows;
///  nenhuma das SETE saidas mudou, e nenhuma delas ganhou ou perdeu um caso.
///  As QUATRO alcancaveis por um consumidor - dataset vazio, linha em dsEdit,
///  linha em dsInsert sob adapter mudo, e detalhe com linha aberta em qualquer
///  nivel - estao fixadas pelas fixtures nomeadas acima, e a quarta e mais
///  larga do que parece: "aberta" e "State in dsEditModes", o que inclui uma
///  linha em dsEdit que ninguem tocou e um dataset em dsSetKey. O preco disso
///  esta medido e fixado, nao descrito - ver o item 2 e
///  MintingWithAnUntouchedGrandchildInEdit_IsRefusedAndThatIsThePrice.
///  As outras tres (AMaster nulo, dataset nulo ou fechado, coluna ausente) sao
///  defensivas e nenhuma fixture as alcanca.
///  PROCEDURE E NAO FUNCTION. O valor nao e devolvido porque nao pode ser
///  transportado com honestidade: entre a cunhagem e a leitura que
///  _StampRowTokens faz no DoNewRecord passam um Post, um Resync e a cascata de
///  MasterChanged, e um Integer levado de um instante para o outro pareceria
///  uma garantia estrutural que na verdade seria circunstancial. Quem le a
///  identidade e _MasterRowToken, na coluna, no momento em que ela e usada.
///  O CONTADOR e o mesmo FRowTokenSeq do #264, consumido aqui pela
///  instanciacao do MASTER via _MintRowToken - ver o comentario daquele campo,
///  que e onde a invariante e a sua premissa nao verificavel estao escritas.
///  </summary>
procedure TDataSetBaseAdapter<M>._EnsureMasterRowToken(
  const AMaster: TDataSetBaseAdapter<M>);
var
  LDataSet: TDataSet;
  LField: TField;
begin
  if AMaster = nil then
    Exit;
  LDataSet := AMaster.FOrmDataSet;
  if LDataSet = nil then
    Exit;
  if not LDataSet.Active then
    Exit;
  if LDataSet.IsEmpty then
    Exit;
  LField := LDataSet.FindField(cRowTokenField);
  if LField = nil then
    Exit;
  if LField.AsInteger <> cNoRowToken then
    Exit;
  if LDataSet.State <> dsBrowse then
    Exit;
  // NENHUM DETALHE DESTE MASTER, EM NIVEL NENHUM, PODE ESTAR COM LINHA ABERTA.
  // Escrever na linha do master notifica os detalhes por dois caminhos da RTL
  // e os dois terminam em CheckBrowseMode do detalhe, que faz
  // "if Modified then Post": o deCheckBrowseMode do Edit, quando os controles
  // nao estao desabilitados, e o deDataSetChange que o Post e o EnableControls
  // emitem, que desce por TDataLink.DataSetChanged -> RecordChanged(nil) ->
  // TMasterDataLink.RecordChanged -> FOnMasterChange ->
  // TCustomClientDataSet.MasterChanged, cuja PRIMEIRA instrucao e
  // CheckBrowseMode. Medido: com um irmao em dsInsert e Modified, ele era
  // POSTADO pela metade - com e sem DisableControls, porque o segundo caminho
  // passa pelos dois. Nao ha guarda que cale os dois lados e ainda deixe a
  // escrita acontecer, entao a escrita nao acontece: o filho que esta sendo
  // digitado fica sem proveniencia e cai no comportamento historico, que
  // continua sendo a troca certa ao lado de comitar a linha que o operador nao
  // terminou. O PRECO DESSA TROCA CRESCEU COM O #261 e a frase que estava aqui
  // - "uma perda estreita" - descrevia o preco de antes. Com UM master pendente
  // ele continua estreito: o filho e escrito como sempre foi. Com MAIS DE UM,
  // ninguem escreve a linha, e o que o consumidor recebe depende da familia -
  // medido nas tres por
  // UntokenisedRow_WithTwoPendingMasters_IsClaimedByNeither e as duas irmas.
  // Estreito ou nao, a alternativa continua sendo postar meia linha.
  // E RECURSIVO PORQUE A CASCATA E. Data.DB.pas, TDataSet.CheckBrowseMode,
  // EMITE o deCheckBrowseMode para as suas fontes de dados antes de olhar o
  // proprio estado - de modo que o nivel do meio estar em dsBrowse nao segura
  // nada, e um neto aberto e Modified era postado. Uma recusa de um nivel so
  // olhava para o meio, nao via nada aberto, e deixava a escrita passar.
  // Medido por MintingWithASiblingChildMidInsert_DoesNotPostThatSibling e por
  // FDMemTable_MintingWithASiblingChildMidInsert_DoesNotPostThatSibling, um
  // nivel, e por MintingWithAGrandchildRowOpen_DoesNotPostThatGrandchild e
  // FDMemTable_MintingWithAGrandchildRowOpen_DoesNotPostThatGrandchild, dois
  // niveis - as DUAS familias nas DUAS profundidades, a do FireDAC tambem, ao
  // contrario do que uma frase deste cabecalho chegou a afirmar. E "aberta"
  // quer dizer
  // "State in dsEditModes", nao "Modified": o preco dessa largura esta medido
  // e fixado por
  // MintingWithAnUntouchedGrandchildInEdit_IsRefusedAndThatIsThePrice.
  // Ver _AnyDetailRowOpen, que e onde a caminhada esta e onde esta escrito por
  // que ela nao e a de _RecurseOverChildRows.
  if _AnyDetailRowOpen(AMaster) then
    Exit;
  AMaster.DisableDataSetEvents;
  try
    LDataSet.Edit;
    LField.AsInteger := AMaster._MintRowToken;
    LDataSet.Post;
  finally
    AMaster.EnableDataSetEvents;
  end;
end;

/// <summary> Diz se a linha corrente do dataset filho foi criada sob a linha
///  de master identificada por AMasterToken.
///  A FOLGA E DE UM LADO SO, e isso e uma decisao medida. Quando o FILHO nao
///  tem proveniencia registrada - linha acrescentada com os eventos do adapter
///  filho desligados, ou lida de um armazenamento que nao tem a coluna - e HA
///  UM MASTER PENDENTE SO, que e a condicao do paragrafo seguinte e nao um
///  detalhe dele, a resposta e True e a linha recebe a chave como sempre
///  recebeu; tirar essa folga faria o filho deixar de ser escrito, que e
///  regressao silenciosa. Medido por Test.Janus.AutoInc.Distribution
///  .ChildRowWithNoRecordedParentage_IsStillWrittenByItsMaster.
///  Do lado do MASTER nao ha folga: um filho que sabe de quem e filho nao e
///  reapontado para uma linha de master que nao se identifica.
///
///  A FOLGA TEM UMA FRONTEIRA, E ELA E UMA CONTAGEM - issue #261. A frase
///  acima descreve um master perguntando. Com MAIS DE UM master pendente na
///  mesma passagem, todos eles perguntam, todos recebem True, e a linha sem
///  proveniencia acaba com a chave do ULTIMO que passou - o item do Pedido #10
///  recebendo a chave do Pedido #N, em silencio. A folga fica, portanto,
///  condicionada a FCascadeMasterRows: enquanto ha um master so a resposta e a
///  historica, e onde ha ambiguidade real ninguem escreve. Uma linha nao
///  escrita e visivel - continua pendente, com a chave que tinha - enquanto
///  uma linha escrita pelo master errado nao e.
///  NAO E "RECUSAR O FILHO SEM PROVENIENCIA", e a diferenca e o conserto
///  inteiro. Medido em d01d4f3, trocando a linha por Exit(False): UM vermelho
///  em 547, e ele e
///  ChildRowWithNoRecordedParentage_IsStillWrittenByItsMaster - o caso de UM
///  master so, onde nunca houve ambiguidade e o filho sempre foi escrito.
///  UM E NAO DOIS, e a conta importa:
///  MutedMasterAppend_WithThePendingPlaceholder_ItsChildIsRepaired PARECE o
///  mesmo caso e nao e - o filho dele foi digitado com os eventos LIGADOS,
///  portanto tem proveniencia registrada e nunca passa por esta folga.
///  Nas duas familias locais e na REST, medido por
///  UntokenisedRow_WithTwoPendingMasters_IsClaimedByNeither,
///  ClientDataSetUntokenisedRow_WithTwoPendingMasters_IsClaimedByNeither e
///  RestUntokenisedRow_WithTwoPendingMasters_IsClaimedByNeither; um andar
///  abaixo, por
///  Recursion_UntokenisedLeaf_WithTwoPendingMidRows_IsClaimedByNeither.
///
///  DUAS RESPOSTAS, E NAO TRES - issue #265. Houve a tentacao de acrescentar
///  aqui um terceiro estado, "registrado, e o meu master nao tinha
///  identidade", e ela foi medida e recusada: aquele estado so consegue
///  distinguir um master identificado de um nao identificado, e nao dois
///  masters nao identificados entre si, de modo que o primeiro deles
///  continuava escrevendo nos filhos do segundo. O caso deixou de existir na
///  origem - _EnsureMasterRowToken da identidade a linha do master no instante
///  do carimbo - e por isso este metodo nao precisa saber nada sobre ele.
///  O zero que ainda chega aqui e SO o do filho que ninguem registrou, e o
///  #261 nao acrescentou estado nenhum ao TOKEN: quem ganhou um terceiro valor
///  foi a PERGUNTA, que agora sabe quantos masters a estao fazendo.
///  </summary>
function TDataSetBaseAdapter<M>._IsOwnedByMasterRow(const AChild: TDataSet;
  const AMasterToken: Integer): Boolean;
var
  LField: TField;
begin
  Result := True;
  LField := AChild.FindField(cOwnerTokenField);
  if LField = nil then
    Exit;
  if LField.AsInteger = cNoRowToken then
    Exit(FCascadeMasterRows <= 1);
  Result := LField.AsInteger = AMasterToken;
end;

/// <summary> A identidade da linha de master sobre a qual o cursor esta
///  parado, ou cNoRowToken quando nao ha resposta - dataset nulo, fechado,
///  VAZIO, ou sem a coluna, que e o caso de um dataset criado por codigo que
///  nao passou por SetInternalInitFieldDefsObjectClass.
///  UM lugar so, porque os TRES sitios que precisam desta resposta -
///  _StampRowTokens ao carimbar a proveniencia de uma linha nova,
///  _AutoIncToChildRows ao filtrar os filhos, e SetAutoIncValueChilds ao
///  passar o mesmo filtro para a recursao - tem que responder sobre a MESMA
///  linha; tres leituras escritas a mao sao tres chances de divergirem.
///  A guarda de IsEmpty acompanha _HasPendingRows: ler um TField de um
///  dataset sem linha nenhuma nao tem significado. </summary>
function TDataSetBaseAdapter<M>._MasterRowToken(
  const AMaster: TDataSet): Integer;
var
  LField: TField;
begin
  Result := cNoRowToken;
  if AMaster = nil then
    Exit;
  if not AMaster.Active then
    Exit;
  if AMaster.IsEmpty then
    Exit;
  LField := AMaster.FindField(cRowTokenField);
  if LField = nil then
    Exit;
  Result := LField.AsInteger;
end;

/// <summary> Percorre as linhas PENDENTES do adapter filho e dispara a cascata
///  do nivel seguinte UMA VEZ POR LINHA, com o cursor do filho parado sobre
///  ela.
///  POR QUE ISTO E METADE DO CONSERTO. Marcar cada neto com o pai certo nao
///  adianta se a recursao entra uma unica vez: SetAutoIncValueChilds recursava
///  uma vez por ADAPTER filho, montada em qualquer linha que o `finally` de
///  _AutoIncToChildRows tivesse deixado corrente - a primeira - e os netos
///  digitados sob qualquer outra linha nao eram alcancados por ninguem. A
///  identidade diz QUAIS linhas escrever; a caminhada e o que faz a escrita
///  acontecer mais de uma vez. Nenhuma das duas metades resolve sozinha.
///  Percorre por BOOKMARK pela mesma razao que _AutoIncToChildRows: a escrita
///  do nivel de baixo pode reordenar o filho quando ele esta indexado pela
///  coluna que esta sendo reescrita.
///  SEM NENHUMA LINHA PENDENTE DESTE MASTER recursa uma unica vez, de onde o
///  cursor estiver, que e exatamente o que este metodo substituiu - um filho
///  ja gravado tem chave propria e os seus filhos continuam a receber.
///  O PAR DE FILTROS E O MESMO DE _AutoIncToChildRows, e pelo mesmo motivo:
///  marcar toda linha pendente do filho, sem perguntar de quem ela e filha,
///  faz a recursao entrar tambem sobre as linhas de OUTRO master pendente. O
///  resultado final nao mudava - naquele instante nenhum filho foi gravado
///  ainda e o ApplyInternal do proprio nivel filho reescreve depois - mas
///  SetAutoIncValueChilds roda uma vez por master pendente, de modo que com P
///  masters, N filhos e M netos o ciclo Edit/Post do nivel 3 saia de O(N*M)
///  para O(P*N*M). Filtrar aqui e mais barato E mais preciso.
///  O QUE ESTE METODO NAO DECIDE SOZINHO - issue #262. Entrar na recursao sobre
///  uma linha nao quer dizer que alguma coisa sera escrita a partir dela:
///  SetAutoIncValueChilds recusa a associacao cuja chave ainda e o placeholder
///  de AutoInc. A caminhada continua a mesma; quem decide o que se propaga e
///  _AutoIncKeyIsGenerated, e decide por VALOR de chave e nao por estado da
///  linha - por estado, esta caminhada inteira ficaria sem proposito.
///  E DELIBERADO QUE ESTA FRASE NAO DIGA "TODA LINHA PENDENTE". Uma linha
///  pendente que passou por aqui vindo de um master costuma estar no
///  placeholder, mas nao ha nada que a obrigue: o consumidor pode ter digitado
///  a chave, e nesse caso a recursao a partir dela escreve, e deve escrever.
///  Medido por Test.Janus.AutoInc.UngeneratedKey
///  .Local_AMidRowThatAlreadyCarriesItsKey_StillStampsTheGrandchild. </summary>
procedure TDataSetBaseAdapter<M>._RecurseOverChildRows(
  const AChildAdapter: TDataSetBaseAdapter<M>;
  const AMasterToken: Integer);
var
  LDataSet: TDataSet;
  LMarks: TList<TBookmark>;
  LMark: TBookmark;
  LOuterRows: Integer;
  LFor: Integer;
begin
  LDataSet := AChildAdapter.FOrmDataSet;
  if LDataSet = nil then
    Exit;
  if not LDataSet.Active then
    Exit;
  LMark := LDataSet.GetBookmark;
  LDataSet.DisableControls;
  LMarks := TList<TBookmark>.Create;
  LOuterRows := AChildAdapter.FCascadeMasterRows;
  try
    LDataSet.First;
    while not LDataSet.Eof do
    begin
      if _IsPendingInsertRow(LDataSet) and
         _IsOwnedByMasterRow(LDataSet, AMasterToken) then
        LMarks.Add(LDataSet.GetBookmark);
      LDataSet.Next;
    end;
    // QUANTOS MASTERS O NIVEL DE BAIXO VAI TER - issue #261. Para os netos, os
    // "masters pendentes" sao exatamente as linhas do meio que esta caminhada
    // vai percorrer, e este e o unico ponto onde esse numero existe. Sem ele o
    // nivel 3 herdaria o zero e um neto sem proveniencia voltaria a ser
    // escrito por cada linha do meio, em ordem, ficando com a ultima - o mesmo
    // defeito do nivel 2 um andar abaixo. Ver FCascadeMasterRows.
    // O RAMO SEM LINHA PENDENTE VALE 1, e nao 0: ele recursa UMA vez, de onde
    // o cursor estiver, portanto ha um master so e nada e ambiguo.
    // ESTA ATRIBUICAO SOBREVIVE A MUTACAO, e esta declarada em vez de
    // escondida. Medido em d01d4f3: apagando a linha, 547 verdes, zero
    // vermelhos. A razao e que 0 e 1 dao a MESMA resposta ao unico leitor -
    // _IsOwnedByMasterRow compara com <= 1 - e o campo do filho chega aqui em
    // 0 em todo caminho que a suite alcanca. Ela fica porque as duas
    // quantidades nao SIGNIFICAM a mesma coisa: 0 e "ninguem estabeleceu" e 1 e
    // "eu estabeleci, e e um". E SO ISSO.
    // UMA SEGUNDA JUSTIFICATIVA FOI ESCRITA AQUI E RETIRADA: "protege contra
    // reentrada com valor herdado maior que 1 numa hierarquia com ciclo".
    // Ciclo nao e construivel - TManagerDataSet.AddAdapter<T, M> sai cedo nos
    // dois sentidos, e o argumento esta escrito no cabecalho de
    // _AnyDetailRowOpen. Apoiar uma linha em algo que a casa ja mediu como
    // impossivel e pior do que nao justificar.
    if LMarks.Count = 0 then
    begin
      AChildAdapter.FCascadeMasterRows := 1;
      AChildAdapter.SetAutoIncValueChilds;
    end
    else
    begin
      AChildAdapter.FCascadeMasterRows := LMarks.Count;
      for LFor := 0 to LMarks.Count -1 do
      begin
        LDataSet.GotoBookmark(LMarks[LFor]);
        AChildAdapter.SetAutoIncValueChilds;
      end;
    end;
  finally
    // A SEGUNDA ATRIBUICAO QUE SOBREVIVE A MUTACAO, medida e declarada pelo
    // mesmo padrao da de cima, porque duas linhas sobreviventes no mesmo metodo
    // e uma so declarada seria escolher qual confessar. Medido em 0c5de92:
    // apagando esta restauracao, 547 verdes, zero vermelhos. Sobrevive porque
    // LOuterRows vale 0 em todo caminho que a suite alcanca - o campo do filho
    // so e escrito aqui - e porque quem roda depois, o ApplyInserter do proprio
    // nivel filho, estabelece o seu numero antes de ler. Ela fica pela regra
    // que vale para escrita em campo de OUTRO objeto: quem emprestou devolve.
    // Sem ela, o valor deste nivel vazaria para fora da caminhada e o proximo
    // leitor herdaria uma contagem que nao e a dele.
    AChildAdapter.FCascadeMasterRows := LOuterRows;
    if LDataSet.BookmarkValid(LMark) then
      LDataSet.GotoBookmark(LMark);
    LDataSet.FreeBookmark(LMark);
    LDataSet.EnableControls;
    LMarks.Free;
  end;
end;

/// <summary> Escreve a chave do master em cada linha elegivel do dataset filho.
///  Percorre por BOOKMARK de proposito: quando o filho esta indexado pela
///  propria coluna que esta sendo reescrita - o que
///  TFDMemTableAdapter<M>._GetIndexFieldNames produz para uma entidade cujo
///  [OrderBy] e a sua FK - o Post REORDENA a linha, e um laco Post+Next cai
///  fora do conjunto depois da primeira. Bookmark identifica a LINHA, nao a
///  posicao. Medido: Post+Next atualiza 1 de 3; por bookmark, 3 de 3. </summary>
procedure TDataSetBaseAdapter<M>._AutoIncToChildRows(const AMaster,
  AChild: TDataSet; const AAssociation: TAssociationMapping);
var
  LMasterFields: TList<TField>;
  LChildFields: TList<TField>;
  LMarks: TList<TBookmark>;
  LSource: TObject;
  LMasterField: TField;
  LChildField: TField;
  LMasterToken: Integer;
  LFor: Integer;
  LCol: Integer;
begin
  if (AMaster = nil) or (AChild = nil) then
    Exit;
  if not AChild.Active then
    Exit;
  LMasterFields := TList<TField>.Create;
  LChildFields := TList<TField>.Create;
  LMarks := TList<TBookmark>.Create;
  try
    for LFor := 0 to AAssociation.ColumnsName.Count -1 do
    begin
      if LFor > AAssociation.ColumnsNameRef.Count -1 then
        Break;
      LMasterField := AMaster.FindField(AAssociation.ColumnsName[LFor]);
      LChildField := AChild.FindField(AAssociation.ColumnsNameRef[LFor]);
      if (LMasterField = nil) or (LChildField = nil) then
        Continue;
      LMasterFields.Add(LMasterField);
      LChildFields.Add(LChildField);
    end;
    if LMasterFields.Count = 0 then
      Exit;
    // A identidade da linha de master sobre a qual estamos parados. Lida ANTES
    // de mexer no filho, porque e o cursor do master que a define.
    LMasterToken := _MasterRowToken(AMaster);
    LSource := _DetachMasterLink(AChild);
    AChild.DisableControls;
    try
      // 1a passada: marca as linhas elegiveis ANTES de escrever qualquer uma.
      // DOIS filtros, e nao um: pendente de insercao - senao a linha ja
      // pertence a outro master e gravado - E filha DESTA linha de master. O
      // segundo e o que impede que uma segunda linha de master pendente, na sua
      // propria passagem por ApplyInserter, reaponte os filhos da primeira.
      AChild.First;
      while not AChild.Eof do
      begin
        if _IsPendingInsertRow(AChild) and
           _IsOwnedByMasterRow(AChild, LMasterToken) then
          LMarks.Add(AChild.GetBookmark);
        AChild.Next;
      end;
      // 2a passada: carimba a chave nova em cada linha marcada.
      for LFor := 0 to LMarks.Count -1 do
      begin
        AChild.GotoBookmark(LMarks[LFor]);
        AChild.Edit;
        for LCol := 0 to LMasterFields.Count -1 do
          LChildFields[LCol].Value := LMasterFields[LCol].Value;
        AChild.Post;
      end;
    finally
      _RestoreMasterLink(AChild, LSource);
      AChild.First;
      AChild.EnableControls;
    end;
  finally
    LMarks.Free;
    LChildFields.Free;
    LMasterFields.Free;
  end;
end;

/// <summary> Diz se a chave que ESTA associacao propaga ja existe na linha
///  corrente, ou se ela ainda e o placeholder que toda chave primaria AutoInc
///  carrega ate o gerador responder - cAutoIncNotGenerated, escrito como
///  DefaultExpression por TBind.SetInternalInitFieldDefsObjectClass.
///
///  POR QUE ISTO E PRECISO - issue #262. _RecurseOverChildRows entra na
///  recursao com o cursor parado sobre uma linha do filho que esta PENDENTE DE
///  INSERCAO. Uma linha nessas condicoes NEM SEMPRE esta sem chave - o
///  consumidor pode ter digitado uma - mas quando ninguem digitou nada ela esta
///  no placeholder, que e o caso ordinario de uma chave AutoInc, e era esse
///  placeholder que a recursao copiava para a FK do neto. Medido nas duas
///  familias sobre
///  a arvore de tres niveis, com o neto semeado num valor que nenhuma linha do
///  meio carrega: LEAF.mid_id ia de -7 para -1 nas duas. Na familia local o
///  ApplyInserter do proprio nivel do meio reescreve o valor logo depois e o
///  estrago e transitorio; na familia REST nao ha nada depois -
///  TRESTFDMemTableAdapter<M>.ApplyInternal nao itera FMasterObject, o nivel do
///  meio nunca e aplicado sozinho, e o neto FICA com o placeholder como chave
///  estrangeira. Medido por Test.Janus.AutoInc.UngeneratedKey.
///
///  A GUARDA E SOBRE O VALOR, E NAO SOBRE O ESTADO DA LINHA, e a diferenca e o
///  conserto inteiro. "Nao recursar sobre linha pendente" seria mais simples e
///  estaria errado: uma linha pendente pode carregar uma chave que o consumidor
///  digitou, e os netos dela TEM de ser carimbados - e exatamente a forma de
///  Test.Janus.AutoInc.Childs.Linked_EveryGrandchildRowReceivesTheNewKey, que
///  aquela leitura derrubaria sozinha.
///
///  RESPONDE True QUANDO NAO HA PERGUNTA A FAZER: entidade sem chave primaria
///  mapeada, chave que nao e AutoInc - onde -1 pode ser uma chave legitima -,
///  associacao que nao nomeia nenhuma coluna da chave, coluna ausente do
///  dataset, ou coluna que nao e inteira, caso do ftGuid. Em todos esses o
///  placeholder nao existe como conceito e nada deve ser recusado.
///
///  O TESTE DE FCurrentInternal NAO ENTRA NESSA LISTA, e a distincao importa
///  para quem for mexer aqui: ele e INALCANCAVEL a partir do unico chamador que
///  existe. SetAutoIncValueChilds desreferencia FCurrentInternal.ClassType para
///  buscar a lista de associacoes ANTES de chamar este metodo, de modo que um
///  nil ja teria estourado la em cima. O ramo fica como defesa de um chamador
///  futuro, nao como uma resposta que alguem consegue provocar hoje - e por
///  isso remove-lo nao avermelha nada, o que esta declarado no log de mutacao
///  de Test.Janus.AutoInc.UngeneratedKey em vez de ficar parecendo cobertura.
///  </summary>
function TDataSetBaseAdapter<M>._AutoIncKeyIsGenerated(
  const AAssociation: TAssociationMapping): Boolean;
const
  cINTEGERKINDS = [ftInteger, ftSmallint, ftWord, ftLargeint, ftAutoInc,
                   ftLongWord, ftShortint, ftByte];
var
  LPrimaryKey: TPrimaryKeyMapping;
  LField: TField;
  LFor: Integer;
begin
  Result := True;
  if FCurrentInternal = nil then
    Exit;
  LPrimaryKey := TMappingExplorer
                   .GetMappingPrimaryKey(FCurrentInternal.ClassType);
  if LPrimaryKey = nil then
    Exit;
  if not LPrimaryKey.AutoIncrement then
    Exit;
  for LFor := 0 to AAssociation.ColumnsName.Count -1 do
  begin
    // So as colunas da associacao que SAO a chave primaria desta entidade. Uma
    // associacao que propaga outra coluna nao propaga uma chave gerada, e o
    // placeholder nao diz nada sobre ela.
    if LPrimaryKey.Columns.IndexOf(AAssociation.ColumnsName[LFor]) < 0 then
      Continue;
    LField := FOrmDataSet.FindField(AAssociation.ColumnsName[LFor]);
    if LField = nil then
      Continue;
    if not (LField.DataType in cINTEGERKINDS) then
      Continue;
    if LField.AsInteger = cAutoIncNotGenerated then
      Exit(False);
  end;
end;

procedure TDataSetBaseAdapter<M>.SetAutoIncValueChilds;
var
  LAssociation: TAssociationMapping;
  LAssociations: TAssociationMappingList;
  LDataSetChild: TDataSetBaseAdapter<M>;
  LMasterToken: Integer;
begin
  LAssociations := TMappingExplorer
                     .GetMappingAssociation(FCurrentInternal.ClassType);
  if LAssociations = nil then
    Exit;
  // Lida ANTES de mexer em qualquer filho, porque e o cursor do MASTER que a
  // define e nada abaixo o move. A mesma resposta vai para os dois filtros: o
  // de _AutoIncToChildRows, que decide QUAIS linhas do filho recebem a chave,
  // e o de _RecurseOverChildRows, que decide sobre quais delas a recursao
  // entra.
  LMasterToken := _MasterRowToken(FOrmDataSet);
  for LAssociation in LAssociations do
  begin
    if not (TCascadeAction.CascadeAutoInc in LAssociation.CascadeActions) then
      Continue;
    // A chave que esta associacao propaga tem de EXISTIR - issue #262. Quando a
    // linha corrente ainda esta no placeholder de AutoInc, nao ha o que
    // propagar, e escrever o placeholder na FK do filho e escrever uma chave
    // estrangeira invalida. Ver _AutoIncKeyIsGenerated.
    if not _AutoIncKeyIsGenerated(LAssociation) then
      Continue;
    // TryGetValue, nao Items[]: TDictionary.Items[] LEVANTA EListError quando a
    // chave nao existe, de modo que o teste de nil que vinha logo abaixo era
    // inalcancavel. Um model que declara CascadeAutoInc para uma classe cujo
    // dataset filho nunca foi criado derrubava a insercao do master.
    if not FMasterObject.TryGetValue(LAssociation.ClassNameRef,
                                     LDataSetChild) then
      Continue;
    if LDataSetChild = nil then
      Continue;
    // Eventos do filho desligados durante a escrita: o AfterScroll do adapter
    // filho chama OpenDataSetChilds, que RE-ABRE os netos a partir do banco.
    // Percorrer o filho com os eventos ligados apagaria os netos ainda nao
    // gravados antes que a recursao logo abaixo pudesse carimba-los.
    // O contrato novo (OnBeforeScrollPendingChilds) NAO substitui isto, e nao
    // ha dois mecanismos para um problema: aquele responde a uma rolagem do
    // MASTER feita pelo usuario; aqui ninguem esta rolando nada - quem anda no
    // cursor do filho e o proprio ApplyInserter, no meio de uma gravacao.
    // Medido: com o contrato novo no lugar, remover este par ainda derruba
    // Test.Janus.AutoInc.Childs.Linked_EveryGrandchildRowReceivesTheNewKey.
    // O que os dois compartilham e a TECNICA (DisableDataSetEvents), pela mesma
    // razao - e o detector de pendencia precisa dela tambem, medido por
    // Test.Janus.Scroll.PendingChilds.Detecting_DoesNotDestroyTheGrandchildren.
    LDataSetChild.DisableDataSetEvents;
    try
      _AutoIncToChildRows(FOrmDataSet, LDataSetChild.FOrmDataSet, LAssociation);
      // Populando em hierarquia de varios niveis: netos, bisnetos...
      // UMA VEZ POR LINHA do filho, e nao uma vez por adapter filho: o neto
      // pertence a uma linha determinada do meio, e so com o cursor do meio
      // parado sobre ela e que a chave que chega ao neto e a do pai dele.
      // O par de mute acima passou a cobrir tambem esta chamada porque agora
      // ela ANDA no cursor do filho, e andar com os eventos ligados dispara o
      // AfterScroll que reabre - e portanto apaga - os netos ainda nao
      // gravados.
      if LDataSetChild.FMasterObject.Count > 0 then
        _RecurseOverChildRows(LDataSetChild, LMasterToken);
    finally
      LDataSetChild.EnableDataSetEvents;
    end;
  end;
end;

procedure TDataSetBaseAdapter<M>._SetAutoNextPacket(const Value: Boolean);
begin
  FAutoNextPacket := Value;
end;

function TDataSetBaseAdapter<M>._GetCurrentPKAsString: String;
var
  LPKColumns: TPrimaryKeyColumnsMapping;
  LFor: Integer;
begin
  Result := '';
  LPKColumns := TMappingExplorer.GetMappingPrimaryKeyColumns(M);
  if LPKColumns = nil then
    Exit;
  for LFor := 0 to LPKColumns.Columns.Count - 1 do
  begin
    if LFor > 0 then
      Result := Result + '|';
    Result := Result + VarToStr(FOrmDataSet.FieldByName(LPKColumns.Columns[LFor].ColumnName).Value);
  end;
end;

procedure TDataSetBaseAdapter<M>.SetDataSetEvents;
begin
  FOrmDataSet.BeforeScroll := DoBeforeScroll;
  FOrmDataSet.AfterScroll  := DoAfterScroll;
  FOrmDataSet.BeforeClose  := DoBeforeClose;
  FOrmDataSet.BeforeOpen   := DoBeforeOpen;
  FOrmDataSet.AfterOpen    := DoAfterOpen;
  FOrmDataSet.AfterClose   := DoAfterClose;
  FOrmDataSet.BeforeDelete := DoBeforeDelete;
  FOrmDataSet.AfterDelete  := DoAfterDelete;
  FOrmDataSet.BeforeInsert := DoBeforeInsert;
  FOrmDataSet.AfterInsert  := DoAfterInsert;
  FOrmDataSet.BeforeEdit   := DoBeforeEdit;
  FOrmDataSet.AfterEdit    := DoAfterEdit;
  FOrmDataSet.BeforePost   := DoBeforePost;
  FOrmDataSet.AfterPost    := DoAfterPost;
  FOrmDataSet.OnNewRecord  := DoNewRecord;
end;

/// <summary> O SEGUNDO SITIO DA ISSUE #255, e o cast continua aqui de
///  proposito. Quem garante que FOwnerMasterObject e mesmo um adapter e
///  SetMasterObject, a unica escrita do campo alem do `:= nil` de Destroy.
///  O ARGUMENTO DE TIPO DO CAST E O DO DETALHE, e nao muda o que esta linha
///  faz: ClassType nasce do ponteiro de VMT do objeto lido, nao de
///  TypeInfo(M), de modo que quem chega a GetMappingAssociation e a classe
///  REAL do master. Medido por
///  Test.Janus.Manager.AddAdapter
///  .Recovery_TheObjectBehindTheDetailTypedCastIsTheMasterEntity. </summary>
procedure TDataSetBaseAdapter<M>._GetMasterValues;
var
  LAssociation: TAssociationMapping;
  LAssociations: TAssociationMappingList;
  LDataSetMaster: TDataSetBaseAdapter<M>;
  LField: TField;
  LFor: Integer;
begin
  if not Assigned(FOwnerMasterObject) then
    Exit;
  LDataSetMaster := TDataSetBaseAdapter<M>(FOwnerMasterObject);
  LAssociations := TMappingExplorer
                     .GetMappingAssociation(LDataSetMaster.FCurrentInternal.ClassType);
  if LAssociations = nil then
    Exit;
  for LAssociation in LAssociations do
  begin
    if not (TCascadeAction.CascadeAutoInc in LAssociation.CascadeActions) then
      Continue;
    for LFor := 0 to LAssociation.ColumnsName.Count -1 do
    begin
      LField := LDataSetMaster
                  .FOrmDataSet.FindField(LAssociation.ColumnsName.Items[LFor]);
      if LField = nil then
        Continue;
      FOrmDataSet
        .FieldByName(LAssociation.ColumnsNameRef
                                 .Items[LFor]).Value := LField.Value;
    end;
  end;
end;

/// <summary> A UNICA PORTA DE ENTRADA DE FOwnerMasterObject, e por isso o
///  unico lugar onde a checagem cabe. O campo tem exatamente duas escritas em
///  todo o repositorio - o `:= nil` de Destroy e a linha final deste metodo -
///  de modo que tudo que LE FOwnerMasterObject atraves de um cast, incluindo
///  _GetMasterValues e _EnsureMasterRowToken, passa a estar coberto por este
///  raise sem que nenhum deles precise repetir a pergunta.
///
///  O QUE O CAST ESCONDIA. TDataSetBaseAdapter&lt;M&gt;(AValue) e um cast duro
///  entre classes: nao pergunta nada ao objeto. Passar um objeto que NAO e
///  adapter fazia o metodo ler FMasterObject de dentro dele e chamar Add
///  naquilo - sem excecao, sem mensagem, e sem nada no fault que nomeie quem
///  foi passado. Medido comentando o raise abaixo e rodando
///  Test.Janus.Manager.AddAdapter
///  .MasterNotAnAdapter_IsRefusedByNameInsteadOfFaulting: com um objeto de
///  campos nulos no lugar do master, o que saiu foi
///  `EAccessViolation | ... Read of address 00000008` - o endereco do modulo
///  varia por build, o `00000008` nao: e FMasterObject lido como nil e usado
///  em seguida.
///
///  E ISSO NAO E TEORICO: TDataSetAdapter&lt;M&gt;.LoadLazy declara
///  `AOwner: M` - uma ENTIDADE - e entrega esse valor aqui, onde so um ADAPTER
///  serve. Os testes da casa passam o adapter do master com um cast para M
///  (`FMid.LoadLazy(TAitMid(FRoot.This))`); quem ler a declaracao e obedecer
///  a ela entrega uma entidade de verdade. Corrigir a DECLARACAO de LoadLazy e
///  mexer em superficie publica, o que a issue #255 reserva ao dono; recusar
///  o valor errado com nome nao e.
///
///  O QUE ESTE RAISE NAO CONSERTA. O argumento de tipo do cast continua sendo
///  o do DETALHE. Medido, nesta versao, como OBSERVACIONALMENTE inerte nos
///  dois sitios da issue #255: o que se le atraves do cast e FMasterObject
///  (chaves String e valores que sao referencia de classe em toda
///  instanciacao), FOrmDataSet (TDataSet, nao depende de M) e
///  FCurrentInternal, do qual so se pedem ClassName e ClassType - ambos
///  resolvidos pelo ponteiro de VMT do objeto, nao por TypeInfo(M).
///  OBSERVACIONALMENTE, E NAO `NENHUM TypeInfo(M) E ALCANCADO`, e a diferenca
///  e real: ContainsKey/Remove/TrimExcess/Add nao sao virtuais e ligam
///  ESTATICAMENTE ao codigo da instanciacao do DETALHE, rodando sobre o
///  dicionario do MASTER, e o Rehash interno entrega a RTL um TypeInfo
///  derivado de M. O que se mediu foi que isso nao muda comportamento, porque
///  o TItem e estruturalmente identico para todo M que a restricao
///  `M: class, constructor` admite - nao que o TypeInfo nao seja tocado.
///  Os offsets tambem nao sao o risco, e isso ja estava medido em
///  Layout_EveryInstantiationOfTheBaseAdapterAgreesOnEveryOffset. </summary>
procedure TDataSetBaseAdapter<M>.SetMasterObject(const AValue: TObject);
var
  LOwnerObject: TDataSetBaseAdapter<M>;
begin
  if FOwnerMasterObject = AValue then
    Exit;
  // ANTES DO BLOCO DE UNLINK ABAIXO, e a ordem e carga. Recusar depois dele
  // deixa uma chamada que FALHOU tendo removido o filho do FMasterObject do
  // master legitimo, com FOwnerMasterObject ainda apontando para um master
  // que nao lista mais o filho. Ancorado por Test.Janus.Manager.AddAdapter
  // .Refusal_LeavesTheLegitimateLinkExactlyAsItWas.
  // E `is TDataSetBaseAdapter<M>` NAO serve aqui - recusaria o master
  // legitimo, que e sempre de outra instanciacao. Ver _IsBaseAdapterInstance.
  if (AValue <> nil) and (not _IsBaseAdapterInstance(AValue)) then
    raise Exception.CreateFmt(cMASTERNOTADAPTER,
                              [FCurrentInternal.ClassName, AValue.ClassName]);
  if FOwnerMasterObject <> nil then
  begin
    LOwnerObject := TDataSetBaseAdapter<M>(FOwnerMasterObject);
    if LOwnerObject.FMasterObject.ContainsKey(FCurrentInternal.ClassName) then
    begin
      LOwnerObject.FMasterObject.Remove(FCurrentInternal.ClassName);
      LOwnerObject.FMasterObject.TrimExcess;
    end;
  end;
  if AValue <> nil then
    TDataSetBaseAdapter<M>(AValue).FMasterObject
                                  .Add(FCurrentInternal.ClassName, Self);

  FOwnerMasterObject := AValue;
end;

procedure TDataSetBaseAdapter<M>._ValideFieldEvents(
  const AFieldEvents: TFieldEventsMappingList);
var
  LFor: Integer;
  LField: TField;
begin
  for LFor := 0 to AFieldEvents.Count -1 do
  begin
    LField := FOrmDataSet.FindField(AFieldEvents.Items[LFor].FieldName);
    if LField = nil then
      Continue;

    if TFieldEvent.onSetText in AFieldEvents.Items[LFor].Events then
      if not Assigned(LField.OnSetText) then
        raise Exception.CreateFmt(cFIELDEVENTS, ['OnSetText()', LField.FieldName]);

    if TFieldEvent.onGetText in AFieldEvents.Items[LFor].Events then
      if not Assigned(LField.OnGetText) then
        raise Exception.CreateFmt(cFIELDEVENTS, ['OnGetText()', LField.FieldName]);

    if TFieldEvent.onChange in AFieldEvents.Items[LFor].Events then
      if not Assigned(LField.OnChange) then
        raise Exception.CreateFmt(cFIELDEVENTS, ['OnChange()', LField.FieldName]);

    if TFieldEvent.onValidate in AFieldEvents.Items[LFor].Events then
      if not Assigned(LField.OnValidate) then
        raise Exception.CreateFmt(cFIELDEVENTS, ['OnValidate()', LField.FieldName]);
  end;
end;

function TDataSetBaseAdapter<M>.Find(const AID: String): M;
begin
  Result := FSession.Find(AID);
end;

end.
