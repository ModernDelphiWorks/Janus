unit Janus.Dependencies.Executor;

interface

uses
  Forms,
  Janus.Dependencies.Interfaces,
  System.Generics.Collections;

type TJanusDependenciesExecutor = class(TInterfacedObject, IJanusDependenciesExecutor)

  private
    FCommands: TList<IJanusDependenciesCommand>;

  protected
    function AddCommand(ACommand: IJanusDependenciesCommand): IJanusDependenciesExecutor;
    function Execute: IJanusDependenciesExecutor;

  public
    constructor create;
    class function New: IJanusDependenciesExecutor;
    destructor Destroy; override;
end;

implementation

{ TJanusDependenciesExecutor }

function TJanusDependenciesExecutor.AddCommand(ACommand: IJanusDependenciesCommand): IJanusDependenciesExecutor;
begin
  result := Self;
  FCommands.Add(ACommand);
end;

constructor TJanusDependenciesExecutor.create;
begin
  FCommands := TList<IJanusDependenciesCommand>.Create;
end;

destructor TJanusDependenciesExecutor.Destroy;
begin
  FCommands.Free;
  inherited;
end;

function TJanusDependenciesExecutor.Execute: IJanusDependenciesExecutor;
var
  i: Integer;
begin
  result := Self;
  for i := 0 to Pred(FCommands.Count) do
  begin
    FCommands[i].Execute;
    Application.ProcessMessages;
  end;
end;

class function TJanusDependenciesExecutor.New: IJanusDependenciesExecutor;
begin
  Result := Self.create;
end;

end.
