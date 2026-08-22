{
  ------------------------------------------------------------------------------
  Janus
  Modern Object-Relational Mapping (ORM) framework for Delphi.

  SPDX-License-Identifier: MIT
  Copyright (c) 2016-2026 Isaque Pinheiro

  Licensed under the MIT License.
  See the LICENSE file in the project root for full license information.
  ------------------------------------------------------------------------------
}

{ @abstract(Janus Framework - test fixture: an entity that records EVERY
  destruction OF EACH INSTANCE, keyed by the instance ADDRESS. Issue #362.)

  WHY A PER-POINTER LEDGER AND NOT A COUNTER

  Test.Janus.Model.OpenIdRow already counts destructions - one `class var
  DestroyCount` bumped by the destructor - and that instrument answers issue
  #328's question, which is "was the object the session built released at all".
  It cannot answer THIS one, which is "was the object THE CALLER PASSED
  released", because more than one instance of the entity exists during the
  call: TSessionRestFul<M>.Create builds a throwaway `M.Create` of its own to
  read the [Table]/[Resource] attributes off, and destroys it before the
  constructor returns. A flat counter cannot tell that instance's destruction
  from the caller's.

  A ledger keyed by the ADDRESS can, and the address is taken INSIDE the
  destructor, where Self is still a live object. Nothing outside ever
  dereferences a pointer it put in the ledger - that is the whole discipline
  the instrument exists to keep. A clause reads
  `TOwnedProbe.DestructionsOf(LPointer)`; it never reads `LProbe.tag` unless
  the ledger has just said the object is still alive.

  THE ONE WAY A PER-ADDRESS LEDGER CAN LIE, AND WHY IT DOES NOT HERE

  The memory manager reuses addresses. If the probe under test were freed and a
  SECOND TOwnedProbe happened to be allocated at the same address and freed
  too, the ledger would read 2 for what was really two different objects.

  Every clause avoids that by construction: the probe under test is created
  FIRST and is still alive while the adapter - and therefore the session's own
  throwaway instance - is built, so that instance cannot land on the probe's
  address. And the ledger is zeroed after the adapter exists, so nothing that
  happened during construction is counted at all.

  ONE UPDATABLE COLUMN, ONE GENERATED KEY

  `tag` is what proves the body that went out on the wire carries the object's
  own payload, so a repair that stops calling the session at all is not green.

  The key is AutoInc with a [Sequence] on purpose: that is what makes
  TSessionRestFul<M>.ExistSequence answer True, so an Insert driven with this
  entity runs the WHOLE of TRESTObjectSetAdapter<M>.Insert - the answer reader
  and the cascade included - rather than falling straight through the gate. The
  enumeration in issue #362 asks what each of the three methods does with the
  caller's object; asking it of a method that exited early would answer nothing.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Model.OwnedProbe;

interface

uses
  Classes,
  DB,
  SysUtils,
  Generics.Collections,
  MetaDbDiff.mapping.attributes,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Register;

type
  [Entity]
  [Table('ownedprobe', '')]
  [PrimaryKey('probe_id', TAutoIncType.AutoInc,
                          TGeneratorType.SequenceInc,
                          TSortingOrder.NoSort,
                          True, 'Primary key')]
  [Sequence('ownedprobe')]
  TOwnedProbe = class
  private
    Fprobe_id: Integer;
    Ftag: String;
  public
    /// <summary> How many times each ADDRESS has been destroyed since the last
    ///  ResetLedger. Owned by this unit; created and released by its
    ///  initialization/finalization. </summary>
    class var Ledger: TDictionary<Pointer, Integer>;
    /// <summary> Forget everything recorded so far. </summary>
    class procedure ResetLedger;
    /// <summary> How many times the instance that LIVED AT this address has
    ///  been destroyed. The argument is a bare address on purpose: a caller
    ///  that asked with an object reference would be holding a reference it
    ///  may not hold. </summary>
    class function DestructionsOf(const AInstance: Pointer): Integer;
    destructor Destroy; override;

    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('probe_id', ftInteger)]
    property probe_id: Integer read Fprobe_id write Fprobe_id;

    [Column('tag', ftString, 30)]
    property tag: String read Ftag write Ftag;
  end;

implementation

{ TOwnedProbe }

class procedure TOwnedProbe.ResetLedger;
begin
  if Ledger <> nil then
    Ledger.Clear;
end;

class function TOwnedProbe.DestructionsOf(const AInstance: Pointer): Integer;
begin
  Result := 0;
  if Ledger <> nil then
    if not Ledger.TryGetValue(AInstance, Result) then
      Result := 0;
end;

destructor TOwnedProbe.Destroy;
var
  LCount: Integer;
begin
  // Self is still a live object here, so taking its address is legal. This is
  // the ONLY place the address is produced; nothing ever dereferences it
  // afterwards.
  if Ledger <> nil then
  begin
    if not Ledger.TryGetValue(Pointer(Self), LCount) then
      LCount := 0;
    Ledger.AddOrSetValue(Pointer(Self), LCount + 1);
  end;
  inherited;
end;

initialization
  TOwnedProbe.Ledger := TDictionary<Pointer, Integer>.Create;
  TRegisterClass.RegisterEntity(TOwnedProbe);

finalization
  TOwnedProbe.Ledger.Free;
  TOwnedProbe.Ledger := nil;

end.
