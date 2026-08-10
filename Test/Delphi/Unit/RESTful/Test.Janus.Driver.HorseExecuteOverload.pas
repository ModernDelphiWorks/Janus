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

{ @abstract(Janus Framework - the one-resource Execute on the HORSE chain, and
  the ARGUMENT ORDER it hands down.)

  WHY THIS EXISTS AND WHY THE WiRL FIXTURE WAS NOT ENOUGH

  #211 was fixed in a base class shared by all six driver families: the
  one-resource Execute is defined as the pair (resource, ''). The fixture that
  proved it, Test.Janus.Driver.WiRLExecuteOverload, cannot see the ORDER of
  those two arguments - and a review mutation proved it, staying green at 19/19
  while the base class passed ('', AResource) instead of (AResource, '').

  The reason is WiRL-specific: TRESTClientWiRL builds its path with
  TWiRLURL.CombinePath, which DISCARDS empty segments, so CombinePath([R,''])
  and CombinePath(['',R]) are the same string. No assertion over a WiRL path,
  however strict, can tell the two apart.

  In Horse the order IS observable. TRESTClientHorse.Execute assigns the two
  arguments to two DIFFERENT properties - AResource to FRESTRequest.Resource
  and ASubResource to FRESTRequest.ResourceSuffix - and this project,
  Janus.Tests.RESTfulDriver, already compiles that whole chain. Horse is also
  the most used driver, and this PR is what changes it from EAbstractError to
  actually issuing a request, so the new behaviour needs its own witness.

  THE SEAM THAT MAKES ORDER UNDENIABLE

  Not the URL. A URL is one string, and any assertion over it depends on how
  the transport joins and trims segments - which is exactly the trap above.

  TJanusClient.OnErrorCommand receives AResource and ASubResource as SEPARATE,
  NAMED, POSITIONAL parameters, and TRESTClientHorse.DoGET raises it with the
  very values it was called with. Stopping the stub server makes the request
  fail on purpose, the event fires, and the two slots are read back
  INDIVIDUALLY. A swap cannot survive that: the marker turns up in the other
  slot, and the failure message names which.

  TwoResource_FillsBothSlotsInOrder is the premise for it - it proves the seam
  reports the two slots faithfully when BOTH are loaded with distinct markers.
  Without that, a seam that always reported (x, '') would make the
  one-resource assertion vacuous.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Driver.HorseExecuteOverload;

interface

{$IFNDEF DRIVERRESTFUL}
  {$MESSAGE FATAL 'This unit belongs to Janus.Tests.RESTfulDriver, whose .dproj carries DRIVERRESTFUL. If this fires, the configuration this suite exists to protect has been switched off.'}
{$ENDIF}

uses
  Classes,
  SysUtils,
  SyncObjs,
  Generics.Collections,
  DUnitX.TestFramework,
  IdContext,
  IdCustomHTTPServer,
  IdHTTPServer,
  IdSocketHandle,
  Janus.Client.Base,
  Janus.Client,
  Janus.Client.Horse,
  Janus.Client.RestDriver.Horse,
  Janus.Client.Methods,
  Janus.RestFactory.Interfaces;

type
  /// <summary> Servidor minimo de emprestimo. Responde qualquer documento com
  ///   uma lista vazia e guarda, EM ORDEM, o caminho de cada requisicao que
  ///   chegou. Sabe parar, o que e como as asercoes de ordem forcam a falha de
  ///   proposito. Nada sai da maquina. </summary>
  TStubHorsePathServer = class
  private
    FServer: TIdHTTPServer;
    FLock: TCriticalSection;
    FPaths: TList<string>;
    FPort: Integer;
    procedure DoCommandGet(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
  public
    constructor Create;
    destructor Destroy; override;
    /// <summary> Desliga o listener. A porta passa a recusar conexao, entao a
    ///   requisicao seguinte falha e OnErrorCommand roda. </summary>
    procedure Stop;
    function Count: Integer;
    function Path(const AIndex: Integer): string;
    property Port: Integer read FPort;
  end;

  [TestFixture]
  TTestDriverHorseExecuteOverload = class
  private
    FStub: TStubHorsePathServer;
    FClient: TRESTClientHorse;
    /// As duas vagas, lidas SEPARADAMENTE do evento de erro.
    FSeenResource: string;
    FSeenSubResource: string;
    FErrorFired: Boolean;
    procedure OnErrorCommand(const AURLBase, AResource, ASubResource,
      ARequestMethod, AMessage: String; const AResponseCode: Integer);
    /// <summary> Arma o seam: para o servidor e liga o evento, de modo que a
    ///   proxima chamada falhe e entregue as duas vagas. </summary>
    procedure ArmTheFailingSeam;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// The premise for every path assertion: distinct markers, and a recorder
    /// that sees them.
    [Test]
    procedure Premise_TheMarkersAreDistinctAndTheRecorderSeesThem;

    /// The premise for every SLOT assertion: with both slots loaded, the error
    /// seam must report each one where it belongs. If it did not, the
    /// one-resource assertion below would be vacuous.
    [Test]
    procedure Premise_TwoResource_FillsBothSlotsInOrder;

    /// #211 on the most used driver. Before this PR the line raised
    /// EAbstractError and nothing left the process.
    [Test]
    procedure OneResource_ThroughTheConnection_DoesNotDieAbstract;

    /// THE ONE THE WiRL FIXTURE COULD NOT MAKE. The resource must land in the
    /// RESOURCE slot and the sub-resource slot must stay empty - read as two
    /// separate values, not as one joined path.
    [Test]
    procedure OneResource_FillsTheResourceSlotAndLeavesTheSubResourceEmpty;

    /// And the path it produces is the one an empty sub-resource produces,
    /// character for character.
    [Test]
    procedure OneResource_LandsOnTheSamePathAsAnEmptySubResource;

    /// The same hole one layer down: TRESTDriver, called directly, with the
    /// same ordered-slot assertion.
    [Test]
    procedure OneResource_OnTheDriverItself_FillsTheResourceSlot;

    /// The optional params procedure must still be run.
    [Test]
    procedure OneResource_StillRunsTheParamsProcedure;
  end;

implementation

const
  cAPI_CONTEXT = 'mk-apicontext';
  cRESOURCE    = 'horse-mk-resource';
  cSUBRESOURCE = 'horse-mk-subresource';

{ TStubHorsePathServer }

constructor TStubHorsePathServer.Create;
var
  LBinding: TIdSocketHandle;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FPaths := TList<string>.Create;
  FPort := 9730 + Random(60);
  FServer := TIdHTTPServer.Create(nil);
  FServer.OnCommandGet := DoCommandGet;
  FServer.OnCommandOther := DoCommandGet;
  LBinding := FServer.Bindings.Add;
  LBinding.IP := '127.0.0.1';
  LBinding.Port := FPort;
  FServer.Active := True;
end;

destructor TStubHorsePathServer.Destroy;
begin
  Stop;
  FServer.Free;
  FPaths.Free;
  FLock.Free;
  inherited;
end;

procedure TStubHorsePathServer.Stop;
begin
  if FServer.Active then
    FServer.Active := False;
end;

procedure TStubHorsePathServer.DoCommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
begin
  FLock.Acquire;
  try
    FPaths.Add(ARequestInfo.Document);
  finally
    FLock.Release;
  end;
  AResponseInfo.ResponseNo := 200;
  AResponseInfo.ContentType := 'application/json';
  AResponseInfo.ContentText := '[]';
end;

function TStubHorsePathServer.Count: Integer;
begin
  FLock.Acquire;
  try
    Result := FPaths.Count;
  finally
    FLock.Release;
  end;
end;

function TStubHorsePathServer.Path(const AIndex: Integer): string;
begin
  FLock.Acquire;
  try
    if (AIndex < 0) or (AIndex >= FPaths.Count) then
      Result := ''
    else
      Result := FPaths[AIndex];
  finally
    FLock.Release;
  end;
end;

{ TTestDriverHorseExecuteOverload }

procedure TTestDriverHorseExecuteOverload.Setup;
begin
  FSeenResource := '<never called>';
  FSeenSubResource := '<never called>';
  FErrorFired := False;
  FStub := TStubHorsePathServer.Create;
  FClient := TRESTClientHorse.Create(nil);
  FClient.Host := '127.0.0.1';
  FClient.Port := FStub.Port;
  FClient.APIContext := cAPI_CONTEXT;
end;

procedure TTestDriverHorseExecuteOverload.TearDown;
begin
  FreeAndNil(FClient);
  FreeAndNil(FStub);
end;

procedure TTestDriverHorseExecuteOverload.OnErrorCommand(const AURLBase,
  AResource, ASubResource, ARequestMethod, AMessage: String;
  const AResponseCode: Integer);
begin
  FErrorFired := True;
  FSeenResource := AResource;
  FSeenSubResource := ASubResource;
end;

procedure TTestDriverHorseExecuteOverload.ArmTheFailingSeam;
begin
  /// <summary> A porta passa a recusar conexao: TRESTRequest.Execute levanta,
  ///   e TRESTClientHorse.DoGET chama FErrorCommand com os MESMOS dois
  ///   argumentos que recebeu - cada um na sua vaga nomeada. </summary>
  FStub.Stop;
  FClient.OnErrorCommand := OnErrorCommand;
end;

procedure TTestDriverHorseExecuteOverload.Premise_TheMarkersAreDistinctAndTheRecorderSeesThem;
var
  LConnection: IRESTConnection;
begin
  Assert.AreNotEqual(cRESOURCE, cSUBRESOURCE,
    'the two markers MUST differ; with one marker a swapped pair is ' +
    'undetectable and this whole fixture is decorative');
  LConnection := FClient.AsConnection;
  LConnection.Execute(cRESOURCE, cSUBRESOURCE, TRESTRequestMethodType.rtGET);
  Assert.AreEqual(1, FStub.Count,
    'the request must have reached the stub - with nothing recorded every ' +
    'path assertion here would be comparing empty strings');
  Assert.IsTrue(Pos(cRESOURCE, FStub.Path(0)) > 0,
    'the resource marker must appear in the path. Found: ' + FStub.Path(0));
  Assert.IsTrue(Pos(cSUBRESOURCE, FStub.Path(0)) > 0,
    'and so must the sub-resource marker. Found: ' + FStub.Path(0));
end;

procedure TTestDriverHorseExecuteOverload.Premise_TwoResource_FillsBothSlotsInOrder;
var
  LConnection: IRESTConnection;
begin
  ArmTheFailingSeam;
  LConnection := FClient.AsConnection;
  LConnection.Execute(cRESOURCE, cSUBRESOURCE, TRESTRequestMethodType.rtGET);
  Assert.IsTrue(FErrorFired,
    'the request had to FAIL for the seam to report anything - the stub was ' +
    'stopped, so a success here means something else answered on that port ' +
    'and this fixture measured nothing');
  Assert.AreEqual(cRESOURCE, FSeenResource,
    'with BOTH slots loaded, the first argument must be reported as the ' +
    'RESOURCE. This is the premise that makes the one-resource assertion ' +
    'meaningful: a seam that always answered ('' x '', '''') would make it vacuous');
  Assert.AreEqual(cSUBRESOURCE, FSeenSubResource,
    'and the second argument as the SUB-RESOURCE');
end;

procedure TTestDriverHorseExecuteOverload.OneResource_ThroughTheConnection_DoesNotDieAbstract;
var
  LConnection: IRESTConnection;
begin
  LConnection := FClient.AsConnection;
  LConnection.Execute(cRESOURCE, TRESTRequestMethodType.rtGET);
  Assert.AreEqual(1, FStub.Count,
    '#211 on the Horse chain: the one-resource Execute was `virtual; abstract` ' +
    'in TRESTFactoryConnection and TRESTFactoryHorse did not override it, so ' +
    'this line raised EAbstractError and no request ever left. This is the ' +
    'behaviour the fix introduces on the most used driver');
  Assert.IsTrue(Pos(cRESOURCE, FStub.Path(0)) > 0,
    'and the request must carry the resource. Found: ' + FStub.Path(0));
end;

procedure TTestDriverHorseExecuteOverload.OneResource_FillsTheResourceSlotAndLeavesTheSubResourceEmpty;
var
  LConnection: IRESTConnection;
begin
  ArmTheFailingSeam;
  LConnection := FClient.AsConnection;
  LConnection.Execute(cRESOURCE, TRESTRequestMethodType.rtGET);
  Assert.IsTrue(FErrorFired,
    'the request had to FAIL for the seam to report the two slots; it did not');
  Assert.AreEqual(cRESOURCE, FSeenResource,
    'ONE resource is the pair (resource, ''''). "' + cRESOURCE + '" must land ' +
    'in the RESOURCE slot - the one TRESTClientHorse.Execute assigns to ' +
    'FRESTRequest.Resource. Reported instead: "' + FSeenResource + '"');
  Assert.AreEqual('', FSeenSubResource,
    'and the SUB-RESOURCE slot - FRESTRequest.ResourceSuffix - must stay ' +
    'EMPTY. Reported instead: "' + FSeenSubResource + '"');
  Assert.AreNotEqual(cRESOURCE, FSeenSubResource,
    'the swap stated as such: passing ('''', AResource) instead of ' +
    '(AResource, '''') puts the resource in the SUFFIX. It is invisible in a ' +
    'WiRL path, because TWiRLURL.CombinePath drops empty segments, and it is ' +
    'NOT invisible here - Horse keeps the two in different properties');
end;

procedure TTestDriverHorseExecuteOverload.OneResource_LandsOnTheSamePathAsAnEmptySubResource;
var
  LConnection: IRESTConnection;
begin
  LConnection := FClient.AsConnection;
  LConnection.Execute(cRESOURCE, '', TRESTRequestMethodType.rtGET);
  LConnection.Execute(cRESOURCE, TRESTRequestMethodType.rtGET);
  Assert.AreEqual(2, FStub.Count, 'both calls must have travelled');
  Assert.AreEqual(FStub.Path(0), FStub.Path(1),
    'the two-resource call with an empty sub-resource reached "' +
    FStub.Path(0) + '" and the one-resource call reached "' + FStub.Path(1) +
    '" - they must be the same path, character for character');
end;

procedure TTestDriverHorseExecuteOverload.OneResource_OnTheDriverItself_FillsTheResourceSlot;
var
  LDriver: TRESTDriverHorse;
begin
  /// <summary> A conexao passa pela FABRICA. TRESTDriver tinha a MESMA
  ///   sobrecarga abstrata, e so a chamada direta ao driver a exercita. </summary>
  ArmTheFailingSeam;
  LDriver := TRESTDriverHorse.Create(FClient);
  try
    LDriver.Execute(cRESOURCE, TRESTRequestMethodType.rtGET);
    Assert.IsTrue(FErrorFired,
      'the request had to FAIL for the seam to report the two slots');
    Assert.AreEqual(cRESOURCE, FSeenResource,
      'TRESTDriver.Execute(AResource) must hand the resource down in the ' +
      'RESOURCE slot. Reported instead: "' + FSeenResource + '"');
    Assert.AreEqual('', FSeenSubResource,
      'and leave the sub-resource slot empty. Reported instead: "' +
      FSeenSubResource + '"');
  finally
    LDriver.Free;
  end;
end;

procedure TTestDriverHorseExecuteOverload.OneResource_StillRunsTheParamsProcedure;
var
  LConnection: IRESTConnection;
  LRan: Boolean;
begin
  LRan := False;
  LConnection := FClient.AsConnection;
  LConnection.Execute(cRESOURCE, TRESTRequestMethodType.rtGET,
    procedure
    begin
      LRan := True;
    end);
  Assert.IsTrue(LRan,
    'the optional AParams procedure must be forwarded down to the client, ' +
    'which runs it before the URL is assembled. An implementation that ' +
    'dropped the third argument would reach the right path and still be wrong');
  Assert.AreEqual(1, FStub.Count, 'and the request must still have travelled');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDriverHorseExecuteOverload);

end.
