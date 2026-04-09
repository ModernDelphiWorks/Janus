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
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Janus.Command.Executor.Abstract;

interface

uses
  Rtti,
  Generics.Collections,
  // Janus
  DataEngine.FactoryInterfaces,
  MetaDbDiff.Mapping.Popular,
  MetaDbDiff.Mapping.Register,
  MetaDbDiff.Mapping.Explorer,
  MetaDbDiff.Mapping.Repository,
  MetaDbDiff.Mapping.Classes;

type
  TSQLCommandExecutorAbstract<M: class, constructor> = class abstract
  protected
    function FindSQLInternal(const ASQL: String): IDBDataSet; virtual; abstract;
    procedure ExecuteOneToOne(AObject: TObject; AProperty: TRttiProperty;
      AAssociation: TAssociationMapping); virtual; abstract;
    procedure ExecuteOneToMany(AObject: TObject; AProperty: TRttiProperty;
      AAssociation: TAssociationMapping); virtual; abstract;
  public
    constructor Create(const AOwner: TObject; const AConnection: IDBConnection;
      const APageSize: Integer); virtual;
    procedure InsertInternal(const AObject: M); virtual; abstract;
    procedure UpdateInternal(const AObject: TObject;
      const AModifiedFields: TDictionary<String, String>); virtual; abstract;
    procedure DeleteInternal(const AObject: M); virtual; abstract;
    function SelectInternalWhere(const AWhere: String;
      const AOrderBy: String): String; virtual; abstract;
    function SelectInternalAll: IDBDataSet; virtual; abstract;
    function SelectInternalID(const AID: TValue): IDBDataSet; virtual; abstract;
    function SelectInternal(const ASQL: String): IDBDataSet; virtual; abstract;
    function SelectInternalAssociation(const AObject: TObject): String; virtual; abstract;
    function GetDMLCommand: String; virtual; abstract;
    function Find: IDBDataSet; overload; virtual; abstract;
    function Find(const AID: TValue): M; overload; virtual; abstract;
    function FindWhere(const AWhere: String;
      const AOrderBy: String = ''): IDBDataSet; virtual; abstract;
    function ExistSequence: Boolean; virtual; abstract;
    function NextPacket: IDBDataSet; overload; virtual; abstract;
    function NextPacket(const APageSize,
      APageNext: Integer): IDBDataSet; overload; virtual; abstract;
    function NextPacket(const AWhere, AOrderBy: String;
      const APageSize, APageNext: Integer): IDBDataSet; overload; virtual; abstract;
    function NextPacketList: IDBDataSet; overload; virtual; abstract;
    function NextPacketList(const APageSize,
      APageNext: Integer): IDBDataSet; overload; virtual; abstract;
    function NextPacketList(const AWhere, AOrderBy: String;
      const APageSize, APageNext: Integer): IDBDataSet; overload; virtual; abstract;
    procedure NextPacketList(const AObjectList: TObjectList<M>;
      const APageSize, APageNext: Integer); overload; virtual; abstract;
    procedure NextPacketList(const AObjectList: TObjectList<M>;
      const AWhere, AOrderBy: String;
      const APageSize, APageNext: Integer); overload; virtual; abstract;
    procedure LoadLazy(const AOwner, AObject: TObject); virtual; abstract;
    procedure FillAssociation(const AObject: M); virtual; abstract;
    procedure FillAssociationLazy(const AOwner, AObject: TObject); virtual; abstract;
    procedure InjectLazyFactories(const AObject: TObject); virtual; abstract;
  end;

implementation

{ TObjectManagerAbstract<M> }

constructor TSQLCommandExecutorAbstract<M>.Create(const AOwner: TObject;
  const AConnection: IDBConnection; const APageSize: Integer);
begin
  TMappingExplorer.GetRepositoryMapping;
end;

end.
