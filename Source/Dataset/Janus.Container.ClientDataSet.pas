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
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
}

unit Janus.Container.ClientDataSet;

interface

uses
  DB,
  SysUtils,
  DBClient,
  /// Janus
  Janus.Session.DataSet,
  Janus.Container.DataSet,
  Janus.DataSet.ClientDataSet,
  DataEngine.FactoryInterfaces;

type
  TContainerClientDataSet<M: class, constructor> = class(TContainerDataSet<M>)
  public
    constructor Create(AConnection: IDBConnection;
      ADataSet: TDataSet; APageSize: Integer; AMasterObject: TObject); overload;
    constructor Create(AConnection: IDBConnection;
      ADataSet: TDataSet; APageSize: Integer); overload;
    constructor Create(AConnection: IDBConnection;
      ADataSet: TDataSet; AMasterObject: TObject); overload;
    constructor Create(AConnection: IDBConnection;
      ADataSet: TDataSet); overload;
    destructor Destroy; override;
  end;

implementation

{ TContainerClientDataSet }

constructor TContainerClientDataSet<M>.Create(AConnection: IDBConnection;
  ADataSet: TDataSet; APageSize: Integer; AMasterObject: TObject);
begin
  if not (ADataSet is TClientDataSet) then
    raise Exception.Create('Is not TClientDataSet type');

  FDataSetAdapter := TClientDataSetAdapter<M>.Create(AConnection, ADataSet, APageSize, AMasterObject)
end;

constructor TContainerClientDataSet<M>.Create(AConnection: IDBConnection;
  ADataSet: TDataSet; APageSize: Integer);
begin
  Create(AConnection, ADataSet, APageSize, nil);
end;

constructor TContainerClientDataSet<M>.Create(AConnection: IDBConnection;
  ADataSet: TDataSet; AMasterObject: TObject);
begin
  Create(AConnection, ADataSet, -1, AMasterObject);
end;

constructor TContainerClientDataSet<M>.Create(AConnection: IDBConnection;
  ADataSet: TDataSet);
begin
  Create(AConnection, ADataSet, -1, nil);
end;

destructor TContainerClientDataSet<M>.Destroy;
begin
  FDataSetAdapter.Free;
  inherited;
end;

end.
