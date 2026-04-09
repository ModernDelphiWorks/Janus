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
}

unit Janus.Utils;

interface

uses
  Rtti,
  Classes,
  SysUtils,
  StrUtils,
  Variants,
  Generics.Collections;

type
  TStrArray = array of String;
  PIInterface = ^IInterface;

  IUtilSingleton = interface
    ['{D41BA6C1-EFDB-4C58-937A-59B864A8F0F4}']
    function ParseCommandNoSQL(const ASubStr, ACommandText: String;
      const ADefault: String = ''): String;

  end;

  TUtilSingleton = class sealed(TInterfacedObject, IUtilSingleton)
  private
    class var FInstance: IUtilSingleton;
  public
    { Public declarations }
    class function GetInstance: IUtilSingleton;
    function ParseCommandNoSQL(const ASubStr, ASQL: String;
      const ADefault: String): String;
    function IfThen<T>(ACondition: Boolean; ATrue: T; AFalse: T): T;
    procedure SetWeak(AInterfaceField: PIInterface; const AValue: IInterface);
  end;

implementation

{ TUtilSingleton }

procedure TUtilSingleton.SetWeak(AInterfaceField: PIInterface; const AValue: IInterface);
begin
  PPointer(AInterfaceField)^ := Pointer(AValue);
end;

class function TUtilSingleton.GetInstance: IUtilSingleton;
begin
  if not Assigned(FInstance) then
    FInstance := TUtilSingleton.Create;
   Result := FInstance;
end;

function TUtilSingleton.IfThen<T>(ACondition: Boolean; ATrue, AFalse: T): T;
begin
  Result := AFalse;
  if ACondition then
    Result := ATrue;
end;

function TUtilSingleton.ParseCommandNoSQL(const ASubStr, ASQL: String;
  const ADefault: String): String;
var
  LFor: Integer;
  LPosI: Integer;
  LPosF: Integer;
begin
  Result := '';
  LPosI := Pos(ASubStr + '=', ASQL);
  try
    if LPosI > 0 then
    begin
      LPosI := LPosI + Length(ASubStr);
      for LFor := LPosI to Length(ASQL) do
      begin
        case ASQL[LFor] of
          '=': LPosI := LFor;
          '&': begin
                 if (not MatchText(ASubStr, ['values','json'])) then
                   Break;
               end;
        end;
//        if (ASQL[LFor] = '=') then
//          LPosI := LFor
//        else
//        if (ASQL[LFor] = ',') and
//           (not MatchText(ASubStr, ['values','json'])) then
//          Break;
      end;
      LPosF  := LFor - LPosI;
      Result := Copy(ASQL, LPosI+1, LPosF-1);
    end;
  finally
    if (Result = '') and (ADefault <> '') then
      Result := ADefault
  end;
end;

end.
