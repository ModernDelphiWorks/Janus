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

unit Janus.Client.RestWiRL.Factory;

{$IFDEF JANUS_REST_WIRL}

interface

uses
  Classes,
  SysUtils,
  Janus.RestFactory.Connection,
  Janus.Client.RestDriver.WiRL,
  Janus.Client.Methods;

type
  /// <summary>
  ///   Fábrica de conexões abstratas
  /// </summary>
  TRESTFactoryWiRL = class (TRESTFactoryConnection)
  public
    constructor Create(AConnection: TComponent); override;
    destructor Destroy; override;
    function Execute(const AResource, ASubResource: string;
      const ARequestMethod: TRESTRequestMethodType; const AParams: TProc = nil): string; overload; override;
  end;

implementation

{ TFactoryRestWiRL }

constructor TRESTFactoryWiRL.Create(AConnection: TComponent);
begin
  inherited;
  FDriverConnection := TRESTDriverWiRL.Create(AConnection);
end;

destructor TRESTFactoryWiRL.Destroy;
begin
  inherited;
end;

function TRESTFactoryWiRL.Execute(const AResource, ASubResource: string;
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
