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

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Janus.Client.RestDriver;

interface

uses
  Classes,
  SysUtils,
  Janus.Client.Methods;

type
  TRESTDriver = class abstract
  public
    constructor Create(AConnection: TComponent); virtual;
    destructor Destroy; override;
    function GetBaseURL: String; virtual; abstract;
    function GetFullURL: String; virtual; abstract;
    function GetUsername: String; virtual; abstract;
    function GetPassword: String; virtual; abstract;
    function GetMethodGET: String; virtual; abstract;
    function GetMethodGETId: String; virtual; abstract;
    function GetMethodGETWhere: String; virtual; abstract;
    function GetMethodPOST: String; virtual; abstract;
    function GetMethodPUT: String; virtual; abstract;
    function GetMethodDELETE: String; virtual; abstract;
    function GetMethodGETNextPacket: String; virtual; abstract;
    function GetMethodGETNextPacketWhere: String; virtual; abstract;
    function GetMethodToken: String; virtual; abstract;
    function GetServerUse: Boolean; virtual; abstract;
    function Execute(const AResource, ASubResource: String;
      const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc = nil): String; overload; virtual; abstract;
    /// <summary> UM recurso, sem sub-recurso. Deixou de ser abstrata: era
    ///   declarada `virtual; abstract` e nenhum dos seis drivers concretos a
    ///   sobrescrevia, entao a primeira chamada morria em EAbstractError - sem
    ///   nenhum aviso do compilador. MEDIDO no Janus.Tests.RESTWiRL: o
    ///   TRESTDriverWiRL tinha DUAS abstratas nao sobrescritas, esta e
    ///   GetFullURL, e saiu W1020 so para a GetFullURL. Sobre esta, cuja outra
    ///   sobrecarga de mesmo nome esta implementada, nada foi dito.
    ///
    ///   A regra e a mesma que Janus.Session.RESTful ja usa quando nao ha
    ///   sub-recurso: UM recurso e o par (recurso, ''). Fica definida aqui, uma
    ///   vez, em termos da sobrecarga de dois recursos - que e virtual, entao a
    ///   chamada desce para o driver concreto e nenhum deles precisa repetir
    ///   codigo.
    ///
    ///   ATENCAO ao nome do parametro: aqui e AResource, um RECURSO relativo a
    ///   BaseURL. NAO e o AURL das classes cliente (TRESTClientHorse.Execute,
    ///   TRESTClientWiRL.Execute), que troca a BaseURL inteira. As duas
    ///   assinaturas tem a mesma forma e significados diferentes; ligar esta
    ///   naquela trocaria o destino da requisicao em silencio. </summary>
    function Execute(const AResource: String; const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc = nil): String; overload; virtual;
    procedure SetClassNotServerUse(const Value: Boolean); virtual; abstract;
    procedure AddParam(const AValue: String); virtual; abstract;
    procedure AddQueryParam(const AValue: String); virtual; abstract;
    procedure AddBodyParam(const AValue: String); virtual; abstract;
  end;

implementation

{ TDriverRest }

constructor TRESTDriver.Create(AConnection: TComponent);
begin

end;

destructor TRESTDriver.Destroy;
begin
  inherited;
end;

function TRESTDriver.Execute(const AResource: String;
  const ARequestMethod: TRESTRequestMethodType; const AParams: TProc): String;
begin
  Result := Execute(AResource, '', ARequestMethod, AParams);
end;

end.
