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
