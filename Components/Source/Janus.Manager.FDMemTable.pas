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

  ORM Brasil � um ORM simples e descomplicado para quem utiliza Delphi.
}

unit Janus.Manager.FDMemTable;

interface

uses
  DB,
  Rtti,
  Classes,
  Generics.Collections,
  DataEngine.connection.base,
  Janus.DB.Manager.FDMemTable;

type
  TJanusManagerFDMemTable = class(TComponent)
  private
    FOwner: TComponent;
    FConnection: TDataEngineConnectionBase;
    FManagerDataSet: TManagerFDMemTable;
    function GetConnection: TDataEngineConnectionBase;
    procedure SetConnection(const Value: TDataEngineConnectionBase);
    function GetOwnerNestedList: Boolean;
    procedure SetOwnerNestedList(const Value: Boolean);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure RemoveAdapter<T: class>;
    function AddAdapter<T: class, constructor>(const ADataSet: TDataSet;
      const APageSize: Integer = -1): TManagerFDMemTable; overload;
    function AddAdapter<T, M: class, constructor>(const ADataSet: TDataSet): TManagerFDMemTable; overload;
    function AddLookupField<T, M: class, constructor>(const AFieldName: String;
                                                      const AKeyFields: String;
                                                      const ALookupKeyFields: String;
                                                      const ALookupResultField: String;
                                                      const ADisplayLabel: String = ''): TManagerFDMemTable;
    procedure Open<T: class, constructor>; overload;
    procedure Open<T: class, constructor>(const AID: Integer); overload;
    procedure Open<T: class, constructor>(const AID: String); overload;
    procedure OpenWhere<T: class, constructor>(const AWhere: String; const AOrderBy: String = '');
    procedure Close<T: class, constructor>;
    procedure LoadLazy<T: class, constructor>(const AOwner: T);
    procedure RefreshRecord<T: class, constructor>;
    procedure EmptyDataSet<T: class, constructor>;
    procedure CancelUpdates<T: class, constructor>;
    procedure ApplyUpdates<T: class, constructor>(const MaxErros: Integer);
    procedure Save<T: class, constructor>(AObject: T);
    function Current<T: class, constructor>: T;
    function DataSet<T: class, constructor>: TDataSet;
    /// ObjectSet
    function Find<T: class, constructor>: TObjectList<T>; overload;
    function Find<T: class, constructor>(const AID: TValue): T; overload;
    function FindWhere<T: class, constructor>(const AWhere: String;
                                              const AOrderBy: String = ''): TObjectList<T>;
    function NestedList<T: class>: TObjectList<T>;
    function AutoNextPacket<T: class, constructor>(const AValue: Boolean): TManagerFDMemTable;
    property OwnerNestedList: Boolean read GetOwnerNestedList write SetOwnerNestedList;
  published
    property Connection: TDataEngineConnectionBase read GetConnection write SetConnection;
  end;

implementation

{ TDBManagerDataSet }

function TJanusManagerFDMemTable.AddAdapter<T, M>(const ADataSet: TDataSet): TManagerFDMemTable;
begin
  Result := FManagerDataSet.AddAdapter<T, M>(ADataSet);
end;

function TJanusManagerFDMemTable.AddAdapter<T>(const ADataSet: TDataSet;
  const APageSize: Integer): TManagerFDMemTable;
begin
  Result := FManagerDataSet.AddAdapter<T>(ADataSet, APageSize);
end;

function TJanusManagerFDMemTable.AddLookupField<T, M>(const AFieldName, AKeyFields,
  ALookupKeyFields, ALookupResultField, ADisplayLabel: String): TManagerFDMemTable;
begin
  Result := FManagerDataSet.AddLookupField<T, M>(AFieldName, AKeyFields,
                                                 ALookupKeyFields, ALookupResultField, ADisplayLabel);
end;

procedure TJanusManagerFDMemTable.ApplyUpdates<T>(const MaxErros: Integer);
begin
  FManagerDataSet.ApplyUpdates<T>(MaxErros);
end;

function TJanusManagerFDMemTable.AutoNextPacket<T>(const AValue: Boolean): TManagerFDMemTable;
begin
  Result := FManagerDataSet.AutoNextPacket<T>(AValue);
end;

procedure TJanusManagerFDMemTable.CancelUpdates<T>;
begin
  FManagerDataSet.CancelUpdates<T>;
end;

procedure TJanusManagerFDMemTable.Close<T>;
begin
  FManagerDataSet.Close<T>;
end;

constructor TJanusManagerFDMemTable.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FOwner := AOwner;
end;

function TJanusManagerFDMemTable.Current<T>: T;
begin
  Result := FManagerDataSet.Current<T>;
end;

function TJanusManagerFDMemTable.DataSet<T>: TDataSet;
begin
  Result := FManagerDataSet.DataSet<T>;
end;

destructor TJanusManagerFDMemTable.Destroy;
begin
  if Assigned(FManagerDataSet) then
    FManagerDataSet.Free;
  inherited;
end;

procedure TJanusManagerFDMemTable.EmptyDataSet<T>;
begin
  FManagerDataSet.EmptyDataSet<T>;
end;

function TJanusManagerFDMemTable.Find<T>(const AID: TValue): T;
begin
  Result := FManagerDataSet.Find<T>(AID);
end;

function TJanusManagerFDMemTable.Find<T>: TObjectList<T>;
begin
  Result := FManagerDataSet.Find<T>;
end;

function TJanusManagerFDMemTable.FindWhere<T>(const AWhere, AOrderBy: String): TObjectList<T>;
begin
  Result := FManagerDataSet.FindWhere<T>(AWhere, AOrderBy);
end;

function TJanusManagerFDMemTable.GetConnection: TDataEngineConnectionBase;
begin
  Result := FConnection;
end;

function TJanusManagerFDMemTable.GetOwnerNestedList: Boolean;
begin
  Result := FManagerDataSet.OwnerNestedList;
end;

procedure TJanusManagerFDMemTable.LoadLazy<T>(const AOwner: T);
begin
  FManagerDataSet.LoadLazy<T>(AOwner);
end;

function TJanusManagerFDMemTable.NestedList<T>: TObjectList<T>;
begin
  Result := FManagerDataSet.NestedList<T>;
end;

procedure TJanusManagerFDMemTable.Open<T>;
begin
  FManagerDataSet.Open<T>;
end;

procedure TJanusManagerFDMemTable.Open<T>(const AID: Integer);
begin
  FManagerDataSet.Open<T>(AID);
end;

procedure TJanusManagerFDMemTable.Open<T>(const AID: String);
begin
  FManagerDataSet.Open<T>(AID);
end;

procedure TJanusManagerFDMemTable.OpenWhere<T>(const AWhere, AOrderBy: String);
begin
  FManagerDataSet.OpenWhere<T>(AWhere, AOrderBy);
end;

procedure TJanusManagerFDMemTable.RefreshRecord<T>;
begin
  FManagerDataSet.RefreshRecord<T>;
end;

procedure TJanusManagerFDMemTable.RemoveAdapter<T>;
begin
  FManagerDataSet.RemoveAdapter<T>;
end;

procedure TJanusManagerFDMemTable.Save<T>(AObject: T);
begin
  FManagerDataSet.Save<T>(AObject);
end;

procedure TJanusManagerFDMemTable.SetConnection(const Value: TDataEngineConnectionBase);
begin
  FConnection := Value;
  if Assigned(FManagerDataSet) then
    FManagerDataSet.Free;
  FManagerDataSet := TManagerFDMemTable.Create(FConnection.DBConnection);
end;

procedure TJanusManagerFDMemTable.SetOwnerNestedList(const Value: Boolean);
begin
  FManagerDataSet.OwnerNestedList := Value;
end;

end.
