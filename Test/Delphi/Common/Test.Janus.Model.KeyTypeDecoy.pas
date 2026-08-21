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

{ @abstract(Janus Framework - the ONE shape that reaches an EMPTY Variant,
  issue #311.)

  WHY THIS UNIT IS SEPARATE

  It declares a record type called `Nullable<T>` that is NOT
  Janus.Types.Nullable. The two names cannot coexist in one unit, and this one
  must not be reachable by accident from a model that meant the real thing.

  WHAT IT IS FOR

  MetaDbDiff's TRttiPropertyHelper.IsNullable is a check BY NAME: a record
  whose type name begins with 'Nullable<' is treated as nullable, whatever its
  layout. TRttiPropertyHelper.GetNullableValue then reads FHasValue and, when
  it is set, FValue - and when FValue is not there, it returns the
  Default(TValue) it started with. An EMPTY TValue.

  TValue.AsVariant on an empty value does not raise and does not answer Null:
  AsTypeInternal takes the branch that FillChars the result to zero, and a
  zeroed Variant is varEmpty. So `VarIsNull` is False and `VarIsEmpty` is True
  - which is why the value builder guards on both, and why the two halves of
  that guard need different shapes to reach them.

  This is the only shape in this repository that reaches the second half.
  It is deliberately grotesque: nobody would write it on purpose. It exists so
  that "the varEmpty guard is unreachable" is a MEASUREMENT and not a story. }

unit Test.Janus.Model.KeyTypeDecoy;

interface

uses
  Classes,
  DB,
  SysUtils,
  MetaDbDiff.mapping.attributes,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Register;

type
  /// Same NAME as Janus.Types.Nullable, deliberately NOT the same layout:
  /// FHasValue is here and FValue is not.
  Nullable<T> = record
  private
    FHasValue: Boolean;
  public
    procedure Claim;
  end;

  [Entity]
  [Table('ktdecoy', '')]
  [PrimaryKey('ktdec', TAutoIncType.NotInc,
                       TGeneratorType.NoneInc,
                       TSortingOrder.NoSort,
                       True, 'Nullable-shaped key with no value field')]
  TKeyTypeDecoy = class
  private
    Fktdec: Nullable<String>;
    Fkttag: String;
  public
    /// TAppResourceBase.ParseInsert calls MethodCall('Create', []) on the
    /// instance it just built, so this runs before the body is applied.
    /// Without it FHasValue stays False and GetNullableValue answers Null,
    /// which is the OTHER half of the guard.
    constructor Create;

    [Column('ktdec', ftString, 60)]
    property ktdec: Nullable<String> read Fktdec write Fktdec;

    [Column('kttag', ftString, 60)]
    property kttag: String read Fkttag write Fkttag;
  end;

implementation

{ Nullable<T> }

procedure Nullable<T>.Claim;
begin
  FHasValue := True;
end;

{ TKeyTypeDecoy }

constructor TKeyTypeDecoy.Create;
begin
  Fktdec.Claim;
end;

initialization
  TRegisterClass.RegisterEntity(TKeyTypeDecoy);

end.
