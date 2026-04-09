{
      ORM Brasil � um ORM simples e descomplicado para quem utiliza Delphi

                   Copyright (c) 2016, Isaque Pinheiro
                          All rights reserved.

                    GNU Lesser General Public License
                      Vers�o 3, 29 de junho de 2007

       Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
       A todos � permitido copiar e distribuir c�pias deste documento de
       licen�a, mas mud�-lo n�o � permitido.

       Esta vers�o da GNU Lesser General Public License incorpora
       os termos e condi��es da vers�o 3 da GNU General Public License
       Licen�a, complementado pelas permiss�es adicionais listadas no
       arquivo LICENSE na pasta principal.
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
