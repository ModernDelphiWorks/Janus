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

unit Janus.Oracle.Model.Produto;

interface

uses
  DB,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Attributes;

type
  [Entity]
  [Table('produtos', '')]
  [PrimaryKey('id_produto', 'Product primary key')]
  TModelProduto = class
  private
    FIdProduto: Integer;
    FDescricao: String;
    FPreco: Double;
    FCategoria: String;
  public
    [Restrictions([NoUpdate, NotNull])]
    [Column('id_produto', ftInteger)]
    property IdProduto: Integer read FIdProduto write FIdProduto;

    [Restrictions([NotNull])]
    [Column('descricao', ftString, 200)]
    property Descricao: String read FDescricao write FDescricao;

    [Restrictions([NotNull])]
    [Column('preco', ftFloat)]
    property Preco: Double read FPreco write FPreco;

    [Column('categoria', ftString, 50)]
    property Categoria: String read FCategoria write FCategoria;
  end;

implementation

end.
