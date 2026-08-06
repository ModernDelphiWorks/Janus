unit Test.Janus.Model.FieldShapes;

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
  [Table('fsshapes', '')]
  [PrimaryKey('fskey', 'Primary key')]
  [AggregateField('AGGVAL', 'SUM(fsval)', taRightJustify, '#,##0.00')]
  TFsShapes = class
  private
    Ffskey: Integer;
    Ffsval: Double;
    Ffscalc: String;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('fskey', ftInteger)]
    property fskey: Integer read Ffskey write Ffskey;

    [Column('fsval', ftFloat, 18, 3)]
    property fsval: Double read Ffsval write Ffsval;

    [CalcField('FSCALC', ftString, 20)]
    property fscalc: String read Ffscalc write Ffscalc;
  end;

  [Entity]
  [Table('fslookup', '')]
  [PrimaryKey('lkkey', 'Primary key')]
  TFsLookup = class
  private
    Flkkey: Integer;
    Flkname: String;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('lkkey', ftInteger)]
    property lkkey: Integer read Flkkey write Flkkey;

    [Column('lkname', ftString, 20)]
    property lkname: String read Flkname write Flkname;
  end;

implementation

initialization
  TRegisterClass.RegisterEntity(TFsShapes);
  TRegisterClass.RegisterEntity(TFsLookup);

end.
