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

{ @abstract(Janus Framework - test fixture: a flat entity that COUNTS ITS OWN
  DESTRUCTIONS. Issue #328.)

  WHY A NEW MODEL AND NOT ONE OF THE EXISTING ONES

  What issue #328 is about is an object that the session BUILDS and the caller
  then throws away: TRESTClientDataSetAdapter<M>.OpenIDInternal called
  FSession.Find and dropped the result on the floor. Two of the three
  consequences are observable through the dataset, but the third - the found
  object is never freed - is only observable from the object itself. No entity
  already in Common\ counts its destructions, and adding the counter to one of
  them would change a type that four other fixtures share.

  The counter is a class var on purpose: JsonFlow builds the instance inside
  TJanusJson.JsonToObject<T>, so the test never holds the reference and cannot
  hook the instance any other way.

  ONE UPDATABLE COLUMN IS PART OF THE POINT. `tag` is what proves the row that
  reached the dataset carries the SERVER's payload and not a blank record the
  adapter appended on its own.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Model.OpenIdRow;

interface

uses
  Classes,
  DB,
  SysUtils,
  MetaDbDiff.mapping.attributes,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Register;

type
  [Entity]
  [Table('openidrow', '')]
  [PrimaryKey('oid', TAutoIncType.NotInc,
                     TGeneratorType.NoneInc,
                     TSortingOrder.NoSort,
                     True,
                     'Simple integer key - what OpenIDInternal is asked for')]
  TOpenIdRow = class
  private
    Foid: Integer;
    Ftag: String;
  public
    /// <summary> How many TOpenIdRow instances have been destroyed since the
    ///  test last zeroed it. A test that drives a path which is SUPPOSED to
    ///  own and release the object it received reads this to say whether the
    ///  release happened at all. </summary>
    class var DestroyCount: Integer;
    destructor Destroy; override;

    [Restrictions([TRestriction.NotNull])]
    [Column('oid', ftInteger)]
    property oid: Integer read Foid write Foid;

    [Column('tag', ftString, 30)]
    property tag: String read Ftag write Ftag;
  end;

implementation

{ TOpenIdRow }

destructor TOpenIdRow.Destroy;
begin
  Inc(DestroyCount);
  inherited;
end;

initialization
  TRegisterClass.RegisterEntity(TOpenIdRow);

end.
