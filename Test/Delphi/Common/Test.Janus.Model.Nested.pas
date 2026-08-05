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

{ @abstract(Janus Framework - an entity carrying a NESTED DATASET column.)

  WHY THIS MODEL EXISTS

  A column declared [Column(..., ftDataSet)] over a list property is what makes
  TBind.SetInternalInitFieldDefsObjectClass reach _CreateFieldsNestedDataSet,
  which touches TDataSetField.NestedDataSet and therefore REGISTERS a dataset in
  the parent's TDataSet.NestedDataSets list. That list is the one
  TDataSetAdapter<M>.DoBeforeDelete walks, and no model under Test\Delphi
  declared such a column - the only one in the repository sits under
  Examples\Delphi\NoSQL\MongoDB\Models, whose unit names collide with the
  Examples\Delphi\Data\Models units the test project already compiles.

  Two rows of a parent point at the same shape of child, so the fixture can
  build the nested dataset both EMPTY and POPULATED from the same mapping.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Model.Nested;

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
  [Table('ndchild', '')]
  [PrimaryKey('citem', 'Primary key of the nested row')]
  TNestedChild = class
  private
    Fcitem: Integer;
    Fctag: String;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('citem', ftInteger)]
    property citem: Integer read Fcitem write Fcitem;

    [Column('ctag', ftString, 20)]
    property ctag: String read Fctag write Fctag;
  end;

  [Entity]
  [Table('ndparent', '')]
  [PrimaryKey('pkey', 'Primary key of the owner row')]
  TNestedParent = class
  private
    Fpkey: Integer;
    Fptag: String;
    Fitems: TObjectList<TNestedChild>;
  public
    constructor Create;
    destructor Destroy; override;

    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('pkey', ftInteger)]
    property pkey: Integer read Fpkey write Fpkey;

    [Column('ptag', ftString, 20)]
    property ptag: String read Fptag write Fptag;

    /// The column that produces the nested dataset. Hidden for the same reason
    /// the MongoDB example hides its own: it is not a scalar a grid can show.
    [Restrictions([TRestriction.Hidden])]
    [Column('items', ftDataSet)]
    property items: TObjectList<TNestedChild> read Fitems write Fitems;
  end;

implementation

{ TNestedParent }

constructor TNestedParent.Create;
begin
  Fitems := TObjectList<TNestedChild>.Create;
end;

destructor TNestedParent.Destroy;
begin
  Fitems.Free;
  inherited;
end;

initialization
  TRegisterClass.RegisterEntity(TNestedChild);
  TRegisterClass.RegisterEntity(TNestedParent);

end.
