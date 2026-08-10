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

unit Janus.Server.RestObjectSet.Session;

interface

uses
  DB,
  Rtti,
  TypInfo,
  Generics.Collections,
  /// Janus
  MetaDbDiff.rtti.helper,
  MetaDbDiff.mapping.classes,
  MetaDbDiff.mapping.attributes,
  MetaDbDiff.mapping.explorer,
  MetaDbDiff.mapping.popular,
  DataEngine.FactoryInterfaces,
  Janus.Core.Consts,
  Janus.Types.Blob,
  Janus.Server.RestObject.Manager;

type
  TRESTObjectSetSession = class
  protected
    FConnection: IDBConnection;
    FPageSize: Integer;
    FPageNext: Integer;
    FModifiedFields: TDictionary<String, TDictionary<String, String>>;
    FDeleteList: TObjectList<TObject>;
    FManager: TRESTObjectManager;
    FResultParams: TParams;
    FFindWhereUsed: Boolean;
    FWhere: String;
    FOrderBy: String;
  public
    constructor Create(const AConnection: IDBConnection; const AClassType: TClass;
      const APageSize: Integer = -1); virtual;
    destructor Destroy; override;
    function ExistSequence: Boolean; virtual;
    function ModifiedFields: TDictionary<String, TDictionary<String, String>>; virtual;
    // ObjectSet
    procedure Insert(const AObject: TObject); overload; virtual;
    procedure Insert(const AObjectList: TObjectList<TObject>); overload; virtual; abstract;
    procedure Update(const AObject: TObject; const AKey: String); overload; virtual;
    procedure Update(const AObjectList: TObjectList<TObject>); overload; virtual; abstract;
    procedure Delete(const AObject: TObject); overload; virtual;
    procedure Delete(const AID: Integer); overload; virtual; abstract;
    procedure LoadLazy(const AOwner, AObject: TObject); virtual;
    procedure NextPacketList(const AObjectList: TObjectList<TObject>); overload; virtual;
    function NextPacketList: TObjectList<TObject>; overload; virtual;
    function NextPacketList(const APageSize, APageNext: Integer): TObjectList<TObject>; overload; virtual;
    function NextPacketList(const AWhere, AOrderBy: String; const APageSize, APageNext: Integer): TObjectList<TObject>; overload; virtual;
    function ResultParams: TParams;
    // DataSet e ObjectSet
    procedure ModifyFieldsCompare(const AKey: String; const AObjectSource,
      AObjectUpdate: TObject); virtual;
    function Find: TObjectList<TObject>; overload; virtual;
    function Find(const AID: Integer): TObject; overload; virtual;
    function Find(const AID: String): TObject; overload; virtual;
    function FindWhere(const AWhere: String; const AOrderBy: String): TObjectList<TObject>; virtual;
    function FindOne(const AWhere: String): TObject;
    function DeleteList: TObjectList<TObject>; virtual;
  end;

implementation

uses
  Janus.Objects.Helper;

{ TRESTObjectSetSession<M> }

constructor TRESTObjectSetSession.Create(const AConnection: IDBConnection;
  const AClassType: TClass; const APageSize: Integer = -1);
begin
  FPageSize := APageSize;
  FModifiedFields := TObjectDictionary<String, TDictionary<String, String>>.Create([doOwnsValues]);
  FDeleteList := TObjectList<TObject>.Create;
  FResultParams := TParams.Create;
  FManager := TRESTObjectManager.Create(Self, AConnection, AClassType, APageSize);
  // Inicia uma lista interna para gerenciar campos alterados
  FModifiedFields.Clear;
  FModifiedFields.TrimExcess;
  FModifiedFields.Add(AClassType.ClassName, TDictionary<String, String>.Create);
end;

destructor TRESTObjectSetSession.Destroy;
begin
  FDeleteList.Clear;
  FDeleteList.Free;
  FModifiedFields.Clear;
  FModifiedFields.Free;
  FResultParams.Clear;
  FResultParams.Free;
  FManager.Free;
  inherited;
end;

function TRESTObjectSetSession.ModifiedFields: TDictionary<String, TDictionary<String, String>>;
begin
  Result := FModifiedFields;
end;

procedure TRESTObjectSetSession.Delete(const AObject: TObject);
begin
  FManager.DeleteInternal(AObject);
end;

function TRESTObjectSetSession.DeleteList: TObjectList<TObject>;
begin
  Result := FDeleteList;
end;

function TRESTObjectSetSession.ExistSequence: Boolean;
begin
  Result := FManager.ExistSequence;
end;

function TRESTObjectSetSession.Find(const AID: String): TObject;
begin
  FFindWhereUsed := False;
  Result := FManager.Find(AID);
end;

function TRESTObjectSetSession.FindOne(const AWhere: String): TObject;
begin
  Result := FManager.FindOne(AWhere);
end;

function TRESTObjectSetSession.FindWhere(const AWhere, AOrderBy: String): TObjectList<TObject>;
begin
  FFindWhereUsed := True;
  FWhere := AWhere;
  FOrderBy := AOrderBy;
  if FPageSize > -1 then
  begin
    Result := NextPacketList(FWhere, FOrderBy, FPageSize, FPageNext);
    Exit;
  end;
  Result := FManager.FindWhere(FWhere, FOrderBy);
end;

function TRESTObjectSetSession.Find(const AID: Integer): TObject;
begin
  FFindWhereUsed := False;
  Result := FManager.Find(AID);
end;

function TRESTObjectSetSession.Find: TObjectList<TObject>;
begin
  FFindWhereUsed := False;
  Result := FManager.Find;
end;

procedure TRESTObjectSetSession.Insert(const AObject: TObject);
begin
  FManager.InsertInternal(AObject);
end;

procedure TRESTObjectSetSession.ModifyFieldsCompare(const AKey: String;
  const AObjectSource, AObjectUpdate: TObject);
var
  LColumn: TColumnMapping;
  LColumns: TColumnMappingList;
  LProperty: TRttiProperty;
begin
  LColumns := TMappingExplorer
                  .GetMappingColumn(AObjectSource.ClassType);
  for LColumn in LColumns do
  begin
    LProperty := LColumn.ColumnProperty;
    if LProperty.IsNoUpdate then
      Continue;
    if LProperty.PropertyType.TypeKind in cPROPERTYTYPES_1 then
      Continue;
    if not FModifiedFields.ContainsKey(AKey) then
      FModifiedFields.Add(AKey, TDictionary<String, String>.Create);
    // Se o tipo da property for tkRecord provavelmente tem Nullable nela
    // Se nao for tkRecord entra no ELSE e pega o valor de forma direta
    if LProperty.PropertyType.TypeKind in [tkRecord] then // Nullable ou TBlob
    begin
      if LProperty.IsBlob then
      begin
        if LProperty.GetValue(AObjectSource).AsType<TBlob>.ToSize <>
           LProperty.GetValue(AObjectUpdate).AsType<TBlob>.ToSize then
        begin
          FModifiedFields.Items[AKey].Add(LProperty.Name, LColumn.ColumnName);
        end;
      end
      else
      begin
        if LProperty.GetNullableValue(AObjectSource).AsType<Variant> <>
           LProperty.GetNullableValue(AObjectUpdate).AsType<Variant> then
        begin
          FModifiedFields.Items[AKey].Add(LProperty.Name, LColumn.ColumnName);
        end;
      end;
    end
    else
    begin
      if LProperty.GetValue(AObjectSource).AsType<Variant> <>
         LProperty.GetValue(AObjectUpdate).AsType<Variant> then
      begin
        FModifiedFields.Items[AKey].Add(LProperty.Name, LColumn.ColumnName);
      end;
    end;
  end;
end;

function TRESTObjectSetSession.NextPacketList(const AWhere, AOrderBy: String;
  const APageSize, APageNext: Integer): TObjectList<TObject>;
begin
  Result := nil;
  if not FManager.FetchingRecords then
    Result := FManager.NextPacketList(AWhere, AOrderBy, APageSize, APageNext);
end;

function TRESTObjectSetSession.NextPacketList: TObjectList<TObject>;
begin
  Result := nil;
  if FManager.FetchingRecords then
    Exit;

  FPageNext := FPageNext + FPageSize;
  if FFindWhereUsed then
    Result := FManager.NextPacketList(FWhere, FOrderBy, FPageSize, FPageNext)
  else
    Result := FManager.NextPacketList(FPageSize, FPageNext);
end;

procedure TRESTObjectSetSession.NextPacketList(const AObjectList: TObjectList<TObject>);
begin
  if FManager.FetchingRecords then
    Exit;

  FPageNext := FPageNext + FPageSize;
  if FFindWhereUsed then
    FManager.NextPacketList(AObjectList, FWhere, FOrderBy, FPageSize, FPageNext)
  else
    FManager.NextPacketList(AObjectList, FPageSize, FPageNext);
end;

function TRESTObjectSetSession.ResultParams: TParams;
begin
  Result := FResultParams;
end;

procedure TRESTObjectSetSession.Update(const AObject: TObject; const AKey: String);
begin
  FManager.UpdateInternal(AObject, FModifiedFields.Items[AKey]);
end;

/// <summary> Delega a carga lazy ao manager, como todos os outros metodos
///  desta classe delegam.
///
///  O CORPO ERA A CHAMADA COMENTADA, e ela e' a unica saida que existe. Quem
///  chega aqui e' TRESTObjectSet.LoadLazy, e o unico caminho adiante e'
///  TRESTObjectManager.LoadLazy -> FillAssociationLazy, que monta o SELECT do
///  filho a partir do mapeamento da associacao. A familia local faz o mesmo
///  em TSessionObjectSet<M>.LoadLazy, chamando FCommandExecutor.LoadLazy com
///  os mesmos dois argumentos.
///
///  NAO E' HERANCA, E ISSO FOI CONFERIDO: TRESTObjectManager e' `class` sem
///  ancestral declarado, uma classe paralela. O LoadLazy /
///  FillAssociationLazy abstratos de TSQLCommandExecutorAbstract<M> sao
///  sobrescritos por TSQLCommandExecutor<M>, a familia local - nao por este
///  manager. As duas familias tem o mesmo desenho e nenhum codigo em comum.
///
///  O QUE FOI MEDIDO ANTES DE DESCOMENTAR:
///  - a assinatura casa: TRESTObjectManager.LoadLazy(const AOwner, AObject:
///    TObject), os dois parametros na mesma ordem;
///  - o alvo esta implementado, nao e' stub;
///  - FManager e' atribuido no construtor desta classe, antes de qualquer
///    chamada publica, e so' e' liberado no destrutor;
///  - nao ha recursao: FillAssociationLazy chama ExecuteOneToOne /
///    ExecuteOneToMany, e o FillAssociation que essas duas rodam sobre o
///    filho nao volta para LoadLazy;
///  - o git nao registra motivo: a linha ja' nasceu comentada no commit de
///    importacao, e os commits posteriores no arquivo so' mexeram em cabecalho
///    e encoding.
///
///  ANTES DISSO o metodo era um `begin end`: pedir a carga de um filho lazy e
///  nao pedir nada davam a mesma resposta - nada, sem excecao e sem aviso.
/// </summary>
procedure TRESTObjectSetSession.LoadLazy(const AOwner, AObject: TObject);
begin
  FManager.LoadLazy(AOwner, AObject);
end;

function TRESTObjectSetSession.NextPacketList(const APageSize,
  APageNext: Integer): TObjectList<TObject>;
begin
  Result := nil;
  if not FManager.FetchingRecords then
    Result := FManager.NextPacketList(APageSize, APageNext);
end;

end.

