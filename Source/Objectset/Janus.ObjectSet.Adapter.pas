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

unit Janus.ObjectSet.Adapter;

interface

uses
  Rtti,
  TypInfo,
  Classes,
  Variants,
  SysUtils,
  Generics.Collections,
  // Janus
  Janus.ObjectSet.Base.Adapter,
  Janus.Objects.Helper,
  DataEngine.FactoryInterfaces,
  MetaDbDiff.mapping.classes,
  MetaDbDiff.mapping.popular,
  MetaDbDiff.types.mapping;

type
  TObjectSetAdapter<M: class, constructor> = class(TObjectSetBaseAdapter<M>)
  private
    FConnection: IDBConnection;
  public
    constructor Create(const AConnection: IDBConnection;
      const APageSize: Integer = -1); overload;
    destructor Destroy; override;
    function Find: TObjectList<M>; overload; override;
    function Find(const AID: Int64): M; overload; override;
    function Find(const AID: String): M; overload; override;
    function FindWhere(const AWhere: String;
      const AOrderBy: String = ''): TObjectList<M>; overload; override;
    procedure Insert(const AObject: M); override;
    procedure Update(const AObject: M); override;
    procedure Delete(const AObject: M); override;
  end;

implementation

uses
  Janus.Session.ObjectSet,
  Janus.Core.Consts,
  MetaDbDiff.mapping.explorer;

{ TObjectSetAdapter<M> }

constructor TObjectSetAdapter<M>.Create(const AConnection: IDBConnection;
  const APageSize: Integer);
begin
  inherited Create;
  FConnection := AConnection;
  FSession := TSessionObjectSet<M>.Create(AConnection, APageSize);
end;

destructor TObjectSetAdapter<M>.Destroy;
begin
  FSession.Free;
  inherited;
end;

procedure TObjectSetAdapter<M>.Delete(const AObject: M);
var
  LInTransaction: Boolean;
  LIsConnected: Boolean;
begin
  inherited;
  // Controle de transa��o externa, controlada pelo desenvolvedor
  LInTransaction := FConnection.InTransaction;
  LIsConnected := FConnection.IsConnected;
  if not LIsConnected then
    FConnection.Connect;
  try
    if not LInTransaction then
      FConnection.StartTransaction;
    try
      // Executa comando delete em cascade
      CascadeActionsExecute(AObject, TCascadeAction.CascadeDelete);
      // Executa comando delete master
      FSession.Delete(AObject);
      ///
      if not LInTransaction then
        FConnection.Commit;
    except
      on E: Exception do
      begin
        if not LInTransaction then
          FConnection.Rollback;
        raise Exception.Create(E.Message);
      end;
    end;
  finally
    if not LIsConnected then
      FConnection.Disconnect;
  end;
end;

function TObjectSetAdapter<M>.FindWhere(const AWhere, AOrderBy: String): TObjectList<M>;
var
  LIsConnected: Boolean;
begin
  inherited;
  LIsConnected := FConnection.IsConnected;
  if not LIsConnected then
    FConnection.Connect;
  try
    Result := FSession.FindWhere(AWhere, AOrderBy);
  finally
    if not LIsConnected then
      FConnection.Disconnect;
  end;
end;

function TObjectSetAdapter<M>.Find(const AID: Int64): M;
var
  LIsConnected: Boolean;
begin
  inherited;
  LIsConnected := FConnection.IsConnected;
  if not LIsConnected then
    FConnection.Connect;
  try
    Result := FSession.Find(AID);
  finally
    if not LIsConnected then
      FConnection.Disconnect;
  end;
end;

function TObjectSetAdapter<M>.Find: TObjectList<M>;
var
  LIsConnected: Boolean;
begin
  inherited;
  LIsConnected := FConnection.IsConnected;
  if not LIsConnected then
    FConnection.Connect;
  try
    Result := FSession.Find;
  finally
    if not LIsConnected then
      FConnection.Disconnect;
  end;
end;

procedure TObjectSetAdapter<M>.Insert(const AObject: M);
var
  LPrimaryKey: TPrimaryKeyColumnsMapping;
  LColumn: TColumnMapping;
  LInTransaction: Boolean;
  LIsConnected: Boolean;
begin
  inherited;
  // Controle de transa��o externa, controlada pelo desenvolvedor
  LInTransaction := FConnection.InTransaction;
  LIsConnected := FConnection.IsConnected;
  if not LIsConnected then
    FConnection.Connect;
  try
    if not LInTransaction then
      FConnection.StartTransaction;
    try
      FSession.Insert(AObject);
      if FSession.ExistSequence then
      begin
        LPrimaryKey := TMappingExplorer
                           .GetMappingPrimaryKeyColumns(AObject.ClassType);
        if LPrimaryKey = nil then
          raise Exception.Create(cMESSAGEPKNOTFOUND);

        for LColumn in LPrimaryKey.Columns do
          SetAutoIncValueChilds(AObject, LColumn);
      end;
      // Executa comando insert em cascade
      CascadeActionsExecute(AObject, TCascadeAction.CascadeInsert);
      //
      if not LInTransaction then
        FConnection.Commit;
    except
      on E: Exception do
      begin
        if not LInTransaction then
          FConnection.Rollback;
        raise Exception.Create(E.Message);
      end;
    end;
  finally
    if not LIsConnected then
      FConnection.Disconnect;
  end;
end;

procedure TObjectSetAdapter<M>.Update(const AObject: M);
var
  LRttiType: TRttiType;
  LProperty: TRttiProperty;
  LObjectKey: TObject;
  LKey: String;
  LInTransaction: Boolean;
  LIsConnected: Boolean;
begin
  inherited;
  // Controle de transa��o externa, controlada pelo desenvolvedor
  LInTransaction := FConnection.InTransaction;
  LIsConnected := FConnection.IsConnected;
  if not LIsConnected then
    FConnection.Connect;
  try
    if not LInTransaction then
      FConnection.StartTransaction;
    try
      // Executa comando update em cascade
      CascadeActionsExecute(AObject, TCascadeAction.CascadeUpdate);
      // Gera a lista com as propriedades que foram alteradas
      if TObject(AObject).GetType(LRttiType) then
      begin
        LKey := GenerateKey(AObject);
        if FObjectState.TryGetValue(LKey, LObjectKey) then
        begin
          FSession.ModifyFieldsCompare(LKey, LObjectKey, AObject);
          FSession.Update(AObject, LKey);
          FObjectState.Remove(LKey);
          FObjectState.TrimExcess;
        end;
        // Remove o item exclu�do em Update Mestre-Detalhe
        for LObjectKey in FObjectState.Values do
          FSession.Delete(LObjectKey);
      end;
      if not LInTransaction then
        FConnection.Commit;
    except
      on E: Exception do
      begin
        if not LInTransaction then
          FConnection.Rollback;
        raise Exception.Create(E.Message);
      end;
    end;
  finally
    if not LIsConnected then
      FConnection.Disconnect;
    FObjectState.Clear;
    // Ap�s executar o comando SQL Update, limpa a lista de campos alterados.
    FSession.ModifiedFields.Clear;
    FSession.ModifiedFields.TrimExcess;
    FSession.DeleteList.Clear;
    FSession.DeleteList.TrimExcess;
  end;
end;

function TObjectSetAdapter<M>.Find(const AID: String): M;
var
  LIsConnected: Boolean;
begin
  inherited;
  LIsConnected := FConnection.IsConnected;
  if not LIsConnected then
    FConnection.Connect;
  try
    Result := FSession.Find(AID);
  finally
    if not LIsConnected then
      FConnection.Disconnect;
  end;
end;

end.
