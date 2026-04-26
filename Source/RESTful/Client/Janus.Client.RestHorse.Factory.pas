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

{ 
  @abstract(REST Componentes)
  @created(20 Jun 2018)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Janus.Client.RestHorse.Factory;

interface

uses
  Classes,
  SysUtils,
  Janus.RestFactory.Connection,
  Janus.Client.RestDriver.Horse,
  Janus.Client.Methods;

type
  // F�brica de conex�es abstratas
  TRESTFactoryHorse = class (TRESTFactoryConnection)
  public
    constructor Create(AConnection: TComponent); override;
    destructor Destroy; override;
    /// <summary>
    ///
    /// </summary>
    function Execute(const AResource, ASubResource: String;
      const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc = nil): String; overload; override;
  end;

implementation

{ TFactoryRestHorse }

constructor TRESTFactoryHorse.Create(AConnection: TComponent);
begin
  inherited;
  FDriverConnection := TRESTDriverHorse.Create(AConnection);
end;

destructor TRESTFactoryHorse.Destroy;
begin
  inherited;
end;

function TRESTFactoryHorse.Execute(const AResource, ASubResource: String;
  const ARequestMethod: TRESTRequestMethodType; const AParams: TProc): String;
begin
  Result := FDriverConnection
              .Execute(AResource, ASubResource, ARequestMethod, AParams);
end;

end.
