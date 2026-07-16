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

  Retargeted (frente-8, 16 Jul 2026): this fixture used to exercise
  Janus.Metadata.Classe.Factory.TMetadataClasseFactory, which is now a thin,
  deprecated, empty subclass of MetaDbDiff.Metadata.Model.Factory.
  TMetadataModelFactory (see that unit's header for why). Testing the
  deprecated alias here would add indirection with no extra coverage - and
  would emit a deprecation warning inside Janus' own test build for nothing -
  so this fixture now exercises TMetadataModelFactory directly, the real,
  canonical implementation both the Janus alias and TModelDbCompare rely on.
  Behaviour under test (constructor allocation, ModelMetadata reference
  stability, ExtractMetadata(nil) raising with a CatalogMetadata-mentioning
  message, create/free lifecycle) is unchanged - only the type under test
  moved. One assert DID change as a direct consequence: MetaDbDiff's ported
  ExtractMetadata raise message is in English ("Before extracting the
  metadata, assign the catalog...") where the old Janus message was PT-BR
  ("Antes de executar a extração do metadata...") - see
  ExtractMetadata_RaisesWhenCatalogNil below for the updated regex.
}

unit Test.Janus.Metadata.Compare;

interface

uses
  SysUtils,
  DUnitX.TestFramework,
  MetaDbDiff.Metadata.Model.Factory,
  MetaDbDiff.Metadata.Extract, // TModelMetadataAbstract (declared here, not re-exported by MetaDbDiff.metadata.model)
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
  LFactory: TMetadataModelFactory;
begin
  LFactory := TMetadataModelFactory.Create(nil);
  try
    Assert.IsNotNull(LFactory.ModelMetadata,
      'Constructor must allocate ModelMetadata regardless of owner');
  finally
    LFactory.Free;
  end;
end;

procedure TTestJanusMetadataCompare.Create_WithNilOwner_StillInitializesModel;
var
  LFactory: TMetadataModelFactory;
begin
  LFactory := TMetadataModelFactory.Create(nil);
  try
    Assert.IsNotNull(LFactory.ModelMetadata,
      'ModelMetadata must be initialised when owner is nil');
  finally
    LFactory.Free;
  end;
end;

procedure TTestJanusMetadataCompare.ModelMetadata_ReturnsSameReferenceAcrossReads;
var
  LFactory: TMetadataModelFactory;
  LFirst: TModelMetadataAbstract;
  LSecond: TModelMetadataAbstract;
begin
  LFactory := TMetadataModelFactory.Create(nil);
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
  LFactory: TMetadataModelFactory;
begin
  LFactory := TMetadataModelFactory.Create(nil);
  try
    // MetaDbDiff.Metadata.Model.Factory.TMetadataModelFactory.ExtractMetadata
    // raises in English ("Before extracting the metadata, assign the catalog
    // to be filled in..."), unlike the old Janus.Metadata.Classe.Factory
    // message this test used to assert on ("Antes de executar a extração do
    // metadata..."). Regex updated accordingly (frente-8).
    Assert.WillRaiseWithMessageRegex(
      procedure
      begin
        LFactory.ExtractMetadata(nil);
      end,
      Exception,
      'extract.{0,3} the metadata',
      'ExtractMetadata(nil) must raise a message about extracting the metadata');
  finally
    LFactory.Free;
  end;
end;

procedure TTestJanusMetadataCompare.ExtractMetadata_RaiseMessageMentionsCatalogMetadataProperty;
var
  LFactory: TMetadataModelFactory;
begin
  LFactory := TMetadataModelFactory.Create(nil);
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
  LFactory: TMetadataModelFactory;
begin
  for LFor := 1 to CLifecycleCycles do
  begin
    LFactory := TMetadataModelFactory.Create(nil);
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
