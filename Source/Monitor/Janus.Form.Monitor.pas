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

  ORM Brasil � um ORM simples e descomplicado para quem utiliza Delphi.
}

{$INCLUDE ..\Janus.inc}

unit Janus.Form.Monitor;

interface

uses
  DB,
  Forms,
  Classes,
  Controls,
  SysUtils,
  Variants,
  StdCtrls,
  {$IFDEF MONITORRESTFULCLIENT}
  Janus.RestFactory.Interfaces,
  {$ELSE}
  DataEngine.FactoryInterfaces,
  {$ENDIF}
  TypInfo,
  ComCtrls;

type
  TCommandMonitor = class(TForm, ICommandMonitor)
    Button1: TButton;
    MemoSQL: TRichEdit;
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
    class var
      FInstance: TCommandMonitor;
    procedure Command(const ASQL: String; AParams: TParams);
  public
    { Public declarations }
    class destructor Destroy;
    class function GetInstance: ICommandMonitor;
  end;

implementation

{$R *.dfm}

{ TFSQLMonitor }

procedure TCommandMonitor.Button1Click(Sender: TObject);
begin
  MemoSQL.Lines.Clear;
end;

procedure TCommandMonitor.Command(const ASQL: String; AParams: TParams);
var
  LFor: Integer;
  LAsValue: String;
begin
  MemoSQL.Lines.Add('');
  MemoSQL.Lines.Add(ASQL);
  if AParams <> nil then
  begin
    for LFor := 0 to AParams.Count -1 do
    begin
      if AParams.Items[LFor].Value = Variants.Null then
        LAsValue := 'NULL'
      else
      if AParams.Items[LFor].DataType = ftDateTime then
        LAsValue := '"' + DateTimeToStr(AParams.Items[LFor].Value) + '"'
      else
      if AParams.Items[LFor].DataType = ftDate then
        LAsValue := '"' + DateToStr(AParams.Items[LFor].Value) + '"'
      else
        LAsValue := '"' + VarToStr(AParams.Items[LFor].Value) + '"';

      MemoSQL.Lines.Add(AParams.Items[LFor].Name + ' = ' + LAsValue + ' (' +
            GetEnumName(TypeInfo(TFieldType), Ord(AParams.Items[LFor].DataType)) + ')');
    end;
  end;
end;

class destructor TCommandMonitor.Destroy;
begin
  if Assigned(FInstance) then
    FreeAndNil(FInstance);
end;

class function TCommandMonitor.GetInstance: ICommandMonitor;
begin
  if FInstance = nil then
    FInstance := TCommandMonitor.Create(nil);
  Result := FInstance;
end;

end.
