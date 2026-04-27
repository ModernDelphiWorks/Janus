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

unit TestJanusRESTOracleAutoView;

interface

uses
  SysUtils,
  Classes,
  Net.HTTPClient,
  Net.URLClient,
  DUnitX.TestFramework,
  RestHorseOracleTest.Base;

type
  [TestFixture]
  TTestOracleAutoView = class(TRestHorseOracleTestBase)
  private
    FHTTPClient: THTTPClient;
    function _BuildURL(const AResource: string; const AQuery: string = ''): string;
    function _Get(const AURL: string): string;
    function _Post(const AURL: string; const ABody: string): string;
  public
    [SetupFixture]
    procedure SetupFixture;
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure GetAutoView_ViewNotExisting_ServerCreatesViewAndReturnsData;
    [Test]
    procedure GetAutoView_ViewAlreadyExists_SkipsDDLAndReturnsData;
    [Test]
    procedure PostAutoView_Blocked_ReturnsReadOnlyError;
    [Test]
    procedure GetAutoView_WithFilter_ReturnsFilteredData;
  end;

implementation

uses
  Janus.Server.RestView.Manager;

const
  cREADONLY_MSG = 'read-only (RESTReadOnly)';

{ TTestOracleAutoView }

procedure TTestOracleAutoView.SetupFixture;
begin
  FPrefix := 'api/Janus';
  inherited SetupFixture;
end;

procedure TTestOracleAutoView.Setup;
begin
  FHTTPClient := THTTPClient.Create;
  FHTTPClient.ConnectionTimeout := 5000;
  FHTTPClient.ResponseTimeout := 5000;
  DropView('vw_pedidos_completos');
  TRESTViewManager.ClearCache;
  SeedOracleData;
end;

procedure TTestOracleAutoView.TearDown;
begin
  FreeAndNil(FHTTPClient);
end;

function TTestOracleAutoView._BuildURL(const AResource: string;
  const AQuery: string): string;
begin
  Result := BuildResourceURL(AResource);
  if AQuery <> '' then
    Result := Result + '?' + AQuery;
end;

function TTestOracleAutoView._Get(const AURL: string): string;
begin
  Result := FHTTPClient.Get(AURL).ContentAsString(TEncoding.UTF8);
end;

function TTestOracleAutoView._Post(const AURL: string;
  const ABody: string): string;
var
  LStream: TStringStream;
begin
  LStream := TStringStream.Create(ABody, TEncoding.UTF8);
  try
    Result := FHTTPClient.Post(AURL, LStream, nil,
      [TNameValuePair.Create('Content-Type', 'application/json')])
      .ContentAsString(TEncoding.UTF8);
  finally
    LStream.Free;
  end;
end;

procedure TTestOracleAutoView.GetAutoView_ViewNotExisting_ServerCreatesViewAndReturnsData;
var
  LResult: string;
begin
  // Pre: DropView + ClearCache in Setup — view does not exist
  LResult := _Get(_BuildURL('modelpedidoscompletos'));
  Assert.IsFalse(LResult.Contains('"exception"'),
    'GET auto-view returned exception: ' + LResult);
  Assert.IsTrue(ViewExists('vw_pedidos_completos'),
    'View was not created by the server');
end;

procedure TTestOracleAutoView.GetAutoView_ViewAlreadyExists_SkipsDDLAndReturnsData;
var
  LResult: string;
begin
  // Pre: first GET creates and caches the view
  _Get(_BuildURL('modelpedidoscompletos'));
  // Second GET — uses cache (no DDL)
  LResult := _Get(_BuildURL('modelpedidoscompletos'));
  Assert.IsFalse(LResult.Contains('"exception"'),
    'Second GET returned exception: ' + LResult);
end;

procedure TTestOracleAutoView.PostAutoView_Blocked_ReturnsReadOnlyError;
var
  LResult: string;
begin
  // Ensure view exists so request reaches the read-only check
  _Get(_BuildURL('modelpedidoscompletos'));
  LResult := _Post(_BuildURL('modelpedidoscompletos'), '{"id_pedido":999}');
  Assert.Contains(LResult, cREADONLY_MSG,
    'POST on view must return read-only error, got: ' + LResult);
end;

procedure TTestOracleAutoView.GetAutoView_WithFilter_ReturnsFilteredData;
var
  LResult: string;
begin
  _Get(_BuildURL('modelpedidoscompletos')); // ensure view exists
  LResult := _Get(_BuildURL('modelpedidoscompletos', '$filter=id_pedido eq 1'));
  Assert.IsFalse(LResult.Contains('"exception"'),
    'Filtered GET returned exception: ' + LResult);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestOracleAutoView);

end.
