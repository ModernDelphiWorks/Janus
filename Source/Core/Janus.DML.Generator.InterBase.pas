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
  FluentSQL,
  FluentSQL.Interfaces;

type
  // Classe de banco de dados Interbase
  TDMLGeneratorInterbase = class(TDMLGeneratorFirebird)
  protected
    /// <summary> Issue #355. dbnInterbase EXISTS in TFluentSQLDriver and its
    ///  INTERBASE define is switched OFF in FluentSQL.inc, so it is as
    ///  unregistered as dbnADS: measured, naming it here raises
    ///  EFluentSQLDriverNotRegistered on all four statements.
    ///
    ///  Answers dbnFirebird, which is what this generator has been answering
    ///  since it was written - by INHERITANCE from TDMLGeneratorFirebird, not
    ///  by choice. Declared here so that the inheritance stops being the
    ///  reason. </summary>
    class function SerializationDialect: TFluentSQLDriver; override;
    /// Ver TDMLGeneratorAbstract.GuidLiteral: abstract de proposito,
    /// para que um dialeto novo nao herde em silencio o literal de outro.
    function GuidLiteral(const AGuid: TGUID): String; override;
  public
    constructor Create; override;
    destructor Destroy; override;
  end;

implementation

{ TDMLGeneratorInterbase }

class function TDMLGeneratorInterbase.SerializationDialect: TFluentSQLDriver;
begin
  Result := dbnFirebird;
end;

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
///  O que ESTA medido e' o lado desta casa: MetaDbDiff.Metadata.Extract.pas:442
///  PRETENDE CHAR(n) para dnInterbase, ou seja coluna de texto guardando os 38
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
