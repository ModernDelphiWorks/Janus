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

unit Janus.Client.RestMARS.Factory;

interface

uses
  Classes,
  SysUtils,
  Janus.RestFactory.Connection,
  Janus.Client.RestDriver.MARS,
  Janus.Client.Methods;

type
  /// <summary>
  /// F�brica de conex�es abstratas
  /// </summary>
  TRESTFactoryMARS = class (TRESTFactoryConnection)
  public
    constructor Create(AConnection: TComponent); override;
    destructor Destroy; override;
    function Execute(const AResource, ASubResource: String;
      const ARequestMethod: TRESTRequestMethodType; const AParams: TProc = nil): String; overload; override;
  end;

implementation

{ TFactoryRestMARS }

constructor TRESTFactoryMARS.Create(AConnection: TComponent);
begin
  inherited;
  FDriverConnection := TRESTDriverMARS.Create(AConnection);
end;

destructor TRESTFactoryMARS.Destroy;
begin
  inherited;
end;

function TRESTFactoryMARS.Execute(const AResource, ASubResource: String;
  const ARequestMethod: TRESTRequestMethodType; const AParams: TProc): String;
begin
  Result := FDriverConnection
              .Execute(AResource, ASubResource, ARequestMethod, AParams);
end;

end.
