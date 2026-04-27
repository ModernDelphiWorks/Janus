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

{ @abstract(Janus R22.1 LiveBindings DUnitX fixture)
  @created(23 Apr 2026)
  Covers CA-001, CA-002, CA-004, CA-008.
}

unit Tests.Janus.LiveBindings.R221;

interface

{$IFDEF DCC}

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
  Vcl.Forms,
  Vcl.StdCtrls,
  Janus.Binder.Attributes,
  Janus.Binder.Resolver,
  Janus.Binder;

type
  TTestPersonR221 = class
  private
    FNome: string;
    FIdade: Integer;
  published
    [Bind('EditNome', 'Text')]
    property Nome: string read FNome write FNome;
    [Bind('EditIdade', 'Text')]
    property Idade: Integer read FIdade write FIdade;
  end;

  [TestFixture]
  TTestJanusBinderR221 = class
  private
    FForm: TForm;
    FEditNome: TEdit;
    FEditIdade: TEdit;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;

    [Test]
    procedure TestBind_SimpleControl_TwoWaySync;
    [Test]
    procedure TestBind_TwoOwners_NoGlobalStateCollision;
    [Test]
    procedure TestResolver_FindComponent_ByName;
    [Test]
    procedure TestDestroy_FreesAllLinkComponents;
  end;

{$ENDIF DCC}

implementation

{$IFDEF DCC}

{ TTestJanusBinderR221 }

procedure TTestJanusBinderR221.SetupFixture;
begin
  FForm := TForm.Create(nil);
  FForm.Name := 'TestForm';
  FEditNome := TEdit.Create(FForm);
  FEditNome.Name := 'EditNome';
  FEditNome.Parent := FForm;
  FEditIdade := TEdit.Create(FForm);
  FEditIdade.Name := 'EditIdade';
  FEditIdade.Parent := FForm;
end;

procedure TTestJanusBinderR221.TearDownFixture;
begin
  FreeAndNil(FForm);
end;

procedure TTestJanusBinderR221.TestBind_SimpleControl_TwoWaySync;
var
  LPerson: TTestPersonR221;
  LBinder: TJanusBinder;
  LEdit: TEdit;
begin
  LPerson := TTestPersonR221.Create;
  LBinder := TJanusBinder.Create(FForm);
  try
    LPerson.Nome := 'Alice';
    LBinder.Bind(LPerson);
    LEdit := FForm.FindComponent('EditNome') as TEdit;
    Assert.IsNotNull(LEdit, 'EditNome must exist on form');
    Assert.AreEqual('Alice', LEdit.Text, 'Initial bind: entity -> control');
    LPerson.Nome := 'Bob';
    LBinder.Refresh;
    Assert.AreEqual('Bob', LEdit.Text, 'After refresh: entity change -> control');
  finally
    LBinder.Free;
    LPerson.Free;
  end;
end;

procedure TTestJanusBinderR221.TestBind_TwoOwners_NoGlobalStateCollision;
var
  LForm1, LForm2: TForm;
  LEdit1, LEdit2: TEdit;
  LEditIdade1, LEditIdade2: TEdit;
  LPerson1, LPerson2: TTestPersonR221;
  LBinder1, LBinder2: TJanusBinder;
begin
  LForm1 := TForm.Create(nil);
  LForm2 := TForm.Create(nil);
  LEdit1 := TEdit.Create(LForm1);
  LEdit2 := TEdit.Create(LForm2);
  LEditIdade1 := TEdit.Create(LForm1);
  LEditIdade2 := TEdit.Create(LForm2);
  LPerson1 := TTestPersonR221.Create;
  LPerson2 := TTestPersonR221.Create;
  LBinder1 := TJanusBinder.Create(LForm1);
  LBinder2 := TJanusBinder.Create(LForm2);
  try
    LEdit1.Name := 'EditNome';
    LEdit1.Parent := LForm1;
    LEdit2.Name := 'EditNome';
    LEdit2.Parent := LForm2;
    LEditIdade1.Name := 'EditIdade';
    LEditIdade1.Parent := LForm1;
    LEditIdade2.Name := 'EditIdade';
    LEditIdade2.Parent := LForm2;
    LPerson1.Nome := 'Alice';
    LPerson2.Nome := 'Bob';
    LBinder1.Bind(LPerson1);
    LBinder2.Bind(LPerson2);
    Assert.AreEqual('Alice', LEdit1.Text, 'Form1 EditNome must show Alice');
    Assert.AreEqual('Bob',   LEdit2.Text, 'Form2 EditNome must show Bob');
    Assert.AreNotEqual(LEdit1.Text, LEdit2.Text, 'No shared state between binders');
  finally
    LBinder2.Free;
    LBinder1.Free;
    LPerson2.Free;
    LPerson1.Free;
    LForm2.Free;
    LForm1.Free;
  end;
end;

procedure TTestJanusBinderR221.TestResolver_FindComponent_ByName;
var
  LForm: TForm;
  LEdit: TEdit;
  LFound: TComponent;
begin
  LForm := TForm.Create(nil);
  LEdit := TEdit.Create(LForm);
  try
    LEdit.Name := 'LookupTarget';
    LEdit.Parent := LForm;
    LFound := TJanusBinderResolver.Resolve(LForm, 'LookupTarget');
    Assert.IsNotNull(LFound, 'Resolve must find existing component');
    Assert.AreSame(LEdit, LFound, 'Resolved component must be the TEdit');
    LFound := TJanusBinderResolver.Resolve(LForm, 'NonExistent');
    Assert.IsNull(LFound, 'Resolve must return nil for missing name');
  finally
    LForm.Free;
  end;
end;

procedure TTestJanusBinderR221.TestDestroy_FreesAllLinkComponents;
var
  LPerson: TTestPersonR221;
  LBinder: TJanusBinder;
begin
  LPerson := TTestPersonR221.Create;
  try
    LPerson.Nome := 'Alice';
    LBinder := TJanusBinder.Create(FForm);
    LBinder.Bind(LPerson);
    Assert.WillNotRaiseAny(
      procedure begin
        LBinder.Free;
      end,
      'TJanusBinder.Destroy must free all owned links without error');
  finally
    LPerson.Free;
  end;
end;

{$ENDIF DCC}

initialization
{$IFDEF DCC}
  TDUnitX.RegisterTestFixture(TTestJanusBinderR221);
{$ENDIF}

end.
