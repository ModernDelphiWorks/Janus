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
