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

unit Janus.Model.Client;

interface

uses
  Classes, 
  DB, 
  SysUtils, 
  Generics.Collections, 
  /// orm 
  MetaDbDiff.mapping.attributes,
  Janus.Types.Nullable,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Register,
  Janus.Types.Blob;

type
  [Entity]
  [Table('client','')]
  [PrimaryKey('client_id', 'Chave prim�ria')]
  [Indexe('idx_client_name','client_name')]
  [OrderBy('client_id Desc')]
  Tclient = class
  private
    { Private declarations }
    Fclient_id: Integer;
    Fclient_name: String;
//    Fclient_foto: TBlob;
  public
    { Public declarations }
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('client_id', ftInteger)]
    [Dictionary('client_id','Mensagem de valida��o','','','',taCenter)]
    property client_id: Integer read Fclient_id write Fclient_id;

    [Column('client_name', ftString, 40)]
    [Dictionary('client_name','Mensagem de valida��o','','','',taLeftJustify)]
    property client_name: String read Fclient_name write Fclient_name;

//    [Column('client_foto', ftBlob)]
//    [Dictionary('client_foto','Mensagem de valida��o')]
//    property client_foto: TBlob read Fclient_foto write Fclient_foto;
  end;

implementation

initialization
  TRegisterClass.RegisterEntity(Tclient);

end.
