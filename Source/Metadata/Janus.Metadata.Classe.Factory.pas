{
  ------------------------------------------------------------------------------
  Janus ORM
  State-of-the-art Object-Relational Mapping (ORM) framework for Delphi.

  SPDX-License-Identifier: MIT
  Copyright (c) 2025-2026 Isaque Pinheiro

  Licensed under the MIT License.
  See the LICENSE file in the project root for full license information.
  ------------------------------------------------------------------------------
}

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)

  ORM Brasil � um ORM simples e descomplicado para quem utiliza Delphi.
}

unit Janus.Metadata.Classe.Factory;

interface

uses
  SysUtils,
  Rtti,
  DataEngine.FactoryInterfaces,
  MetaDbDiff.metadata.model,
  MetaDbDiff.metadata.extract,
  MetaDbDiff.database.mapping,
  MetaDbDiff.database.abstract;

type
  TMetadataClasseAbstract = class abstract
  protected
    FOwner: TDatabaseAbstract;
    FModelMetadata: TModelMetadataAbstract;
  public
    constructor Create(AOwner: TDatabaseAbstract); virtual;
    destructor Destroy; override;
    procedure ExtractMetadata(ACatalogMetadata: TCatalogMetadataMIK); virtual; abstract;
    property ModelMetadata: TModelMetadataAbstract read FModelMetadata;
  end;

  TMetadataClasseFactory = class(TMetadataClasseAbstract)
  public
    procedure ExtractMetadata(ACatalogMetadata: TCatalogMetadataMIK); override;
  end;

implementation

{ TMetadataClasseAbstract }

constructor TMetadataClasseAbstract.Create(AOwner: TDatabaseAbstract);
begin
  FOwner := AOwner;
  FModelMetadata := TModelMetadata.Create;
end;

destructor TMetadataClasseAbstract.Destroy;
begin
  FModelMetadata.Free;
  inherited;
end;

{ TMetadataClasseFactory }

procedure TMetadataClasseFactory.ExtractMetadata(ACatalogMetadata: TCatalogMetadataMIK);
begin
  inherited;
  if ACatalogMetadata = nil then
    raise Exception.Create('Antes de executar a extra��o do metadata, atribua a propriedade o catalogue a set preenchido em "DatabaseMetadata.CatalogMetadata"');

  FModelMetadata.CatalogMetadata := ACatalogMetadata;
  FModelMetadata.ModelForDatabase := FOwner.ModelForDatabase;
  FModelMetadata.GetModelMetadata;
end;

end.
