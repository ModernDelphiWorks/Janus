{
  ------------------------------------------------------------------------------
  Janus
  Modern Object-Relational Mapping (ORM) framework for Delphi.

  SPDX-License-Identifier: MIT
  Copyright (c) 2016-2026 Isaque Pinheiro

  Licensed under the MIT License.
  See the LICENSE file in the project root for full license information.
  ------------------------------------------------------------------------------
}

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Test.Janus.Command.UnregisteredDriver;

interface

uses
  SysUtils,
  DUnitX.TestFramework,
  DataEngine.FactoryInterfaces,
  Janus.Driver.Register,
  Janus.Command.Selecter,
  Janus.Command.Inserter,
  Janus.Model.Client,
  // TFakeConnection
  Test.Janus.DML.Generator.SQLite;

type
  [TestFixture]
  TTestCommandUnregisteredDriver = class
  private
    // dnDB2 e o alvo por construcao: nao existe Janus.DML.Generator.DB2.pas no
    // Source, entao nenhum projeto consegue registra-lo por engano e o teste
    // nao fica refem de quem linkou o que.
    const CUnregistered = dnDB2;
    // Trecho ASCII da mensagem de Janus.Driver.Register.pas (o texto completo
    // tem acento, e este arquivo e ASCII puro por convencao do repo).
    const CCleanMessagePart =
      ' registrado, adicione a unit "Janus.DML.Generator.???.pas"';
  public
    [Test]
    procedure TestSelecter_UnregisteredDriver_RaisesTheRegistryMessage;
    [Test]
    procedure TestInserter_UnregisteredDriver_RaisesTheRegistryMessage;
    [Test]
    procedure TestGetDriver_UnregisteredDriver_RaisesTheRegistryMessage;
  end;

implementation

procedure TTestCommandUnregisteredDriver.TestGetDriver_UnregisteredDriver_RaisesTheRegistryMessage;
var
  LClass: String;
  LMessage: String;
begin
  // Linha de base: o registry sozinho SEMPRE deu a mensagem limpa. Este teste
  // existe para separar as duas metades -- se ele passar e o do TCommandSelecter
  // falhar, o defeito esta no comando, nao no registry.
  LClass := '';
  LMessage := '';
  try
    TDriverRegister.GetDriver(CUnregistered);
  except
    on E: Exception do
    begin
      LClass := E.ClassName;
      LMessage := E.Message;
    end;
  end;
  Assert.AreNotEqual('EAccessViolation', LClass,
    'O registry deve recusar o driver com mensagem, nao com AV');
  Assert.Contains(LMessage, CCleanMessagePart,
    'A mensagem do registry mudou: ' + LMessage);
end;

procedure TTestCommandUnregisteredDriver.TestSelecter_UnregisteredDriver_RaisesTheRegistryMessage;
var
  LClient: Tclient;
  LClass: String;
  LMessage: String;
begin
  // TDMLCommandAbstract.Create levanta antes de FParams := TParams.Create. O
  // Delphi chama Destroy do objeto meio-construido, e sem a guarda de nil o
  // FParams.Clear substituia a mensagem do registry por um EAccessViolation --
  // o usuario via "Read of address 00000008" em vez de "adicione a unit".
  LClient := Tclient.Create;
  try
    LClass := '';
    LMessage := '';
    try
      TCommandSelecter.Create(TFakeConnection.Create(CUnregistered),
                              CUnregistered, LClient).Free;
    except
      on E: Exception do
      begin
        LClass := E.ClassName;
        LMessage := E.Message;
      end;
    end;
    Assert.AreNotEqual('EAccessViolation', LClass,
      'Um driver nao registrado deve chegar ao usuario como mensagem, nao ' +
      'como Access Violation');
    Assert.Contains(LMessage, CCleanMessagePart,
      'A excecao que chegou nao foi a do registry: [' + LClass + '] ' + LMessage);
  finally
    LClient.Free;
  end;
end;

procedure TTestCommandUnregisteredDriver.TestInserter_UnregisteredDriver_RaisesTheRegistryMessage;
var
  LClient: Tclient;
  LClass: String;
  LMessage: String;
begin
  // O mesmo Destroy serve todos os comandos; o Inserter confirma que a guarda
  // esta na base e nao numa especializacao.
  LClient := Tclient.Create;
  try
    LClass := '';
    LMessage := '';
    try
      TCommandInserter.Create(TFakeConnection.Create(CUnregistered),
                              CUnregistered, LClient).Free;
    except
      on E: Exception do
      begin
        LClass := E.ClassName;
        LMessage := E.Message;
      end;
    end;
    Assert.AreNotEqual('EAccessViolation', LClass,
      'O Inserter tambem deve entregar a mensagem do registry');
    Assert.Contains(LMessage, CCleanMessagePart,
      'A excecao que chegou nao foi a do registry: [' + LClass + '] ' + LMessage);
  finally
    LClient.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestCommandUnregisteredDriver);

end.
