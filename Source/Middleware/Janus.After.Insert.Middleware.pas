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

unit Janus.After.Insert.Middleware;

interface

uses
  SysUtils,
  Generics.Collections,
  Janus.Register.Middleware;

type
  IAfterInsertMiddleware = interface
    ['{D02951F5-CD4A-4F2D-B421-58C14C864583}']
      procedure AddEvent(const AResource: String; const AProc: TEvent); overload; deprecated 'Use AddEvent with TContextEvent';
    procedure AddEvent(const AResource: String; const AProc: TContextEvent;
      const APriority: Integer = 100); overload;
  end;

  TAfterInsertMiddleware = class(TInterfacedObject, IAfterInsertMiddleware)
  strict private
    class var FInstance: IAfterInsertMiddleware;
    class var FEventList: TDictionary<String, TEvent>;
    class var FContextEventList: TDictionary<String, TContextEventList>;
    constructor CreatePrivate;
  protected
    constructor Create;
  public
    destructor Destroy; override;
    class function Get: IAfterInsertMiddleware;
    procedure AddEvent(const AResource: String; const AProc: TEvent); overload;
    procedure AddEvent(const AResource: String; const AProc: TContextEvent;
      const APriority: Integer = 100); overload;
    class function GetEvent(const AResource: String): TEvent;
    class function GetContextEvents(const AResource: String): TContextEventList;
  end;

implementation

{ TAfterInsertMiddleware }

procedure TAfterInsertMiddleware.AddEvent(const AResource: String;
  const AProc: TEvent);
var
  LResource: String;
begin
  LResource := UpperCase(AResource);
  if not FEventList.ContainsKey(LResource) then
    FEventList.Add(LResource, AProc);
end;

procedure TAfterInsertMiddleware.AddEvent(const AResource: String;
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

constructor TAfterInsertMiddleware.Create;
begin
  raise Exception.Create('Para usar o IAfterInsertMiddleware chame AfterInsertMiddleware.');
end;

constructor TAfterInsertMiddleware.CreatePrivate;
begin
  FEventList := TDictionary<String, TEvent>.Create;
  FContextEventList := TObjectDictionary<String, TContextEventList>.Create([doOwnsValues]);
end;

destructor TAfterInsertMiddleware.Destroy;
begin
  FEventList.Free;
  FContextEventList.Free;
  inherited;
end;

class function TAfterInsertMiddleware.Get: IAfterInsertMiddleware;
begin
  if not Assigned(FInstance) then
    FInstance := TAfterInsertMiddleware.CreatePrivate;
   Result := FInstance;
end;

class function TAfterInsertMiddleware.GetEvent(const AResource: String): TEvent;
begin
  Result := nil;
  if FEventList = nil then
    exit;
  if not FEventList.ContainsKey(AResource) then
    Exit;
  Result := FEventList[AResource];
end;

class function TAfterInsertMiddleware.GetContextEvents(
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
  TJanusMiddlewares.RegisterEventCallback('AfterInsert', TAfterInsertMiddleware.GetEvent);
  TJanusMiddlewares.RegisterContextEventCallback('AfterInsert', TAfterInsertMiddleware.GetContextEvents);

end.
