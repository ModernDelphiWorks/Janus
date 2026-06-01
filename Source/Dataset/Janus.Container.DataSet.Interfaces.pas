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

{
  @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
}

unit Janus.Container.DataSet.Interfaces;

interface

uses
  DB,
  RTTi,
  Classes,
  Generics.Collections,
  Janus.DataSet.Base.Adapter;

type
  IContainerDataSet<M: class, constructor> = interface
    ['{67DC311E-06BF-4B41-93E1-FA66AB0D8537}']
  {$REGION 'Property Getters & Setters'}
    function _GetAutoNextPacket: Boolean;
    procedure _SetAutoNextPacket(const Value: Boolean);
  {$ENDREGION}
    procedure LoadLazy(AOwner: M);
    procedure Open; overload;
    procedure Open(const AID: Integer); overload;
    procedure Open(const AID: String); overload;
    procedure OpenWhere(const AWhere: String; const AOrderBy: String = '');
    procedure Insert;
    procedure Append;
    procedure Post;
    procedure Edit;
    procedure Delete;
    procedure Close;
    procedure Cancel;
    procedure RefreshRecord;
    procedure RefreshRecordWhere(const AWhere: String);
    procedure EmptyDataSet;
    procedure CancelUpdates;
    procedure Save(AObject: M);
    procedure ApplyUpdates(MaxErros: Integer);
    procedure AddLookupField(AFieldName: String;
                             AKeyFields: String;
                             ALookupDataSet: TObject;
                             ALookupKeyFields: String;
                             ALookupResultField: String;
                             ADisplayLabel: String = '');
    procedure NextPacket;
    function DataSet: TDataSet;
    function MasterObject: TDataSetBaseAdapter<M>; deprecated 'Use This';
    function This: TDataSetBaseAdapter<M>;
    function Current: M;
    /// ObjectSet
    function Find: TObjectList<M>; overload;
    function Find(const AID: Integer): M; overload;
    function Find(const AID: String): M; overload;
    function FindWhere(const AWhere: String; const AOrderBy: String = ''): TObjectList<M>;
    /// DataSet
    property AutoNextPacket: Boolean read _GetAutoNextPacket write _SetAutoNextPacket;
  end;

implementation

end.
