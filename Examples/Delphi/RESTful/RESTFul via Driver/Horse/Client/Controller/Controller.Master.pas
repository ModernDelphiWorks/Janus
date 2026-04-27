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

unit Controller.Master;

interface

uses
  DB,
  SysUtils,
  Repository.Master,
  Provider.DataModule,
  Janus.Client.Methods;

type
  TControllerMaster = class
  private
    FRepository: TRepositoryMaster;
  protected
  public
    constructor Create;
    destructor Destroy; override;
    procedure Open;
    procedure OpenWhere(const AWhere: String);
    procedure ApplyUpdates;
    procedure MonitorShow;
    function Execute(const AURL: String; const ARequestMethod: TRESTRequestMethodType;
      const AParamsProc: TProc): String;
    function Master: TDataSet;
    function Detail: TDataSet;
    function Client: TDataSet;
    function Lookup: TDataSet;
    function ProviderDM: TProviderDM;
  end;

implementation

{ TControllerMaster }

function TControllerMaster.Client: TDataSet;
begin
  Result := FRepository.Client;
end;

constructor TControllerMaster.Create;
begin
  FRepository := TRepositoryMaster.Create;
end;

destructor TControllerMaster.Destroy;
begin
  FRepository.Free;
  inherited;
end;

function TControllerMaster.Detail: TDataSet;
begin
  Result := FRepository.Detail;
end;

function TControllerMaster.Execute(const AURL: String; const ARequestMethod: TRESTRequestMethodType;
  const AParamsProc: TProc): String;
begin
  Result := FRepository.Execute(AURL, ARequestMethod, AParamsProc);
end;

function TControllerMaster.Lookup: TDataSet;
begin
  Result := FRepository.Lookup;
end;

function TControllerMaster.Master: TDataSet;
begin
  Result := FRepository.Master;
end;

procedure TControllerMaster.MonitorShow;
begin
  FRepository.MonitorShow;
end;

procedure TControllerMaster.Open;
begin
  FRepository.Open;
end;

procedure TControllerMaster.OpenWhere(const AWhere: String);
begin
  FRepository.OpenWhere(AWhere);
end;

function TControllerMaster.ProviderDM: TProviderDM;
begin
  Result := FRepository.ProviderDM;
end;

procedure TControllerMaster.ApplyUpdates;
begin
  FRepository.ApplyUpdates;
end;

end.

