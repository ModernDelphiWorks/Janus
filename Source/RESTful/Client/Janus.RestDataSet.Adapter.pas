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

{$INCLUDE ..\..\Janus.inc}

unit Janus.RestDataSet.Adapter;

interface

uses
  DB,
  Rtti,
  TypInfo,
  Classes,
  SysUtils,
  StrUtils,
  Variants,
  Generics.Collections,
  Janus.Bind,
  Janus.DataSet.Fields,
  Janus.DataSet.Base.Adapter,
  MetaDbDiff.mapping.classes,
  MetaDbDiff.types.mapping,
  MetaDbDiff.mapping.exceptions,
  Janus.RestFactory.Interfaces;

const
  /// ISO-8601 para data/hora dentro do $filter, e a razao NAO e' a mesma nas
  /// duas metades - cada uma foi medida:
  ///  - DATA: o irmao local formata com FDateFormat, que e' campo do gerador
  ///    de DML e tem QUATRO valores distintos nos 13 dialetos - 'MM/dd/yyyy'
  ///    no Firebird, 'dd/MM/yyyy' no MSSQL, 'yyyy-mm-dd' no NexusDB,
  ///    'yyyy-MM-dd' no MySQL e tambem no ADS. Um cliente REST nao sabe
  ///    qual banco esta do outro lado, entao copiar aquele formato e'
  ///    impossivel daqui.
  ///  - HORA: FTimeFormat NAO varia - e' 'HH:MM:SS' nos 13 geradores, e esse
  ///    formato esta CORRETO (em FormatDateTime o 'M' depois de um 'H' e'
  ///    minuto e nao mes; medido em probe). Aqui ele nao e' copiado por outro
  ///    motivo: o valor nao vira SQL no cliente, vira literal OData na URL, e
  ///    o idioma que ESTA familia ja fala no fio e' ISO-8601, fixado em
  ///    TJanusJson (UseISO8601DateFormat := True). Manter as duas metades no
  ///    mesmo idioma vale mais do que espelhar so a que por acaso e' uniforme.
  /// OS DOIS-PONTOS VAO ENTRE ASPAS porque ':' em FormatDateTime e' o
  /// PLACEHOLDER de TimeSeparator e sairia trocado pelo separador do locale.
  /// Vive na interface, e nao na implementation, porque metodo de tipo
  /// parametrizado declarado na interface nao pode usar simbolo local (E2506).
  cISODATE     = 'yyyy-mm-dd';
  cISODATETIME = 'yyyy-mm-dd"T"hh":"nn":"ss';
  cISOTIME     = 'hh":"nn":"ss';

type
  TRESTDataSetAdapter<M: class, constructor> = class(TDataSetBaseAdapter<M>)
  private
    procedure _SetMasterDataSetStateEdit;
    procedure _ExecuteCheckNotNull;
    procedure _PopularDataSetChilds(const AObject: TObject);
    procedure _PopularDataSetOneToMany(const AObjectList: TObjectList<TObject>);
    function _WhereAssociation(
      const AOwnerObject: TDataSetBaseAdapter<M>): String;
    function _FilterLiteral(const AField: TField): String;
  protected
    procedure PopularDataSetOneToOne(const AObject: TObject;
      const AAssociation: TAssociationMapping); virtual; abstract;
    procedure RefreshDataSetOneToOneChilds(AFieldName: String); override;
    procedure DoBeforePost(DataSet: TDataSet); override;
    procedure DoBeforeDelete(DataSet: TDataSet); override;
    procedure DoAfterDelete(DataSet: TDataSet); override;
    procedure ApplyInserter(const MaxErros: Integer); override;
    procedure ApplyUpdater(const MaxErros: Integer); override;
    procedure ApplyDeleter(const MaxErros: Integer); override;
    procedure PopularDataSet(const AObject: TObject);
    procedure PopularDataSetList(const AObjectList: TObjectList<M>);
    procedure DeleteDataSetChilds; virtual;
    procedure OpenDataSetChilds; override;
    procedure LoadLazy(const AOwner: M); override;
  public
    constructor Create(const AConnection: IRESTConnection; ADataSet: TDataSet;
      APageSize: Integer; AMasterObject: TObject); overload; virtual;
    procedure RefreshRecordInternal(const AObject: TObject); override;
    destructor Destroy; override;
    procedure NextPacket; override;
  end;

implementation

uses
  Janus.Session.RESTful,
  Janus.Objects.Helper,
  Janus.RTTI.Helper,
  MetaDbDiff.mapping.explorer,
  MetaDbDiff.mapping.attributes;

{ TRESTDataSetAdapter<M> }

constructor TRESTDataSetAdapter<M>.Create(const AConnection: IRESTConnection;
  ADataSet: TDataSet; APageSize: Integer; AMasterObject: TObject);
begin
  inherited Create(ADataSet, APageSize, AMasterObject);
  FSession := TSessionRestFul<M>.Create(AConnection, Self, APageSize);
end;

destructor TRESTDataSetAdapter<M>.Destroy;
begin
  FSession.Free;
  inherited;
end;

procedure TRESTDataSetAdapter<M>.DeleteDataSetChilds;
var
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LChild: TPair<String, TDataSetBaseAdapter<M>>;
  LDataSet: TDataSet;
begin
  inherited;
  if FMasterObject.Count = 0 then
    Exit;
  LAssociations := TMappingExplorer.GetMappingAssociation(FCurrentInternal.ClassType);
  if LAssociations = nil then
    Exit;
  for LChild in FMasterObject do
  begin
    for LAssociation in LAssociations do
    begin
      if not (TCascadeAction.CascadeDelete in LAssociation.CascadeActions) then
        Continue;
      if LAssociation.ClassNameRef <> LChild.Value.FCurrentInternal.ClassName then
        Continue;
      LDataSet := LChild.Value.FOrmDataSet;
      if not LDataSet.Active then
        Continue;
      LDataSet.DisableControls;
      try
        LDataSet.First;
        while not LDataSet.Eof do
          LDataSet.Delete;
      finally
        LDataSet.EnableControls;
      end;
    end;
  end;
end;

procedure TRESTDataSetAdapter<M>.ApplyDeleter(const MaxErros: Integer);
var
  LObject: TObject;
begin
  inherited;
  // Varre a lista de objetos excluidos e passa para a sessao REST
  for LObject in FSession.DeleteList do
    FSession.Delete(LObject);
end;

procedure TRESTDataSetAdapter<M>.ApplyInserter(const MaxErros: Integer);
var
  LObject: TObject;
  LProperty: TRttiProperty;
  LDataSetChild: TDataSetBaseAdapter<M>;
  LFor: Integer;
  LField: TField;
  LParam: TParam;
begin
  inherited;
  // Filtar somente os registros inseridos
  FOrmDataSet.Filter := cInternalField + '=' + IntToStr(Integer(dsInsert));
  FOrmDataSet.Filtered := True;
  FOrmDataSet.First;
  try
    while not FOrmDataSet.Eof do
    begin
      // Append/Insert
      if TDataSetState(FOrmDataSet.Fields[FInternalIndex].AsInteger) in [dsInsert] then
      begin
        LObject := M.Create;
        try
          TBind.Instance.SetFieldToProperty(FOrmDataSet, LObject);
          for LDataSetChild in FMasterObject.Values do
            LDataSetChild.FillMastersClass(LDataSetChild, LObject);
          ///
          FSession.Insert(LObject);
          FOrmDataSet.Edit;
          if FSession.ExistSequence then
          begin
            if FSession.ResultParams.Count > 0 then
            begin
              for LFor := 0 to FSession.ResultParams.Count -1 do
              begin
                LParam := FSession.ResultParams.Items[LFor];
                LField := FOrmDataSet.FindField(LParam.Name);
                if LField <> nil then
                  LField.Value := LParam.Value;
              end;
              // Atualiza o valor do AutoInc nas sub tabelas
              SetAutoIncValueChilds;
            end;
          end;
          FOrmDataSet.Fields[FInternalIndex].AsInteger := -1;
          FOrmDataSet.Post;
        finally
          LObject.Free;
        end;
      end;
    end;
  finally
    FOrmDataSet.Filtered := False;
    FOrmDataSet.Filter := '';
  end;
end;

procedure TRESTDataSetAdapter<M>.ApplyUpdater(const MaxErros: Integer);
var
  LObject: TObject;
  LUpdateList: TObjectList<M>;
  LDataSetChild: TDataSetBaseAdapter<M>;
begin
  inherited;
  // Filtar somente os registros modificados
  FOrmDataSet.Filter := cInternalField + '=' + IntToStr(Integer(dsEdit));
  FOrmDataSet.Filtered := True;
  FOrmDataSet.First;
  LUpdateList := TObjectList<M>.Create;
  try
    while FOrmDataSet.RecordCount > 0 do
    begin
      // Edit
      if TDataSetState(FOrmDataSet.Fields[FInternalIndex].AsInteger) in [dsEdit] then
      begin
        LObject := M.Create;
        TBind.Instance.SetFieldToProperty(FOrmDataSet, LObject);
        for LDataSetChild in FMasterObject.Values do
          LDataSetChild.FillMastersClass(LDataSetChild, LObject);
        ///
        LUpdateList.Add(LObject);
        FOrmDataSet.Edit;
        FOrmDataSet.Fields[FInternalIndex].AsInteger := -1;
        FOrmDataSet.Post;
      end;
    end;
    if LUpdateList.Count > 0 then
      FSession.Update(LUpdateList);
  finally
    FOrmDataSet.Filtered := False;
    FOrmDataSet.Filter := '';
    LUpdateList.Clear;
    LUpdateList.Free;
  end;
end;

procedure TRESTDataSetAdapter<M>.DoAfterDelete(DataSet: TDataSet);
begin
  inherited DoAfterDelete(DataSet);
  // Seta o registro mestre com stado de edicao, considerando esse o
  // registro filho sendo incluido ou alterado
  _SetMasterDataSetStateEdit;
end;

procedure TRESTDataSetAdapter<M>.DoBeforeDelete(DataSet: TDataSet);
var
  LObject: TObject;
begin
  inherited DoBeforeDelete(DataSet);
  // 1o - Instancia um novo objeto do tipo
  // 2o - Popula ele e suas sub-classes com os dados do dataset
  // 3o - Adiciona o objeto na lista de registros excluidos
  if FOwnerMasterObject = nil then
  begin
    LObject := M.Create;
    TBind.Instance.SetFieldToProperty(FOrmDataSet, LObject);
    FSession.DeleteList.Add(LObject);
  end;
  // Deleta registros de todos os DataSet filhos
  DeleteDataSetChilds;
end;

procedure TRESTDataSetAdapter<M>.DoBeforePost(DataSet: TDataSet);
begin
  inherited DoBeforePost(DataSet);
  // Seta o registro mestre com stado de edicao, considerando esse o
  // registro filho sendo incluido ou alterado
  _SetMasterDataSetStateEdit;
  // Rotina de validacao se o campo foi deixado null
  _ExecuteCheckNotNull;
end;

procedure TRESTDataSetAdapter<M>._ExecuteCheckNotNull;
var
  LColumn: TColumnMapping;
  LColumns: TColumnMappingList;
begin
  LColumns := TMappingExplorer.GetMappingColumn(FCurrentInternal.ClassType);
  for LColumn in LColumns do
  begin
    if LColumn.IsNoInsert then
      Continue;
    if LColumn.IsNoUpdate then
      Continue;
    if LColumn.IsJoinColumn then
      Continue;
    if LColumn.IsNoValidate then
      Continue;
    if LColumn.IsNullable then
      Continue;
    if LColumn.FieldType in [ftDataSet, ftADT] then
      Continue;
    if FOrmDataSet.FieldValues[LColumn.ColumnName] = Null then
      raise EFieldValidate.Create(FCurrentInternal.ClassName + '.' + LColumn.ColumnName,
                                  FOrmDataSet.FieldByName(LColumn.ColumnName).ConstraintErrorMessage);
  end;
end;

/// <summary> Monta o WHERE que filtra ESTE filho pela linha corrente do
///  master, no idioma que a familia REST ja usa.
///
///  DE ONDE VEM CADA PONTA - medido, nao suposto. O par de listas da
///  associacao tem dono: ColumnsName[i] e' coluna do MASTER e ColumnsNameRef[i]
///  e' coluna do FILHO. Quem prova isso na propria familia REST e'
///  TRESTFDMemTableAdapter<M>._FilterDataSetChilds, que alimenta MasterFields
///  com ColumnsName e IndexFieldNames (do filho) com ColumnsNameRef. O gerador
///  de SQL do irmao local diz o mesmo em TDMLGeneratorAbstract
///  .GenerateSelectOneToOne: o lado esquerdo do WHERE e' ColumnsNameRef e o
///  valor sai da coluna ColumnsName lida no owner.
///
///  QUAIS ASSOCIACOES ENTRAM: as mesmas que o irmao local escolhe em
///  TSQLCommandExecutor<M>.SelectInternalAssociation - ClassNameRef igual a
///  classe deste adapter, e associacao marcada Lazy e' PULADA. O Lazy aqui e'
///  o 5o e ultimo parametro de [Association] (AMultiplicity, AColumnsName,
///  ATableNameRef, AColumnsNameRef, ALazy - construtor unico, sem overload) e
///  quer dizer "resolvido por proxy transparente de RTTI", nao "carregado sob
///  demanda por este metodo" -
///  TDataSetAdapter<M> diz isso com todas as letras no comentario de
///  Janus.DataSet.Adapter.pas:262. Ou seja: pular e' o certo, e nao ha
///  paradoxo nenhum com o nome LoadLazy.
///
///  AS TRES DIVERGENCIAS EM RELACAO AO SQL LOCAL - A LISTA E' COMPLETA:
///  1) sem prefixo de tabela. O gerador local escreve `tabela.coluna` porque
///     esta montando SQL; aqui o texto vira $filter na URL, e o servidor Janus
///     resolve nome de coluna simples - e' o que TRESTDataSetAdapter<M>
///     .RefreshDataSetOneToOneChilds ja manda e o que os testes de $filter do
///     recurso REST usam.
///  2) o valor sai do DATASET do master (FindField), nao de uma propriedade
///     hidratada por RTTI. E' o mesmo atalho de RefreshDataSetOneToOneChilds e
///     poupa o passo de Bind que o irmao local precisa dar antes. O QUE ESSE
///     ATALHO CUSTA esta no item 3.
///  3) a formatacao do valor e' feita AQUI, e nao herdada. Quem aspa no lado
///     local e' TDMLGeneratorAbstract._GetPropertyValue
///     (Janus.DML.Generator.pas:598-652), e ele fica no caminho da RTTI que o
///     item 2 pulou. Sem repor isso, uma FK string sairia `col eq AB C` - erro
///     de sintaxe com espaco, comparacao contra outra coluna sem espaco, e
///     silenciosamente errada nos dois casos; GUID e codigo alfanumerico sao
///     chave de primeira classe neste framework (TGeneratorType tem
///     Guid32Inc/Guid36Inc/Guid38Inc). Entao _WhereAssociation despacha por
///     LField.DataType com OS MESMOS GRUPOS de _GetPropertyValue, com duas
///     diferencas declaradas:
///       * ftGuid entra no grupo aspado. ATUALIZADO PELA #284: quando esta
///         linha foi escrita, o irmao local mandava ftGuid para o `else` e o
///         valor virava string vazia; hoje ele tem ramo proprio, e o literal
///         sai por TDMLGeneratorAbstract.GuidLiteral, abstract e implementado
///         por cada dialeto (Janus.DML.Generator.pas). A DIVERGENCIA CONTINUA
///         EXISTINDO, e agora e' outra: la' o valor vem de uma propriedade
///         TGUID pela RTTI e o literal e' escolhido PELO DIALETO; aqui vem do
///         CAMPO (item 2) e e' dialeto-cego POR CONSTRUCAO - o cliente REST
///         nao sabe, e nao tem como saber, qual banco o servidor usa, e o
///         $filter atravessa verbatim ate' o WHERE (o tradutor do servidor,
///         Janus.Server.RestQuery.Parse.pas:451-453, so' mapeia palavra de
///         operador e nome de funcao OData; literal passa intacto). Hoje isso
///         nao produz divergencia de TEXTO, porque os 12 dialetos convergem na
///         mesma forma canonica de 38 - ver o comentario de
///         CanonicalGuidLiteral -, mas o dia em que um dialeto divergir, este
///         lado nao tem onde saber disso. Issue propria.
///         O que NAO mudou e' por que a guarda nao absorveria um GUID: ela le
///         o CAMPO e o AsString de um GUID nao e' vazio - sairia `cck3 eq `
///         sem lado direito.
///       * data e hora vao em ISO-8601 e nao em FDateFormat/FTimeFormat.
///         As razoes sao DIFERENTES para cada metade e estao em cISODATE,
///         acima: a de data e' variacao por dialeto; a de hora nao e' (o
///         FTimeFormat e' igual nos 13 e esta correto), e' o fio ser OData.
///     O `else` devolve o texto cru, que e' o certo para os tipos numericos.
///     TODOS OS SETE RAMOS TEM TESTE, num unico $filter de chave composta -
///     ver Load_ACompositeKeyJoinsWithAndAndQuotesEachTypeItsOwnWay.
///
///  OPERADOR COM ESPACOS, E ISSO NAO E' ESTILO. TSessionRestFul<M>
///  ._ParseOperator troca ' = ' por ' eq ' com os espacos DENTRO do padrao;
///  sem eles nada e' trocado. O servidor Janus ate aceita o texto sem
///  traducao, porque _EmitSQL so mapeia word token e deixa o resto passar,
///  mas ai o que sai nao e' OData e quebra em servidor estrito. Por isso
///  ' = ' e nunca '='.
///
///  GUARD DE VALOR NULO: '1 = 0', o mesmo do gerador local, que vira '1 eq 0'
///  na URL e casa zero linhas - em vez de um `coluna = ` sem lado direito.
/// </summary>
function TRESTDataSetAdapter<M>._WhereAssociation(
  const AOwnerObject: TDataSetBaseAdapter<M>): String;
var
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LField: TField;
  LFor: Integer;
begin
  Result := '';
  if AOwnerObject = nil then
    Exit;
  LAssociations := TMappingExplorer
                     .GetMappingAssociation(AOwnerObject.FCurrentInternal.ClassType);
  if LAssociations = nil then
    Exit;
  for LAssociation in LAssociations do
  begin
    if LAssociation.ClassNameRef <> FCurrentInternal.ClassName then
      Continue;
    if LAssociation.Lazy then
      Continue;
    Result := '';
    for LFor := 0 to LAssociation.ColumnsNameRef.Count -1 do
    begin
      if LFor > 0 then
        Result := Result + ' AND ';
      LField := nil;
      if LFor < LAssociation.ColumnsName.Count then
        LField := AOwnerObject.FOrmDataSet
                    .FindField(LAssociation.ColumnsName[LFor]);
      if (LField = nil) or LField.IsNull or (LField.AsString = '') then
        Result := Result + '1 = 0'
      else
        Result := Result + LAssociation.ColumnsNameRef[LFor] + ' = ' +
                           _FilterLiteral(LField);
    end;
  end;
end;

/// <summary> O valor de UMA coluna do master, ja no formato em que pode entrar
///  no $filter. Os grupos sao os de TDMLGeneratorAbstract._GetPropertyValue -
///  ver a lista de divergencias em _WhereAssociation, item 3, que explica por
///  que este passo precisa existir deste lado e o que ele muda de proposito.
///  QuotedStr, e nao aspas na mao, porque ele tambem DOBRA a aspa de dentro do
///  valor: um master chamado O'Brien sai `'O''Brien'` e nao termina a string
///  no meio. </summary>
function TRESTDataSetAdapter<M>._FilterLiteral(const AField: TField): String;
begin
  case AField.DataType of
    ftString, ftWideString, ftMemo, ftWideMemo, ftFmtMemo, ftGuid:
      Result := QuotedStr(AField.AsString);
    ftDateTime, ftDate:
      Result := QuotedStr(FormatDateTime(ifThen(AField.DataType = ftDate,
                            cISODATE, cISODATETIME), AField.AsDateTime));
    ftTime, ftTimeStamp, ftOraTimeStamp:
      Result := QuotedStr(FormatDateTime(cISOTIME, AField.AsDateTime));
    ftCurrency, ftBCD, ftFMTBcd, ftFloat:
      Result := ReplaceStr(AField.AsString, ',', '.');
  else
    Result := AField.AsString;
  end;
end;

/// <summary> O LAZY DA FAMILIA REST, OS DOIS RAMOS.
///
///  Este corpo estava VAZIO: pedir carga e pedir descarga davam exatamente o
///  mesmo resultado - nada, e sem aviso. Issue #251.
///
///  OS DOIS ADAPTERS SAO IRMAOS, nao primos distantes: TRESTDataSetAdapter<M>
///  e TDataSetAdapter<M> descendem os dois de TDataSetBaseAdapter<M>, e tudo
///  que o LoadLazy local usa - SetMasterObject, FOwnerMasterObject,
///  FCurrentInternal, Close - esta identico deste lado. Por isso a ESTRUTURA
///  aqui e' a do irmao, guarda por guarda.
///
///  O QUE MUDA E' SO O PONTO DE ENTRADA DA CARGA. O irmao local monta SQL com
///  FSession.SelectAssociation e entrega a OpenSQLInternal. Nenhum dos dois
///  serve aqui: TSessionRestFul<M> nao sobrescreve SelectAssociation (herda a
///  de TSessionAbstract<M>, que devolve string vazia) e o OpenSQLInternal dos
///  adapters REST nem le o ASQL que recebe - chama FSession.Find, o recurso
///  inteiro. O ponto de entrada IRMAO resolve: OpenWhereInternal e' declarado
///  virtual abstract no MESMO ancestral que OpenSQLInternal, os dois adapters
///  REST o sobrescrevem HONRANDO o AWhere, e ele desce em FSession.FindWhere,
///  que emite GET recurso?$filter=... Ou seja: filtro de verdade, e nao a
///  tabela filha inteira.
///
///  A FLAG DE "JA CARREGADO" E' `FOrmDataSet.Active`, COPIADA DO IRMAO LOCAL.
///  O #248 mostrou que essa flag mente enquanto o dataset nunca fecha, e a
///  resposta la foi fazer Close fechar de verdade, mantendo a flag. A pergunta
///  e' a MESMA nas duas familias; responder diferente so aqui seria inventar.
///
///  O RAMO DE DESCARGA nao precisa de SQL nenhum: SetMasterObject(nil) desfaz
///  o registro no master e Close fecha o dataset, ambos em
///  TDataSetBaseAdapter<M>.
///
///  O QUE ESTE LOAD NAO FAZ: nao aplica o [OrderBy] da entidade. O gerador
///  local anexa ORDER BY ao SELECT; aqui isso seria o segundo argumento de
///  OpenWhereInternal ($orderby) e nenhum caminho da familia REST o monta
///  hoje, entao nao foi inventado um.
///
///  OpenDataSetChilds, logo acima, continua com corpo vazio. E' lacuna irma e
///  NAO faz parte da #251. </summary>
procedure TRESTDataSetAdapter<M>.LoadLazy(const AOwner: M);
var
  LOwnerObject: TDataSetBaseAdapter<M>;
  LWhere: String;
begin
  if AOwner <> nil then
  begin
    if FOwnerMasterObject <> nil then
      Exit;
    if FOrmDataSet.Active then
      Exit;

    SetMasterObject(AOwner);
    LOwnerObject := TDataSetBaseAdapter<M>(FOwnerMasterObject);
    if LOwnerObject <> nil then
    begin
      LWhere := _WhereAssociation(LOwnerObject);
      if Length(LWhere) > 0 then
        OpenWhereInternal(LWhere);
    end;
  end
  else
  begin
    if FOwnerMasterObject = nil then
      Exit;
    if not TDataSetBaseAdapter<M>(FOwnerMasterObject).FOrmDataSet.Active then
      Exit;

    SetMasterObject(nil);
    Close;
  end;
end;

procedure TRESTDataSetAdapter<M>.NextPacket;
var
  LBookMark: TBookmark;
  LObjectList: TObjectList<M>;
begin
  inherited;
  if FSession.FetchingRecords then
    Exit;
  FOrmDataSet.DisableControls;
  DisableDataSetEvents;
  LBookMark := FOrmDataSet.Bookmark;
  LObjectList := FSession.NextPacketList;
  try
    if LObjectList = nil then
      Exit;
    if LObjectList.Count = 0 then
      Exit;
    PopularDataSetList(LObjectList);
  finally
    LObjectList.Clear;
    LObjectList.Free;
    FOrmDataSet.GotoBookmark(LBookMark);
    FOrmDataSet.EnableControls;
    EnableDataSetEvents;
  end;
end;

procedure TRESTDataSetAdapter<M>.OpenDataSetChilds;
begin

end;

procedure TRESTDataSetAdapter<M>.PopularDataSet(const AObject: TObject);
begin
  FOrmDataSet.Append;
  TBind.Instance.SetPropertyToField(AObject, FOrmDataSet);
  FOrmDataSet.Post;
  FOrmDataSet.First;
  // Popula Associations
  if FMasterObject.Count > 0 then
    _PopularDataSetChilds(AObject);
end;

procedure TRESTDataSetAdapter<M>.PopularDataSetList(const AObjectList: TObjectList<M>);
var
  LObject: M;
begin
  for LObject in AObjectList do
    PopularDataSet(LObject);
end;

procedure TRESTDataSetAdapter<M>._PopularDataSetChilds(const AObject: TObject);
var
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LObjectList: TObjectList<TObject>;
  LObjectChild: TObject;
begin
  if not FOrmDataSet.Active then
    Exit;
  if FOrmDataSet.RecordCount = 0 then
    Exit;
  LAssociations := TMappingExplorer.GetMappingAssociation(FCurrentInternal.ClassType);
  if LAssociations = nil then
    Exit;
  for LAssociation in LAssociations do
  begin
    if not LAssociation.PropertyRtti.IsList then
    begin
      LObjectChild := LAssociation.PropertyRtti.GetValue(AObject).AsObject;
      if LObjectChild <> nil then
        PopularDataSetOneToOne(LObjectChild, LAssociation);
    end
    else
    begin
      LObjectList := TObjectList<TObject>(LAssociation.PropertyRtti.GetValue(AObject).AsObject);
      if LObjectList <> nil then
        _PopularDataSetOneToMany(LObjectList);
    end;
  end;
end;

procedure TRESTDataSetAdapter<M>._PopularDataSetOneToMany(
  const AObjectList: TObjectList<TObject>);
var
  LDataSetChild: TRESTDataSetAdapter<M>;
  LObjectChild: TObject;
begin
  for LObjectChild in AObjectList do
  begin
    if not FMasterObject.ContainsKey(LObjectChild.ClassName) then
      Continue;
    // Popular classe ralacionada atraves do atributo Association() e todos
    // as suas classes filhas, caso exista.
    LDataSetChild := TRESTDataSetAdapter<M>(FMasterObject.Items[LObjectChild.ClassName]);
    LDataSetChild.FOrmDataSet.DisableControls;
    LDataSetChild.DisableDataSetEvents;
    try
      LDataSetChild.PopularDataSet(LObjectChild);
    finally
      LDataSetChild.FOrmDataSet.EnableControls;
      LDataSetChild.EnableDataSetEvents;
    end;
  end;
end;

procedure TRESTDataSetAdapter<M>.RefreshDataSetOneToOneChilds(AFieldName: String);
var
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LDataSetChild: TDataSetBaseAdapter<M>;
  LObjectFind: TObjectList<M>;
  LKeyFieldName: String;
  LKeyValue: String;
begin
  inherited;
  if not FOrmDataSet.Active then
    Exit;
  LAssociations := TMappingExplorer.GetMappingAssociation(FCurrentInternal.ClassType);
  if LAssociations = nil then
    Exit;
  for LAssociation in LAssociations do
  begin
    if not (LAssociation.Multiplicity in [TMultiplicity.OneToOne, TMultiplicity.ManyToOne]) then
      Continue;
    if LAssociation.ColumnsName.IndexOf(AFieldName) = -1 then
      Continue;
    if not (FMasterObject.TryGetValue(LAssociation.ClassNameRef, LDataSetChild)) then
      Continue;
    LKeyFieldName := LAssociation.ColumnsNameRef.Items[0];
    LKeyValue := FOrmDataSet.FieldByName(LKeyFieldName).AsString;
    if LDataSetChild.FOrmDataSet.Locate(LKeyFieldName, LKeyValue, [loCaseInsensitive]) then
      Exit;
    // Se o registro nao existir no dataset,sera feito uma requisicao para
    // busca-lo e adiciona-lo ao dataset em memoria
    LObjectFind := LDataSetChild.FindWhere(LKeyFieldName + '=' + LKeyValue);
    LObjectFind.OwnsObjects := True;
    try
      if LObjectFind.Count = 0 then
        raise Exception.Create('N'#$00E3'o foi poss'#$00ED'vel encontrar a informa'#$00E7#$00E3'o ' + LKeyFieldName + '=' + LKeyValue);
      LDataSetChild.FOrmDataSet.DisableControls;
      LDataSetChild.DisableDataSetEvents;
      LDataSetChild.FOrmDataSet.Append;
      TBind.Instance.SetPropertyToField(LObjectFind.Items[0], LDataSetChild.FOrmDataSet);
      LDataSetChild.FOrmDataSet.Post;
    finally
      LObjectFind.Free;
      LDataSetChild.FOrmDataSet.First;
      LDataSetChild.FOrmDataSet.EnableControls;
      LDataSetChild.EnableDataSetEvents;
    end;
//    LDataSetChild.FOrmDataSet.Refresh;
  end;
end;

procedure TRESTDataSetAdapter<M>.RefreshRecordInternal(const AObject: TObject);
var
  LChildDataSet: TDataSetBaseAdapter<M>;
begin
  inherited;
  FOrmDataSet.DisableControls;
  try
    FOrmDataSet.Edit;
    TBind.Instance.SetPropertyToField(AObject, FOrmDataSet);
    FOrmDataSet.Post;
    // Limpa todos os registros filhos para serem atualizados
    for LChildDataSet in FMasterObject.Values do
    begin
      LChildDataSet.FOrmDataSet.DisableControls;
      try
        LChildDataSet.FOrmDataSet.First;
        while not LChildDataSet.FOrmDataSet.Eof do
          LChildDataSet.FOrmDataSet.Delete;
      finally
        LChildDataSet.FOrmDataSet.EnableControls;
      end;
    end;
    // Popula Associations
    if FMasterObject.Count > 0 then
      _PopularDataSetChilds(AObject);
  finally
    FOrmDataSet.EnableControls;
  end;
end;

procedure TRESTDataSetAdapter<M>._SetMasterDataSetStateEdit;
var
  FOwner: TDataSetBaseAdapter<M>;
begin
  if FOwnerMasterObject = nil then
    Exit;
  FOwner := TDataSetBaseAdapter<M>(FOwnerMasterObject);
  if not FOwner.FMasterObject.ContainsKey(FCurrentInternal.ClassName) then
    Exit;
  if not (FOwner.FOrmDataSet.State in [dsEdit]) then
    Exit;
  if FOwner.FOrmDataSet.Fields[FInternalIndex].AsInteger <> -1 then
    Exit;
  FOwner.FOrmDataSet.Fields[FInternalIndex].AsInteger := 2;
end;

end.
