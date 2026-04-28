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

unit Test.Janus.Types.Nullable;

interface

uses
  DUnitX.TestFramework,
  Janus.Types.Nullable;

type
  [TestFixture]
  TTestNullable = class
  public
    [Test]
    procedure TestNullable_HasValue_WhenAssigned;
    [Test]
    procedure TestNullable_NoValue_WhenDefault;
    [Test]
    procedure TestNullable_Clear;
  end;

implementation

{ TTestNullable }

procedure TTestNullable.TestNullable_HasValue_WhenAssigned;
var
  LNullable: Nullable<Integer>;
begin
  LNullable := 42;
  Assert.IsTrue(LNullable.HasValue, 'Must have value after assignment');
  Assert.AreEqual(42, LNullable.Value);
end;

procedure TTestNullable.TestNullable_NoValue_WhenDefault;
var
  LNullable: Nullable<Integer>;
begin
  Assert.IsFalse(LNullable.HasValue, 'Default nullable must not have value');
end;

procedure TTestNullable.TestNullable_Clear;
var
  LNullable: Nullable<Integer>;
begin
  LNullable := 42;
  Assert.IsTrue(LNullable.HasValue, 'Must have value before clear');
  LNullable := nil;
  Assert.IsFalse(LNullable.HasValue, 'Must not have value after clear');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestNullable);

end.
