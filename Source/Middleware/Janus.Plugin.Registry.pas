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

{ @abstract(Janus Framework — Plugin Registry.)
  @created(04 Apr 2026)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

{$INCLUDE ..\Janus.inc}

unit Janus.Plugin.Registry;

interface

uses
  SysUtils,
  Generics.Collections,
  Janus.Plugin.Interfaces;

type
  TPluginRegistry = class
  private
    class var FPlugins: TDictionary<String, IJanusPlugin>;
  public
    class constructor Create;
    class destructor Destroy;
    class procedure Register(const APlugin: IJanusPlugin);
    class procedure Unregister(const APluginId: String);
    class procedure Enable(const APluginId: String);
    class procedure Disable(const APluginId: String);
    class function GetPlugin(const APluginId: String): IJanusPlugin;
    class function GetAll: TArray<IJanusPlugin>;
    class function GetEnabled: TArray<IJanusPlugin>;
    class procedure Clear;
  end;

implementation

{ TPluginRegistry }

class constructor TPluginRegistry.Create;
begin
  FPlugins := TDictionary<String, IJanusPlugin>.Create;
end;

class destructor TPluginRegistry.Destroy;
begin
  Clear;
  FPlugins.Free;
end;

class procedure TPluginRegistry.Register(const APlugin: IJanusPlugin);
var
  LPluginId: String;
begin
  if APlugin = nil then
    raise EJanusPluginException.Create('Plugin cannot be nil.');
  LPluginId := APlugin.GetPluginInfo.PluginId;
  if FPlugins.ContainsKey(LPluginId) then
    raise EJanusPluginException.CreateFmt('Plugin "%s" is already registered.', [LPluginId]);
  APlugin.Init;
  FPlugins.Add(LPluginId, APlugin);
end;

class procedure TPluginRegistry.Unregister(const APluginId: String);
var
  LPlugin: IJanusPlugin;
begin
  if not FPlugins.TryGetValue(APluginId, LPlugin) then
    raise EJanusPluginException.CreateFmt('Plugin "%s" not found.', [APluginId]);
  LPlugin.Finalize;
  FPlugins.Remove(APluginId);
end;

class procedure TPluginRegistry.Enable(const APluginId: String);
var
  LPlugin: IJanusPlugin;
begin
  if not FPlugins.TryGetValue(APluginId, LPlugin) then
    raise EJanusPluginException.CreateFmt('Plugin "%s" not found.', [APluginId]);
  LPlugin.Enabled := True;
end;

class procedure TPluginRegistry.Disable(const APluginId: String);
var
  LPlugin: IJanusPlugin;
begin
  if not FPlugins.TryGetValue(APluginId, LPlugin) then
    raise EJanusPluginException.CreateFmt('Plugin "%s" not found.', [APluginId]);
  LPlugin.Enabled := False;
end;

class function TPluginRegistry.GetPlugin(const APluginId: String): IJanusPlugin;
begin
  if not FPlugins.TryGetValue(APluginId, Result) then
    Result := nil;
end;

class function TPluginRegistry.GetAll: TArray<IJanusPlugin>;
var
  LList: TList<IJanusPlugin>;
  LPlugin: IJanusPlugin;
begin
  LList := TList<IJanusPlugin>.Create;
  try
    for LPlugin in FPlugins.Values do
      LList.Add(LPlugin);
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

class function TPluginRegistry.GetEnabled: TArray<IJanusPlugin>;
var
  LList: TList<IJanusPlugin>;
  LPlugin: IJanusPlugin;
begin
  LList := TList<IJanusPlugin>.Create;
  try
    for LPlugin in FPlugins.Values do
    begin
      if LPlugin.Enabled then
        LList.Add(LPlugin);
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

class procedure TPluginRegistry.Clear;
var
  LPlugin: IJanusPlugin;
begin
  for LPlugin in FPlugins.Values do
    LPlugin.Finalize;
  FPlugins.Clear;
end;

end.
