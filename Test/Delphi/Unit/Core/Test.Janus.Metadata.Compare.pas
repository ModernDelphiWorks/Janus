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

{
  @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
}

unit Test.Janus.Metadata.Compare;

interface

uses
  SysUtils,
  DUnitX.TestFramework,
  Janus.Metadata.Classe.Factory,
  MetaDbDiff.metadata.model;

type
  [TestFixture]
  TTestJanusMetadataCompare = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Create_AllocatesModelMetadata;
    [Test]
    procedure Create_WithNilOwner_StillInitializesModel;
    [Test]
    procedure ModelMetadata_ReturnsSameReferenceAcrossReads;
    [Test]
    procedure ExtractMetadata_RaisesWhenCatalogNil;
    [Test]
    procedure ExtractMetadata_RaiseMessageMentionsCatalogMetadataProperty;
    [Test]
    procedure Lifecycle_RepeatedCreateFree_DoesNotLeak;
  end;

implementation

const
  // Number of create/free cycles for the leak smoke test. ReportMemoryLeaksOnShutdown
  // is enabled by Janus.Tests.Unit.dpr (round 63 #186), so any leaked instance
  // surfaces at executor shutdown.
  CLifecycleCycles = 50;

{ TTestJanusMetadataCompare }

procedure TTestJanusMetadataCompare.Setup;
begin
  // Each test owns its own factory instance — no shared mutable state required.
end;

procedure TTestJanusMetadataCompare.TearDown;
begin
  // No shared resources to release.
end;

procedure TTestJanusMetadataCompare.Create_AllocatesModelMetadata;
var
  LFactory: TMetadataClasseFactory;
begin
  LFactory := TMetadataClasseFactory.Create(nil);
  try
    Assert.IsNotNull(LFactory.ModelMetadata,
      'Constructor must allocate ModelMetadata regardless of owner');
  finally
    LFactory.Free;
  end;
end;

procedure TTestJanusMetadataCompare.Create_WithNilOwner_StillInitializesModel;
var
  LFactory: TMetadataClasseFactory;
begin
  LFactory := TMetadataClasseFactory.Create(nil);
  try
    Assert.IsNotNull(LFactory.ModelMetadata,
      'ModelMetadata must be initialised when owner is nil');
  finally
    LFactory.Free;
  end;
end;

procedure TTestJanusMetadataCompare.ModelMetadata_ReturnsSameReferenceAcrossReads;
var
  LFactory: TMetadataClasseFactory;
  LFirst: TModelMetadataAbstract;
  LSecond: TModelMetadataAbstract;
begin
  LFactory := TMetadataClasseFactory.Create(nil);
  try
    LFirst := LFactory.ModelMetadata;
    LSecond := LFactory.ModelMetadata;
    Assert.AreSame(LFirst, LSecond,
      'ModelMetadata must yield the same reference across multiple reads');
  finally
    LFactory.Free;
  end;
end;

procedure TTestJanusMetadataCompare.ExtractMetadata_RaisesWhenCatalogNil;
var
  LFactory: TMetadataClasseFactory;
begin
  LFactory := TMetadataClasseFactory.Create(nil);
  try
    Assert.WillRaiseWithMessageRegex(
      procedure
      begin
        LFactory.ExtractMetadata(nil);
      end,
      Exception,
      'extra.{0,3}o do metadata',
      'ExtractMetadata(nil) must raise PT-BR contract message about metadata extraction');
  finally
    LFactory.Free;
  end;
end;

procedure TTestJanusMetadataCompare.ExtractMetadata_RaiseMessageMentionsCatalogMetadataProperty;
var
  LFactory: TMetadataClasseFactory;
begin
  LFactory := TMetadataClasseFactory.Create(nil);
  try
    Assert.WillRaiseWithMessageRegex(
      procedure
      begin
        LFactory.ExtractMetadata(nil);
      end,
      Exception,
      'CatalogMetadata',
      'Raise message must reference the CatalogMetadata property name (ASCII anchor)');
  finally
    LFactory.Free;
  end;
end;

procedure TTestJanusMetadataCompare.Lifecycle_RepeatedCreateFree_DoesNotLeak;
var
  LFor: Integer;
  LFactory: TMetadataClasseFactory;
begin
  for LFor := 1 to CLifecycleCycles do
  begin
    LFactory := TMetadataClasseFactory.Create(nil);
    try
      Assert.IsNotNull(LFactory.ModelMetadata,
        'Cycle must produce a fully constructed factory');
    finally
      LFactory.Free;
    end;
  end;
  Assert.Pass(Format('Completed %d create/free cycles without exception', [CLifecycleCycles]));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestJanusMetadataCompare);

end.
