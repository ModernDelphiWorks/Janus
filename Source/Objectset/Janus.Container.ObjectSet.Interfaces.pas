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
}

unit Janus.Container.ObjectSet.Interfaces;

interface

uses
  Rtti,
  Generics.Collections;

type
  IContainerObjectSet<M: class, constructor> = interface
    ['{427CBF16-5FD5-4144-9699-09B08335D545}']
    function ExistSequence: Boolean;
    function ModifiedFields: TDictionary<String, TDictionary<String, String>>;
    function Find: TObjectList<M>; overload;
    function Find(const AID: Int64): M; overload;
    function Find(const AID: String): M; overload;
    function FindWhere(const AWhere: String; const AOrderBy: String = ''): TObjectList<M>;
    procedure Insert(const AObject: M);
    procedure Update(const AObject: M);
    procedure Delete(const AObject: M);
    procedure Modify(const AObject: M);
    procedure LoadLazy(const AOwner, AObject: TObject);
    procedure NextPacket(const AObjectList: TObjectList<M>); overload;
    function NextPacket: TObjectList<M>; overload;
    function NextPacket(const APageSize, APageNext: Integer): TObjectList<M>; overload;
    function NextPacket(const AWhere, AOrderBy: String; const APageSize, APageNext: Integer): TObjectList<M>; overload;
  end;

implementation

end.
