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

unit Janus.Session.RESTful;

interface

uses
  DB,
  Rtti,
  TypInfo,
  Classes,
  Variants,
  SysUtils,
  StrUtils,
  Generics.Collections,
  {$IFDEF DELPHI15_UP}
  JSON,
  {$ELSE}
  DBXJSON,
  {$ENDIF}
  // Janus
  Janus.Session.Abstract,
  DataEngine.FactoryInterfaces,
  Janus.Client.Methods,
  Janus.RestFactory.Interfaces,
  Janus.RestDataSet.Adapter;

type
  TSessionRestFul<M: class, constructor> = class(TSessionAbstract<M>)
  private
    FOwner: TRESTDataSetAdapter<M>;
    FConnection: IRESTConnection;
    FResource: String;
    FSubResource: String;
    FServerUse: Boolean;
    function _NextPacketMethod: TObjectList<M>; overload;
    function _NextPacketMethod(AWhere, AOrderBy: String): TObjectList<M>; overload;
    function _ParseOperator(AParams: String): String;
  public
    constructor Create(const AConnection: IRESTConnection;
      const AOwner: TRESTDataSetAdapter<M>; const APageSize: Integer = -1); overload;
    destructor Destroy; override;
    procedure Insert(const AObject: M); overload; override;
    procedure Update(const AObjectList: TObjectList<M>); overload; override;
    procedure Delete(const AID: Integer); overload; override;
    procedure Delete(const AObject: M); overload; override;
    procedure RefreshRecord(const AColumns: TParams); override;
    procedure NextPacketList(const AObjectList: TObjectList<M>); overload; override;
    function NextPacketList: TObjectList<M>; overload; override;
    function Find: TObjectList<M>; overload; override;
    function Find(const AID: Int64): M; overload; override;
    function Find(const AID: String): M; overload; override;
    function FindWhere(const AWhere: String; const AOrderBy: String = ''): TObjectList<M>; override;
    function ExistSequence: Boolean; override;
    {$IFDEF DRIVERRESTFUL}
    function Find(const AMethodName: String;
      const AParams: array of String): TObjectList<M>; overload; override;
    {$ENDIF}
  end;

implementation

uses
  Janus.Json,
  Janus.Core.Consts,
  Janus.Objects.Utils,
  Janus.Objects.Helper,
  MetaDbDiff.mapping.classes,
  MetaDbDiff.mapping.explorer,
  MetaDbDiff.mapping.attributes;

{ TSessionRest<M> }

constructor TSessionRestFul<M>.Create(const AConnection: IRESTConnection;
  const AOwner: TRESTDataSetAdapter<M>; const APageSize: Integer = -1);
var
  LObject: TObject;
  LTable: TCustomAttribute;
  LResource: TCustomAttribute;
  LSubResource: TCustomAttribute;
  LNotServerUse: TCustomAttribute;
begin
  inherited Create(APageSize);
  FOwner := AOwner;
  FConnection := AConnection;
  FPageSize := APageSize;
  FPageNext := 0;
  FFindWhereUsed := False;
  FFindWhereRefreshUsed := False;
  FResource := '';
  FSubResource := '';
  FServerUse := False;
  // Pega o nome do recurso e subresource definidos na classe
  LObject := TObject(M.Create);
  try
    if FConnection.ServerUse then
    begin
      // Valida se tem o atributo NotServerUse para nao usar o server
      LNotServerUse := LObject.GetNotServerUse;
      if LNotServerUse <> nil then
      begin
        FServerUse := False;
        FConnection.SetClassNotServerUse(True);
      end
      else
      begin
        FServerUse := True;
        FConnection.SetClassNotServerUse(False);
      end;
      LTable := LObject.GetTable;
      if LTable <> nil then
        FResource := Table(LTable).Name;
    end
    else
    begin
      // Nome do Recurso
      LResource := LObject.GetResource;
      if LResource <> nil then
        FResource := Resource(LResource).Name;

      if LResource = nil then
      begin
        LTable := LObject.GetTable;
        if LTable <> nil then
          FResource := Table(LTable).Name;
      end;
      // Nome do SubRecurso
      LSubResource := LObject.GetSubResource;
      if LSubResource <> nil then
        FSubResource := Resource(LSubResource).Name;
    end;
  finally
    LObject.Free;
  end;
end;

destructor TSessionRestFul<M>.Destroy;
begin

  inherited;
end;

function TSessionRestFul<M>.ExistSequence: Boolean;
var
  LSequence: TSequenceMapping;
begin
  Result := False;
  LSequence := TMappingExplorer.GetMappingSequence(TClass(M));
  if LSequence <> nil then
    Result := True;
end;

procedure TSessionRestFul<M>.Delete(const AObject: M);
var
  LColumn: TColumnMapping;
  LPrimaryKey: TPrimaryKeyColumnsMapping;
begin
  LPrimaryKey := TMappingExplorer.GetMappingPrimaryKeyColumns(AObject.ClassType);
  if LPrimaryKey = nil then
    raise Exception.Create(cMESSAGEPKNOTFOUND);

  LColumn := LPrimaryKey.Columns.Items[0];
  Delete(LColumn.ColumnProperty.GetValue(TObject(AObject)).AsInteger);
end;

procedure TSessionRestFul<M>.Delete(const AID: Integer);
var
  LSubResource: String;
  LURL: String;
  LResult: String;
  LResource: String;
begin
  LResource := FResource;
  // So concatena o ID na URI se a propriedade ServerUse for igual a True,
  // caso contrario sera passado como parametro
  if FServerUse then
    LResource := LResource + '(' + IntToStr(AID) + ')';
  LSubResource := ifThen(Length(FConnection.MethodDELETE) > 0, FConnection.MethodDELETE, FSubResource);
  try
    LResult := FConnection.Execute(LResource,
                                   LSubResource,
                                   TRESTRequestMethodType.rtDELETE,
                                   procedure
                                   begin
                                     if not FServerUse then
                                       FConnection.AddQueryParam('$value=' + IntToStr(AID));
                                   end);
  finally
    // Mostra no monitor a URI completa
    if FConnection.CommandMonitor <> nil then
    begin
      LURL := FConnection.FullURL;
      FConnection.CommandMonitor.Command('URI    : ' + LURL + sLineBreak +
                                         'ID     : ' + IntToStr(AID) + sLineBreak +
                                         'M'#$00E9'todo : DELETE' + sLineBreak +
                                         'Result : ' + LResult, nil);
    end;
  end;
end;

function TSessionRestFul<M>.FindWhere(const AWhere, AOrderBy: String): TObjectList<M>;
var
  LSubResource: String;
  LJSON: String;
  LURL: String;
begin
  FFindWhereUsed := True;
  FFetchingRecords := False;
  FWhere := AWhere;
  FOrderBy := AOrderBy;
  // So busca por paginacao se nao for um RefreshRecord
  if not FFindWhereRefreshUsed then
  begin
    if FPageSize > -1 then
    begin
      FPageNext := 0 - FPageSize;
      Result := _NextPacketMethod(FWhere, FOrderBy);
      Exit;
    end;
  end;
  LSubResource := '';
  if not FServerUse then
    LSubResource := ifThen(Length(FConnection.MethodGETWhere) > 0, FConnection.MethodGETWhere, FSubResource);

  try
    LJSON := FConnection.Execute(FResource,
                                 LSubResource,
                                 TRESTRequestMethodType.rtGET,
                                 procedure
                                 begin
                                   FConnection.AddQueryParam('$filter=' + _ParseOperator(FWhere));
                                   if Length(FOrderBy) > 0 then
                                     FConnection.AddQueryParam('$orderby=' + FOrderBy);
                                 end);
    // Caso o JSON retornado nao seja um array, tranforma-se em um.
    if {$IFDEF NEXTGEN}LJSON[0]{$ELSE}LJSON[1]{$ENDIF} = '{' then
      LJSON := '[' + LJSON + ']';

    // Transforma o JSON recebido populando em uma lista de objetos
    Result := TJanusJson.JsonToObjectList<M>(LJSON);
  finally
    // Mostra no monitor a URI completa
    if FConnection.CommandMonitor <> nil then
    begin
      LURL := FConnection.FullURL;
      FConnection.CommandMonitor.Command('URI    : ' + LURL + sLineBreak +
                                         'Where  : ' + AWhere + sLineBreak +
                                         'OrderBy: ' + AOrderBy + sLineBreak +
                                         'M'#$00E9'todo : GET' + sLineBreak +
                                         'Json   : ' + LJSON, nil);
    end;
  end;
end;

function TSessionRestFul<M>.Find(const AID: Int64): M;
begin
  // Transforma o JSON recebido populando o objeto
  FFindWhereUsed := False;
  FFetchingRecords := False;
  Result := Find(IntToStr(AID));
end;

function TSessionRestFul<M>.Find(const AID: String): M;
var
  LResource: String;
  LSubResource: String;
  LJSON: String;
  LURL: String;
begin
  FFindWhereUsed := False;
  FFetchingRecords := False;
  LResource := FResource;
  if not FServerUse then
    LSubResource := FConnection.MethodGETId
  else
  begin
    LResource := LResource + '(' + AID + ')';
    LSubResource := '';
  end;
  try
    LJSON := FConnection.Execute(LResource,
                                 LSubResource,
                                 TRESTRequestMethodType.rtGET,
                                 procedure
                                 begin
                                   if not FServerUse then
                                     FConnection.AddQueryParam('$value=' + AID)
                                 end);
    // Transforma o JSON recebido populando o objeto
    Result := TJanusJson.JsonToObject<M>(LJSON);
  finally
    // ostra no monitor a URI completa
    if FConnection.CommandMonitor <> nil then
    begin
      LURL := FConnection.FullURL;
      FConnection.CommandMonitor.Command('URI    : ' + LURL + sLineBreak +
                                         'ID     : ' + AID  + sLineBreak +
                                         'M'#$00E9'todo : GET' + sLineBreak +
                                         'Json   : ' + LJSON, nil);
    end;
  end;
end;

function TSessionRestFul<M>.Find: TObjectList<M>;
var
  LJSON: String;
  LSubResource: String;
  LURL: String;
begin
  FFetchingRecords := False;
  FFindWhereUsed := False;
  if FPageSize > -1 then
  begin
    FPageNext := 0 - FPageSize;
    Result := _NextPacketMethod;
    Exit;
  end;
  LSubResource := '';
  if not FServerUse then
    LSubResource := ifThen(Length(FConnection.MethodGET) > 0, FConnection.MethodGET, FSubResource);
  try
    LJSON := FConnection.Execute(FResource, LSubResource, TRESTRequestMethodType.rtGET);
    // Caso o JSON retornado nao seja um array, tranforma-se em um.
    if {$IFDEF NEXTGEN}LJSON[0]{$ELSE}LJSON[1]{$ENDIF} = '{' then
      LJSON := '[' + LJSON + ']';

    // Transforma o JSON recebido populando uma lista de objetos
    Result := TJanusJson.JsonToObjectList<M>(LJSON);
  finally
    // Mostra no monitor a URI completa
    if FConnection.CommandMonitor <> nil then
    begin
      LURL := FConnection.FullURL;
      FConnection.CommandMonitor.Command('URI    : ' + LURL + sLineBreak +
                                         'M'#$00E9'todo : GET' + sLineBreak +
                                         'Json   : ' + LJSON, nil);
    end;
  end;
end;

procedure TSessionRestFul<M>.Insert(const AObject: M);
var
  LJSON: String;
  LSubResource: String;
  LURL: String;
  LResult: String;
  LParamsObject: TJSONObject;
  LParamsArray: TJSONArray;
  LValuesObject: TJSONObject;
  LFor: Integer;
  LPar: Integer;
begin
  // ISSUE #313 - O `finally` LIA ESTE LOCAL SEM ELE TER SIDO ATRIBUIDO.
  // TJSONObject e tipo NAO GERENCIADO, e Delphi nao zera local desses. A
  // primeira atribuicao esta DENTRO do try aberto logo abaixo - referida pela
  // estrutura e nao por numero de linha, que este proprio comentario move - e o
  // FConnection.Execute que a antecede pode levantar - servidor fora, timeout,
  // 500 virando EJanusRESTException no cliente concreto. Nesse caminho o
  // `if LParamsObject <> nil` do finally le o que a pilha tinha, e libera lixo:
  // a violacao de acesso SUBSTITUI o erro de rede enquanto ele desempilha, e
  // quem chamou recebe "access violation" no lugar de "o servidor respondeu
  // 500". O `<> nil` nao protege porque lixo de pilha raramente e zero.
  //
  // O QUE FOI MEDIDO, E O QUE A ISSUE ALEGAVA E NAO SE CONFIRMOU. Medido em
  // ea0208f, Studio 37.0, Debug/Win32, RESTfulDriver: a AV NAO acontece hoje.
  // Test.Janus.Rest.InsertAnswerRobustness suja 64KB de pilha com $CD na
  // MESMA profundidade que o frame de Insert vai ocupar, e o slot ainda le
  // 00000000 - com os enderecos batendo (slot em 012FF3E4, faixa raspada
  // 012EF408..012FF407), ou seja o prologo do proprio Insert zera o frame.
  // Tres formas escritas a mao com a MESMA lista de locais - rotina simples,
  // rotina com metodo anonimo capturando locais, e metodo de classe generica
  // instanciada - NAO sao zeradas e dao EAccessViolation "Read of address
  // CDCDCDCD" trocando o erro de rede, todas medidas no mesmo commit e no
  // mesmo compilador. POR QUE o Insert real e zerado e a revisao independente
  // desta branch quem leu, nos bytes do .exe: o prologo dele e
  // `mov ecx,$11 / push 0 ; push 0 / dec ecx ; jnz` - um laco que zera 34
  // dwords, porque o compilador escolheu ALOCAR o frame com `push 0` em laco
  // em vez de um `add esp,-N`. As catorze instanciacoes de Insert no binario
  // tem o mesmo prologo. Ou seja: o defeito e real, e o unico anteparo hoje e
  // uma escolha de alocacao de frame que ninguem controla nem pede.
  //
  // O QUE E CONTRATO E O PROPRIO COMPILADOR DIZER. dcc32 emite em ea0208f
  // "W1036 Variable 'LParamsObject' might not have been initialized" apontando
  // a linha do `finally` deste metodo - `:446` na numeracao de ea0208f, que e
  // do proprio compilador e nao minha. Esta atribuicao e o que faz esse aviso
  // sumir, e o aviso e a medida de que ela e necessaria. Ele e ORACULO, nao
  // portao: nao ha `DCC_WarningsAsErrors` em .dproj nenhum deste repositorio,
  // entao nada impede que o aviso volte sem quebrar o build.
  LParamsObject := nil;
  LSubResource := ifThen(Length(FConnection.MethodPOST) > 0, FConnection.MethodPOST, FSubResource);
  LJSON := TJanusJson.ObjectToJsonString(AObject);
  try
    LResult := FConnection.Execute(FResource,
                                   LSubResource,
                                   TRESTRequestMethodType.rtPOST,
                                   procedure
                                   begin
                                     FConnection.AddBodyParam(LJSON);
                                   end);
    FResultParams.Clear;
    // Gera lista de params com o retorno, se existir o elemento "params" no JSON.
    LParamsObject := TJanusJson.JSONStringToJSONObject(LResult);
    if LParamsObject = nil then
      Exit;

    // ISSUE #315 - O `as` LEVANTAVA ANTES DA GUARDA SER AVALIADA. Escrito
    // `Values['params'] as TJSONArray` seguido de `if = nil then Exit`, isto
    // parece um cast guardado e nao e: `nil as TJSONArray` de fato e nil, entao
    // a guarda cobria a chave AUSENTE - e so ela. Com a chave PRESENTE e de
    // tipo errado o `as` levanta EInvalidCast cru, com uma mensagem que nao
    // menciona HTTP, nem servidor, nem resposta. Medido em ea0208f, cinco
    // formas, todas escapando do Insert: params objeto, params string, params
    // numero, params NULL e params array-de-nao-objetos (esta ultima no cast de
    // baixo). A forma NULL nao estava na issue e e a mais provavel em campo:
    // servidor sem chave a informar escreve null, nao omite a chave; TJSONNull
    // e um TJSONValue como outro qualquer e chega ate aqui.
    //
    // POR QUE `Exit` E NAO EXCECAO NOMEADA. A casa ja responde esta pergunta
    // duas vezes neste mesmo metodo - no `if LParamsObject = nil then Exit`
    // logo acima, quando o corpo nao vira objeto, e na propria guarda abaixo,
    // quando `params` nao existe - e uma vez logo adiante com o motivo
    // escrito: RefreshRecord, issue #297, "NENHUMA LINHA E
    // UMA RESPOSTA, e nao um erro ... a excecao passaria a interromper a
    // gravacao DEPOIS de o servidor ja ter escrito". Vale identico aqui: quando
    // esta resposta e lida a LINHA JA FOI INSERIDA. `params` e o eco da chave
    // gerada - util quando vem, e a ausencia dele ja e resposta suportada. Um
    // `params` malformado nao carrega mais informacao que um ausente, entao
    // recebe a mesma resposta. Duas respostas para a mesma pergunta dentro de
    // um framework e defeito por si so, e este conserto nao inventa a terceira.
    //
    // `nil is TJSONArray` e False, entao a chave ausente continua saindo por
    // aqui exatamente como antes: a guarda foi TROCADA, nao estreitada.
    //
    // As duas guardas vizinhas citadas acima sao referidas pelo CODIGO delas e
    // nao por numero de linha, de proposito: citacao para dentro do proprio
    // arquivo apodrece sozinha, porque o comentario que a carrega e o que
    // empurra a linha citada. Foi o que aconteceu com a versao anterior desta
    // frase - dizia `:387-388`, certo em ea0208f e errado assim que este
    // comentario entrou.
    //
    // E A FORMA AFIADA DISSO, que pegou tres vezes nesta branch e uma delas
    // dentro do proprio commit que consertava as outras duas: numero medido
    // ANTES da edicao que viaja junto com ele e numero de uma arvore que nunca
    // existiu. So vale medir depois de escrever a ultima linha.
    //
    // Citacao para OUTRO arquivo continua por `file:linha`, com o commit em
    // que foi lida - e ainda assim so sobrevive se aquele arquivo estiver
    // parado.
    if not (LParamsObject.Values['params'] is TJSONArray) then
      Exit;
    LParamsArray := TJSONArray(LParamsObject.Values['params']);

    // ISSUE #300 - UM TParam POR PAR, NAO POR OBJETO. O servidor emite a chave
    // primaria INTEIRA num unico objeto: TAppResourceBase.ParseInsert percorre
    // `LPrimaryKey.Columns` e poe uma entrada por coluna da chave dentro do
    // unico objeto que a constante cRESOURCEINSERT reserva.
    //
    // ESTAS TRES CITACOES ERAM POR LINHA E JA CHEGARAM PODRES NESTA BRANCH.
    // Diziam `Janus.Server.Resource.pas:304-307` (duas vezes) e `(:57)`, certas
    // em c608bad e erradas em ea0208f, que e a base daqui: a #311/#322
    // reescreveu aquele arquivo e cRESOURCEINSERT foi para :60 e o laco das
    // colunas para :423. Nao foi este conserto que as moveu, e por isso estao
    // agora por SIMBOLO - aquele arquivo e a frente da #320 e esta mudando
    // agora, entao qualquer numero novo apodrece de novo.
    //
    // E A FRASE ACIMA TAMBEM ENVELHECEU NO MECANISMO, nao so na linha: em
    // c608bad a constante era `"params":[{%s}]` e o servidor CONCATENAVA
    // `"nome":valor,` em texto; em ea0208f ela e `"params":[%s]` e o `%s` ja
    // chega como objeto JSON serializado inteiro - o assunto da #311. O que o
    // cliente le na resposta nao mudou, e por isso a analise abaixo continua
    // valendo; o COMO o servidor a produz mudou.
    //
    // Com o `with FResultParams.Add` do lado
    // de FORA deste laco interno, Name e Value eram sobrescritos a cada par e
    // so o ULTIMO sobrevivia - uma entidade REST de chave composta voltava do
    // insert com uma coluna da chave preenchida e as demais no placeholder, sem
    // excecao e sem log. O laco EXTERNO continua: a resposta tambem pode trazer
    // um objeto por coluna, e as duas formas sao lidas.
    //
    // ISTO ALARGA O QUE UMA RESPOSTA PODE ESCREVER NA LINHA, e o alargamento
    // esta declarado aqui porque nao esta escrito em nenhum outro lugar. O
    // consumidor (TRESTDataSetAdapter<M>.ApplyInserter,
    // Janus.RestDataSet.Adapter.pas:241-246, relido em ea0208f) percorre
    // 0..Count-1 e escreve
    // TODA coluna que o dataset tenha e a resposta nomeie - nao so as da chave.
    // Antes deste conserto o objeto rendia UM param, logo no maximo UMA coluna
    // por objeto podia ser escrita; agora sao todas. Medido em 0f13601 com uma
    // sonda descartavel sobre TCkRoot e sem filho (para o re-ler da #297 nao
    // disparar e reescrever a linha), resposta
    // {"tag":"fromserver","ck1":7,"ck2":9}:
    //   com este conserto        : GetCount 0, tag=fromserver ck1=7  ck2=9
    //   com este trecho revertido: GetCount 0, tag=root       ck1=-1 ck2=9
    // Ou seja: de UMA escrita (o ultimo par) para TRES, uma delas numa coluna
    // que NAO e da chave. Hoje isso e limitado porque o servidor so percorre
    // colunas de PK (o `for LColumn in LPrimaryKey.Columns` de ParseInsert) -
    // o limite mora no SERVIDOR, e o cliente nao o impoe.
    //
    // ISSO MUDA QUANDO O RE-LER DA #297 DISPARA, e o numero esta medido em
    // Test.Janus.Rest.CompositeKeyReReadGate: o portao de
    // TRESTDataSetAdapter<M>.ApplyInserter e `not _RowKeyIsUngenerated`, que le
    // a chave da linha COLUNA A COLUNA. Com a chave composta pela metade ele
    // recusava - e recusava certo, porque nao havia por que perguntar. Sobre o
    // mesmo modelo e a mesma resposta: antes deste conserto GetCount = 0, com
    // ele GetCount = 1. REMEDIDO em 0f13601, RESTfulDriver Debug/Win32: com o
    // conserto no lugar a suite fecha 102/0 e
    // CompositeKey_TheGateOpensAndExactlyOneGetIsIssued exige GetCount = 1;
    // com ESTE trecho revertido em cima do mesmo commit a suite da 102/8 e a
    // mesma clausula devolve GetCount = 0.
    for LFor := 0 to LParamsArray.Count -1 do
    begin
      // ISSUE #315, O SEGUNDO CAST. Aqui a resposta e `Continue` e nao `Exit`
      // porque os elementos sao INDEPENDENTES: o laco de fora existe justamente
      // porque a resposta pode trazer um objeto por coluna, e um elemento
      // malformado nao diz nada sobre os irmaos dele. Pular o ruim e ler os
      // bons entrega mais chave do que abortar a resposta inteira.
      if not (LParamsArray.Items[LFor] is TJSONObject) then
        Continue;
      LValuesObject := TJSONObject(LParamsArray.Items[LFor]);
      for LPar := 0 to LValuesObject.Count -1 do
      begin
        with FResultParams.Add as TParam do
        begin
          Name := LValuesObject.Pairs[LPar].JsonString.Value;
          DataType := ftString;
          Value := LValuesObject.Pairs[LPar].JsonValue.Value;
        end;
      end;
    end;
  finally
    if LParamsObject <> nil then
      LParamsObject.Free;
    // Mostra no monitor a URI completa
    if FConnection.CommandMonitor <> nil then
    begin
      LURL := FConnection.FullURL;
      FConnection.CommandMonitor.Command('URI    : ' + LURL + sLineBreak +
                                         'M'#$00E9'todo : POST' + sLineBreak +
                                         'Result : ' + LResult + sLineBreak +
                                         'Json   : ' + LJSON, nil);
    end;
  end;
end;

function TSessionRestFul<M>.NextPacketList: TObjectList<M>;
begin
  if FFindWhereUsed then
    Result := _NextPacketMethod(FWhere, FOrderBy)
  else
    Result := _NextPacketMethod;
  if Result = nil then
    Exit;
  if Result.Count > 0 then
    Exit;
  FFetchingRecords := True;
end;

procedure TSessionRestFul<M>.NextPacketList(const AObjectList: TObjectList<M>);
var
  LObjectList: TObjectList<M>;
  LFor: Integer;
  LObject: TObject;
begin
  if FFindWhereUsed then
    LObjectList := _NextPacketMethod(FWhere, FOrderBy)
  else
    LObjectList := _NextPacketMethod;
  if LObjectList = nil then
    Exit;
  if LObjectList.Count = 0 then
    FFetchingRecords := True;
  try
    for LFor := 0 to LObjectList.Count -1 do
    begin
      LObject := TRttiSingleton.GetInstance.Clone(LObjectList.Items[LFor]);
      AObjectList.Add(LObject);
    end;
  finally
    LObjectList.Clear;
    LObjectList.Free;
  end;
end;

function TSessionRestFul<M>._NextPacketMethod(AWhere, AOrderBy: String): TObjectList<M>;
var
  LJSON: String;
  LSubResource: String;
  LURL: String;
begin
  if not FFindWhereRefreshUsed then
    FPageNext := FPageNext + FPageSize;

  LSubResource := '';
  if not FServerUse then
    LSubResource := ifThen(Length(FConnection.MethodGETNextPacketWhere) > 0, FConnection.MethodGETNextPacketWhere, FSubResource);
  try
    LJSON := FConnection.Execute(FResource,
                                 LSubResource,
                                 TRESTRequestMethodType.rtGET,
                                 procedure
                                 begin
                                   FConnection.AddQueryParam('$filter='  + _ParseOperator(AWhere));
                                   FConnection.AddQueryParam('$orderby=' + AOrderBy);
                                   FConnection.AddQueryParam('$top='     + IntToStr(FPageSize));
                                   FConnection.AddQueryParam('$skip='    + IntToStr(FPageNext));
                                 end);
    // Transforma o JSON recebido populando o objeto
    Result := TJanusJson.JsonToObjectList<M>(LJSON);
  finally
    // Mostra no monitor a URI completa
    if FConnection.CommandMonitor <> nil then
    begin
      LURL := FConnection.FullURL;
      if Length(LSubResource) > 0 then
        LURL := LURL + '/' + LSubResource;

      FConnection.CommandMonitor.Command('URI    : ' + LURL + sLineBreak +
                                         'M'#$00E9'todo : GET' + sLineBreak +
                                         'Json   : ' + LJSON, nil);
    end;
  end;
end;

function TSessionRestFul<M>._NextPacketMethod: TObjectList<M>;
var
  LJSON: String;
  LSubResource: String;
  LURL: String;
begin
  FPageNext := FPageNext + FPageSize;
  LSubResource := '';
  if not FServerUse then
    LSubResource := ifThen(Length(FConnection.MethodGETNextPacket) > 0, FConnection.MethodGETNextPacket, FSubResource);
  try
    LJSON := FConnection.Execute(FResource,
                                 LSubResource,
                                 TRESTRequestMethodType.rtGET,
                                 procedure
                                 begin
                                   FConnection.AddQueryParam('$top='  + IntToStr(FPageSize));
                                   FConnection.AddQueryParam('$skip=' + IntToStr(FPageNext));
                                 end);
    // Transforma o JSON recebido populando o objeto
    Result := TJanusJson.JsonToObjectList<M>(LJSON);
  finally
    // Mostra no monitor a URI completa
    if FConnection.CommandMonitor <> nil then
    begin
      LURL := FConnection.FullURL;
      if Length(LSubResource) > 0 then
        LURL := LURL + '/' + LSubResource;

      // Gera Lentidao se tiver campo TBlob no JSON
      FConnection.CommandMonitor.Command('URI    : ' + LURL + sLineBreak +
                                         'M'#$00E9'todo : GET' + sLineBreak +
                                         'Json   : ' + LJSON, nil);
    end;
  end;
end;

procedure TSessionRestFul<M>.Update(const AObjectList: TObjectList<M>);
var
  LJSON: String;
  LSubResource: String;
  LURL: String;
  LResult: String;
  LFor: Integer;
  LResource: String;
begin
  LJSON := '';
  LSubResource := ifThen(Length(FConnection.MethodPUT) > 0, FConnection.MethodPUT, FSubResource);
  LResource := FResource;
  try
    for LFor := 0 to AObjectList.Count -1 do
    begin
      LJSON := TJanusJson.ObjectToJsonString(AObjectList.Items[LFor]);
      LResult := FConnection.Execute(LResource,
                                     LSubResource,
                                     TRESTRequestMethodType.rtPUT,
                                     procedure
                                     begin
                                       FConnection.AddBodyParam(LJSON);
                                     end);
    end;
  finally
    // Mostra no monitor a URI completa
    if FConnection.CommandMonitor <> nil then
    begin
      LURL := FConnection.FullURL;
      FConnection.CommandMonitor.Command('URI    : ' + LURL + sLineBreak +
                                         'M'#$00E9'todo : PUT' + sLineBreak +
                                         'Result : ' + LResult + sLineBreak +
                                         'Json   : ' + LJSON, nil);
    end;
  end;
end;

procedure TSessionRestFul<M>.RefreshRecord(const AColumns: TParams);
var
  LObjectList: TObjectList<M>;
  LFindWhere: String;
  LWhereOld: String;
  LOrderByOld: String;
  LFor: Integer;
begin
  FFindWhereRefreshUsed := True;
  LWhereOld := FWhere;
  LOrderByOld := FOrderBy;
  try
    LFindWhere := '';
    for LFor := 0 to AColumns.Count -1 do
    begin
      LFindWhere := LFindWhere + AColumns[LFor].Name + '=' + AColumns[LFor].AsString;
      if LFor < AColumns.Count -1 then
        LFindWhere := LFindWhere + ' AND ';
    end;
    LObjectList := FindWhere(LFindWhere, '');
    if LObjectList = nil then
      Exit;
    try
      // NENHUMA LINHA E UMA RESPOSTA, e nao um erro - issue #297. Uma consulta
      // por chave primaria pode nao casar nada: a linha foi apagada por outro,
      // ou o servidor nao a devolve. First numa lista vazia levanta
      // EArgumentOutOfRange, e ate a #297 este caminho so era alcancado por
      // pedido EXPLICITO do consumidor; agora ele roda sozinho depois de todo
      // insert cujo grafo ficou defasado, de modo que a excecao passaria a
      // interromper a gravacao DEPOIS de o servidor ja ter escrito. Sem linha
      // nao ha o que reescrever, e o cliente fica como estava.
      if LObjectList.Count = 0 then
        Exit;
      FOwner.RefreshRecordInternal(LObjectList.First);
    finally
      LObjectList.Clear;
      LObjectList.Free;
    end;
  finally
    FWhere := LWhereOld;
    FOrderBy := LOrderByOld;
    FFindWhereRefreshUsed := False;
  end;
end;

{$IFDEF DRIVERRESTFUL}
function TSessionRestFul<M>.Find(const AMethodName: String;
  const AParams: array of String): TObjectList<M>;
var
  LJSONArray: TJSONArray;
  LFor: Integer;
  LJSON: String;
  LURL: String;
begin
  FFindWhereUsed := False;
  FFetchingRecords := False;
  LJSONArray := TJSONArray.Create;
  try
    try
      for LFor := Low(AParams) to High(AParams) do
        LJSONArray.Add(AParams[LFor]);

      LJSON := FConnection.Execute(FResource,
                                   AMethodName,
                                   TRESTRequestMethodType.rtGET,
                                   procedure
                                   begin
                                     FConnection.AddBodyParam(LJSONArray.ToJSON);
                                   end);
    except
      on E: Exception do
      begin
        raise Exception.Create(E.Message);
      end;
    end;
    // Transforma o JSON recebido populando o objeto
    Result := TJanusJson.JsonToObjectList<M>(LJSON);
  finally
    LJSONArray.Free;
    // Mostra no monitor a URI completa
    if FConnection.CommandMonitor <> nil then
    begin
      LURL := FConnection.FullURL;
      FConnection.CommandMonitor.Command('URI    : ' + LURL + sLineBreak +
                                         'M'#$00E9'todo : GET' + sLineBreak +
                                         'Json   : ' + LJSON, nil);
    end;
  end;
end;
{$ENDIF}

function TSessionRestFul<M>._ParseOperator(AParams: String): String;
const
  C_OPERATORMAP: array[0..9, 0..1] of String = ( (' = ', ' eq '),
                                                 (' <> ', ' ne '),
                                                 (' > ', ' gt '),
                                                 (' >= ', ' ge '),
                                                 (' < ', ' lt '),
                                                 (' <= ', ' le '),
                                                 (' + ', ' add '),
                                                 (' - ', ' sub '),
                                                 (' * ', ' mul '),
                                                 (' / ', ' div ') );
var
  LFor: Integer;
begin
  Result := AParams;
  for LFor := Low(C_OPERATORMAP) to High(C_OPERATORMAP) do
    Result := StringReplace(Result, C_OPERATORMAP[LFor, 0], C_OPERATORMAP[LFor, 1], [rfReplaceAll]);
end;

end.
