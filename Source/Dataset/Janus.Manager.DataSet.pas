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

{$INCLUDE ..\Janus.inc}

unit Janus.Manager.DataSet;

interface

{ ONE CHOICE, TWO DIRECTIVES - WHY THIS UNIT REFUSES TO BUILD ON TWO OF THE FOUR
  COMBINATIONS

  Which in-memory dataset this unit talks to is decided in two places, and the
  two places do not ask the same question.

    INCLUSION - the uses clause below brings FireDAC.Comp.Client and the
    FDMemTable adapter unit in under USEFDMEMTABLE, and DBClient and the
    ClientDataSet adapter unit in under USECLIENTDATASET. Two independent
    IFDEFs.

    SELECTION - both AddAdapter overloads name the adapter under USEFDMEMTABLE
    alone, with the ClientDataSet adapter sitting in that directive's ELSE arm.
    TManagerDataSet.ResolverDataSetType is not the selection: it is a pair of
    type gates, one compiled in by USEFDMEMTABLE and one by USECLIENTDATASET.

  So USECLIENTDATASET governs INCLUSION only - it never selects anything - and
  USEFDMEMTABLE being ABSENT is what selects the ClientDataSet adapter.

  THE FOUR COMBINATIONS, EACH ONE COMPILED AND RUN - NOT READ OFF THE SOURCE

  Measured on Janus.Tests.Units, the local branch, by moving the Janus.inc
  toggles and the project DCC_Define. The same four answers came back from
  Janus.Tests.RESTfulDriver, which compiles this unit with DRIVERRESTFUL on.

    FDMemTable, the shipped default - Janus.inc as delivered, nothing added by
    the project. Builds; suite green.

    ClientDataSet - reached EITHER by uncommenting USECLIENTDATASET in
    Janus.inc OR by carrying it in a project DCC_Define. Both routes build and
    both run the whole suite green: AddAdapter<T> registers a
    TClientDataSetAdapter, AddAdapter<T, M> links detail to master, and opening
    the master opens the detail. This is a fully working configuration, not a
    tolerated one.

    BOTH defined - builds only if this guard is removed, and then nothing works.
    Both type gates compile in and no one dataset satisfies both: measured
    inside a SINGLE binary, a TClientDataSet raises `Is not TFDMemTable type`
    and a TFDMemTable raises `Is not TClientDataSet type`. Every AddAdapter call
    raises, whatever it is handed. The ClientDataSet unit is dragged into the
    binary and its adapter is still never constructed, because selection sits on
    the FDMemTable arm.

    NEITHER defined - does not build. The ELSE arm of both AddAdapter overloads
    names an adapter class no uses clause brought in: E2003 Undeclared
    identifier, twice, plus the parse noise that follows. The IFNDEF
    USEMEMDATASET arm of ResolverDataSetType, whose whole purpose is to say
    `Enable the directive USEFDMEMTABLE or USECLIENTDATASET`, is compiled in
    exactly here and can therefore never run - the unit it lives in cannot be
    built when it applies. It is left in place: dead code is not behaviour, and
    removing it is not what this guard is for.

  WHAT REACHES THE BOTH-DEFINED COMBINATION, AND WHAT NO LONGER DOES

  Janus.inc defines USEFDMEMTABLE only when USECLIENTDATASET is not, so neither
  supported route can produce it. JanusInstall cannot: TFDMemTable and
  TClientDataSet are two TRadioButtons in one parent whose OnClick handlers
  clear each other, and the two lines it rewrites are the two toggles. A project
  DCC_Define cannot either, because adding USECLIENTDATASET now takes
  USEFDMEMTABLE away with it.

  That last part is a change, and it is the reason this guard is not a trap. A
  DCC_Define can only ADD a symbol; while Janus.inc defined USEFDMEMTABLE
  unconditionally, a project asking for USECLIENTDATASET got BOTH - the dead
  combination - and five Example .dproj files under Examples/Delphi/Data did
  exactly that, all five of them using TClientDataSet. They now reach the
  working ClientDataSet configuration instead, and this guard never fires for
  them. What is left to reach the both-defined state is forcing USEFDMEMTABLE
  from outside as well - measured, and what this guard stops.

  The technique is the one Janus.Tests.RESTfulDriver already uses to refuse to
  build without DRIVERRESTFUL instead of quietly becoming a smaller green suite.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`. }
{$IFDEF USEFDMEMTABLE}
  {$IFDEF USECLIENTDATASET}
    {$MESSAGE FATAL 'USEFDMEMTABLE and USECLIENTDATASET are both defined - one choice with two values, not two switches. Every AddAdapter call would raise, whichever dataset it got. Janus.inc defines one only when the other is not, so something outside forced both. Drop one.'}
  {$ENDIF}
{$ENDIF}
{$IFNDEF USEFDMEMTABLE}
  {$IFNDEF USECLIENTDATASET}
    {$MESSAGE FATAL 'Neither USEFDMEMTABLE nor USECLIENTDATASET is defined - TManagerDataSet has no in-memory dataset to build an adapter over. Define exactly ONE of them in Janus.inc. Without this message the build fails below with E2003 on the unincluded adapter class.'}
  {$ENDIF}
{$ENDIF}

uses
  DB,
  Rtti,
  SysUtils,
  Generics.Collections,
  {$IFDEF USEFDMEMTABLE}
    FireDAC.Comp.Client,
    {$IFDEF DRIVERRESTFUL}
      Janus.RestDataSet.FDMemTable
    {$ELSE}
      Janus.DataSet.FDMemTable
    {$ENDIF},
  {$ENDIF}

  {$IFDEF USECLIENTDATASET}
    DBClient,
    {$IFDEF DRIVERRESTFUL}
      Janus.RestDataSet.ClientDataSet
    {$ELSE}
      Janus.DataSet.ClientDataSet
    {$ENDIF},
  {$ENDIF}

  // Janus Interface
  {$IFDEF DRIVERRESTFUL}
    Janus.RestFactory.Interfaces
  {$ELSE}
    DataEngine.FactoryInterfaces
  {$ENDIF},
  Janus.DataSet.Base.Adapter;

type
  {$IFDEF DRIVERRESTFUL}
    IMDConnection = IRESTConnection
  {$ELSE}
    IMDConnection = IDBConnection
  {$ENDIF};

  TManagerDataSet = class
  private
    FConnection: IMDConnection;
    FRepository: TDictionary<String, TObject>;
    FNestedList: TDictionary<String, TObjectList<TObject>>;
    FOwnerNestedList: Boolean;
    function Resolver<T: class, constructor>: TDataSetBaseAdapter<T>;
    procedure ResolverDataSetType(const ADataSet: TDataSet);
  public
    constructor Create(const AConnection: IMDConnection);
    destructor Destroy; override;
    {$IFNDEF DRIVERRESTFUL}
    procedure NextPacket<T: class, constructor>;
    function GetAutoNextPacket<T: class, constructor>: Boolean;
    procedure SetAutoNextPacket<T: class, constructor>(const AValue: Boolean);
    {$ENDIF}
    procedure RemoveAdapter<T: class>;
    function AddAdapter<T: class, constructor>(const ADataSet: TDataSet;
      const APageSize: Integer = -1): TManagerDataSet; overload;
    function AddAdapter<T, M: class, constructor>(const ADataSet: TDataSet): TManagerDataSet; overload;
    function AddLookupField<T, M: class, constructor>(const AFieldName: String;
                                                      const AKeyFields: String;
                                                      const ALookupKeyFields: String;
                                                      const ALookupResultField: String;
                                                      const ADisplayLabel: String = ''): TManagerDataSet;
    procedure Open<T: class, constructor>; overload;
    procedure Open<T: class, constructor>(const AID: Integer); overload;
    procedure Open<T: class, constructor>(const AID: String); overload;
    procedure OpenWhere<T: class, constructor>(const AWhere: String; const AOrderBy: String = '');
    procedure Close<T: class, constructor>;
    procedure LoadLazy<T: class, constructor>(const AOwner: T);
    procedure RefreshRecord<T: class, constructor>;
    procedure EmptyDataSet<T: class, constructor>;
    procedure CancelUpdates<T: class, constructor>;
    procedure ApplyUpdates<T: class, constructor>(const MaxErros: Integer);
    procedure Save<T: class, constructor>(AObject: T);
    function Current<T: class, constructor>: T;
    function DataSet<T: class, constructor>: TDataSet;
    // ObjectSet
    function Find<T: class, constructor>: TObjectList<T>; overload;
    function Find<T: class, constructor>(const AID: TValue): T; overload;
    function FindWhere<T: class, constructor>(const AWhere: String;
                                              const AOrderBy: String = ''): TObjectList<T>;
    function NestedList<T: class>: TObjectList<T>;
    function AutoNextPacket<T: class, constructor>(const AValue: Boolean): TManagerDataSet;
    property OwnerNestedList: Boolean read FOwnerNestedList write FOwnerNestedList;
  end;

implementation

{ TManagerDataSet }

constructor TManagerDataSet.Create(const AConnection: IMDConnection);
begin
  FConnection := AConnection;
  FRepository := TObjectDictionary<String, TObject>.Create([doOwnsValues]);
  FNestedList := TObjectDictionary<String, TObjectList<TObject>>.Create([doOwnsValues]);
  FOwnerNestedList := False;
end;

destructor TManagerDataSet.Destroy;
begin
  FNestedList.Free;
  FRepository.Free;
  inherited;
end;

function TManagerDataSet.Current<T>: T;
begin
  Result := Resolver<T>.Current;
end;

function TManagerDataSet.NestedList<T>: TObjectList<T>;
var
  LClassName: String;
begin
  Result := nil;
  LClassName := TClass(T).ClassName;
  if FNestedList.ContainsKey(LClassName) then
    Result := TObjectList<T>(FNestedList.Items[LClassName]);
end;

function TManagerDataSet.DataSet<T>: TDataSet;
begin
  Result := Resolver<T>.FOrmDataSet;
end;

procedure TManagerDataSet.EmptyDataSet<T>;
begin
  Resolver<T>.EmptyDataSet;
end;

function TManagerDataSet.Find<T>(const AID: TValue): T;
begin
  if AID.IsType<integer> then
    Result := Resolver<T>.Find(AID.AsType<integer>)
  else
  if AID.IsType<String> then
    Result := Resolver<T>.Find(AID.ToString)
  else
    raise Exception.Create('Invalid parameter type');
end;

function TManagerDataSet.Find<T>: TObjectList<T>;
var
  LObjectList: TObjectList<T>;
begin
  Result := nil;
  if not FOwnerNestedList then
  begin
    Result := Resolver<T>.Find;
    Exit;
  end;
  LObjectList := Resolver<T>.Find;
  // Limpa a lista de objectos
  FNestedList.AddOrSetValue(TClass(T).ClassName, TObjectList<TObject>(LObjectList));
end;

procedure TManagerDataSet.CancelUpdates<T>;
begin
  Resolver<T>.CancelUpdates;
end;

/// <summary> Closes the dataset - the manager's half of the same change made
///  in TContainerDataSet<M>.Close, and for the same measured reason: closing
///  used to be a one-way door because every open path starts with EmptyDataSet
///  and EmptyDataSet raises on a closed dataset.
///  TDataSetBaseAdapter<M>.EnsureOpen is what makes the way back exist.
///  TManagerDataSet.EmptyDataSet<T> still clears without closing - measured
///  side by side in Test.Janus.Reopen.Lazy
///  .Close_EmptyDataSetStillClearsWithoutClosing.
///  Pinned by Test.Janus.Reopen.Lazy
///  .Close_TheManagerNowLeavesTheDataSetClosed. </summary>
procedure TManagerDataSet.Close<T>;
begin
  Resolver<T>.Close;
end;

procedure TManagerDataSet.LoadLazy<T>(const AOwner: T);
begin
  Resolver<T>.LoadLazy(AOwner);
end;

/// <summary> Registers the adapter for the DETAIL class T and links it to the
///  adapter already registered for the MASTER class M.
///
///  WHY THE MASTER IS HELD AS TObject AND NOT AS AN ADAPTER TYPE
///
///  The object filed under the master's class name is a
///  TDataSetBaseAdapter&lt;M&gt;, never a TDataSetBaseAdapter&lt;T&gt;: it was
///  put there by an earlier AddAdapter call whose own T was this method's M.
///  Two instantiations of one generic class are unrelated types in Delphi, so
///  naming the wrong one costs a hard cast, and a hard cast between class
///  types is unchecked - it compiles to nothing and asks the object nothing.
///
///  It is also unnecessary here, which is what the declaration below records.
///  This method does exactly two things with the value: compare it against nil
///  and hand it over as the fourth constructor argument. That parameter is
///  declared AMasterObject: TObject in all four constructors this method can
///  select - TFDMemTableAdapter&lt;T&gt;, TClientDataSetAdapter&lt;T&gt;,
///  TRESTFDMemTableAdapter&lt;T&gt; and TRESTClientDataSetAdapter&lt;T&gt; -
///  and stays TObject the whole way down, through
///  TDataSetBaseAdapter&lt;M&gt;.Create into
///  TDataSetBaseAdapter&lt;M&gt;.SetMasterObject. No member of the value is
///  read here and no method of it is called here. TObject is therefore the
///  honest type, and the compiler now refuses the member access that the hard
///  cast used to wave through.
///
///  WHAT THIS DOES NOT FIX
///
///  The cross-instantiation aliasing itself lives elsewhere and is untouched:
///  TDataSetBaseAdapter&lt;M&gt;.SetMasterObject and
///  TDataSetBaseAdapter&lt;M&gt;._GetMasterValues both cast FOwnerMasterObject
///  to their OWN instantiation and then read fields through it. Removing the
///  cast here removes this method from that family; it does not remove the
///  family.
///
///  THE SILENT EXITS ARE THE SHIPPED BEHAVIOUR
///
///  Three of them: T already registered, M not registered, and the master
///  entry being nil. None of them raises and none of them reports, so a caller
///  that misspells the master or registers it after the detail walks away with
///  no adapter.
///
///  The silence lasts exactly one statement, which is worth knowing before
///  anyone decides whether it is acceptable. DataSet&lt;T&gt; is
///  `Result := Resolver&lt;T&gt;.FOrmDataSet` and Resolver&lt;T&gt; returns nil
///  for a class it never registered, so the next call the caller makes on the
///  detail dereferences nil - measured on Win32 as EAccessViolation, with
///  nothing in it naming the master that was misspelled.
///
///  All of that is measured, none of it is endorsed: changing it would change
///  what every existing consumer sees, and that is the maintainer's call.
///  Pinned as it stands by Test.Janus.Manager.AddAdapter
///  .MasterMissing_ItExitsSilentlyAndRegistersNothing,
///  .MasterMissing_TheNextCallOnTheDetailDereferencesNil and
///  .DetailTwice_TheSecondCallIsANoOpAndTheFirstDataSetSurvives. </summary>
function TManagerDataSet.AddAdapter<T, M>(const ADataSet: TDataSet): TManagerDataSet;
var
  LDataSetAdapter: TDataSetBaseAdapter<T>;
  LMaster: TObject;
  LClassName: String;
  LMasterName: String;
begin
  Result := Self;
  LClassName := TClass(T).ClassName;
  LMasterName := TClass(M).ClassName;
  if FRepository.ContainsKey(LClassName) then
    Exit;
  if not FRepository.ContainsKey(LMasterName) then
    Exit;
  LMaster := FRepository.Items[LMasterName];
  if LMaster = nil then
    Exit;

  // Checagem do tipo do dataset definido para uso
  ResolverDataSetType(ADataSet);
  {$IFDEF DRIVERRESTFUL}
    {$IFDEF USEFDMEMTABLE}
      LDataSetAdapter := TRESTFDMemTableAdapter<T>
                           .Create(FConnection, ADataSet, -1, LMaster);
    {$ELSE}
      LDataSetAdapter := TRESTClientDataSetAdapter<T>
                           .Create(FConnection, ADataSet, -1, LMaster);
    {$ENDIF}
  {$ELSE}
    {$IFDEF USEFDMEMTABLE}
      LDataSetAdapter := TFDMemTableAdapter<T>
                           .Create(FConnection, ADataSet, -1, LMaster);
    {$ELSE}
      LDataSetAdapter := TClientDataSetAdapter<T>
                           .Create(FConnection, ADataSet, -1, LMaster);
    {$ENDIF}
  {$ENDIF}
  // Adiciona o container ao repositorio
  FRepository.Add(LClassName, LDataSetAdapter);
end;

function TManagerDataSet.AddAdapter<T>(const ADataSet: TDataSet;
  const APageSize: Integer): TManagerDataSet;
var
  LDataSetAdapter: TDataSetBaseAdapter<T>;
  LClassName: String;
begin
  Result := Self;
  LClassName := TClass(T).ClassName;
  if FRepository.ContainsKey(LClassName) then
    Exit;

  // Checagem do tipo do dataset definido para uso
  ResolverDataSetType(ADataSet);
  {$IFDEF DRIVERRESTFUL}
    {$IFDEF USEFDMEMTABLE}
      LDataSetAdapter := TRESTFDMemTableAdapter<T>
                           .Create(FConnection, ADataSet, APageSize, nil);
    {$ELSE}
      LDataSetAdapter := TRESTClientDataSetAdapter<T>
                           .Create(FConnection, ADataSet, APageSize, nil);
    {$ENDIF}
  {$ELSE}
    {$IFDEF USEFDMEMTABLE}
      LDataSetAdapter := TFDMemTableAdapter<T>
                           .Create(FConnection, ADataSet, APageSize, nil);
    {$ELSE}
      LDataSetAdapter := TClientDataSetAdapter<T>
                           .Create(FConnection, ADataSet, APageSize, nil);
    {$ENDIF}
  {$ENDIF}
  // Adiciona o container ao repositorio
  FRepository.Add(LClassName, LDataSetAdapter);
end;

function TManagerDataSet.AddLookupField<T, M>(
  const AFieldName, AKeyFields: String;
  const ALookupKeyFields, ALookupResultField, ADisplayLabel: String): TManagerDataSet;
var
  LObject: TDataSetBaseAdapter<M>;
begin
  Result := Self;
  LObject := Resolver<M>;
  if LObject = nil then
    Exit;
  Resolver<T>.AddLookupField(AFieldName,
                             AKeyFields,
                             LObject,
                             ALookupKeyFields,
                             ALookupResultField,
                             ADisplayLabel);
end;

procedure TManagerDataSet.ApplyUpdates<T>(const MaxErros: Integer);
begin
  Resolver<T>.ApplyUpdates(MaxErros);
end;

function TManagerDataSet.AutoNextPacket<T>(const AValue: Boolean): TManagerDataSet;
begin
  Resolver<T>.AutoNextPacket := AValue;
end;

procedure TManagerDataSet.Open<T>(const AID: String);
begin
  Resolver<T>.OpenIDInternal(AID);
end;

procedure TManagerDataSet.OpenWhere<T>(const AWhere,
  AOrderBy: String);
begin
  Resolver<T>.OpenWhereInternal(AWhere, AOrderBy);
end;

procedure TManagerDataSet.Open<T>(const AID: Integer);
begin
  Resolver<T>.OpenIDInternal(AID);
end;

procedure TManagerDataSet.Open<T>;
begin
  Resolver<T>.OpenSQLInternal('');
end;

procedure TManagerDataSet.RefreshRecord<T>;
begin
  Resolver<T>.RefreshRecord;
end;

procedure TManagerDataSet.RemoveAdapter<T>;
var
  LClassName: String;
begin
  LClassName := TClass(T).ClassName;
  if not FRepository.ContainsKey(LClassName) then
    Exit;

  FRepository.Remove(LClassName);
  FRepository.TrimExcess;
end;

/// <summary> Hands back the adapter registered for T, or nil.
///
///  THE CAST HERE IS NOT THE ONE AddAdapter&lt;T, M&gt; CARRIED - DO NOT
///  UNIFORMISE THE TWO
///
///  The two read the same dictionary and the two spell the same thing, and
///  they are still different. AddAdapter&lt;T, M&gt; looked up the MASTER key
///  and named T, so the stored object was an instantiation the name did not
///  describe. This one looks up T's OWN key. Every write to FRepository in this
///  unit is a Add(TClass(T).ClassName, adapter) whose value is typed
///  TDataSetBaseAdapter&lt;T&gt; for the SAME T that produced the key - there
///  are exactly two such writes, one in each AddAdapter overload, and no other
///  member of this class puts anything in. So the type named here is the type
///  stored, and the cast is a widening the compiler simply cannot express for a
///  TObject-valued dictionary.
///
///  It is left as a hard cast, not turned into `as`. A checked cast that can
///  never fire is a claim no test can defend: to make it fire, an object of
///  another class would have to be stored under T's key, and nothing in this
///  unit can do that.
///
///  ONE WAY IT COULD FIRE, WHICH IS A DIFFERENT DEFECT AND IS NOT FIXED HERE
///
///  The key is ClassName - the SHORT name, not the qualified one. Two entity
///  classes called the same thing in two different units share a key. The
///  second AddAdapter&lt;T&gt; for such a pair takes its
///  `already registered` exit and registers nothing, and Resolver&lt;T&gt; then
///  answers for the SECOND class with the FIRST class's adapter - which is the
///  wrong instantiation again, by a different route. Read out of this unit and
///  NOT observed: no such pair exists in this repository to run it on, so
///  nothing here claims to have observed one.
///
///  And the grep that appears to contradict that does not. Counting every
///  `T... = class` under Source, Test and Examples: 30 short names occur more
///  than once, but 22 of those are copies of the SAME unit name in different
///  folders, which cannot both reach one binary, and the remaining 8 are forms,
///  data modules and resource classes - not one of them decorated [Entity], so
///  not one of them can ever be a T here. Entity classes sharing a short name
///  across differently-named units: zero. </summary>
function TManagerDataSet.Resolver<T>: TDataSetBaseAdapter<T>;
var
  LClassName: String;
begin
  Result := nil;
  LClassName := TClass(T).ClassName;
  if FRepository.ContainsKey(LClassName) then
    Result := TDataSetBaseAdapter<T>(FRepository.Items[LClassName]);
end;

procedure TManagerDataSet.ResolverDataSetType(const ADataSet: TDataSet);
begin
  {$IFDEF USEFDMEMTABLE}
    if not (ADataSet is TFDMemTable) then
      raise Exception.Create('Is not TFDMemTable type');
  {$ENDIF}
  {$IFDEF USECLIENTDATASET}
    if not (ADataSet is TClientDataSet) then
      raise Exception.Create('Is not TClientDataSet type');
  {$ENDIF}
  {$IFNDEF USEMEMDATASET}
    raise Exception.Create('Enable the directive "USEFDMEMTABLE" or "USECLIENTDATASET" in file Janus.inc');
  {$ENDIF}
end;

procedure TManagerDataSet.Save<T>(AObject: T);
begin
  Resolver<T>.Save(AObject);
end;

function TManagerDataSet.FindWhere<T>(const AWhere, AOrderBy: String): TObjectList<T>;
var
  LObjectList: TObjectList<T>;
begin
  Result := nil;
  if not FOwnerNestedList then
  begin
    Result := Resolver<T>.FindWhere(AWhere, AOrderBy);
    Exit;
  end;
  LObjectList := Resolver<T>.FindWhere(AWhere, AOrderBy);
  // Limpa a lista de objectos
  FNestedList.AddOrSetValue(TClass(T).ClassName, TObjectList<TObject>(LObjectList));
end;

{$IFNDEF DRIVERRESTFUL}
procedure TManagerDataSet.NextPacket<T>;
begin
  Resolver<T>.NextPacket;
end;

function TManagerDataSet.GetAutoNextPacket<T>: Boolean;
begin
  Result := Resolver<T>.AutoNextPacket;
end;

procedure TManagerDataSet.SetAutoNextPacket<T>(const AValue: Boolean);
begin
  Resolver<T>.AutoNextPacket := AValue;
end;
{$ENDIF}

end.
