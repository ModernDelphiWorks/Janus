unit Janus.DML.Generator.MongoDB;

interface

uses
  DB,
  Classes,
  Generics.Collections,
  Janus.DML.Generator.NoSQL,
  MetaDbDiff.Mapping.Classes,
  DataEngine.FactoryInterfaces,
  Janus.Driver.Register,
  Janus.DML.Interfaces,
  Janus.DML.Commands;

type
  // Classe de conex�o concreta com NoSQL
  TDMLGeneratorMongoDB = class(TDMLGeneratorNoSQL)
  protected
  public
    constructor Create; override;
    destructor Destroy; override;
  end;

implementation

{ TDMLGeneratorMongoDB }

constructor TDMLGeneratorMongoDB.Create;
begin
  inherited;
  FDateFormat := 'yyyy-mm-dd';
  FTimeFormat := 'HH:MM:SS';
end;

destructor TDMLGeneratorMongoDB.Destroy;
begin

  inherited;
end;

initialization
  TDriverRegister.RegisterDriver(dnMongoDB,
    function: IDMLGeneratorCommand
    begin
      Result := TDMLGeneratorMongoDB.Create;
    end);

end.
