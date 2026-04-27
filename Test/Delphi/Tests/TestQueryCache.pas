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

unit TestQueryCache;

interface

uses
  DUnitX.TestFramework,
  Janus.DML.Cache;

type
  [TestFixture]
  TTestQueryCache = class
  public
    [Test]
    procedure TestQueryCache_Clear;
  end;

implementation

{ TTestQueryCache }

procedure TTestQueryCache.TestQueryCache_Clear;
var
  LCache: TQueryCache;
  LValue: String;
begin
  LCache := TQueryCache.Create;
  try
    LCache.AddOrSetValue('key1', 'SELECT 1');
    Assert.IsTrue(LCache.TryGetValue('key1', LValue),
      'Key must exist after AddOrSetValue');
    Assert.AreEqual('SELECT 1', LValue, 'Cached value must match');
    LCache.Clear;
    Assert.IsFalse(LCache.TryGetValue('key1', LValue),
      'Key must not exist after Clear');
  finally
    LCache.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestQueryCache);

end.
