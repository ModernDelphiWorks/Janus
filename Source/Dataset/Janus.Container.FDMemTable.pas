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
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Janus.Container.FDMemTable;

interface

uses
  DB,
  SysUtils,
  FireDAC.Comp.Client,
  /// Janus
  Janus.Session.DataSet,
  Janus.Container.DataSet,
  DataEngine.FactoryInterfaces,
  Janus.DataSet.FDMemTable;

type
  TContainerFDMemTable<M: class, constructor> = class(TContainerDataSet<M>)
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

{ TContainerFDMemTable }

constructor TContainerFDMemTable<M>.Create(AConnection: IDBConnection;
  ADataSet: TDataSet; APageSize: Integer; AMasterObject: TObject);
begin
  if not (ADataSet is TFDMemTable) then
    raise Exception.Create('Is not TFDMemTable type');

  FDataSetAdapter := TFDMemTableAdapter<M>.Create(AConnection, ADataSet, APageSize, AMasterObject)
end;

constructor TContainerFDMemTable<M>.Create(AConnection: IDBConnection;
  ADataSet: TDataSet; APageSize: Integer);
begin
  Create(AConnection, ADataSet, APageSize, nil);
end;

constructor TContainerFDMemTable<M>.Create(AConnection: IDBConnection;
  ADataSet: TDataSet; AMasterObject: TObject);
begin
  Create(AConnection, ADataSet, -1, AMasterObject);
end;

constructor TContainerFDMemTable<M>.Create(AConnection: IDBConnection;
  ADataSet: TDataSet);
begin
  Create(AConnection, ADataSet, -1, nil);
end;

destructor TContainerFDMemTable<M>.Destroy;
begin
  FDataSetAdapter.Free;
  inherited;
end;

end.
