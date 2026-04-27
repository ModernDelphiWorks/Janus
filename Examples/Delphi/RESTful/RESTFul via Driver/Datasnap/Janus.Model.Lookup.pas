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

unit Janus.Model.Lookup;

interface

uses
  Classes, 
  DB, 
  SysUtils, 
  Generics.Collections, 
  /// orm 
  MetaDbDiff.mapping.attributes,
  MetaDbDiff.Mapping.Register,
  MetaDbDiff.Types.Mapping;

type
  [Entity]
  [Table('lookup','')]
  [PrimaryKey('lookup_id', 'Chave prim�ria')]
  [Indexe('idx_lookup_description','lookup_description')]
  [Resource('tapilookup')]
  [SubResource('lookup')]
  Tlookup = class
  private
    { Private declarations }
    Flookup_id: Integer;
    Flookup_description: String;
  public
    { Public declarations }
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('lookup_id', ftInteger)]
    [Dictionary('lookup_id','Mensagem de valida��o','','','',taCenter)]
    property lookup_id: Integer read Flookup_id write Flookup_id;

    [Column('lookup_description', ftString, 30)]
    [Dictionary('lookup_description','Mensagem de valida��o','','','',taLeftJustify)]
    property lookup_description: String read Flookup_description write Flookup_description;
  end;

implementation

initialization
  TRegisterClass.RegisterEntity(Tlookup);

end.
