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
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Janus.ObjectSet.Abstract;

interface

uses
  Rtti,
  Variants,
  Generics.Collections,
  Janus.Session.Abstract;

type
  TObjectSetAbstract<M: class, constructor> = class abstract
  protected
    FSession: TSessionAbstract<M>;
    FObjectState: TDictionary<String, TObject>;
  public
    function ExistSequence: Boolean; virtual; abstract;
    function ModifiedFields: TDictionary<String, TDictionary<String, String>>; virtual; abstract;
    function Find: TObjectList<M>; overload; virtual; abstract;
    function Find(const AID: Int64): M; overload; virtual; abstract;
    function Find(const AID: String): M; overload; virtual; abstract;
    function FindWhere(const AWhere: String;
      const AOrderBy: String = ''): TObjectList<M>; overload; virtual; abstract;
    procedure Insert(const AObject: M); virtual; abstract;
    procedure Update(const AObject: M); virtual; abstract;
    procedure Delete(const AObject: M); virtual; abstract;
    procedure Modify(const AObject: M); virtual; abstract;
    procedure LoadLazy(const AOwner, AObject: TObject); virtual; abstract;
    procedure NextPacket(const AObjectList: TObjectList<M>); overload; virtual; abstract;
    function NextPacket: TObjectList<M>; overload; virtual; abstract;
    function NextPacket(const APageSize, APageNext: Integer): TObjectList<M>; overload; virtual; abstract;
    function NextPacket(const AWhere, AOrderby: String;
      const APageSize, APageNext: Integer): TObjectList<M>; overload; virtual; abstract;
    procedure New(var AObject: M); virtual; abstract;
  end;

implementation

end.
