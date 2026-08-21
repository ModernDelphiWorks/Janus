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

{ @abstract(Janus Framework - a root whose key comes from the CLIENT, over a
  child whose key comes from the SERVER. Issue #305.)

  WHY THIS SHAPE EXISTS, AND WHAT IT UNLOCKS

  TRESTDataSetAdapter<M>.ApplyInserter has THREE doors into the same silence,
  and until this unit existed only two of them could be driven by a test.

  The third is the `else` of `if FSession.ExistSequence`. ExistSequence is not a
  property of the model in any direct sense - it is set exactly once, inside
  TSQLCommandInserter<M>, in the arm that fires only when the primary key is
  AutoIncrement AND its generator is SequenceInc:

      FDMLAutoInc.ExistSequence := (FDMLAutoInc.Sequence <> nil);

  So a root declared TAutoIncType.NotInc / TGeneratorType.NoneInc never reaches
  that line, TDMLCommandFactory.ExistSequence keeps answering False, and the
  insert skips the whole stamping block. Every model this repository points at a
  REST adapter declares [Sequence], which is why the door had no fixture.

  AND THE DOOR IS NOT THE SAME SILENCE AS THE OTHER TWO

  The other two doors of the orphan case are about a key the client CANNOT
  learn: the answer brought no params, or brought params naming no column of
  this row, and either way the row sits on the server under a key nothing can
  ask for. Here the opposite is true - the root's key was typed by the operator
  before the save and is sitting in the dataset the whole time. A GET on
  `$filter=ckrroot_id=<that key>` would work. It simply is never issued, because
  the bookmark that buys the re-read is only ever added inside the ExistSequence
  block.

  That is why #305 gave this door a case of its own, sgcReReadNeverAttempted,
  rather than reusing sgcNoKeyToAskBy: the monitor sentence of the orphan case
  says the client will never know the key, and over THIS shape that sentence is
  simply false.

  WHAT MAKES THE CHILD STALE

  _RowKeyIsUngenerated asks TPrimaryKeyMapping.AutoIncrement, which
  TMappingPopular derives as `AutoIncType = TAutoIncType.AutoInc`. So the CHILD
  has to be AutoInc for the graph below the root to be stale at all - a root and
  a child both on NotInc (which is what Test.Janus.Model.NotIncKey already
  offers) answers "nothing is stale" and reaches no announcement. The asymmetry
  IS the fixture: client key above, server key below.

  ONE LEVEL IS ENOUGH. Depth is measured on Test.Janus.Model.AutoIncTree; the
  question here is which door of ApplyInserter the save goes through, and that
  is decided at the root.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Model.ClientKeyRoot;

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
  /// <summary> The child, and the only half of this pair the SERVER generates a
  ///  key for. AutoInc + SequenceInc + [Sequence] is what makes
  ///  TPrimaryKeyMapping.AutoIncrement answer True, which is what
  ///  _RowKeyIsUngenerated reads before it will call a placeholder a
  ///  placeholder. </summary>
  [Entity]
  [Table('ckrchild', '')]
  [PrimaryKey('ckrchild_id', TAutoIncType.AutoInc,
                             TGeneratorType.SequenceInc,
                             TSortingOrder.NoSort,
                             True, 'Primary key')]
  [Sequence('ckrchild')]
  TCkrChild = class
  private
    Fckrchild_id: Integer;
    Fckrroot_id: Integer;
    Ftag: String;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('ckrchild_id', ftInteger)]
    property ckrchild_id: Integer read Fckrchild_id write Fckrchild_id;

    /// The foreign key onto the root's client-supplied key.
    [Restrictions([TRestriction.NotNull])]
    [Column('ckrroot_id', ftInteger)]
    property ckrroot_id: Integer read Fckrroot_id write Fckrroot_id;

    [Column('tag', ftString, 20)]
    property tag: String read Ftag write Ftag;
  end;

  /// <summary> The root, and the whole point of the unit: NO [Sequence], and a
  ///  key the CLIENT supplies. TAutoIncType.NotInc with TGeneratorType.NoneInc
  ///  is the combination Test.Janus.Model.NotIncKey already uses for the same
  ///  purpose; what is new here is hanging a CascadeAutoInc child off it.
  ///
  ///  IT STILL CARRIES CascadeAutoInc, AND THAT IS NOT A CONTRADICTION. The
  ///  cascade action says "carry MY key down to this child's foreign key when I
  ///  am inserted", and a client-supplied key is still a key to carry. What the
  ///  root does not have is a key the SERVER generates - which is a different
  ///  question, and the one ExistSequence answers. </summary>
  [Entity]
  [Table('ckrroot', '')]
  [PrimaryKey('ckrroot_id', TAutoIncType.NotInc,
                            TGeneratorType.NoneInc,
                            TSortingOrder.NoSort,
                            True, 'Primary key')]
  TCkrRoot = class
  private
    Fckrroot_id: Integer;
    Ftag: String;
    Fchilds: TObjectList<TCkrChild>;
  public
    constructor Create;
    destructor Destroy; override;

    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('ckrroot_id', ftInteger)]
    property ckrroot_id: Integer read Fckrroot_id write Fckrroot_id;

    [Column('tag', ftString, 20)]
    property tag: String read Ftag write Ftag;

    [Association(TMultiplicity.OneToMany, 'ckrroot_id', 'ckrchild', 'ckrroot_id')]
    [CascadeActions([TCascadeAction.CascadeAutoInc,
                     TCascadeAction.CascadeInsert,
                     TCascadeAction.CascadeUpdate,
                     TCascadeAction.CascadeDelete])]
    property childs: TObjectList<TCkrChild> read Fchilds write Fchilds;
  end;

implementation

{ TCkrRoot }

constructor TCkrRoot.Create;
begin
  Fchilds := TObjectList<TCkrChild>.Create;
end;

destructor TCkrRoot.Destroy;
begin
  Fchilds.Free;
  inherited;
end;

initialization
  TRegisterClass.RegisterEntity(TCkrChild);
  TRegisterClass.RegisterEntity(TCkrRoot);

end.
