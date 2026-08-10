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

{ @abstract(Janus Framework - test fixture.)

  An owner entity carrying one ftDateTime column and one ftTime column, so that
  BOTH date-literal branches of TDMLGeneratorAbstract._GetPropertyValue
  (Janus.DML.Generator.pas:613 and :617) can be exercised through real generated
  SQL. Measured before adding it: no model linked into Janus.Tests.Units mapped
  any column as ftTime / ftTimeStamp / ftOraTimeStamp, so the time branch had no
  production-path coverage at all.

  Both properties are plain TDateTime; it is the mapped FieldType, not the
  Delphi type, that selects the branch. }

unit Test.Janus.Model.Moment;

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
  [Table('moment', '')]
  [PrimaryKey('moment_id', 'Surrogate key')]
  TMoment = class
  private
    Fmoment_id: Integer;
    Fmoment_date: TDateTime;
    Fmoment_time: TDateTime;
  public
    [Restrictions([TRestriction.NotNull])]
    [Column('moment_id', ftInteger)]
    property moment_id: Integer read Fmoment_id write Fmoment_id;

    [Column('moment_date', ftDateTime)]
    property moment_date: TDateTime read Fmoment_date write Fmoment_date;

    [Column('moment_time', ftTime)]
    property moment_time: TDateTime read Fmoment_time write Fmoment_time;
  end;

implementation

initialization
  TRegisterClass.RegisterEntity(TMoment);

end.
