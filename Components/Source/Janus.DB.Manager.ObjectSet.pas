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
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Janus.DB.Manager.ObjectSet;

interface

uses
  DB,
  Rtti,
  Classes,
  Generics.Collections,
  DataEngine.connection.base,
  Janus.Manager.ObjectSet;

type
  TJanusManagerObjectSet = class(TComponent)
  private
    FOwner: TComponent;
    FConnection: TDataEngineConnectionBase;
    FManagerObjectSet: TManagerObjectSet;
    function GetConnection: TDataEngineConnectionBase;
    procedure SetConnection(const Value: TDataEngineConnectionBase);
    function GetOwnerNestedList: Boolean;
    procedure SetOwnerNestedList(const Value: Boolean);
    function GetManagerObjectSet: TManagerObjectSet;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function AddAdapter<T: class, constructor>(const APageSize: Integer = -1): TJanusManagerObjectSet;
    function NestedList<T: class>: TObjectList<T>;
    /// ObjectSet
    function Find<T: class, constructor>: TObjectList<T>; overload;
    function Find<T: class, constructor>(const AID: TValue): T; overload;
    function FindWhere<T: class, constructor>(const AWhere: String;
                                              const AOrderBy: String = ''): TObjectList<T>;
    function ModifiedFields<T: class, constructor>: TDictionary<String, TDictionary<String, String>>;
    function ExistSequence<T: class, constructor>: Boolean;
    procedure LoadLazy<T: class, constructor>(const AObject: TObject); overload;
    /// <summary>
    ///   M�todos para serem usados com a propriedade OwnerNestedList := False;
    /// </summary>
    function Insert<T: class, constructor>(const AObject: T): Integer; overload;
    procedure Modify<T: class, constructor>(const AObject: T); overload;
    procedure Update<T: class, constructor>(const AObject: T); overload;
    procedure Delete<T: class, constructor>(const AObject: T); overload;
    procedure NextPacket<T: class, constructor>(var AObjectList: TObjectList<T>); overload;
    procedure New<T: class, constructor>(var AObject: T); overload;
    /// <summary>
    ///   M�todos para serem usados com a propriedade OwnerNestedList := True;
    /// </summary>
    function Current<T: class, constructor>: T; overload;
    function Current<T: class, constructor>(const AIndex: Integer): T; overload;
    function New<T: class, constructor>: Integer; overload;
   	function Insert<T: class, constructor>: Integer; overload;
    procedure Modify<T: class, constructor>; overload;
    procedure Update<T: class, constructor>; overload;
    procedure Delete<T: class, constructor>; overload;
    procedure NextPacket<T: class, constructor>; overload;
    function First<T: class, constructor>: Integer;
    function Next<T: class, constructor>: Integer;
    function Prior<T: class, constructor>: Integer;
    function Last<T: class, constructor>: Integer;
    function Bof<T: class>: Boolean;
    function Eof<T: class>: Boolean;
    property OwnerNestedList: Boolean read GetOwnerNestedList write SetOwnerNestedList;
  published
    property Connection: TDataEngineConnectionBase read GetConnection write SetConnection;
  end;

implementation

function TJanusManagerObjectSet.AddAdapter<T>(const APageSize: Integer): TJanusManagerObjectSet;
begin
  Result := Self;
  GetManagerObjectSet.AddRepository<T>(APageSize);
end;

function TJanusManagerObjectSet.Bof<T>: Boolean;
begin
  Result := GetManagerObjectSet.Bof<T>;
end;

constructor TJanusManagerObjectSet.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FOwner := AOwner;
  OwnerNestedList := True;
end;

function TJanusManagerObjectSet.Current<T>(const AIndex: Integer): T;
begin
  Result := GetManagerObjectSet.Current<T>(AIndex);
end;

function TJanusManagerObjectSet.Current<T>: T;
begin
  Result := GetManagerObjectSet.Current<T>;
end;

procedure TJanusManagerObjectSet.Delete<T>;
begin
  GetManagerObjectSet.Delete<T>;
end;

procedure TJanusManagerObjectSet.Delete<T>(const AObject: T);
begin
  GetManagerObjectSet.Delete<T>(AObject);
end;

destructor TJanusManagerObjectSet.Destroy;
begin
  if Assigned(FManagerObjectSet) then
    FManagerObjectSet.Free;
  inherited;
end;

function TJanusManagerObjectSet.Eof<T>: Boolean;
begin
  Result := GetManagerObjectSet.Eof<T>;
end;

function TJanusManagerObjectSet.ExistSequence<T>: Boolean;
begin
  Result := GetManagerObjectSet.ExistSequence<T>;
end;

function TJanusManagerObjectSet.Find<T>: TObjectList<T>;
begin
  Result := GetManagerObjectSet.Find<T>;
end;

function TJanusManagerObjectSet.Find<T>(const AID: TValue): T;
begin
  Result := GetManagerObjectSet.Find<T>(AID);
end;

function TJanusManagerObjectSet.FindWhere<T>(const AWhere, AOrderBy: String): TObjectList<T>;
begin
  Result := GetManagerObjectSet.FindWhere<T>(AWhere, AOrderBy);
end;

function TJanusManagerObjectSet.First<T>: Integer;
begin
  Result := GetManagerObjectSet.First<T>;
end;

function TJanusManagerObjectSet.GetManagerObjectSet: TManagerObjectSet;
begin
  if not Assigned(FManagerObjectSet) then
    FManagerObjectSet := TManagerObjectSet.Create(FConnection.DBConnection);
  Result := FManagerObjectSet;
end;

function TJanusManagerObjectSet.GetConnection: TDataEngineConnectionBase;
begin
  Result := FConnection;
end;

function TJanusManagerObjectSet.GetOwnerNestedList: Boolean;
begin
  Result := GetManagerObjectSet.OwnerNestedList;
end;

function TJanusManagerObjectSet.Insert<T>(const AObject: T): Integer;
begin
  Result := GetManagerObjectSet.Insert<T>(AObject);
end;

function TJanusManagerObjectSet.Insert<T>: Integer;
begin
  Result := GetManagerObjectSet.Insert<T>;
end;

function TJanusManagerObjectSet.Last<T>: Integer;
begin
  Result := GetManagerObjectSet.Last<T>;
end;

procedure TJanusManagerObjectSet.LoadLazy<T>(const AObject: TObject);
begin
  GetManagerObjectSet.LoadLazy<T>(AObject);
end;

function TJanusManagerObjectSet.ModifiedFields<T>: TDictionary<String, TDictionary<String, String>>;
begin
  Result := GetManagerObjectSet.ModifiedFields<T>;
end;

procedure TJanusManagerObjectSet.Modify<T>;
begin
  GetManagerObjectSet.Modify<T>;
end;

procedure TJanusManagerObjectSet.Modify<T>(const AObject: T);
begin
  GetManagerObjectSet.Modify<T>(AObject);
end;

function TJanusManagerObjectSet.NestedList<T>: TObjectList<T>;
begin
  Result := GetManagerObjectSet.NestedList<T>;
end;

procedure TJanusManagerObjectSet.New<T>(var AObject: T);
begin
  GetManagerObjectSet.New<T>(AObject);
end;

function TJanusManagerObjectSet.New<T>: Integer;
begin
  Result := GetManagerObjectSet.New<T>;
end;

function TJanusManagerObjectSet.Next<T>: Integer;
begin
  Result := GetManagerObjectSet.Next<T>;
end;

procedure TJanusManagerObjectSet.NextPacket<T>(var AObjectList: TObjectList<T>);
begin
  GetManagerObjectSet.NextPacket<T>(AObjectList);
end;

procedure TJanusManagerObjectSet.NextPacket<T>;
begin
  GetManagerObjectSet.NextPacket<T>;
end;

function TJanusManagerObjectSet.Prior<T>: Integer;
begin
  Result := GetManagerObjectSet.Prior<T>;
end;

procedure TJanusManagerObjectSet.SetConnection(const Value: TDataEngineConnectionBase);
begin
  FConnection := Value;
end;

procedure TJanusManagerObjectSet.SetOwnerNestedList(const Value: Boolean);
begin
  GetManagerObjectSet.OwnerNestedList := Value;
end;

procedure TJanusManagerObjectSet.Update<T>(const AObject: T);
begin
  GetManagerObjectSet.Update<T>(AObject);
end;

procedure TJanusManagerObjectSet.Update<T>;
begin
  GetManagerObjectSet.Update<T>;
end;

end.
