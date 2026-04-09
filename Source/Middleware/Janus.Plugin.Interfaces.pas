{
      ORM Brasil — um ORM simples e descomplicado para quem utiliza Delphi

                   Copyright (c) 2016, Isaque Pinheiro
                          All rights reserved.

                    GNU Lesser General Public License
                      Versão 3, 29 de junho de 2007

       Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
       A todos é permitido copiar e distribuir cópias deste documento de
       licença, mas mudá-lo não é permitido.

       Esta versão da GNU Lesser General Public License incorpora
       os termos e condições da versão 3 da GNU General Public License
       Licença, complementado pelas permissões adicionais listadas no
       arquivo LICENSE na pasta principal.
}

{ @abstract(Janus Framework — Plugin Interfaces.)
  @created(04 Apr 2026)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

{$INCLUDE ..\Janus.inc}

unit Janus.Plugin.Interfaces;

interface

uses
  SysUtils,
  Rtti,
  Generics.Collections,
  Janus.Register.Middleware;

type
  EJanusPluginException = class(Exception);

  IJanusPluginInfo = interface
    ['{A1B2C3D4-E5F6-4A7B-8C9D-0E1F2A3B4C5D}']
    function GetPluginId: String;
    function GetPluginName: String;
    function GetVersion: String;
    property PluginId: String read GetPluginId;
    property PluginName: String read GetPluginName;
    property Version: String read GetVersion;
  end;

  IJanusPlugin = interface
    ['{D4C3B2A1-6F5E-B7A4-D9C8-5D4C3B2A1E0F}']
    procedure Init;
    procedure Finalize;
    function GetPluginInfo: IJanusPluginInfo;
    function GetEnabled: Boolean;
    procedure SetEnabled(const AValue: Boolean);
    property Enabled: Boolean read GetEnabled write SetEnabled;
  end;

  TJanusPluginInfo = class(TInterfacedObject, IJanusPluginInfo)
  private
    FPluginId: String;
    FPluginName: String;
    FVersion: String;
    function GetPluginId: String;
    function GetPluginName: String;
    function GetVersion: String;
  public
    constructor Create(const APluginId, APluginName, AVersion: String);
    property PluginId: String read GetPluginId;
    property PluginName: String read GetPluginName;
    property Version: String read GetVersion;
  end;

  TJanusHookContext = class(TInterfacedObject, IJanusHookContext)
  private
    FOperationType: TJanusEventType;
    FEntityClass: TClass;
    FEntity: TObject;
    FAborted: Boolean;
    FMetadata: TDictionary<String, TValue>;
    FIsAfterEvent: Boolean;
    function GetOperationType: TJanusEventType;
    function GetEntityClass: TClass;
    function GetEntity: TObject;
    function GetAborted: Boolean;
    function GetMetadata: TDictionary<String, TValue>;
  public
    constructor Create(const AOperationType: TJanusEventType;
      const AEntityClass: TClass; const AEntity: TObject;
      const AIsAfterEvent: Boolean = False);
    destructor Destroy; override;
    procedure Abort;
    property OperationType: TJanusEventType read GetOperationType;
    property EntityClass: TClass read GetEntityClass;
    property Entity: TObject read GetEntity;
    property Aborted: Boolean read GetAborted;
    property Metadata: TDictionary<String, TValue> read GetMetadata;
  end;

implementation

{ TJanusPluginInfo }

constructor TJanusPluginInfo.Create(const APluginId, APluginName, AVersion: String);
begin
  FPluginId := APluginId;
  FPluginName := APluginName;
  FVersion := AVersion;
end;

function TJanusPluginInfo.GetPluginId: String;
begin
  Result := FPluginId;
end;

function TJanusPluginInfo.GetPluginName: String;
begin
  Result := FPluginName;
end;

function TJanusPluginInfo.GetVersion: String;
begin
  Result := FVersion;
end;

{ TJanusHookContext }

constructor TJanusHookContext.Create(const AOperationType: TJanusEventType;
  const AEntityClass: TClass; const AEntity: TObject;
  const AIsAfterEvent: Boolean);
begin
  FOperationType := AOperationType;
  FEntityClass := AEntityClass;
  FEntity := AEntity;
  FAborted := False;
  FIsAfterEvent := AIsAfterEvent;
  FMetadata := TDictionary<String, TValue>.Create;
end;

destructor TJanusHookContext.Destroy;
begin
  FMetadata.Free;
  inherited;
end;

procedure TJanusHookContext.Abort;
begin
  if FIsAfterEvent then
    raise EJanusPluginException.Create('Cannot abort in After* hooks. Abort is only valid in Before* hooks.');
  FAborted := True;
end;

function TJanusHookContext.GetOperationType: TJanusEventType;
begin
  Result := FOperationType;
end;

function TJanusHookContext.GetEntityClass: TClass;
begin
  Result := FEntityClass;
end;

function TJanusHookContext.GetEntity: TObject;
begin
  Result := FEntity;
end;

function TJanusHookContext.GetAborted: Boolean;
begin
  Result := FAborted;
end;

function TJanusHookContext.GetMetadata: TDictionary<String, TValue>;
begin
  Result := FMetadata;
end;

end.
