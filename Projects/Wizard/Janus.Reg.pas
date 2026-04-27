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

unit Janus.Reg;

interface

uses
  SysUtils,
  Windows,
  Graphics,
  ToolsApi;

implementation

const
  cJANUSSOBRETITULO = 'Janus Framework for Delphi';
  cJANUSVERSION = '2.5';
  cJANUSRELEASE = '2019';
  cJANUSSOBREDESCRICAO = 'Janus Framework http://www.Janus.com.br/' + sLineBreak +
                               'Path Library ' + sLineBreak +
                               'Version : ' + cJANUSVERSION + '.' + cJANUSRELEASE;
  cJANUSSOBRELICENCA = 'MIT';

var
 GAboutBoxServices: IOTAAboutBoxServices = nil;
 GAboutBoxIndex: Integer = 0;

procedure RegisterAboutBox;
var
  LImage: HBITMAP;
begin
  if Supports(BorlandIDEServices, IOTAAboutBoxServices, GAboutBoxServices) then
  begin
    LImage  := LoadBitmap(FindResourceHInstance(HInstance), 'Janus');
    GAboutBoxIndex := GAboutBoxServices.AddPluginInfo(cJANUSSOBRETITULO + ' ' + cJANUSVERSION,
                                                      cJANUSSOBREDESCRICAO,
                                                      LImage,
                                                      False,
                                                      cJanusSOBRELICENCA,
                                                      '',
                                                      otaafIgnored);
  end;
end;

procedure UnregisterAboutBox;
begin
 if (GAboutBoxIndex <> 0) and Assigned(GAboutBoxServices) then
 begin
   GAboutBoxServices.RemovePluginInfo(GAboutBoxIndex);
   GAboutBoxIndex := 0;
   GAboutBoxServices := nil;
  end;
end;

procedure AddSplash;
var
  LImage : HBITMAP;
  LSSS: IOTASplashScreenServices;
begin
  if Supports(SplashScreenServices, IOTASplashScreenServices, LSSS) then
  begin
    LImage := LoadBitmap(HInstance, 'Janus');
    LSSS.AddPluginBitmap(cJANUSSOBRETITULO,
                         LImage,
                         False,
                         cJANUSSOBRELICENCA,
                         '');
  end;
end;

initialization
  RegisterAboutBox;
  AddSplash;

finalization
  UnregisterAboutBox;

end.
