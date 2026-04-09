unit Janus.Dependencies.Interfaces;

interface

type
  TLog = procedure (ALog: String) of object;

  IJanusDependenciesCommand = interface
    ['{0286EC94-9BE4-416D-8F9D-6483ED416B37}']
    procedure Execute;
  end;

  IJanusDependenciesExecutor = interface
    ['{683A300D-0BA6-4B8A-8F8C-43B85304CE93}']
    function AddCommand(ACommand: IJanusDependenciesCommand): IJanusDependenciesExecutor;
    function Execute: IJanusDependenciesExecutor;
  end;

function NewExecutor: IJanusDependenciesExecutor;

function CommandFluentSQL(ATag: String; ALog: TLog): IJanusDependenciesCommand;
function CommandMetaDbDiff(ATag: String; ALog: TLog): IJanusDependenciesCommand;
function CommandDataEngine(ATag: String; ALog: TLog): IJanusDependenciesCommand;
function CommandJsonFlow(ATag: String; ALog: TLog): IJanusDependenciesCommand;

implementation

uses
  Janus.Dependencies.Executor,
  Janus.Dependencies.Command.FluentSQL,
  Janus.Dependencies.Command.MetaDbDiff,
  Janus.Dependencies.Command.DataEngine,
  Janus.Dependencies.Command.JsonFlow;

function NewExecutor: IJanusDependenciesExecutor;
begin
  result := TJanusDependenciesExecutor.New;
end;

function CommandFluentSQL(ATag: String; ALog: TLog): IJanusDependenciesCommand;
begin
  result := TJanusDependenciesCommandFluentSQL.New(ATag, ALog);
end;

function CommandMetaDbDiff(ATag: String; ALog: TLog): IJanusDependenciesCommand;
begin
  result := TJanusDependenciesCommandMetaDbDiff.New(ATag, ALog);
end;

function CommandDataEngine(ATag: String; ALog: TLog): IJanusDependenciesCommand;
begin
  result := TJanusDependenciesCommandDataEngine.New(ATag, ALog);
end;

function CommandJsonFlow(ATag: String; ALog: TLog): IJanusDependenciesCommand;
begin
  result := TJanusDependenciesCommandJsonFlow.New(ATag, ALog);
end;

end.
