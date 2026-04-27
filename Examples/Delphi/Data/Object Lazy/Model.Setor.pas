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

unit Model.Setor;

interface

uses
  DB,
  Classes,
  SysUtils,
  Generics.Collections,
  /// orm
  Janus.Types.Blob,
  Janus.Types.Lazy,
  MetaDbDiff.Types.Mapping,
  Janus.Types.Nullable,
  MetaDbDiff.mapping.classes,
  MetaDbDiff.Mapping.Register,
  MetaDbDiff.mapping.attributes;

type
  [Entity]
  [Table('SETORES', '')]
  [PrimaryKey('SETOR', TAutoIncType.NotInc,
                       TGeneratorType.NoneInc,
                       TSortingOrder.NoSort,
                       False, 'Chave prim�ria')]
  TSetor = class
  private
    { Private declarations }
    FSETOR: Double;
    FNOME: String;
  public
    { Public declarations }
    constructor Create;
    destructor Destroy; override;
    [Restrictions([TRestriction.NotNull])]
    [Column('SETOR', ftBCD, 8, 0)]
    [Dictionary('SETOR', 'Mensagem de valida��o', '0', '', '', taRightJustify)]
    property SETOR: Double read FSETOR write FSETOR;

    [Restrictions([TRestriction.NotNull])]
    [Column('NOME', ftString, 60)]
    [Dictionary('NOME', 'Mensagem de valida��o', '', '', '', taLeftJustify)]
    property NOME: String read FNOME write FNOME;

  end;

implementation

constructor TSetor.Create;
begin
end;

destructor TSetor.Destroy;
begin
  inherited;
end;

initialization
  TRegisterClass.RegisterEntity(TSetor)

end.

