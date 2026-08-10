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

{ @abstract(Janus Framework - the OTHER half of the REST family: lazy load and
  unload over TRESTClientDataSetAdapter. Issue #251.)

  WHY THIS IS NOT A FULL CLONE OF Test.Janus.Rest.Lazy

  LoadLazy and _WhereAssociation live in TRESTDataSetAdapter<M>, which BOTH
  concrete REST adapters descend from. The guards, the association walk, the
  literal formatting and the unload are therefore the SAME CODE on both
  families - already driven, and already proved load-bearing by mutation, on
  the TFDMemTable fixture. Cloning all sixteen tests would re-run one
  implementation twice and report it as twice the coverage.

  What is NOT shared is the one method the load branch hands off to:
  TRESTClientDataSetAdapter<M>.OpenWhereInternal is a separate override with
  its own body. So this fixture drives the path that is genuinely different -
  the filter reaching the wire, the rows arriving and landing in order, and the
  dataset being closed for real - and says out loud that it is deliberately not
  re-measuring the shared half.

  THE DOUBLE AND THE CRACKER COME FROM THE FDMemTable FIXTURE. One seeded
  server, one set of markers, one place to change them - two copies that could
  drift would be a worse fixture, not a bigger one.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Rest.Lazy.Cds;

interface

uses
  DB,
  Classes,
  SysUtils,
  DBClient,
  Generics.Collections,
  DUnitX.TestFramework,
  Janus.RestFactory.Interfaces,
  Janus.DataSet.Base.Adapter,
  Janus.RestDataSet.ClientDataSet,
  Test.Janus.Model.AsymKey,
  /// The filtering double, the seeded markers and the expected sequences. Same
  /// server for both families, on purpose.
  Test.Janus.Rest.Lazy;

type
  /// <summary> Classic cracker descendant, the ClientDataSet twin of
  ///  TRestLazyCrack. </summary>
  TRestCdsLazyCrack<M: class, constructor> = class(TRESTClientDataSetAdapter<M>)
  public
    class procedure Lazy(const AAdapter: TRESTClientDataSetAdapter<M>;
      const AOwner: M);
    class procedure CloseIt(const AAdapter: TRESTClientDataSetAdapter<M>);
    class function RegisteredChilds(
      const AAdapter: TRESTClientDataSetAdapter<M>): String;
  end;

  [TestFixture]
  TTestRestLazyCds = class
  private
    FConn: IRESTConnection;
    FServer: TFilteringRestConnection;
    FMasterCds: TClientDataSet;
    FCdsMaster: TRESTClientDataSetAdapter<TAsymMaster>;
    FChildCds: TClientDataSet;
    FCdsChild: TRESTClientDataSetAdapter<TAsymChild>;
    procedure BuildPair;
    procedure AddMasterRow(const AKey: Integer; const ATag: String);
    procedure MasterGoTo(const AKey: Integer);
    function ChildTags: String;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// LOAD-BEARING. The filter this family puts on the wire, through its OWN
    /// OpenWhereInternal override.
    [Test]
    procedure Load_TheFilterReachesTheWireThroughThisFamilysOwnOpenWhere;
    /// LOAD-BEARING. And the rows it brings back are this master's, in order -
    /// not the whole resource.
    [Test]
    procedure Load_OnlyTheRowsOfThisMasterLandInTheClientDataSet;
    /// LOAD-BEARING. The unload closes the ClientDataSet for real and takes
    /// the child out of the master's registry.
    [Test]
    procedure Unload_ClosesTheClientDataSetAndUnregistersTheChild;
    /// LOAD-BEARING. The round trip, which is also the proof that the unload
    /// really cleared both gates: unload, move the master, load again.
    [Test]
    procedure Load_AfterAnUnloadTheNextLoadFollowsTheMasterCursor;
  end;

implementation

const
  cMASTERCOLUMN = 'mkey';
  cCHILDTAG     = 'ctag';

{ TRestCdsLazyCrack<M> }

class procedure TRestCdsLazyCrack<M>.Lazy(
  const AAdapter: TRESTClientDataSetAdapter<M>; const AOwner: M);
begin
  TRestCdsLazyCrack<M>(AAdapter).LoadLazy(AOwner);
end;

class procedure TRestCdsLazyCrack<M>.CloseIt(
  const AAdapter: TRESTClientDataSetAdapter<M>);
begin
  TRestCdsLazyCrack<M>(AAdapter).Close;
end;

class function TRestCdsLazyCrack<M>.RegisteredChilds(
  const AAdapter: TRESTClientDataSetAdapter<M>): String;
var
  LKeys: TStringList;
begin
  LKeys := TStringList.Create;
  try
    LKeys.Sorted := True;
    LKeys.AddStrings(TRestCdsLazyCrack<M>(AAdapter).FMasterObject.Keys.ToArray);
    Result := LKeys.CommaText;
  finally
    LKeys.Free;
  end;
end;

{ TTestRestLazyCds }

procedure TTestRestLazyCds.Setup;
begin
  FServer := TFilteringRestConnection.Create;
  FConn := FServer;
  FServer.Seed(1, 10, 'ten-alpha');
  FServer.Seed(2, 10, 'ten-beta');
  FServer.Seed(3, 20, 'twenty-gamma');
  FServer.Seed(4, 10, 'ten-delta');
  FServer.Seed(5, 20, 'twenty-epsilon');
  FMasterCds := nil;
  FCdsMaster := nil;
  FChildCds := nil;
  FCdsChild := nil;
end;

procedure TTestRestLazyCds.TearDown;
begin
  FreeAndNil(FCdsChild);
  FreeAndNil(FCdsMaster);
  FreeAndNil(FChildCds);
  FreeAndNil(FMasterCds);
  FConn := nil;
  FServer := nil;
end;

procedure TTestRestLazyCds.AddMasterRow(const AKey: Integer;
  const ATag: String);
begin
  FMasterCds.Append;
  FMasterCds.FieldByName(cMASTERCOLUMN).AsInteger := AKey;
  FMasterCds.FieldByName('mtag').AsString := ATag;
  FMasterCds.Post;
end;

procedure TTestRestLazyCds.BuildPair;
begin
  FMasterCds := TClientDataSet.Create(nil);
  FCdsMaster := TRESTClientDataSetAdapter<TAsymMaster>.Create(FConn,
                  FMasterCds, -1, nil);
  AddMasterRow(10, 'master-ten');
  AddMasterRow(20, 'master-twenty');
  FMasterCds.First;

  FChildCds := TClientDataSet.Create(nil);
  FCdsChild := TRESTClientDataSetAdapter<TAsymChild>.Create(FConn, FChildCds,
                 -1, nil);
  // Same reason as the FDMemTable fixture: the constructor leaves the dataset
  // open and the 'already loaded' guard reads exactly that.
  TRestCdsLazyCrack<TAsymChild>.CloseIt(FCdsChild);
end;

procedure TTestRestLazyCds.MasterGoTo(const AKey: Integer);
begin
  FMasterCds.First;
  while not FMasterCds.Eof do
  begin
    if FMasterCds.FieldByName(cMASTERCOLUMN).AsInteger = AKey then
      Exit;
    FMasterCds.Next;
  end;
  Assert.Fail('the master has no row with ' + cMASTERCOLUMN + ' = ' +
    IntToStr(AKey) + ', so nothing below would be measuring what it says');
end;

function TTestRestLazyCds.ChildTags: String;
begin
  Result := '';
  if not FChildCds.Active then
    Exit;
  FChildCds.First;
  while not FChildCds.Eof do
  begin
    if Length(Result) > 0 then
      Result := Result + '|';
    Result := Result + FChildCds.FieldByName(cCHILDTAG).AsString;
    FChildCds.Next;
  end;
end;

procedure TTestRestLazyCds.Load_TheFilterReachesTheWireThroughThisFamilysOwnOpenWhere;
begin
  BuildPair;
  MasterGoTo(10);

  TRestCdsLazyCrack<TAsymChild>.Lazy(FCdsChild, TAsymChild(FCdsMaster));

  Assert.AreEqual('cparent eq 10', FServer.LastFilter,
    'THE HALF OF THE FAMILY THAT IS NOT SHARED. LoadLazy and the WHERE it ' +
    'builds are common code, but the hand-off is not: this family has its ' +
    'own TRESTClientDataSetAdapter<M>.OpenWhereInternal, and an override ' +
    'that dropped the AWhere on the floor would leave the transcript empty ' +
    'while the FDMemTable fixture stayed green');
end;

procedure TTestRestLazyCds.Load_OnlyTheRowsOfThisMasterLandInTheClientDataSet;
begin
  BuildPair;
  MasterGoTo(10);

  TRestCdsLazyCrack<TAsymChild>.Lazy(FCdsChild, TAsymChild(FCdsMaster));

  Assert.IsTrue(FChildCds.Active,
    'the load must leave the ClientDataSet open, otherwise there is nothing ' +
    'to read');
  Assert.AreEqual('ten-alpha|ten-beta|ten-delta', ChildTags,
    'ORDERED CORRESPONDENCE, on this family''s own dataset implementation. ' +
    '`ten-alpha|ten-beta|twenty-gamma|ten-delta|twenty-epsilon` would mean ' +
    'no filter reached the server; `twenty-gamma|twenty-epsilon` would mean ' +
    'the wrong master value travelled');
end;

procedure TTestRestLazyCds.Unload_ClosesTheClientDataSetAndUnregistersTheChild;
begin
  BuildPair;
  MasterGoTo(10);
  TRestCdsLazyCrack<TAsymChild>.Lazy(FCdsChild, TAsymChild(FCdsMaster));
  Assert.AreEqual('ten-alpha|ten-beta|ten-delta', ChildTags,
    'the child must really be carrying rows before the unload, otherwise ' +
    'closing it would be closing nothing');
  Assert.AreEqual('TAsymChild',
    TRestCdsLazyCrack<TAsymMaster>.RegisteredChilds(FCdsMaster),
    'and it must really be registered before it can be shown to leave');

  TRestCdsLazyCrack<TAsymChild>.Lazy(FCdsChild, nil);

  Assert.IsFalse(FChildCds.Active,
    'A REAL CLOSE ON THIS FAMILY TOO. #248 measured that a reopened ' +
    'TClientDataSet comes back with the rows it had, unlike a TFDMemTable - ' +
    'so "it is closed" is the only honest signal here, and a rows-based one ' +
    'would have been the wrong question to ask');
  Assert.AreEqual('',
    TRestCdsLazyCrack<TAsymMaster>.RegisteredChilds(FCdsMaster),
    'and SetMasterObject(nil) took it out of the master registry');
end;

procedure TTestRestLazyCds.Load_AfterAnUnloadTheNextLoadFollowsTheMasterCursor;
begin
  BuildPair;
  MasterGoTo(10);
  TRestCdsLazyCrack<TAsymChild>.Lazy(FCdsChild, TAsymChild(FCdsMaster));
  Assert.AreEqual('ten-alpha|ten-beta|ten-delta', ChildTags,
    'the first leg must really be master 10');

  TRestCdsLazyCrack<TAsymChild>.Lazy(FCdsChild, nil);
  MasterGoTo(20);
  TRestCdsLazyCrack<TAsymChild>.Lazy(FCdsChild, TAsymChild(FCdsMaster));

  Assert.AreEqual('cparent eq 20', FServer.LastFilter,
    'the second load carries the value of the row the master cursor moved to');
  Assert.AreEqual('twenty-gamma|twenty-epsilon', ChildTags,
    'ORDERED CORRESPONDENCE. Still holding the first master''s rows would ' +
    'mean the second load never happened - which is also how a broken unload ' +
    'shows up here, because the two guards would have refused it');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRestLazyCds);

end.
