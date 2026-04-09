{
      ORM Brasil � um ORM simples e descomplicado para quem utiliza Delphi

                   Copyright (c) 2018, Isaque Pinheiro
                          All rights reserved.
}

{ 
  @abstract(REST Componentes)
  @created(20 Jun 2018)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Janus.Server.MARS;

interface

uses
  Classes,
  SysUtils,
  Generics.Collections,
  Janus.RestComponent,
  /// Janus Conex�o
  Janus.Factory.Interfaces,
  /// MARS
  MARS.Core.Engine,
  MARS.Core.Application;

type
  TRESTServerMARS = class(TJanusComponent)
  private
    class var
    FConnection: IDBConnection;
  private
    FMARSEngine: TMARSEngine;
    procedure SetMARSEngine(const Value: TMARSEngine);
    procedure SetConnection(const AConnection: IDBConnection);
    procedure AddResource;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    class function GetConnection: IDBConnection;
    property Connection: IDBConnection read GetConnection write SetConnection;
    property MARSEngine: TMARSEngine read FMARSEngine write SetMARSEngine;
  published

  end;

implementation

uses
  Janus.Server.Resource.MARS;

{ TRESTServerMARS }

procedure TRESTServerMARS.AddResource;
var
  LPair: TPair<String, TMARSApplication>;
begin
  if FMARSEngine = nil then
    Exit;

  if FMARSEngine.Applications.Count = 0 then
    Exit;

  for LPair in FMARSEngine.Applications do
    LPair.Value.AddResource('Janus.Server.Resource.MARS.TAppResource');
end;

constructor TRESTServerMARS.Create(AOwner: TComponent);
begin
  inherited;
end;

destructor TRESTServerMARS.Destroy;
begin
  FMARSEngine := nil;
  inherited;
end;

class function TRESTServerMARS.GetConnection: IDBConnection;
begin
  Result := FConnection;
end;

procedure TRESTServerMARS.SetConnection(const AConnection: IDBConnection);
begin
  FConnection := AConnection;
end;

procedure TRESTServerMARS.SetMARSEngine(const Value: TMARSEngine);
begin
  /// <summary> Atualiza o valor da VAR </summary>
  FMARSEngine := Value;
  /// <summary> Adiciona a App REST no MARS </summary>
  AddResource;
end;

end.

