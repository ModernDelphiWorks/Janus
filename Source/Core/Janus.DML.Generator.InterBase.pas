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
}

unit Janus.DML.Generator.InterBase;

interface

uses
  SysUtils,
  StrUtils,
  Rtti,
  Janus.DML.Generator.Firebird,
  Janus.Driver.Register,
  Janus.DML.Interfaces,
  DataEngine.FactoryInterfaces,
  FluentSQL;

type
  // Classe de banco de dados Interbase
  TDMLGeneratorInterbase = class(TDMLGeneratorFirebird)
  protected
    /// Ver TDMLGeneratorAbstract.GuidLiteral: abstract de proposito,
    /// para que um dialeto novo nao herde em silencio o literal de outro.
    function GuidLiteral(const AGuid: TGUID): String; override;
  public
    constructor Create; override;
    destructor Destroy; override;
  end;

implementation

{ TDMLGeneratorInterbase }

constructor TDMLGeneratorInterbase.Create;
begin
  inherited;
  FDateFormat := 'MM/dd/yyyy';
  FTimeFormat := 'HH:MM:SS';
end;

destructor TDMLGeneratorInterbase.Destroy;
begin

  inherited;
end;

/// <summary> NAO MEDIDO CONTRA DOCUMENTACAO OFICIAL. docwiki.embarcadero.com
///  responde HTTP 403 a fetch programatico em todos os caminhos tentados
///  (Data_Types, Language Reference Guide, Function_List e os dois caminhos do
///  LangRef.pdf), e ausencia em busca nao e' prova. Nao herda do Firebird por
///  parentesco historico: enquanto a doc nao for lida, a afirmacao "e' igual ao
///  Firebird" seria invencao.
///  O que ESTA medido e' o lado desta casa: MetaDbDiff.Metadata.Extract.pas:432
///  emite CHAR(n) para dnInterbase, ou seja a coluna guarda o texto de 38 que o
///  INSERT gravou. Por isso o literal conservador - a mesma forma canonica dos
///  demais - e' o certo aqui por construcao, independente do que a doc do
///  InterBase disser sobre funcoes de UUID.
///  Sem excecao de proposito: hoje este dialeto devolve '1 = 0' em silencio, e
///  qualquer literal ja e' melhora. Para medir de verdade: abrir
///  Function_List_(Language_Reference_Guide) num navegador. </summary>
function TDMLGeneratorInterbase.GuidLiteral(const AGuid: TGUID): String;
begin
  Result := CanonicalGuidLiteral(AGuid);
end;

initialization
  TDriverRegister.RegisterDriver(dnInterbase,
    function: IDMLGeneratorCommand
    begin
      Result := TDMLGeneratorInterbase.Create;
    end);

end.
