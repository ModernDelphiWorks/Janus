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
  @abstract(REST Componentes)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

{$INCLUDE ..\..\Janus.inc}

unit Janus.Server.RestObjectSet;

interface

uses
  Rtti,
  Variants,
  SysUtils,
  Generics.Collections,
  MetaDbDiff.mapping.classes,
  MetaDbDiff.types.mapping,
  MetaDbDiff.rtti.helper,
  MetaDbDiff.mapping.explorer,
  MetaDbDiff.mapping.popular,
  DataEngine.FactoryInterfaces,
  Janus.Core.Consts,
  Janus.Objects.Helper,
  Janus.Server.RestObjectSet.Session;

type
  TRESTObjectSet = class
  private
    FConnection: IDBConnection;
    procedure AddObjectState(const ASourceObject: TObject);
    procedure UpdateInternal(const AObject: TObject);
  protected
    FSession: TRESTObjectSetSession;
    FObjectState: TDictionary<String, TObject>;
    function GenerateKey(const AObject: TObject): String;
    procedure CascadeActionsExecute(const AObject: TObject; const ACascadeAction: TCascadeAction);
    procedure OneToOneCascadeActionsExecute(const AObject: TObject;
      const AAssociation: TAssociationMapping; const ACascadeAction: TCascadeAction);
    procedure OneToManyCascadeActionsExecute(const AObject: TObject;
      const AAssociation: TAssociationMapping; const ACascadeAction: TCascadeAction);
    procedure SetAutoIncValueChilds(const AObject: TObject; const AColumn: TColumnMapping);
    procedure SetAutoIncValueOneToOne(const AObject: TObject;
      const AAssociation: TAssociationMapping; const AProperty: TRttiProperty);
    procedure SetAutoIncValueOneToMany(const AObject: TObject;
      const AAssociation: TAssociationMapping; const AProperty: TRttiProperty);
  public
    constructor Create(const AConnection: IDBConnection; const AClassType: TClass;
      const APageSize: Integer = -1);
    destructor Destroy; override;
    function ExistSequence: Boolean;
    function ModifiedFields: TDictionary<String, TDictionary<String, String>>; virtual;
    function Find: TObjectList<TObject>; overload; virtual;
    function Find(const AID: Int64): TObject; overload; virtual;
    function Find(const AID: String): TObject; overload; virtual;
    function FindOne(const AWhere: String): TObject; virtual;
    function FindWhere(const AWhere: String; const AOrderBy: String = ''): TObjectList<TObject>; overload; virtual;
    procedure Insert(const AObject: TObject); virtual;
    procedure Update(const AObject: TObject); virtual;
    procedure Delete(const AObject: TObject); virtual;
    procedure Modify(const AObject: TObject); virtual;
    procedure LoadLazy(const AOwner, AObject: TObject); virtual;
    procedure NextPacket(const AObjectList: TObjectList<TObject>); overload; virtual;
    function NextPacket: TObjectList<TObject>; overload; virtual;
    function NextPacket(const APageSize, APageNext: Integer): TObjectList<TObject>; overload; virtual;
    function NextPacket(const AWhere, AOrderBy: String; const APageSize, APageNext: Integer): TObjectList<TObject>; overload; virtual;
  end;

implementation

{ TRESTObjectSet<M> }

constructor TRESTObjectSet.Create(const AConnection: IDBConnection;
  const AClassType: TClass; const APageSize: Integer);
begin
  FConnection := AConnection;
  FObjectState := TObjectDictionary<String, TObject>.Create([doOwnsValues]);
  FSession := TRESTObjectSetSession.Create(AConnection, AClassType, APageSize);
end;

destructor TRESTObjectSet.Destroy;
begin
  FSession.Free;
  FObjectState.Clear;
  FObjectState.Free;
  inherited;
end;

procedure TRESTObjectSet.Delete(const AObject: TObject);
var
  LInTransaction: Boolean;
  LIsConnected: Boolean;
begin
  inherited;
  // Controle de transacao externa, controlada pelo desenvolvedor
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

procedure TRESTObjectSet.AddObjectState(const ASourceObject: TObject);
var
  LRttiType: TRttiType;
  LProperty: TRttiProperty;
  LObjectList: TObjectList<TObject>;
  LStateObject: TObject;
  LObjectItem: TObject;
  LKey: String;
begin
  if ASourceObject.GetType(LRttiType) then
  begin
    // Cria um novo objeto para ser guardado na lista com o estado atual do ASourceObject.
    LStateObject := ASourceObject.ClassType.Create;
    // Gera uma chave de identificacao unica para cada item da lista
    LKey := GenerateKey(ASourceObject);
    // Guarda o novo objeto na lista, identificado pela chave
    FObjectState.Add(LKey, LStateObject);
    try
      for LProperty in LRttiType.GetProperties do
      begin
        if not LProperty.IsWritable then
          Continue;
        if LProperty.IsNotCascade then
          Continue;
        if LProperty.PropertyType.TypeKind in cPROPERTYTYPES_2 then
          Continue;
        if LProperty.PropertyType.TypeKind = tkClass then
        begin
          if LProperty.IsList then
          begin
            LObjectList := TObjectList<TObject>(LProperty.GetValue(ASourceObject).AsObject);
            for LObjectItem in LObjectList do
            begin
              if LObjectItem <> nil then
                AddObjectState(LObjectItem);
            end;
          end
          else
            AddObjectState(LProperty.GetValue(ASourceObject).AsObject);
        end
        else
          LProperty.SetValue(LStateObject, LProperty.GetValue(ASourceObject));
      end;
    except
      raise;
    end;
  end;
end;

procedure TRESTObjectSet.CascadeActionsExecute(const AObject: TObject;
  const ACascadeAction: TCascadeAction);
var
  LAssociation: TAssociationMapping;
  LAssociations: TAssociationMappingList;
begin
  LAssociations := TMappingExplorer.GetMappingAssociation(AObject.ClassType);
  if LAssociations = nil then
    Exit;
  for LAssociation in LAssociations do
  begin
    if not (ACascadeAction in LAssociation.CascadeActions) then
      Continue;
    if LAssociation.Multiplicity in [TMultiplicity.OneToOne, TMultiplicity.ManyToOne] then
      OneToOneCascadeActionsExecute(AObject, LAssociation, ACascadeAction)
    else
    if LAssociation.Multiplicity in [TMultiplicity.OneToMany, TMultiplicity.ManyToMany] then
      OneToManyCascadeActionsExecute(AObject, LAssociation, ACascadeAction);
  end;
end;

function TRESTObjectSet.ExistSequence: Boolean;
begin
  Result := FSession.ExistSequence;
end;

function TRESTObjectSet.Find(const AID: String): TObject;
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

function TRESTObjectSet.FindOne(const AWhere: String): TObject;
var
  LIsConnected: Boolean;
begin
  inherited;
  LIsConnected := FConnection.IsConnected;
  if not LIsConnected then
    FConnection.Connect;
  try
    Result := FSession.FindOne(AWhere);
  finally
    if not LIsConnected then
      FConnection.Disconnect;
  end;
end;

function TRESTObjectSet.FindWhere(const AWhere,
  AOrderBy: String): TObjectList<TObject>;
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

function TRESTObjectSet.Find(const AID: Int64): TObject;
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

function TRESTObjectSet.Find: TObjectList<TObject>;
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

function TRESTObjectSet.GenerateKey(const AObject: TObject): String;
var
  LPrimaryKey: TPrimaryKeyColumnsMapping;
  LColumn: TColumnMapping;
  LKey: String;
begin
  LKey := AObject.ClassName;
  LPrimaryKey := TMappingExplorer
                     .GetMappingPrimaryKeyColumns(AObject.ClassType);
  if LPrimaryKey = nil then
    raise Exception.Create(cMESSAGEPKNOTFOUND);

  for LColumn in LPrimaryKey.Columns do
    LKey := LKey + '-' + VarToStr(LColumn.ColumnProperty.GetNullableValue(AObject).AsVariant);
  Result := LKey;
end;

procedure TRESTObjectSet.Insert(const AObject: TObject);
var
  LPrimaryKey: TPrimaryKeyColumnsMapping;
  LColumn: TColumnMapping;
  LInTransaction: Boolean;
  LIsConnected: Boolean;
begin
  // Controle de transacao externa, controlada pelo desenvolvedor
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

procedure TRESTObjectSet.LoadLazy(const AOwner, AObject: TObject);
begin
  FSession.LoadLazy(AOwner, AObject);
end;

function TRESTObjectSet.ModifiedFields: TDictionary<String, TDictionary<String, String>>;
begin
  Result := FSession.ModifiedFields;
end;

procedure TRESTObjectSet.Modify(const AObject: TObject);
begin
  FObjectState.Clear;
  AddObjectState(AObject);
end;

function TRESTObjectSet.NextPacket(const AWhere, AOrderBy: String;
  const APageSize, APageNext: Integer): TObjectList<TObject>;
begin
  Result := FSession.NextPacketList(AWhere, AOrderBy, APageSize, APageNext);
end;

function TRESTObjectSet.NextPacket(const APageSize, APageNext: Integer): TObjectList<TObject>;
begin
  Result := FSession.NextPacketList(APageSize, APageNext);
end;

procedure TRESTObjectSet.NextPacket(const AObjectList: TObjectList<TObject>);
begin
  FSession.NextPacketList(AObjectList);
end;

procedure TRESTObjectSet.OneToManyCascadeActionsExecute(const AObject: TObject;
  const AAssociation: TAssociationMapping; const ACascadeAction: TCascadeAction);
var
  LPrimaryKey: TPrimaryKeyColumnsMapping;
  LColumn: TColumnMapping;
  LValue: TValue;
  LObjectList: TObjectList<TObject>;
  LObject: TObject;
  LObjectKey: TObject;
  LFor: Integer;
  LKey: String;
begin
  LValue := AAssociation.PropertyRtti.GetNullableValue(AObject);
  if not LValue.IsObject then
    Exit;

  LObjectList := TObjectList<TObject>(LValue.AsObject);
  for LFor := 0 to LObjectList.Count -1 do
  begin
    LObject := LObjectList.Items[LFor];
    if ACascadeAction = TCascadeAction.CascadeInsert then // Insert
    begin
      FSession.Insert(LObject);
      // Popula as propriedades de relacionamento com os valores do filho recem
      // inserido. A chave lida e a de LObject, o objeto que acabou de receber
      // seu proprio valor gerado e cujos filhos SetAutoIncValueChilds percorre;
      // ler a chave de AObject entrega a SetAutoIncValueOneToMany uma
      // TRttiProperty do master para ser lida contra o filho.
      //
      // Sem guarda de ExistSequence, como na base. Medido: aquela flag e um
      // campo unico do TCommandInserter que TDMLCommandFactory cria UMA vez no
      // construtor, escrito so por TCommandInserter.GenerateInsert e nunca
      // limpo - ela diz qual foi o ULTIMO insert a entrar no ramo do gerador,
      // nao se ESTA entidade tem autoinc. Com as chaves vindas do proprio
      // cliente nenhum insert entra naquele ramo, a flag continua no False
      // inicial, e a propagacao era pulada para um filho que TEM chave:
      // os netos chegavam ao banco em zero, sem levantar nada.
      LPrimaryKey := TMappingExplorer
                         .GetMappingPrimaryKeyColumns(LObject.ClassType);
      if LPrimaryKey = nil then
        raise Exception.Create(cMESSAGEPKNOTFOUND);

      for LColumn in LPrimaryKey.Columns do
        SetAutoIncValueChilds(LObject, LColumn);
    end
    else
    if ACascadeAction = TCascadeAction.CascadeDelete then // Delete
    begin
      // Desce ANTES de apagar, como na base. Apagar o item e alcancar os
      // filhos DELE depois derruba a linha enquanto as linhas que apontam
      // para ela ainda existem - que e exatamente o que uma chave estrangeira
      // obrigatoria levanta.
      CascadeActionsExecute(LObject, TCascadeAction.CascadeDelete);
      FSession.Delete(LObject);
    end
    else
    if ACascadeAction = TCascadeAction.CascadeUpdate then // Update
    begin
      LKey := GenerateKey(LObject);
      if FObjectState.ContainsKey(LKey) then
      begin
        LObjectKey := FObjectState.Items[LKey];
        FSession.ModifyFieldsCompare(LKey, LObjectKey, LObject);
        UpdateInternal(LObject);
        FObjectState.Remove(LKey);
        FObjectState.TrimExcess;
      end
      else
      begin
        FSession.Insert(LObject);
        // Item ausente do estado guardado por Modify: entra como INSERT, e
        // acaba de ganhar sua propria chave. Quem espera essa chave sao os
        // filhos DELE, gravados logo abaixo pelo CascadeActionsExecute - o que
        // nao for carimbado aqui chega ao banco em zero, sem levantar nada.
        // Mesma leitura do ramo de insert: a chave e lida de LObject, e o
        // carimbo roda DENTRO do laco, para cada item, porque cada item da
        // lista ganhou uma chave diferente da do anterior.
        LPrimaryKey := TMappingExplorer
                           .GetMappingPrimaryKeyColumns(LObject.ClassType);
        if LPrimaryKey = nil then
          raise Exception.Create(cMESSAGEPKNOTFOUND);

        for LColumn in LPrimaryKey.Columns do
          SetAutoIncValueChilds(LObject, LColumn);
      end;
    end;
    // Executa comando em cascade de cada objeto da lista. O delete ja desceu
    // no ramo acima, antes de apagar; repetir a descida aqui apagaria a
    // subarvore uma segunda vez.
    if not (ACascadeAction = TCascadeAction.CascadeDelete) then
      CascadeActionsExecute(LObject, ACascadeAction);
  end;
end;

procedure TRESTObjectSet.OneToOneCascadeActionsExecute(
  const AObject: TObject; const AAssociation: TAssociationMapping;
  const ACascadeAction: TCascadeAction);
var
  LPrimaryKey: TPrimaryKeyColumnsMapping;
  LColumn: TColumnMapping;
  LValue: TValue;
  LObject: TObject;
  LObjectKey: TObject;
  LKey: String;
begin
  LValue := AAssociation.PropertyRtti.GetNullableValue(AObject);
  if not LValue.IsObject then
    Exit;

  LObject := LValue.AsObject;
  // TValue reporta tkClass tambem para uma instancia nil, entao IsObject acima
  // deixa passar um ramo opcional que nunca foi preenchido. Medido pela rota de
  // producao: sem esta linha, inserir uma raiz cujo ramo OneToOne e nil devolve
  // `Access violation ... Read of address 00000000` e o rollback leva junto a
  // linha do master - o registro nao chega a ser criado.
  if LObject = nil then
    Exit;
  if ACascadeAction = TCascadeAction.CascadeInsert then // Insert
  begin
    FSession.Insert(LObject);
    // Popula as propriedades de relacionamento com os valores do filho recem
    // inserido. Mesma razao de OneToManyCascadeActionsExecute: quem acabou de
    // ganhar chave e LObject, e e a chave DELE que os filhos dele esperam.
    // Sem guarda de ExistSequence, pelo mesmo motivo medido la.
    LPrimaryKey := TMappingExplorer.GetMappingPrimaryKeyColumns(LObject.ClassType);
    if LPrimaryKey = nil then
      raise Exception.Create(cMESSAGEPKNOTFOUND);

    for LColumn in LPrimaryKey.Columns do
      SetAutoIncValueChilds(LObject, LColumn);
  end
  else
  if ACascadeAction = TCascadeAction.CascadeDelete then // Delete
  begin
    // Desce ANTES de apagar, como na base - ver OneToManyCascadeActionsExecute.
    CascadeActionsExecute(LObject, TCascadeAction.CascadeDelete);
    FSession.Delete(LObject);
  end
  else
  if ACascadeAction = TCascadeAction.CascadeUpdate then // Update
  begin
    LKey := GenerateKey(LObject);
    if FObjectState.ContainsKey(LKey) then
    begin
      LObjectKey := FObjectState.Items[LKey];
      FSession.ModifyFieldsCompare(LKey, LObjectKey, LObject);
      UpdateInternal(LObject);
      FObjectState.Remove(LKey);
      FObjectState.TrimExcess;
    end
    else
    begin
      FSession.Insert(LObject);
      // Objeto ausente do estado guardado por Modify: entra como INSERT, e
      // acaba de ganhar sua propria chave. Quem espera essa chave sao os
      // filhos DELE, gravados logo abaixo pelo CascadeActionsExecute - o que
      // nao for carimbado aqui chega ao banco em zero, sem levantar nada.
      // Mesma leitura do ramo de insert: a chave e lida de LObject.
      LPrimaryKey := TMappingExplorer
                         .GetMappingPrimaryKeyColumns(LObject.ClassType);
      if LPrimaryKey = nil then
        raise Exception.Create(cMESSAGEPKNOTFOUND);

      for LColumn in LPrimaryKey.Columns do
        SetAutoIncValueChilds(LObject, LColumn);
    end;
  end;
  // Executa comando em cascade de cada objeto da lista. O delete ja desceu no
  // ramo acima, antes de apagar.
  if not (ACascadeAction = TCascadeAction.CascadeDelete) then
    CascadeActionsExecute(LObject, ACascadeAction);
end;

procedure TRESTObjectSet.SetAutoIncValueChilds(const AObject: TObject;
  const AColumn: TColumnMapping);
var
  LAssociation: TAssociationMapping;
  LAssociations: TAssociationMappingList;
begin
  /// Association
  LAssociations := TMappingExplorer.GetMappingAssociation(AObject.ClassType);
  if LAssociations = nil then
    Exit;

  for LAssociation in LAssociations do
  begin
    if not (TCascadeAction.CascadeAutoInc in LAssociation.CascadeActions) then
      Continue;

    if LAssociation.Multiplicity in [TMultiplicity.OneToOne, TMultiplicity.ManyToOne] then
      SetAutoIncValueOneToOne(AObject, LAssociation, AColumn.ColumnProperty)
    else
    if LAssociation.Multiplicity in [TMultiplicity.OneToMany, TMultiplicity.ManyToMany] then
      SetAutoIncValueOneToMany(AObject, LAssociation, AColumn.ColumnProperty);
  end;
end;

procedure TRESTObjectSet.SetAutoIncValueOneToMany(const AObject: TObject;
  const AAssociation: TAssociationMapping; const AProperty: TRttiProperty);
var
  LType: TRttiType;
  LProperty: TRttiProperty;
  LValue: TValue;
  LObjectList: TObjectList<TObject>;
  LObject: TObject;
  LFor: Integer;
  LIndex: Integer;
begin
  LValue := AAssociation.PropertyRtti.GetNullableValue(AObject);
  if not LValue.IsObject then
    Exit;

  LObjectList := TObjectList<TObject>(LValue.AsObject);
  for LFor := 0 to LObjectList.Count -1 do
  begin
    LObject := LObjectList.Items[LFor];
    if LObject.GetType(LType) then
    begin
      LIndex := AAssociation.ColumnsName.IndexOf(AProperty.Name);
      if LIndex > -1 then
      begin
        LProperty := LType.GetProperty(AAssociation.ColumnsNameRef.Items[LIndex]);
        if LProperty <> nil then
          LProperty.SetValue(LObject, AProperty.GetValue(AObject));
      end;
    end;
  end;
end;

procedure TRESTObjectSet.SetAutoIncValueOneToOne(const AObject: TObject;
  const AAssociation: TAssociationMapping; const AProperty: TRttiProperty);
var
  LType: TRttiType;
  LProperty: TRttiProperty;
  LValue: TValue;
  LObject: TObject;
  LIndex: Integer;
begin
  LValue := AAssociation.PropertyRtti.GetNullableValue(AObject);
  if not LValue.IsObject then
    Exit;

  LObject := LValue.AsObject;
  if LObject.GetType(LType) then
  begin
    LIndex := AAssociation.ColumnsName.IndexOf(AProperty.Name);
    if LIndex > -1 then
    begin
      LProperty := LType.GetProperty(AAssociation.ColumnsNameRef.Items[LIndex]);
      if LProperty <> nil then
        LProperty.SetValue(LObject, AProperty.GetValue(AObject));
    end;
  end;
end;

procedure TRESTObjectSet.Update(const AObject: TObject);
var
  LPrimaryKey: TPrimaryKeyColumnsMapping;
  LColumn: TColumnMapping;
  LRttiType: TRttiType;
  LObject: TObject;
  LKey: String;
  LInTransaction: Boolean;
  LIsConnected: Boolean;
begin
  inherited;
  // Controle de transacao externa, controlada pelo desenvolvedor
  LInTransaction := FConnection.InTransaction;
  LIsConnected := FConnection.IsConnected;
  if not LIsConnected then
    FConnection.Connect;
  try
    if not LInTransaction then
      FConnection.StartTransaction;
    try
      // Carimba a chave do master nos filhos ANTES do cascade, do mesmo jeito
      // que Insert faz. O cascade abaixo grava os filhos, e um filho que so
      // existe no objeto editado - a linha de detalhe que o registro gravado
      // nao tinha - chega nele com a chave estrangeira em zero se ninguem a
      // preencheu. Aqui a chave do master ja existe: e um update, nao ha
      // sequence a esperar.
      LPrimaryKey := TMappingExplorer
                         .GetMappingPrimaryKeyColumns(AObject.ClassType);
      if LPrimaryKey = nil then
        raise Exception.Create(cMESSAGEPKNOTFOUND);

      for LColumn in LPrimaryKey.Columns do
        SetAutoIncValueChilds(AObject, LColumn);
      // Executa comando update em cascade
      CascadeActionsExecute(AObject, TCascadeAction.CascadeUpdate);
      // Gera a lista com as propriedades que foram alteradas
      if TObject(AObject).GetType(LRttiType) then
      begin
        LKey := GenerateKey(AObject);
        if FObjectState.ContainsKey(LKey) then
        begin
          LObject := FObjectState.Items[LKey];
          FSession.ModifyFieldsCompare(LKey, AObject, LObject);
          // Guarda o Update vazio / so-de-chave, como na base. ModifyFieldsCompare
          // so cria a entrada da linha ao alcancar a primeira coluna que nao pula;
          // numa entidade cujas colunas sao TODAS NoUpdate - uma tabela de ligacao
          // ou de detalhe cujas unicas colunas sao a propria chave composta - ela
          // nao alcanca nenhuma, a entrada nunca nasce, e FSession.Update indexa
          // ModifiedFields.Items[AKey] direto: EListError 'Item not found'.
          if FSession.ModifiedFields.ContainsKey(LKey) and
             (FSession.ModifiedFields.Items[LKey].Count > 0) then
            FSession.Update(AObject, LKey);
          FObjectState.Remove(LKey);
          FObjectState.TrimExcess;
        end;
        // Remove o item excluido em Update Mestre-Detalhe
        for LObject in FObjectState.Values do
          FSession.Delete(LObject);
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
    // Apos executar o comando SQL Update, limpa a lista de campos alterados.
    FSession.ModifiedFields.Clear;
    FSession.ModifiedFields.TrimExcess;
    FSession.DeleteList.Clear;
    FSession.DeleteList.TrimExcess;
  end;
end;

procedure TRESTObjectSet.UpdateInternal(const AObject: TObject);
var
  LPrimaryKey: TPrimaryKeyColumnsMapping;
  LColumn: TColumnMapping;
  LKey: String;
begin
  LKey := AObject.ClassName;
  LPrimaryKey := TMappingExplorer
                     .GetMappingPrimaryKeyColumns(AObject.ClassType);
  if LPrimaryKey = nil then
    raise Exception.Create(cMESSAGEPKNOTFOUND);

  for LColumn in LPrimaryKey.Columns do
    LKey := LKey + '-' +
            VarToStr(LColumn.ColumnProperty.GetNullableValue(TObject(AObject)).AsVariant);
  ///
  if not FSession.ModifiedFields.ContainsKey(LKey) then
    Exit;

  if FSession.ModifiedFields.Items[LKey].Count = 0 then
    Exit;

  FSession.Update(AObject, LKey);
end;

function TRESTObjectSet.NextPacket: TObjectList<TObject>;
begin
  Result := FSession.NextPacketList;
end;

end.
