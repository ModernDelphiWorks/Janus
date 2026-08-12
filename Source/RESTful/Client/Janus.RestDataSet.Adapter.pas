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
    /// <summary> Ligado apenas enquanto a re-leitura AUTOMATICA da #297 esta em
    ///  curso, para que RefreshRecordInternal aplique uma exigencia que NAO
    ///  cabe ao refresh pedido pelo consumidor: a resposta tem de alcancar
    ///  todos os niveis que o cliente ja segura.
    ///  A DIFERENCA E REAL E NAO E ESTILO. Quando o consumidor pede um refresh,
    ///  filho que sumiu no servidor DEVE sumir na tela - e para isso que ele
    ///  pediu. Quando quem pede e o ApplyInserter, um instante depois de o
    ///  servidor ter GRAVADO aqueles filhos, "a resposta nao os mencionou" nunca
    ///  quer dizer "eles foram apagados"; quer dizer que o servidor nao os
    ///  devolve - e o caso ordinario disso e a associacao Lazy, que
    ///  TRESTObjectManager.FillAssociation pula por contrato.
    ///  O MESMO FORMATO QUE TSessionRestFul<M>.RefreshRecord ja usa com
    ///  FFindWhereRefreshUsed: uma flag ligada em volta de uma chamada, para
    ///  mudar o comportamento de um metodo mais abaixo que nao recebe
    ///  parametro para isso. </summary>
    FReReadAfterInsert: Boolean;
    procedure _SetMasterDataSetStateEdit;
    procedure _ExecuteCheckNotNull;
    procedure _PopularDataSetChilds(const AObject: TObject);
    procedure _PopularDataSetOneToMany(const AObjectList: TObjectList<TObject>);
    function _WhereAssociation(
      const AOwnerObject: TDataSetBaseAdapter<M>): String;
    function _FilterLiteral(const AField: TField): String;
    function _RowKeyIsUngenerated(
      const AAdapter: TDataSetBaseAdapter<M>): Boolean;
    function _OwnKeyIsUngenerated(
      const AAdapter: TDataSetBaseAdapter<M>): Boolean;
    function _GraphBelowIsStale(
      const AAdapter: TDataSetBaseAdapter<M>): Boolean;
    procedure _ReReadRootRow;
    procedure _ReReadStaleRoots(const AMarks: TList<TBookmark>);
    function _AnswerIsTheRowUnderTheCursor(const AObject: TObject): Boolean;
    function _AnswerReachesEveryLoadedLevel(
      const AAdapter: TDataSetBaseAdapter<M>; const AObject: TObject): Boolean;
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
  MetaDbDiff.RTTI.Helper,
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
  LStale: TList<TBookmark>;
begin
  inherited;
  // Filtar somente os registros inseridos
  FOrmDataSet.Filter := cInternalField + '=' + IntToStr(Integer(dsInsert));
  FOrmDataSet.Filtered := True;
  FOrmDataSet.First;
  // A TERCEIRA COPIA DESTE LACO, e a que mais precisa do numero: aqui os dois
  // masters seguram os seus filhos AO MESMO TEMPO, porque
  // TRESTDataSetAdapter<M>.OpenDataSetChilds tem corpo vazio e a rolagem do
  // master nao descarta nada. Ver TDataSetBaseAdapter<M>.FCascadeMasterRows -
  // issue #261.
  FCascadeMasterRows := FOrmDataSet.RecordCount;
  LStale := TList<TBookmark>.Create;
  try
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
                // ISSUE #297 - A RESPOSTA DO INSERT NOMEIA A CHAVE DA RAIZ E
                // NADA ABAIXO DELA. O carimbo acima reconcilia a FK que os
                // filhos apontam para esta raiz; as chaves PROPRIAS dos niveis
                // 2 e 3 continuam no placeholder de AutoInc enquanto o servidor
                // ja gerou valores reais - o cliente fica com um grafo que o
                // servidor nao tem, e qualquer UPDATE ou DELETE feito dessa
                // tela mira uma chave que nao existe.
                // A pergunta e feita AQUI, com o cursor ainda parado sobre a
                // linha, e a resposta e' guardada como bookmark: o Post logo
                // abaixo tira a linha do filtro e leva o cursor embora.
                // E SAO DUAS PERGUNTAS, nao uma. "Voltou resposta" NAO e "a
                // chave chegou": o laco acima so escreve as colunas que o
                // dataset tem, de modo que uma resposta bem formada que nomeie
                // outra coluna deixa a raiz no placeholder - e o GET sairia
                // como $filter=root_id=-1, que so pode responder a linha de
                // outro ou coisa nenhuma. Medido por
                // Cost_ParamsThatNameNoColumnOfThisRowBuyNoGet.
                //
                // ISSUE #300 - E A CHAVE PODE CHEGAR PELA METADE. Com chave
                // primaria COMPOSTA, _RowKeyIsUngenerated le coluna a coluna e
                // basta UMA no placeholder para o portao fechar. Ate a #300 o
                // cliente caia sempre nesse estado, porque o parser de
                // ResultParams criava um TParam por OBJETO e so a ULTIMA coluna
                // da chave sobrevivia - logo este portao nunca abria para chave
                // composta. Sobre o mesmo modelo e a mesma resposta: antes da
                // #300 GetCount = 0, depois GetCount = 1, por
                // Test.Janus.Rest.CompositeKeyReReadGate,
                // CompositeKey_TheGateOpensAndExactlyOneGetIsIssued. REMEDIDO
                // em 0f13601, RESTfulDriver Debug/Win32: com o conserto a suite
                // fecha 102/0 e essa clausula exige GetCount = 1; com o trecho
                // do parser revertido em cima do mesmo commit a suite da 102/8
                // e a clausula devolve GetCount = 0.
                //
                // E O LACO ACIMA ESCREVE MAIS DO QUE ESCREVIA. Ele percorre
                // 0..Count-1 e carimba TODA coluna que o dataset tenha e a
                // resposta nomeie - nao so as da chave; a guarda e o FindField
                // nil, nao a chave primaria. Antes da #300 um objeto rendia UM
                // param, logo no maximo UMA coluna por objeto era escrita.
                // Medido em 0f13601, sonda descartavel sobre TCkRoot sem filho
                // (para este portao nao disparar e reescrever a linha), com a
                // resposta {"tag":"fromserver","ck1":7,"ck2":9}: com o conserto
                // sai tag=fromserver ck1=7 ck2=9; com ele revertido sai
                // tag=root ck1=-1 ck2=9. Hoje o alcance so e estreito porque o
                // SERVIDOR percorre apenas colunas de PK
                // (Janus.Server.Resource.pas:304-307) - o limite nao esta aqui.
                if _GraphBelowIsStale(Self) and
                   not _RowKeyIsUngenerated(Self) then
                  LStale.Add(FOrmDataSet.GetBookmark);
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
      FCascadeMasterRows := 0;
      FOrmDataSet.Filtered := False;
      FOrmDataSet.Filter := '';
    end;
    // FORA do laco e DEPOIS de o filtro cair, e as duas coisas por medicao:
    // dentro do laco a re-leitura apagaria os filhos AINDA NAO ENVIADOS das
    // raizes seguintes - RefreshRecordInternal esvazia os datasets filhos
    // inteiros -, e com o filtro ligado o bookmark aponta para uma linha que o
    // conjunto filtrado nao contem mais.
    _ReReadStaleRoots(LStale);
  finally
    for LFor := 0 to LStale.Count -1 do
      FOrmDataSet.FreeBookmark(LStale[LFor]);
    LStale.Free;
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
///     (em Janus.DML.Generator.pas - ANCORA POR SIMBOLO: o ":609-663" que
///     estava aqui apodreceu quando a issue #326 inseriu 97 linhas naquela
///     unit), e ele fica no caminho da RTTI que o
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

/// <summary> A linha que voltou do servidor E a linha sobre a qual o cursor
///  esta? - issue #297.
///
///  POR QUE PRECISOU EXISTIR. O unico caminho de producao que chega em
///  RefreshRecordInternal nesta familia e TSessionRestFul<M>.RefreshRecord, que
///  monta o filtro a partir da CHAVE PRIMARIA da linha corrente
///  (TDataSetBaseAdapter<M>.RefreshRecord) - TSessionRestFul nao sobrescreve
///  RefreshRecordWhere, e a versao de TSessionAbstract tem corpo vazio. Ou seja:
///  o que volta ou e aquela linha, ou nao e resposta a esta pergunta. Reescrever
///  a linha do cliente com o que quer que tenha voltado transforma um servidor
///  que respondeu outra coisa - ou um proxy, ou um duplo - em perda silenciosa
///  de dado, e isso passou a importar porque a partir da #297 esta chamada
///  acontece SOZINHA depois de todo insert com grafo defasado, e nao apenas
///  quando o consumidor pede.
///
///  COMPARA POR VALOR DE VARIANTE, e nao por texto: chave de data, de moeda ou
///  de GUID chegaria formatada diferente dos dois lados e seria recusada por
///  engano. VarCompareValue trata Null contra Null como igual.
///  E ESSE RAMO NAO TEM TESTE. NAO MEDIDO: toda clausula que exercita esta
///  guarda usa chave INTEIRA, porque nao ha no repositorio modelo REST com
///  chave primaria de data, moeda ou GUID para dirigir por aqui. Que a
///  comparacao por variante nao recusa por formatacao e RACIOCINIO sobre
///  VarCompareValue, e nao medicao - quem for acrescentar um modelo desses
///  comeca por aqui.
///
///  RESPONDE True QUANDO NAO HA PERGUNTA A FAZER - sem chave primaria mapeada,
///  sem a coluna no dataset, sem a propriedade no objeto, ou com o dataset
///  vazio. Em nenhum desses casos existe divergencia a detectar, e recusar por
///  falta de resposta desligaria o refresh inteiro. </summary>
function TRESTDataSetAdapter<M>._AnswerIsTheRowUnderTheCursor(
  const AObject: TObject): Boolean;
var
  LPrimaryKey: TPrimaryKeyMapping;
  LColumns: TColumnMappingList;
  LColumn: TColumnMapping;
  LField: TField;
  LFor: Integer;
begin
  Result := True;
  if AObject = nil then
    Exit;
  if FCurrentInternal = nil then
    Exit;
  if not FOrmDataSet.Active then
    Exit;
  if FOrmDataSet.IsEmpty then
    Exit;
  LPrimaryKey := TMappingExplorer
                   .GetMappingPrimaryKey(FCurrentInternal.ClassType);
  if LPrimaryKey = nil then
    Exit;
  LColumns := TMappingExplorer.GetMappingColumn(FCurrentInternal.ClassType);
  if LColumns = nil then
    Exit;
  for LFor := 0 to LPrimaryKey.Columns.Count -1 do
  begin
    LField := FOrmDataSet.FindField(LPrimaryKey.Columns.Items[LFor]);
    if LField = nil then
      Continue;
    for LColumn in LColumns do
    begin
      if not SameText(LColumn.ColumnName, LPrimaryKey.Columns.Items[LFor]) then
        Continue;
      if LColumn.ColumnProperty = nil then
        Break;
      if VarCompareValue(LField.Value,
           LColumn.ColumnProperty.GetNullableValue(AObject)
             .AsVariant) <> vrEqual then
        Exit(False);
      Break;
    end;
  end;
end;

/// <summary> A resposta alcanca TODO nivel que o cliente ja segura? - issue
///  #297.
///
///  O QUE ELA IMPEDE. RefreshRecordInternal esvazia os datasets filhos INTEIROS
///  antes de repopular, e esvaziar uma linha do meio dispara a CascadeDelete
///  dela, que leva junto o dataset dos netos. Se a resposta nao trouxe aquele
///  nivel, o esvaziamento apaga linha que o servidor ACABOU de gravar a partir
///  do POST, e nada volta a por essas linhas no lugar.
///
///  E ISSO E O SERVIDOR SHIPADO, NAO UMA HIPOTESE. TRESTObjectManager
///  .FillAssociation PULA associacao Lazy. Um agregado com um ramo
///  CascadeAutoInc defasado e um ramo Lazy irmao dispara a re-leitura, e a
///  resposta legitimamente nao menciona o ramo Lazy.
///
///  POR QUE A RESPOSTA E RECUSADA INTEIRA, e nao aplicada em parte: aplicar so
///  os niveis que vieram deixa o cliente num terceiro estado - parte
///  reconciliada, parte nao - que ninguem consegue descrever depois. Recusar
///  devolve o cliente ao estado ANTERIOR a #297, que e o defeito, e defeito e
///  melhor do que perda de linha.
///
///  O NIVEL VAZIO NAO E NIVEL FALTANDO. A exigencia so vale onde o CLIENTE tem
///  linha: um agregado de dois niveis recebe uma resposta sem netos e ela
///  concorda com ele. Sem essa metade, a recusa desligaria a correcao para todo
///  agregado que nao tenha exatamente a profundidade da resposta. Medido por
///  Shallow_AnAnswerIsNotRefusedForALevelTheClientDoesNotHold.
///
///  BASTA UM OBJETO DA LISTA alcancar o nivel de baixo. A resposta traz N
///  objetos de meio e o cliente tem UM dataset de netos: exigir que todos os N
///  tragam netos recusaria a resposta certa de um agregado onde so uma linha do
///  meio tem filhos - medido por
///  Shallow_OneObjectOfTheListReachingDeeperIsEnough, onde a exigencia estrita
///  derruba uma resposta correta.
///
///  E ESSA METADE TEM UM RESIDUO, QUE FICA DECLARADO E NAO ESCONDIDO. Se o
///  cliente segura neto sob DUAS linhas do meio e a resposta traz neto so para a
///  PRIMEIRA, esta funcao aceita a resposta e o neto da SEGUNDA - que o operador
///  digitou e que o POST levou - e apagado pelo esvaziamento. Medido: entram 2
///  netos, sai 1.
///  POR QUE ISSO FICA ASSIM, e nao e a mesma coisa que o defeito que esta guarda
///  conserta:
///    * o gatilho REAL de resposta rasa e a associacao Lazy, e Lazy e por
///      ASSOCIACAO e nao por linha - o servidor devolve o ramo para TODAS as
///      linhas ou para NENHUMA. No caso "para nenhuma" esta guarda recusa, e e
///      isso que as duas clausulas Shallow medem;
///    * a granularidade que falta e a MESMA causa-raiz do caso multi-raiz logo
///      abaixo: RefreshRecordInternal esvazia o dataset filho INTEIRO sem
///      perguntar de qual linha do meio a linha e. Consertar por linha e
///      consertar os dois de uma vez, e e a issue propria ja aberta para o
///      multi-raiz;
///    * apertar so este lado - exigir que TODOS os objetos alcancem - troca uma
///      perda rara por uma recusa comum, medida na clausula citada acima.
///  </summary>
function TRESTDataSetAdapter<M>._AnswerReachesEveryLoadedLevel(
  const AAdapter: TDataSetBaseAdapter<M>; const AObject: TObject): Boolean;
var
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LChild: TDataSetBaseAdapter<M>;
  LList: TObjectList<TObject>;
  LItem: TObject;
  LValue: TObject;
  LDeeper: Boolean;
begin
  Result := True;
  if AAdapter = nil then
    Exit;
  if AObject = nil then
    Exit;
  if AAdapter.FCurrentInternal = nil then
    Exit;
  if AAdapter.FMasterObject = nil then
    Exit;
  if AAdapter.FMasterObject.Count = 0 then
    Exit;
  LAssociations := TMappingExplorer
                     .GetMappingAssociation(AAdapter.FCurrentInternal.ClassType);
  if LAssociations = nil then
    Exit;
  for LAssociation in LAssociations do
  begin
    if not AAdapter.FMasterObject.TryGetValue(LAssociation.ClassNameRef,
                                              LChild) then
      Continue;
    if LChild = nil then
      Continue;
    if LChild.FOrmDataSet = nil then
      Continue;
    if not LChild.FOrmDataSet.Active then
      Continue;
    // O cliente nao segura nada neste ramo: nao ha o que perder e nao ha o que
    // exigir da resposta.
    if LChild.FOrmDataSet.IsEmpty then
      Continue;
    LValue := LAssociation.PropertyRtti.GetValue(AObject).AsObject;
    if not LAssociation.PropertyRtti.IsList then
    begin
      if LValue = nil then
        Exit(False);
      if not _AnswerReachesEveryLoadedLevel(LChild, LValue) then
        Exit(False);
      Continue;
    end;
    LList := TObjectList<TObject>(LValue);
    if LList = nil then
      Exit(False);
    if LList.Count = 0 then
      Exit(False);
    LDeeper := False;
    for LItem in LList do
    begin
      if _AnswerReachesEveryLoadedLevel(LChild, LItem) then
      begin
        LDeeper := True;
        Break;
      end;
    end;
    if not LDeeper then
      Exit(False);
  end;
end;

procedure TRESTDataSetAdapter<M>.RefreshRecordInternal(const AObject: TObject);
var
  LChildDataSet: TDataSetBaseAdapter<M>;
begin
  inherited;
  if not _AnswerIsTheRowUnderTheCursor(AObject) then
    Exit;
  // SO NA RE-LEITURA AUTOMATICA - ver FReReadAfterInsert. Num refresh PEDIDO
  // pelo consumidor, filho que sumiu no servidor deve sumir na tela; num
  // refresh que o proprio ApplyInserter disparou um instante depois de o
  // servidor gravar, "a resposta nao mencionou" nunca quer dizer "foi apagado".
  if FReReadAfterInsert and not _AnswerReachesEveryLoadedLevel(Self, AObject) then
    Exit;
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

/// <summary> A LINHA CORRENTE deste adapter ainda carrega o placeholder de
///  AutoInc na sua propria chave primaria? - issue #297. Uma linha so, sem mover
///  cursor nenhum, para os dois leitores: o que pergunta pela raiz que acabou de
///  ser inserida e o que percorre as linhas de um filho.
///
///  PERGUNTA POR VALOR, PELOS MESMOS MOTIVOS DE
///  TDataSetBaseAdapter<M>._AutoIncKeyIsGenerated: entidade sem chave mapeada,
///  ou chave que nao e AutoInc - onde -1 pode ser uma chave legitima - nao tem
///  placeholder como conceito, e nenhuma das duas deve responder "defasado".
///
///  A GUARDA DE cINTEGERKINDS SOBREVIVE A MUTACAO, e esta declarada em vez de
///  escondida. Medido em f7f8e76, ja sobre a #296: removendo as duas linhas,
///  RESTfulDriver 87 total, zero falhas, zero erros - nenhuma clausula morre.
///  A razao
///  e que nenhum modelo do repositorio declara chave primaria AutoInc que nao
///  seja inteira, de modo que o ramo nao e alcancavel por teste nenhum hoje.
///  Ela fica porque cAutoIncNotGenerated e o inteiro -1: sobre um ftGuid ou um
///  ftString, AsInteger ou levanta ou responde 0, e as duas respostas seriam
///  sobre uma pergunta que nao existe. E a mesma guarda, pela mesma razao, de
///  _AutoIncKeyIsGenerated - onde ela E alcancavel, porque la as colunas vem da
///  ASSOCIACAO e nao da chave primaria. </summary>
function TRESTDataSetAdapter<M>._RowKeyIsUngenerated(
  const AAdapter: TDataSetBaseAdapter<M>): Boolean;
const
  cINTEGERKINDS = [ftInteger, ftSmallint, ftWord, ftLargeint, ftAutoInc,
                   ftLongWord, ftShortint, ftByte];
var
  LPrimaryKey: TPrimaryKeyMapping;
  LDataSet: TDataSet;
  LField: TField;
  LFor: Integer;
begin
  Result := False;
  if AAdapter = nil then
    Exit;
  if AAdapter.FCurrentInternal = nil then
    Exit;
  LDataSet := AAdapter.FOrmDataSet;
  if LDataSet = nil then
    Exit;
  if not LDataSet.Active then
    Exit;
  if LDataSet.IsEmpty then
    Exit;
  LPrimaryKey := TMappingExplorer
                   .GetMappingPrimaryKey(AAdapter.FCurrentInternal.ClassType);
  if LPrimaryKey = nil then
    Exit;
  if not LPrimaryKey.AutoIncrement then
    Exit;
  for LFor := 0 to LPrimaryKey.Columns.Count -1 do
  begin
    LField := LDataSet.FindField(LPrimaryKey.Columns.Items[LFor]);
    if LField = nil then
      Continue;
    if not (LField.DataType in cINTEGERKINDS) then
      Continue;
    if LField.AsInteger = cAutoIncNotGenerated then
      Exit(True);
  end;
end;

/// <summary> ALGUMA linha deste adapter carrega o placeholder na chave propria?
///  - issue #297.
///
///  E A CHAVE PROPRIA, E NAO A ESTRANGEIRA. A decisao e por SENSIBILIDADE, e o
///  que segue e MEDIDO. Substituindo esta leitura por uma que percorre as
///  colunas da ASSOCIACAO no dataset filho - a chave estrangeira - e re-rodando
///  a suite em f7f8e76, ja sobre a #296: 87 total, morrem DUAS clausulas - e sao
///  estas duas, nao um numero estimado. As duas dizem exatamente onde a leitura
///  pela FK e cega:
///    * o agregado de DOIS niveis - a FK do filho para a raiz JA foi
///      reconciliada pelo carimbo mais SetAutoIncValueChilds, entao pela FK nao
///      sobra nada para denunciar, e so a chave propria do filho denuncia
///      (Shallow_AnAnswerIsNotRefusedForALevelTheClientDoesNotHold);
///    * o meio que carrega uma chave que o operador DIGITOU - a cascata propaga
///      essa chave para a FK do neto, que fica correta, enquanto a chave propria
///      do neto continua no placeholder
///      (Cost_AStaleGrandchildAloneStillBuysTheGet).
///  Fora esses dois, as duas leituras enxergam o mesmo: na arvore de tres niveis
///  a FK do neto para o meio tambem nunca e reconciliada e denuncia o grafo pelo
///  nivel 3. A chave propria e ESTRITAMENTE mais sensivel, e e por isso que
///  fica - nao porque a outra leitura seja cega.
///
///  A CAMINHADA DESLIGA OS EVENTOS DO FILHO, e nao e cosmetico: andar num
///  dataset filho dispara o AfterScroll dele, que chama OpenDataSetChilds e
///  RE-LE os netos do servidor - perguntar se o filho esta defasado destruiria
///  os netos ainda nao gravados. Mesma armadilha e mesma tecnica de
///  TDataSetBaseAdapter<M>._HasPendingRows e de SetAutoIncValueChilds. </summary>
function TRESTDataSetAdapter<M>._OwnKeyIsUngenerated(
  const AAdapter: TDataSetBaseAdapter<M>): Boolean;
var
  LDataSet: TDataSet;
  LMark: TBookmark;
begin
  Result := False;
  if AAdapter = nil then
    Exit;
  LDataSet := AAdapter.FOrmDataSet;
  if LDataSet = nil then
    Exit;
  if not LDataSet.Active then
    Exit;
  if LDataSet.IsEmpty then
    Exit;
  AAdapter.DisableDataSetEvents;
  LDataSet.DisableControls;
  LMark := LDataSet.GetBookmark;
  try
    LDataSet.First;
    while not LDataSet.Eof do
    begin
      if _RowKeyIsUngenerated(AAdapter) then
        Exit(True);
      LDataSet.Next;
    end;
  finally
    if LDataSet.BookmarkValid(LMark) then
      LDataSet.GotoBookmark(LMark);
    LDataSet.FreeBookmark(LMark);
    LDataSet.EnableControls;
    AAdapter.EnableDataSetEvents;
  end;
end;

/// <summary> O grafo abaixo de AAdapter esta defasado em relacao ao servidor?
///  - issue #297.
///
///  SO AS ASSOCIACOES CascadeAutoInc, e nao todas: uma associacao que o modelo
///  NAO marcou para cascatear chave nao teve chave nenhuma gerada pelo servidor
///  a partir desta insercao, e um -1 nela e do consumidor. TAitRoot.others
///  existe no fixture exatamente para isso.
///
///  RECURSA PORQUE O DEFEITO E DE PROFUNDIDADE. Com dois niveis o carimbo ja
///  resolvia; o que nunca foi reconciliado comeca no nivel 2 (chave propria) e
///  segue no 3. Parar no primeiro nivel deixaria o neto para tras, que e
///  exatamente o que a opcao de reordenar nao alcancava. </summary>
function TRESTDataSetAdapter<M>._GraphBelowIsStale(
  const AAdapter: TDataSetBaseAdapter<M>): Boolean;
var
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LChild: TDataSetBaseAdapter<M>;
begin
  Result := False;
  if AAdapter = nil then
    Exit;
  if AAdapter.FCurrentInternal = nil then
    Exit;
  if AAdapter.FMasterObject = nil then
    Exit;
  if AAdapter.FMasterObject.Count = 0 then
    Exit;
  LAssociations := TMappingExplorer
                     .GetMappingAssociation(AAdapter.FCurrentInternal.ClassType);
  if LAssociations = nil then
    Exit;
  for LAssociation in LAssociations do
  begin
    if not (TCascadeAction.CascadeAutoInc in LAssociation.CascadeActions) then
      Continue;
    if not AAdapter.FMasterObject.TryGetValue(LAssociation.ClassNameRef,
                                              LChild) then
      Continue;
    if LChild = nil then
      Continue;
    if _OwnKeyIsUngenerated(LChild) then
      Exit(True);
    if _GraphBelowIsStale(LChild) then
      Exit(True);
  end;
end;

/// <summary> A re-leitura de UMA raiz: monta os params da chave primaria da
///  linha corrente e desce em TSessionRestFul<M>.RefreshRecord, que emite o GET
///  na rota que ja existe e devolve o grafo inteiro - o FillAssociation do
///  servidor recursa e so pula as associacoes Lazy. Quem reescreve o cliente
///  do outro lado e RefreshRecordInternal, logo acima.
///
///  POR QUE ESTE METODO EXISTE EM VEZ DE UMA CHAMADA A
///  TDataSetBaseAdapter<M>.RefreshRecord, que monta os mesmos params: aquele
///  metodo se cerca de DisableDataSetEvents/EnableDataSetEvents, e esse par e
///  uma TROCA e nao um contador. Um segundo Disable encontra os handlers ja em
///  nil, nao guarda nada, e o Enable correspondente devolve os ORIGINAIS ao
///  dataset enquanto o chamador de fora ainda acredita que estao desligados.
///  Aqui isso re-armaria o DoBeforePost no meio do ApplyInternal, e o
///  ApplyUpdater que roda em seguida NAO TERMINA com ele armado - e a nota
///  "load-bearing" do DisableDataSetEvents nos dois ApplyInternal da familia.
///  Medido por Test.Janus.Rest.ReReadAfterInsert
///  .Design_TheEventSwitchIsASwapAndNotACounter. </summary>
procedure TRESTDataSetAdapter<M>._ReReadRootRow;
var
  LPrimaryKey: TPrimaryKeyMapping;
  LParams: TParams;
  LField: TField;
  LFor: Integer;
begin
  if FCurrentInternal = nil then
    Exit;
  LPrimaryKey := TMappingExplorer
                   .GetMappingPrimaryKey(FCurrentInternal.ClassType);
  if LPrimaryKey = nil then
    Exit;
  LParams := TParams.Create(nil);
  try
    for LFor := 0 to LPrimaryKey.Columns.Count -1 do
    begin
      LField := FOrmDataSet.FindField(LPrimaryKey.Columns.Items[LFor]);
      if LField = nil then
        Exit;
      with LParams.Add as TParam do
      begin
        // A GRAFIA DO MAPEAMENTO, e nao a do dataset. O irmao que monta os
        // mesmos params - TDataSetBaseAdapter<M>.RefreshRecord - nomeia por
        // LPrimaryKey.Columns, e o filtro que sai daqui viaja como nome de
        // coluna ate o servidor.
        // ESTA LINHA JA FOI UM SOBREVIVENTE DECLARADO, E A DECLARACAO ESTAVA
        // ERRADA. Ela dizia que a divergencia entre as duas grafias "nao e
        // medivel hoje": e medivel, com o duplo que esta fixtura ja tem, e o
        // que faltava era a ASSERCAO. ReRead_TheGetAsksByTheKeyTheServerReturned
        // comparava a query por SUBSTRING, de modo que um PREFIXO no nome da
        // coluna passava verde e so a troca do nome inteiro morria - ou seja, o
        // nome de coluna que viaja no $filter nao tinha cobertura nenhuma.
        // Hoje a clausula compara a query INTEIRA, e as duas mutacoes morrem.
        // Medido em f7f8e76, RESTfulDriver 87 total, uma falha em cada:
        //   prefixo      -> Expected [$filter=root_id=777]
        //                   but got  [$filter=zzroot_id=777]
        //   nome trocado -> Expected [$filter=root_id=777]
        //                   but got  [$filter=nope=777]
        // A ESCOLHA CONTINUA SENDO A GRAFIA DO MAPEAMENTO, que e a do irmao em
        // TDataSetBaseAdapter<M>.RefreshRecord; unificar as duas montagens num
        // helper exigiria mexer no adapter BASE.
        Name := LPrimaryKey.Columns.Items[LFor];
        ParamType := ptInput;
        DataType := LField.DataType;
        Value := LField.Value;
      end;
    end;
    if LParams.Count = 0 then
      Exit;
    FReReadAfterInsert := True;
    try
      FSession.RefreshRecord(LParams);
    finally
      FReReadAfterInsert := False;
    end;
  finally
    LParams.Clear;
    LParams.Free;
  end;
end;

/// <summary> Uma re-leitura por raiz inserida cujo grafo ficou defasado, e
///  NENHUMA para as outras - e o unico custo que esta correcao cobra.
///
///  A LISTA VEM VAZIA NO CASO ORDINARIO: uma raiz sem filhos registrados, ou
///  cujos filhos ja carregam chave propria, nao entra nela, e o metodo sai sem
///  tocar na rede.
///
///  MAIS DE UMA RAIZ NA MESMA GRAVACAO NAO E RE-LIDA, E ISSO E MEDICAO E NAO
///  PREFERENCIA. RefreshRecordInternal esvazia os datasets filhos INTEIROS -
///  o laco de Delete nao pergunta de qual master a linha e -, e apagar uma
///  linha do meio ainda dispara a CascadeDelete dela, que esvazia o dataset dos
///  netos inteiro tambem.
///  MEDIDO EM f7f8e76, ja sobre a #296, com esta guarda removida e com o resto
///  da correcao no lugar: duas raizes com uma linha de meio e um neto cada, o
///  duplo respondendo CHAVES DIFERENTES por raiz - 777 e 888 no POST, e um grafo
///  proprio por raiz no GET. Resultado:
///  `roots=2 mids=1 leafs=1 posts=2 gets=2`. A re-leitura da segunda raiz levou
///  os filhos JA RECONCILIADOS da primeira.
///  AS CHAVES DISTINTAS SAO PARTE DA MEDICAO: com as duas raizes respondendo a
///  MESMA chave, a perda medida podia ser artefato de duas raizes que a fixtura
///  nao consegue distinguir. Nao e - ela se reproduz com as raizes separadas.
///  Isso e PIOR do que o defeito que esta correcao conserta, entao neste caso o
///  cliente fica exatamente como ficava antes dela: com as chaves proprias no
///  placeholder, e sem perder linha nenhuma. Consertar tambem esse caso exige
///  que o esvaziamento seja limitado as linhas DAQUELE master, nos dois niveis -
///  inclusive dentro de DeleteDataSetChilds, que e o guarda da #235 e serve
///  tambem o caminho de exclusao de verdade. Issue propria.
///  MEDIDO POR MultiRoot_TwoRootsSavedTogetherAreLeftAloneAndKeepEveryRow.
///  </summary>
procedure TRESTDataSetAdapter<M>._ReReadStaleRoots(
  const AMarks: TList<TBookmark>);
var
  LFor: Integer;
begin
  if AMarks.Count = 0 then
    Exit;
  if AMarks.Count > 1 then
    Exit;
  for LFor := 0 to AMarks.Count -1 do
  begin
    if not FOrmDataSet.BookmarkValid(AMarks[LFor]) then
      Continue;
    FOrmDataSet.GotoBookmark(AMarks[LFor]);
    _ReReadRootRow;
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
