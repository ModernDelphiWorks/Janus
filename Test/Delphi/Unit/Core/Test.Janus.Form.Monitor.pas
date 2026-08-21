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

{ THE SQL MONITOR - issue #341, Level 2.

  Janus.Form.Monitor is named by 38 files under Examples/ and was compiled by
  none of the seven test projects. It is a VCL TForm with a .dfm, so the first
  question was whether it can be linked into a CONSOLE test project at all.

  MEASURED: IT CAN. Linking it into Janus.Tests.Units builds clean and the
  suite stays green - the unit guards its whole body with an IF DEFINED(DCC)
  AND DEFINED(MSWINDOWS) directive, and the .dfm travels in as a resource like
  any other. What could NOT be taken for granted is the FORM
  ITSELF: a console application never calls Application.Initialize and never
  runs a message loop, so whether TCommandMonitor.Create(nil) can stream its
  .dfm here was the actual open question. Monitor_TheSingletonBuildsItsForm is
  the answer, measured rather than assumed - and it is also the only clause
  that reaches the .dfm, which is the half of this unit no compiler checks:
  a control renamed or deleted in the .dfm raises EReadError at construction
  and NOTHING else in this repository would run that constructor.

  The behavioural clause is Command: the ICommandMonitor implementation every
  DataEngine connection calls on each statement. It appends the SQL to the
  memo, and the parameter dump under it, which is the whole point of the form. }

unit Test.Janus.Form.Monitor;

interface

uses
  DB,
  Classes,
  SysUtils,
  DUnitX.TestFramework,
  DataEngine.FactoryInterfaces,
  /// The unit under test.
  Janus.Form.Monitor;

type
  [TestFixture]
  TTestJanusFormMonitor = class
  private
    function Memo: TStrings;
    procedure ClearMemo;
  public
    [Setup]
    procedure Setup;

    [Test]
    procedure Monitor_TheSingletonBuildsItsForm;
    [Test]
    procedure Monitor_GetInstanceAnswersTheSameFormEveryTime;
    [Test]
    procedure Command_TheSqlReachesTheMemo;
    [Test]
    procedure Command_TheParametersAreDumpedUnderTheSql;
    [Test]
    procedure Command_NilParametersAreNotAFailure;
  end;

implementation

uses
  StdCtrls,
  ComCtrls;

{ TTestJanusFormMonitor }

{ The memo is a published field of the form, so it is reachable through the
  concrete class - and the concrete class is reachable from the interface,
  which is how the form under test is observed without showing it. }
function TTestJanusFormMonitor.Memo: TStrings;
begin
  Result := TCommandMonitor(TCommandMonitor.GetInstance as TObject).MemoSQL.Lines;
end;

procedure TTestJanusFormMonitor.ClearMemo;
begin
  Memo.Clear;
end;

procedure TTestJanusFormMonitor.Setup;
begin
  // The monitor is a class-level singleton shared by every test in this
  // process; each clause starts from an empty memo or it would read whatever
  // the previous one wrote.
  ClearMemo;
end;

{ THE .dfm. A console test project never initialises the VCL Application, and
  the form is never shown - but it IS streamed, and streaming is where a .dfm
  that no longer matches its class raises EReadError. Nothing else in the
  repository constructs this form. }
procedure TTestJanusFormMonitor.Monitor_TheSingletonBuildsItsForm;
var
  LMonitor: ICommandMonitor;
begin
  LMonitor := TCommandMonitor.GetInstance;

  Assert.IsNotNull(LMonitor,
    'GetInstance must build the monitor form; a nil here means the singleton ' +
    'never constructed');
  Assert.IsNotNull(TCommandMonitor(LMonitor as TObject).MemoSQL,
    'MemoSQL must have been streamed in from Janus.Form.Monitor.dfm - a nil ' +
    'control is what a .dfm that lost the component looks like');
  Assert.IsNotNull(TCommandMonitor(LMonitor as TObject).Button1,
    'and so must Button1, whose OnClick clears the log');
end;

procedure TTestJanusFormMonitor.Monitor_GetInstanceAnswersTheSameFormEveryTime;
var
  LFirst: ICommandMonitor;
  LSecond: ICommandMonitor;
begin
  LFirst := TCommandMonitor.GetInstance;
  LSecond := TCommandMonitor.GetInstance;

  Assert.AreSame(LFirst as TObject, LSecond as TObject,
    'The monitor is a singleton: every connection that asks for it must get ' +
    'the SAME window, or each one opens its own and the log fragments');
end;

{ The one thing this form exists to do. TCommandMonitor.Command is what a
  DataEngine connection calls for every statement it executes. }
procedure TTestJanusFormMonitor.Command_TheSqlReachesTheMemo;
const
  CSql = 'SELECT client.client_id FROM client WHERE client.client_id = 7';
begin
  TCommandMonitor.GetInstance.Command(CSql, nil);

  Assert.IsTrue(Pos(CSql, Memo.Text) > 0,
    'The statement handed to the monitor must appear in the log verbatim. ' +
    'Log was: ' + Memo.Text);
end;

procedure TTestJanusFormMonitor.Command_TheParametersAreDumpedUnderTheSql;
var
  LParams: TParams;
begin
  LParams := TParams.Create(nil);
  try
    LParams.CreateParam(ftInteger, 'CLIENT_ID', ptInput).AsInteger := 42;
    LParams.CreateParam(ftString, 'CLIENT_NAME', ptInput).AsString := 'Ada';

    TCommandMonitor.GetInstance.Command('UPDATE client SET ...', LParams);

    Assert.IsTrue(Pos('CLIENT_ID', Memo.Text) > 0,
      'Every parameter NAME must reach the log - reading a parameterised ' +
      'statement without its values is the thing this window exists to fix. ' +
      'Log was: ' + Memo.Text);
    Assert.IsTrue(Pos('42', Memo.Text) > 0,
      'and its VALUE. Log was: ' + Memo.Text);
    Assert.IsTrue(Pos('Ada', Memo.Text) > 0,
      'for the string parameter too. Log was: ' + Memo.Text);
    Assert.IsTrue(Pos('ftInteger', Memo.Text) > 0,
      'and its declared TFieldType, which is what tells a wrong binding from ' +
      'a wrong value. Log was: ' + Memo.Text);
  finally
    LParams.Free;
  end;
end;

{ Not decoration: Command takes AParams as a plain pointer and dereferences it
  in a loop. Every statement executed without parameters arrives here as nil. }
procedure TTestJanusFormMonitor.Command_NilParametersAreNotAFailure;
begin
  Assert.WillNotRaise(
    procedure
    begin
      TCommandMonitor.GetInstance.Command('COMMIT', nil);
    end,
    Exception,
    'A statement with no parameters must log, not raise');

  Assert.IsTrue(Pos('COMMIT', Memo.Text) > 0,
    'and it must still reach the log. Log was: ' + Memo.Text);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestJanusFormMonitor);

end.
