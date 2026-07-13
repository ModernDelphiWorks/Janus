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

{ @abstract(Janus Framework — test fixture.)

  Canonical KEY-ONLY detail entity: BOTH columns form the composite primary key
  and are NoUpdate — there is NO updatable column. The composite PK is declared
  the canonical way: a SINGLE [PrimaryKey] with a ';'-separated column list
  (see Examples\...\Object Lazy\Model.Exame.pas). This mirrors the shape of the
  live entities E13_F01 / EPV_F02 / R01_F01 (a junction/detail table whose only
  columns are its key). A no-op Update on such an entity used to raise the RTL
  EListError 'Item not found' on the ObjectSet path. }

unit Test.Janus.Model.KeyOnly;

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
  [Table('keyonly', '')]
  [PrimaryKey('k1;k2', 'Composite key (canonical single-attribute declaration)')]
  TKeyOnly = class
  private
    Fk1: Integer;
    Fk2: Integer;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('k1', ftInteger)]
    property k1: Integer read Fk1 write Fk1;

    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('k2', ftInteger)]
    property k2: Integer read Fk2 write Fk2;
  end;

implementation

initialization
  TRegisterClass.RegisterEntity(TKeyOnly);

end.
