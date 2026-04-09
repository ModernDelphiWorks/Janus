{
      ORM Brasil é um ORM simples e descomplicado para quem utiliza Delphi

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

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Janus.Client.RestException;

interface

uses
  Classes,
  SysUtils;

type

  EJanusRESTException = class(Exception)
  public
    constructor Create(const AURL, AResource, ASubResource,
      AMethodType, AMessage, AMessageError: String;
      const AStatusCode: Integer); overload;
  end;

implementation

{ EJanusRESTException }

constructor EJanusRESTException.Create(const AURL, AResource, ASubResource,
  AMethodType, AMessage, AMessageError: String; const AStatusCode: Integer);
var
  LMessage: String;
begin
  LMessage := 'URL : '         + AURL          + sLineBreak +
              'Resource : '    + AResource     + sLineBreak +
              'SubResource : ' + ASubResource  + sLineBreak +
              'Method : '      + AMethodType   + sLineBreak +
              'Message : '     + AMessage      + sLineBreak +
              'Error : '       + AMessageError + sLineBreak +
              'Status Code : ' + IntToStr(AStatusCode);
  inherited Create(LMessage);
end;

end.
