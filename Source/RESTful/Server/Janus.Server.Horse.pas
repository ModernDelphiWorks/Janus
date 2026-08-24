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

unit Janus.Server.Horse;

interface

uses
  Classes,
  SysUtils,
  StrUtils,
  Janus.RestComponent,
  /// TJsonBuilder.StringToJson is what turns an exception message into the
  /// JSON string literal cEXCEPTION now interpolates - see the note on that
  /// constant. It is the SAME escaper the framework's own serialisation walks
  /// through: TJanusJson delegates to TJsonBuilder, and every string VALUE
  /// this repository writes out leaves through it. Anchored by SYMBOL.
  JsonFlow.Builders,
  // DataEngine Conexao
  DataEngine.FactoryInterfaces,
  // HorseCore
  Horse,
  Horse.Core;

type
  TRESTServerHorse = class(TJanusComponent)
  private
    class var FConnection: IDBConnection;
  private
    FAPIAddress: String;
    /// ISSUE #376 - THE `%s` IS NO LONGER INSIDE THE QUOTES, AND THE QUOTES
    /// ARE NOW THE ESCAPER'S.
    ///
    /// THE DOCUMENT ON THE WIRE IS UNCHANGED: still one object, still the
    /// single key `Exception`, still a JSON STRING for its value. What moved
    /// is WHO writes the delimiters. This constant used to spell them, so
    /// Format pasted the exception message RAW between them - and a message
    /// carrying a quote, a backslash or a character below #32 closed or
    /// corrupted the string it landed in, and the answer stopped being a
    /// document at all. Now every handler below hands over
    /// TJsonBuilder.StringToJson(E.Message), which returns the delimiters and
    /// the escaped text together.
    ///
    /// WHY THAT IS THE WHOLE DEFECT AND NOT A COSMETIC ONE: an answer Delphi's
    /// parser refuses makes TCustomRESTResponse.GetJSONValue answer nil,
    /// TJanusClient.ResponseValue raises cRESTNOJSONVALUE on that nil, and its
    /// wording - "the body was empty, was not JSON, or the configured root
    /// element is absent from it" - blames the CALLER's payload for an answer
    /// this server wrote. Anchored by SYMBOL, in Janus.Client.Horse and
    /// Janus.Client.
    ///
    /// THE VALUE STAYS A STRING ON PURPOSE. A message that is itself a
    /// serialised document could have been NESTED under this key instead, and
    /// that would change the wire contract for every consumer already reading
    /// `Exception` as a string. Escaping keeps the contract and makes it
    /// reversible: whatever the message was, a consumer gets it back byte for
    /// byte.
    ///
    /// Pinned by Test.Janus.Server.ExceptionEnvelope, over BOTH message
    /// shapes - one that is plain prose and one that is still a JSON document
    /// with quotes in it. The second is the one that dies if the escape is
    /// removed and only the wording of a message is repaired.
    const cEXCEPTION = '{"Exception": %s}';
    const cCONTENTTYPE = 'application/json; charset=UTF-8';
    procedure AddResources;
  public
    constructor Create(AOwner: TComponent;
      const AConnection: IDBConnection;
      const AAPIAddress: String = ''); overload;
    destructor Destroy; override;
    class function GetConnection: IDBConnection;
  published

  end;

implementation

uses
  Janus.Server.Resource.Horse;

{ TRESTServerHorse }

constructor TRESTServerHorse.Create(AOwner: TComponent;
  const AConnection: IDBConnection;
  const AAPIAddress: String = '');
begin
//  inherited Create(AOwner);
  FConnection := AConnection;
  if AAPIAddress = '' then
    FAPIAddress := 'api/Janus/:resource'
  else
  begin
    // Se o ultimo caracter nao for '/' concatena ele para ser
    FAPIAddress := AAPIAddress;
    if RightStr(FAPIAddress, 1) <> '/' then
      FAPIAddress := FAPIAddress + '/';
    FAPIAddress := FAPIAddress + ':resource';
  end;
  // Define as rotas para no horse e verbos
  AddResources;
end;

destructor TRESTServerHorse.Destroy;
begin
  inherited;
end;

class function TRESTServerHorse.GetConnection: IDBConnection;
begin
  Result := FConnection;
end;

procedure TRESTServerHorse.AddResources;
begin
  THorse.Get(FAPIAddress,
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LAppResource: TAppResource;
    begin
      LAppResource := TAppResource.Create;
      try
        try
          Res.Send(LAppResource.select(Req.Params['resource'],
                                       Req.Params,
                                       Req.Query)).ContentType(cCONTENTTYPE);
          // Add records count in Headers "ResultCount"
          if LAppResource.ResultCount > 0 then
            Res.RawWebResponse.CustomHeaders.AddPair('ResultCount', IntToStr(LAppResource.ResultCount));
        except
          on E: Exception do
            Res.Send(Format(cEXCEPTION,
                            [TJsonBuilder.StringToJson(E.Message)]))
              .ContentType(cCONTENTTYPE);
        end;
      finally
        LAppResource.Free;
      end;
    end);

  THorse.Post(FAPIAddress,
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LAppResource: TAppResource;
    begin
      LAppResource := TAppResource.Create;
      try
        try
          Res.Send(LAppResource.insert(Req.Params['resource'],
                                       Req.Body)).ContentType(cCONTENTTYPE);
        except
          on E: Exception do
            Res.Send(Format(cEXCEPTION,
                            [TJsonBuilder.StringToJson(E.Message)]))
              .ContentType(cCONTENTTYPE);
        end;
      finally
        LAppResource.Free;
      end;
    end);

  THorse.Put(FAPIAddress,
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LAppResource: TAppResource;
    begin
      LAppResource := TAppResource.Create;
      try
        try
          Res.Send(LAppResource.update(Req.Params['resource'],
                                       Req.Body)).ContentType(cCONTENTTYPE);
        except
          on E: Exception do
            Res.Send(Format(cEXCEPTION,
                            [TJsonBuilder.StringToJson(E.Message)]))
              .ContentType(cCONTENTTYPE);
        end;
      finally
        LAppResource.Free;
      end;
    end);

  THorse.Delete(FAPIAddress,
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LAppResource: TAppResource;
    begin
      LAppResource := TAppResource.Create;
      try
        try
          if Req.Query.Count = 0 then
            Res.Send(LAppResource.delete(Req.Params['resource'])).ContentType(cCONTENTTYPE)
          else
            Res.Send(LAppResource.delete(Req.Params['resource'],
                                         Req.Query['$filter'])).ContentType(cCONTENTTYPE);
        except
          on E: Exception do
            Res.Send(Format(cEXCEPTION,
                            [TJsonBuilder.StringToJson(E.Message)]))
              .ContentType(cCONTENTTYPE);
        end;
      finally
        LAppResource.Free;
      end;
    end);
end;

end.
