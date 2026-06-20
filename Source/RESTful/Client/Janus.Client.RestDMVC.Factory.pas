{
  ------------------------------------------------------------------------------
  Janus ORM
  State-of-the-art Object-Relational Mapping (ORM) framework for Delphi.

  SPDX-License-Identifier: MIT
  Copyright (c) 2025-2026 Isaque Pinheiro

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

unit Janus.Client.RestDMVC.Factory;

{$IFDEF JANUS_REST_DMVC}

interface

uses
  Classes,
  SysUtils,
  Janus.RestFactory.Connection,
  Janus.Client.RestDriver.DMVC,
  Janus.Client.Methods;

type
  /// <summary>
  ///   Fábrica de conexões abstratas
  /// </summary>
  TRESTFactoryDMVC = class (TRESTFactoryConnection)
  public
    constructor Create(AConnection: TComponent); override;
    destructor Destroy; override;
    function Execute(const AResource, ASubResource: string;
      const ARequestMethod: TRESTRequestMethodType; const AParams: TProc = nil): string; overload; override;
  end;

implementation

{ TFactoryRestDMVC }

constructor TRESTFactoryDMVC.Create(AConnection: TComponent);
begin
  inherited;
  FDriverConnection := TRESTDriverDMVC.Create(AConnection);
end;

destructor TRESTFactoryDMVC.Destroy;
begin
  inherited;
end;

function TRESTFactoryDMVC.Execute(const AResource, ASubResource: string;
  const ARequestMethod: TRESTRequestMethodType; const AParams: TProc): string;
begin
  Result := FDriverConnection
              .Execute(AResource, ASubResource, ARequestMethod, AParams);
end;

{$ELSE}
interface
implementation
{$ENDIF}

end.
