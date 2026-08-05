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

{ @abstract(Janus Framework - a key-only Update on the server side, issue #240.)

  WHAT IS UNDER TEST

  TRESTObjectSet.Update. After ModifyFieldsCompare it calls
  FSession.Update(AObject, LKey) with nothing in between, and
  TRESTObjectSetSession.Update indexes FModifiedFields.Items[AKey] straight
  away. TDictionary raises EListError 'Item not found' on a key that was never
  added.

  The base adapter, TObjectSetAdapter<M>.Update, guards that call with
  ContainsKey plus a non-empty count, and carries a comment saying why. The
  server copy does not.

  WHEN THE KEY IS ABSENT

  ModifyFieldsCompare creates the per-row entry the first time it reaches a
  column it does not skip. An entity whose columns are ALL NoUpdate - a
  junction or detail table whose only columns are its own composite key - gives
  it nothing to reach, so the entry is never created and the very next line
  indexes it.

  Test.Janus.Model.KeyOnly is exactly that entity, and it already exists: it was
  added for the base's own regression, whose header records the live shapes it
  came from - E13_F01, EPV_F02, R01_F01. This suite asks the same question of
  the server copy, which is a route those same tables reach over HTTP.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Server.RestObjectSet.NoOpUpdate;

interface

uses
  Classes,
  SysUtils,
  Variants,
  IOUtils,
  Generics.Collections,
  DUnitX.TestFramework,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Comp.Client,
  DataEngine.FactoryInterfaces,
  MetaDbDiff.Mapping.Classes,
  MetaDbDiff.Mapping.Explorer,
  MetaDbDiff.RTTI.Helper,
  MetaDbDiff.Types.Mapping,
  Janus.Server.RestObjectSet,
  Test.Janus.Model.KeyOnly;

type
  [TestFixture]
  TTestServerRestObjectSetNoOpUpdate = class
  private
    FDConnection: TFDConnection;
    FConnection: IDBConnection;
    FDbFile: string;
    FObjectSet: TRESTObjectSet;
    FEntity: TKeyOnly;
    function _ScalarInt(const ASQL: string): Integer;
    function _ModifyThenUpdateWithNothingChanged: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Premise_EveryColumnOfTheEntityIsNoUpdate;
    [Test]
    procedure AKeyOnlyUpdateMustNotRaiseItemNotFound;
    [Test]
    procedure AKeyOnlyUpdateMustLeaveTheRowAlone;
  end;

implementation

uses
  DataEngine.FactoryFireDAC;

const
  cDBFILE = 'janus_server_objectset_noopupdate.db';
  cK1     = 7;
  cK2     = 42;

  cDDL_KEYONLY =
    'CREATE TABLE IF NOT EXISTS keyonly (' +
    '  k1 INTEGER NOT NULL,' +
    '  k2 INTEGER NOT NULL,' +
    '  PRIMARY KEY (k1, k2)' +
    ')';

{ TTestServerRestObjectSetNoOpUpdate }

procedure TTestServerRestObjectSetNoOpUpdate.Setup;
begin
  FDbFile := cDBFILE;
  if TFile.Exists(FDbFile) then
    TFile.Delete(FDbFile);
  FDConnection := TFDConnection.Create(nil);
  FDConnection.Params.DriverID := 'SQLite';
  FDConnection.Params.Database := FDbFile;
  FDConnection.Params.Values['OpenMode'] := 'CreateUTF8';
  FDConnection.ResourceOptions.SilentMode := True;
  FDConnection.Connected := True;
  FConnection := TFactoryFireDAC.Create(FDConnection, dnSQLite);
  FConnection.ExecuteDirect(cDDL_KEYONLY);
  FConnection.ExecuteDirect('INSERT INTO keyonly (k1, k2) VALUES (' +
                            IntToStr(cK1) + ', ' + IntToStr(cK2) + ')');
end;

procedure TTestServerRestObjectSetNoOpUpdate.TearDown;
begin
  FEntity.Free;
  FEntity := nil;
  FObjectSet.Free;
  FObjectSet := nil;
  FConnection := nil;
  if Assigned(FDConnection) then
  begin
    FDConnection.Connected := False;
    FreeAndNil(FDConnection);
  end;
  if TFile.Exists(FDbFile) then
    TFile.Delete(FDbFile);
end;

function TTestServerRestObjectSetNoOpUpdate._ScalarInt(const ASQL: string): Integer;
var
  LValue: Variant;
begin
  LValue := FDConnection.ExecSQLScalar(ASQL);
  if VarIsNull(LValue) or VarIsEmpty(LValue) then
    Result := -1
  else
    Result := LValue;
end;

function TTestServerRestObjectSetNoOpUpdate._ModifyThenUpdateWithNothingChanged: string;
begin
  Result := '';
  FObjectSet := TRESTObjectSet.Create(FConnection, TKeyOnly);
  FEntity := TKeyOnly.Create;
  FEntity.k1 := cK1;
  FEntity.k2 := cK2;
  // The pair the server performs on a PUT: snapshot the stored row, then hand
  // Update the object parsed from the body. Here the two are identical, which
  // is the case a junction table can only ever produce.
  FObjectSet.Modify(FEntity);
  try
    FObjectSet.Update(FEntity);
  except
    on E: Exception do
      Result := E.Message;
  end;
end;

procedure TTestServerRestObjectSetNoOpUpdate.Premise_EveryColumnOfTheEntityIsNoUpdate;
var
  LColumns: TColumnMappingList;
  LColumn: TColumnMapping;
  LUpdatable: Integer;
begin
  // Names the property the suite depends on. If the model ever grew an
  // updatable column, ModifyFieldsCompare would create the entry and the
  // assertion below would go green without the site being fixed.
  LUpdatable := 0;
  LColumns := TMappingExplorer.GetMappingColumn(TKeyOnly);
  Assert.IsNotNull(LColumns, 'TKeyOnly must expose columns');
  for LColumn in LColumns do
    if not LColumn.ColumnProperty.IsNoUpdate then
      Inc(LUpdatable);
  Assert.AreEqual(0, LUpdatable,
    'TKeyOnly must have NO updatable column - that is what leaves the ' +
    'ModifiedFields entry uncreated');
end;

procedure TTestServerRestObjectSetNoOpUpdate.AKeyOnlyUpdateMustNotRaiseItemNotFound;
begin
  // The site. Nothing to write is not an error; indexing a dictionary entry
  // that was never created is.
  Assert.AreEqual('', _ModifyThenUpdateWithNothingChanged,
    'a key-only Update must be a graceful no-op - EListError here is the ' +
    'missing guard the base adapter carries');
end;

procedure TTestServerRestObjectSetNoOpUpdate.AKeyOnlyUpdateMustLeaveTheRowAlone;
begin
  // The same step measured on the row: a graceful no-op writes nothing and
  // destroys nothing.
  _ModifyThenUpdateWithNothingChanged;
  Assert.AreEqual(1,
    _ScalarInt('SELECT COUNT(*) FROM keyonly WHERE k1 = ' + IntToStr(cK1) +
               ' AND k2 = ' + IntToStr(cK2)),
    'the stored row must still be there, unchanged');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestServerRestObjectSetNoOpUpdate);

end.
