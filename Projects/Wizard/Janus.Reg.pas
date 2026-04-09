{
      Janus Framework - ORM simples e descomplicado para quem utiliza Delphi

                   Copyright (c) 2016, Isaque Pinheiro
                          All rights reserved.

                    GNU Lesser General Public License
                      Vers�o 3, 29 de junho de 2007

       Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
       A todos � permitido copiar e distribuir c�pias deste documento de
       licen�a, mas mud�-lo n�o � permitido.

       Esta vers�o da GNU Lesser General Public License incorpora
       os termos e condi��es da vers�o 3 da GNU General Public License
       Licen�a, complementado pelas permiss�es adicionais listadas no
       arquivo LICENSE na pasta principal.
}

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)

  Janus Framework - ORM simples e descomplicado para quem utiliza Delphi.
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
  cJANUSSOBRELICENCA = 'LGPL Version 3';

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
