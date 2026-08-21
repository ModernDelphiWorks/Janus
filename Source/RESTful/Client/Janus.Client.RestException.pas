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

  /// <summary>
  ///   ISSUE #323 - THE ANSWER IS NOT IN THE AGREED SHAPE.
  ///
  ///   Raised by TJanusClient.ResponsePayload, INSIDE the try of the Do* method
  ///   that asked for the round trip, so the handler already written there is
  ///   the one that reports it - either through FErrorCommand or wrapped in an
  ///   EJanusRESTException naming URL, resource, method, status and the response
  ///   body. This class is not meant to reach the consumer of a Do* method; it
  ///   exists so the malformed shapes stop arriving as an EInvalidCast, an
  ///   EArgumentOutOfRangeException or - worst of the three - an access
  ///   violation, none of which say anything about HTTP.
  /// </summary>
  EJanusRESTResponseShape = class(Exception);

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
