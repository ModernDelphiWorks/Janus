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

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Janus.Model.ReadOnly;

interface

uses
  Classes,
  DB,
  SysUtils,
  Generics.Collections,
  /// orm
  MetaDbDiff.mapping.attributes,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Register;

type
  // [RESTReadOnly] blocks POST, PUT, and DELETE at the framework level.
  // Only GET operations are permitted for entities decorated with this attribute.
  [Entity]
  [Table('readonly_example', '')]
  [PrimaryKey('id', 'Primary key')]
  [RESTReadOnly]
  TReadOnlyModel = class
  private
    Fid: Integer;
    Fname: String;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('id', ftInteger)]
    property id: Integer read Fid write Fid;

    [Column('name', ftString, 100)]
    property name: String read Fname write Fname;
  end;

implementation

initialization
  TRegisterClass.RegisterEntity(TReadOnlyModel);

end.
