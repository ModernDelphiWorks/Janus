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

{ @abstract(Janus Framework - test fixture: entities that map a column under one
  of the names Janus reserved for row provenance.)

  WHY THIS EXISTS

  TBind.SetInternalInitFieldDefsObjectClass creates cRowTokenField and
  cOwnerTokenField on EVERY dataset the framework opens. That made those two
  names RESERVED, and an entity that had been mapping a column called ROWTOKEN
  or OWNERTOKEN since before issue #261 now collides with them. The mapped
  columns above are created under a FindField, so they are the ones that would
  win the race and the internal creation would be the one to fail. Taking the
  guard out and running the test MEASURES what that failure says: "A component
  named RowToken already exists", from TComponent, raised inside an adapter
  constructor, with nothing about a reservation in it.

  TWO entities and not one, because the reservation is TWO names and a guard
  written for the first one only would look complete. The columns are spelled in
  a DIFFERENT CASE from the constants on purpose: TDataSet.FindField is
  case-insensitive, so an entity that spells it `rowtoken` collides just as hard
  as one that spells it `RowToken`, and a guard that compared strings itself
  could miss that.

  NOTHING ELSE uses these entities. They are never opened successfully - the
  point of the fixture is the exception - so they carry the smallest shape a
  registered entity can have.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Model.ReservedColumn;

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
  [Table('resrowtoken', '')]
  [PrimaryKey('res_id', TAutoIncType.AutoInc,
                        TGeneratorType.SequenceInc,
                        TSortingOrder.NoSort,
                        True, 'Primary key')]
  [Sequence('resrowtoken')]
  TResRowToken = class
  private
    Fres_id: Integer;
    Frowtoken: Integer;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('res_id', ftInteger)]
    property res_id: Integer read Fres_id write Fres_id;

    /// Lower case on purpose - see the header.
    [Column('rowtoken', ftInteger)]
    property rowtoken: Integer read Frowtoken write Frowtoken;
  end;

  [Entity]
  [Table('resownertoken', '')]
  [PrimaryKey('res_id', TAutoIncType.AutoInc,
                        TGeneratorType.SequenceInc,
                        TSortingOrder.NoSort,
                        True, 'Primary key')]
  [Sequence('resownertoken')]
  TResOwnerToken = class
  private
    Fres_id: Integer;
    Fownertoken: Integer;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('res_id', ftInteger)]
    property res_id: Integer read Fres_id write Fres_id;

    /// Lower case on purpose - see the header.
    [Column('ownertoken', ftInteger)]
    property ownertoken: Integer read Fownertoken write Fownertoken;
  end;

implementation

initialization
  TRegisterClass.RegisterEntity(TResRowToken);
  TRegisterClass.RegisterEntity(TResOwnerToken);

end.
