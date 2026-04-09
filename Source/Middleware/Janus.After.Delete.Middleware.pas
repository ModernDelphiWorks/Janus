{
      ORM Brasil � um ORM simples e descomplicado para quem utiliza Delphi

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
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Janus.After.Delete.Middleware;

interface

uses
  SysUtils,
  Generics.Collections,
  Janus.Register.Middleware;

type
  IAfterDeleteMiddleware = interface
    ['{B269BBD9-E8D9-4D7C-96BE-A4D53FE954F4}']
      procedure AddEvent(const AResource: String; const AProc: TEvent); overload; deprecated 'Use AddEvent with TContextEvent';
    procedure AddEvent(const AResource: String; const AProc: TContextEvent;
      const APriority: Integer = 100); overload;
  end;

  TAfterDeleteMiddleware = class(TInterfacedObject, IAfterDeleteMiddleware)
  strict private
    class var FInstance: IAfterDeleteMiddleware;
    class var FEventList: TDictionary<String, TEvent>;
    class var FContextEventList: TDictionary<String, TContextEventList>;
    constructor CreatePrivate;
  protected
    constructor Create;
  public
    destructor Destroy; override;
    class function Get: IAfterDeleteMiddleware;
    procedure AddEvent(const AResource: String; const AProc: TEvent); overload;
    procedure AddEvent(const AResource: String; const AProc: TContextEvent;
      const APriority: Integer = 100); overload;
    class function GetEvent(const AResource: String): TEvent;
    class function GetContextEvents(const AResource: String): TContextEventList;
  end;

implementation

{ TAfterDeleteMiddleware }

procedure TAfterDeleteMiddleware.AddEvent(const AResource: String;
  const AProc: TEvent);
var
  LResource: String;
begin
  LResource := UpperCase(AResource);
  if not FEventList.ContainsKey(LResource) then
    FEventList.Add(LResource, AProc);
end;

procedure TAfterDeleteMiddleware.AddEvent(const AResource: String;
  const AProc: TContextEvent; const APriority: Integer);
var
  LResource: String;
  LList: TContextEventList;
  LEntry: TContextEventEntry;
  LIndex: Integer;
  LInserted: Boolean;
begin
  LResource := UpperCase(AResource);
  if not FContextEventList.TryGetValue(LResource, LList) then
  begin
    LList := TContextEventList.Create;
    FContextEventList.Add(LResource, LList);
  end;
  LEntry.Priority := APriority;
  LEntry.Callback := AProc;
  LInserted := False;
  for LIndex := 0 to LList.Count - 1 do
  begin
    if APriority < LList[LIndex].Priority then
    begin
      LList.Insert(LIndex, LEntry);
      LInserted := True;
      Break;
    end;
  end;
  if not LInserted then
    LList.Add(LEntry);
end;

constructor TAfterDeleteMiddleware.Create;
begin
  raise Exception.Create('Para usar o IAfterDeleteMiddleware chame AfterDeleteMiddleware.');
end;

constructor TAfterDeleteMiddleware.CreatePrivate;
begin
  FEventList := TDictionary<String, TEvent>.Create;
  FContextEventList := TObjectDictionary<String, TContextEventList>.Create([doOwnsValues]);
end;

destructor TAfterDeleteMiddleware.Destroy;
begin
  FEventList.Free;
  FContextEventList.Free;
  inherited;
end;

class function TAfterDeleteMiddleware.Get: IAfterDeleteMiddleware;
begin
  if not Assigned(FInstance) then
    FInstance := TAfterDeleteMiddleware.CreatePrivate;
   Result := FInstance;
end;

class function TAfterDeleteMiddleware.GetEvent(const AResource: String): TEvent;
begin
  Result := nil;
  if FEventList = nil then
    exit;
  if not FEventList.ContainsKey(AResource) then
    Exit;
  Result := FEventList[AResource];
end;

class function TAfterDeleteMiddleware.GetContextEvents(
  const AResource: String): TContextEventList;
begin
  Result := nil;
  if FContextEventList = nil then
    Exit;
  if not FContextEventList.ContainsKey(AResource) then
    Exit;
  Result := FContextEventList[AResource];
end;

initialization
  TJanusMiddlewares.RegisterEventCallback('AfterDelete', TAfterDeleteMiddleware.GetEvent);
  TJanusMiddlewares.RegisterContextEventCallback('AfterDelete', TAfterDeleteMiddleware.GetContextEvents);

end.
