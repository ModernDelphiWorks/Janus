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

{
  @abstract(Janus Framework.)
  @created(12 Out 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
}

unit Janus.DML.Interfaces;

interface

uses
  DB,
  Rtti,
  Generics.Collections,
  /// Janus
  Janus.DML.Commands,
  DataEngine.FactoryInterfaces,
  MetaDbDiff.Mapping.Classes;

type
  IDMLGeneratorCommand = interface
    ['{03BADA2C-2D5E-4F67-8F54-FDCCF16ACD56}']
    procedure SetConnection(const AConnaction: IDBConnection);
    function GeneratorSelectAll(AClass: TClass;
      APageSize: Integer; AID: TValue): String;
    function GeneratorSelectWhere(AClass: TClass; AWhere: String;
      AOrderBy: String; APageSize: Integer): String;
    function GenerateSelectOneToOne(AOwner: TObject; AClass: TClass;
      AAssociation: TAssociationMapping): String;
    function GenerateSelectOneToOneMany(AOwner: TObject; AClass: TClass;
      AAssociation: TAssociationMapping): String;
    function GeneratorUpdate(AObject: TObject; AParams: TParams;
      AModifiedFields: TDictionary<String, String>): String; overload;
    function GeneratorInsert(AObject: TObject): String;
    function GeneratorDelete(AObject: TObject; AParams: TParams): String;
    function GeneratorAutoIncCurrentValue(AObject: TObject;
      AAutoInc: TDMLCommandAutoInc): Int64;
    function GeneratorAutoIncNextValue(AObject: TObject;
      AAutoInc: TDMLCommandAutoInc): Int64;
    function GeneratorPageNext(const ACommandSelect: String;
      APageSize, APageNext: Integer): String;
  end;

implementation

end.
