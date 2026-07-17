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

{ @abstract(Thread-safety regression for the RTTI singleton and lazy-mapping
  explorer caches.)

  Reproduces the residual concurrency fault reported under high-volume, multi
  threaded reads (Horse worker pool binding the same entities per row): the
  RTL's TRttiContext.GetType funnels into a process-global, refcounted RTTI
  pool whose per-type member arrays (GetProperties/GetFields) are populated
  lazily and without locking. Two worker threads racing the first population of
  the same TRttiInstanceType corrupt/half-build those arrays -> intermittent
  access violations. The same shape exists in TLazyMappingExplorer's
  ContainsKey/Add cache pair.

  Before the fix (unguarded FContext.GetType per row + unguarded cache pairs)
  this fixture is expected to raise an AV/EListError under load. After the fix
  (class-keyed TRttiType cache resolved and member-warmed once under a lock;
  TLazyMappingExplorer cache serialized) it must stay green across >= 50 rounds
  of concurrent hammering.

  @created(16 Jul 2026)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
}

unit Test.Janus.RTTI.Singleton.Concurrency;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestRttiSingletonConcurrency = class
  public
    [Test]
    procedure ConcurrentGetRttiType_NoAccessViolation;
    [Test]
    procedure ConcurrentGetLazyFields_NoAccessViolation;
  end;

implementation

uses
  System.Classes,
  System.SysUtils,
  System.SyncObjs,
  Rtti,
  Janus.Objects.Utils,
  Janus.Mapping.Lazy,
  Model.Atendimento,
  Model.Exame;

type
  TWorkerProc = reference to procedure;

  { A thread that waits on a shared start gate so every worker is released at
    the same instant (maximizing contention on the first-population window),
    then runs the supplied work AIterations times. Any exception escaping
    Execute is captured by TThread.FatalException for the driver to inspect. }
  TRttiHammerThread = class(TThread)
  private
    FStartGate: TEvent;
    FIterations: Integer;
    FWork: TWorkerProc;
  protected
    procedure Execute; override;
  public
    constructor Create(const AStartGate: TEvent; const AIterations: Integer;
      const AWork: TWorkerProc);
  end;

constructor TRttiHammerThread.Create(const AStartGate: TEvent;
  const AIterations: Integer; const AWork: TWorkerProc);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FStartGate := AStartGate;
  FIterations := AIterations;
  FWork := AWork;
end;

procedure TRttiHammerThread.Execute;
var
  I: Integer;
begin
  FStartGate.WaitFor(INFINITE);
  for I := 1 to FIterations do
    FWork();
end;

procedure RunConcurrent(const AWork: TWorkerProc);
const
  THREADS = 16;
  ITERATIONS = 200;
  ROUNDS = 50;
var
  LRound: Integer;
  I: Integer;
  LGate: TEvent;
  LThreads: array of TRttiHammerThread;
  LError: string;
begin
  for LRound := 1 to ROUNDS do
  begin
    LError := '';
    LGate := TEvent.Create(nil, True, False, '');
    try
      SetLength(LThreads, THREADS);
      for I := 0 to THREADS - 1 do
        LThreads[I] := TRttiHammerThread.Create(LGate, ITERATIONS, AWork);
      for I := 0 to THREADS - 1 do
        LThreads[I].Start;
      // Release all workers simultaneously.
      LGate.SetEvent;
      for I := 0 to THREADS - 1 do
      begin
        LThreads[I].WaitFor;
        if (LError = '') and Assigned(LThreads[I].FatalException) and
           (LThreads[I].FatalException is Exception) then
          LError := Format('round %d / thread %d: %s',
            [LRound, I, Exception(LThreads[I].FatalException).Message]);
      end;
      for I := 0 to THREADS - 1 do
        LThreads[I].Free;
      Assert.AreEqual('', LError,
        'Concurrent RTTI access must not raise. First failure: ' + LError);
    finally
      LGate.Free;
    end;
  end;
end;

{ TTestRttiSingletonConcurrency }

procedure TTestRttiSingletonConcurrency.ConcurrentGetRttiType_NoAccessViolation;
begin
  RunConcurrent(
    procedure
    var
      LType: TRttiType;
    begin
      LType := RttiSingleton.GetRttiType(TAtendimento);
      if LType <> nil then
      begin
        // Touch the lazily-populated member arrays: this is where the RTL
        // race manifests when the type is resolved off a shared context.
        LType.GetProperties;
        LType.GetFields;
        LType.GetMethods;
      end;
    end);
end;

procedure TTestRttiSingletonConcurrency.ConcurrentGetLazyFields_NoAccessViolation;
begin
  RunConcurrent(
    procedure
    var
      LFields: TObject;
    begin
      // TExame carries a Lazy<TProcedimento> field, so GetLazyFields exercises
      // the ContainsKey/populate/Add cache path under contention.
      LFields := LazyMappingExplorer.GetLazyFields(TExame);
      Assert.IsNotNull(LFields);
    end);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRttiSingletonConcurrency);

end.
