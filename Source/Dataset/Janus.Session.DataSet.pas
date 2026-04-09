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
  @author(Skype : ispinheiro)
}

unit Janus.Session.DataSet;

interface

uses
  DB,
  Rtti,
  TypInfo,
  Classes,
  Variants,
  SysUtils,
  Generics.Collections,
  /// Janus
  Janus.Command.Executor,
  Janus.Session.Abstract,
  Janus.DataSet.Base.Adapter,
  // MetaDbDiff
  MetaDbDiff.mapping.classes,
  DataEngine.FactoryInterfaces;

type
  TSessionDataSet<M: class, constructor> = class(TSessionAbstract<M>)
  private
    FOwner: TDataSetBaseAdapter<M>;
    procedure _PopularDataSet(const ADBResultSet: IDBDataSet);
  protected
    FConnection: IDBConnection;
  public
    constructor Create(const AOwner: TDataSetBaseAdapter<M>;
      const AConnection: IDBConnection; const APageSize: Integer = -1); overload;
    destructor Destroy; override;
    procedure OpenID(const AID: TValue); override;
    procedure OpenSQL(const ASQL: String); override;
    procedure OpenWhere(const AWhere: String; const AOrderBy: String = ''); override;
    procedure NextPacket; override;
    procedure RefreshRecord(const AColumns: TParams); override;
    procedure RefreshRecordWhere(const AWhere: String); override;
    function SelectAssociation(const AObject: TObject): String; override;
  end;

implementation

uses
  Janus.Bind;

{ TSessionDataSet<M> }

constructor TSessionDataSet<M>.Create(const AOwner: TDataSetBaseAdapter<M>;
  const AConnection: IDBConnection; const APageSize: Integer);
begin
  inherited Create(APageSize);
  FOwner := AOwner;
  FConnection := AConnection;
  FCommandExecutor := TSQLCommandExecutor<M>.Create(Self, AConnection, APageSize);
end;

destructor TSessionDataSet<M>.Destroy;
begin
  FCommandExecutor.Free;
  inherited;
end;

function TSessionDataSet<M>.SelectAssociation(const AObject: TObject): String;
begin
  inherited;
  Result := FCommandExecutor.SelectInternalAssociation(AObject);
end;

procedure TSessionDataSet<M>.OpenID(const AID: TValue);
var
  LDBResultSet: IDBDataSet;
begin
  inherited;
  LDBResultSet := FCommandExecutor.SelectInternalID(AID);
  _PopularDataSet(LDBResultSet);
end;

procedure TSessionDataSet<M>.OpenSQL(const ASQL: String);
var
  LDBResultSet: IDBDataSet;
begin
  inherited;
  if ASQL = '' then
    LDBResultSet := FCommandExecutor.SelectInternalAll
  else
    LDBResultSet := FCommandExecutor.SelectInternal(ASQL);
  _PopularDataSet(LDBResultSet);
end;

procedure TSessionDataSet<M>.OpenWhere(const AWhere: String;
  const AOrderBy: String);
begin
  inherited;
  OpenSQL(FCommandExecutor.SelectInternalWhere(AWhere, AOrderBy));
end;

procedure TSessionDataSet<M>.RefreshRecord(const AColumns: TParams);
var
  LDBResultSet: IDBDataSet;
  LWhere: String;
  LFor: Integer;
begin
  inherited;
  LWhere := '';
  for LFor := 0 to AColumns.Count -1 do
  begin
    LWhere := LWhere + AColumns[LFor].Name + '=' + AColumns[LFor].AsString;
    if LFor < AColumns.Count -1 then
      LWhere := LWhere + ' AND ';
  end;
  LDBResultSet := FCommandExecutor.SelectInternal(FCommandExecutor.SelectInternalWhere(LWhere, ''));
  while not LDBResultSet.Eof do
  begin
    FOwner.FOrmDataSet.Edit;
    Bind.SetFieldToField(LDBResultSet, FOwner.FOrmDataSet);
    FOwner.FOrmDataSet.Post;
  end;
end;

procedure TSessionDataSet<M>.RefreshRecordWhere(const AWhere: String);
var
  LDBResultSet: IDBDataSet;
begin
  inherited;
  LDBResultSet := FCommandExecutor.SelectInternal(FCommandExecutor.SelectInternalWhere(AWhere, ''));
  while not LDBResultSet.Eof do
  begin
    FOwner.FOrmDataSet.Edit;
    Bind.SetFieldToField(LDBResultSet, FOwner.FOrmDataSet);
    FOwner.FOrmDataSet.Post;
  end;
end;

procedure TSessionDataSet<M>.NextPacket;
var
  LDBResultSet: IDBDataSet;
begin
  inherited;
  LDBResultSet := FCommandExecutor.NextPacket;
  if LDBResultSet.RecordCount > 0 then
    _PopularDataSet(LDBResultSet)
  else
    FFetchingRecords := True;
end;

procedure TSessionDataSet<M>._PopularDataSet(const ADBResultSet: IDBDataSet);
begin
//  FOrmDataSet.Locate(KeyFiels, KeyValues, Options);
//  { TODO -oISAQUE : Procurar forma de verificar se o registro n�o j� est� em mem�ria
//  pela chave primaria }
  try
    while not ADBResultSet.Eof do
    begin
       FOwner.FOrmDataSet.Append;
       Bind.SetFieldToField(ADBResultSet, FOwner.FOrmDataSet);
       FOwner.FOrmDataSet.Fields[0].AsInteger := -1;
       FOwner.FOrmDataSet.Post;
    end;
  finally
    ADBResultSet.Close;
  end;
end;

end.
