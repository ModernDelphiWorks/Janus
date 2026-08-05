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

{ @abstract(Janus Framework - test fixture: master-detail with ASYMMETRIC keys.)

  WHY THIS SHAPE EXISTS

  Measured before this unit existed: the models compiled into
  Janus.Tests.Units declared EIGHT [Association]s and all eight named the two
  ends identically (aitroot.root_id -> aitmid.root_id, master.master_id ->
  detail.master_id, and so on). With identical names, a master-detail wiring
  that feeds the MASTER column name to the detail's IndexFieldNames and the
  DETAIL column name to its MasterFields is indistinguishable from the correct
  wiring: both strings are the same string.

  (Asymmetric associations DO exist in the tree - eleven of them, all under
  Examples\Delphi - so this is a gap in what the suite compiles, not a
  property of the framework's users.)

  This fixture makes the two sides impossible to confuse:

      mdmaster.mkey   --(OneToMany)-->   mdchild.cparent

  `mkey` does not exist in mdchild and `cparent` does not exist in mdmaster,
  so exactly ONE of the two possible wirings resolves and the other raises.

  Reading the attribute: Association(AMultiplicity, AColumnsName,
  ATableNameRef, AColumnsNameRef). ColumnsName is the column on the DECLARING
  entity (the master, mkey); ColumnsNameRef is the column on the REFERENCED
  table (the child, cparent). The same convention is what
  TDataSetBaseAdapter<M>._AutoIncToChildRows relies on when it resolves
  ColumnsName against the master dataset and ColumnsNameRef against the child.
}

unit Test.Janus.Model.AsymKey;

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
  [Table('mdchild', '')]
  [PrimaryKey('ckey', TAutoIncType.AutoInc,
                      TGeneratorType.SequenceInc,
                      TSortingOrder.NoSort,
                      True, 'Primary key')]
  [Sequence('mdchild')]
  TAsymChild = class
  private
    Fckey: Integer;
    Fcparent: Integer;
    Fctag: String;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('ckey', ftInteger)]
    property ckey: Integer read Fckey write Fckey;

    /// The foreign key. Deliberately NOT called `mkey`.
    [Restrictions([TRestriction.NotNull])]
    [Column('cparent', ftInteger)]
    property cparent: Integer read Fcparent write Fcparent;

    [Column('ctag', ftString, 20)]
    property ctag: String read Fctag write Fctag;
  end;

  [Entity]
  [Table('mdmaster', '')]
  [PrimaryKey('mkey', TAutoIncType.AutoInc,
                      TGeneratorType.SequenceInc,
                      TSortingOrder.NoSort,
                      True, 'Primary key')]
  [Sequence('mdmaster')]
  TAsymMaster = class
  private
    Fmkey: Integer;
    Fmtag: String;
    Fchilds: TObjectList<TAsymChild>;
  public
    constructor Create;
    destructor Destroy; override;

    /// The primary key. Deliberately NOT called `cparent`.
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('mkey', ftInteger)]
    property mkey: Integer read Fmkey write Fmkey;

    [Column('mtag', ftString, 20)]
    property mtag: String read Fmtag write Fmtag;

    [Association(TMultiplicity.OneToMany, 'mkey', 'mdchild', 'cparent')]
    [CascadeActions([TCascadeAction.CascadeInsert,
                     TCascadeAction.CascadeUpdate,
                     TCascadeAction.CascadeDelete])]
    property childs: TObjectList<TAsymChild> read Fchilds write Fchilds;
  end;

implementation

{ TAsymMaster }

constructor TAsymMaster.Create;
begin
  Fchilds := TObjectList<TAsymChild>.Create;
end;

destructor TAsymMaster.Destroy;
begin
  Fchilds.Free;
  inherited;
end;

initialization
  TRegisterClass.RegisterEntity(TAsymChild);
  TRegisterClass.RegisterEntity(TAsymMaster);

end.
