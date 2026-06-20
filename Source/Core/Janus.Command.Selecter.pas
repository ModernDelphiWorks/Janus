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
  @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
}

unit Janus.Command.Selecter;

interface

uses
  SysUtils,
  Rtti,
  DB,
  Janus.Command.Abstract,
  DataEngine.FactoryInterfaces,
  MetaDbDiff.Mapping.Classes,
  MetaDbDiff.Mapping.Explorer;

type
  TCommandSelecter = class(TDMLCommandAbstract)
  private
    FPageSize: Integer;
    FPageNext: Integer;
    FRequestedDriver: TDriverName;
    FSelectCommand: String;
    function NormalizeFirebirdPagination(const ASQL: String): String;
  public
    constructor Create(AConnection: IDBConnection; ADriverName: TDriverName;
      AObject: TObject); override;
    procedure SetPageSize(const APageSize: Integer);
    function GenerateSelectAll(const AClass: TClass): String;
    function GeneratorSelectWhere(const AClass: TClass;
      const AWhere, AOrderBy: String): String;
    function GenerateSelectID(const AClass: TClass; const AID: TValue): String;
    function GenerateSelectOneToOne(const AOwner: TObject;
      const AClass: TClass; const AAssociation: TAssociationMapping): String;
    function GenerateSelectOneToMany(const AOwner: TObject;
      const AClass: TClass; const AAssociation: TAssociationMapping): String;
    function GenerateNextPacket: String; overload;
    function GenerateNextPacket(const AClass: TClass;
      const APageSize, APageNext: Integer): String; overload;
    function GenerateNextPacket(const AClass: TClass;
      const AWhere, AOrderBy: String;
      const APageSize, APageNext: Integer): String; overload;
  end;

implementation

{ TCommandSelecter }

constructor TCommandSelecter.Create(AConnection: IDBConnection;
  ADriverName: TDriverName; AObject: TObject);
begin
  FRequestedDriver := ADriverName;
  if ADriverName in [dnFirebird, dnFirebird3] then
    inherited Create(AConnection, dnSQLite, AObject)
  else
    inherited Create(AConnection, ADriverName, AObject);
  FSelectCommand := '';
  FResultCommand := '';
  FPageSize := -1;
  FPageNext := 0;
end;

function TCommandSelecter.NormalizeFirebirdPagination(const ASQL: String): String;
var
  LUpperSQL: String;
  LClause: String;
  LLimitPos: Integer;
  LOffsetPos: Integer;
  LSelectPos: Integer;
  LLimitValue: String;
  LOffsetValue: String;
begin
  Result := ASQL;
  if not (FRequestedDriver in [dnFirebird, dnFirebird3]) then
    Exit;

  LUpperSQL := UpperCase(Result);
  LLimitPos := Pos(' LIMIT ', LUpperSQL);
  if LLimitPos = 0 then
    Exit;

  LClause := Copy(Result, LLimitPos + Length(' LIMIT '), MaxInt);
  Delete(Result, LLimitPos, MaxInt);

  LOffsetPos := Pos(' OFFSET ', UpperCase(LClause));
  if LOffsetPos = 0 then
    Exit;

  LLimitValue := Trim(Copy(LClause, 1, LOffsetPos - 1));
  LOffsetValue := Trim(Copy(LClause, LOffsetPos + Length(' OFFSET '), MaxInt));
  LSelectPos := Pos('SELECT ', UpperCase(Result));
  if LSelectPos > 0 then
    Insert(Format('FIRST %s SKIP %s ', [LLimitValue, LOffsetValue]),
      Result, LSelectPos + Length('SELECT '));
end;

function TCommandSelecter.GenerateNextPacket: String;
begin
  FPageNext := FPageNext + FPageSize;
  FResultCommand := FGeneratorCommand.GeneratorPageNext(FSelectCommand, FPageSize, FPageNext);
  Result := FResultCommand;
end;

procedure TCommandSelecter.SetPageSize(const APageSize: Integer);
begin
  FPageSize := APageSize;
end;

function TCommandSelecter.GenerateSelectAll(const AClass: TClass): String;
begin
  FPageNext := 0;
  FSelectCommand := FGeneratorCommand.GeneratorSelectAll(AClass, FPageSize, -1);
  FResultCommand := FGeneratorCommand.GeneratorPageNext(FSelectCommand, FPageSize, FPageNext);
  FResultCommand := NormalizeFirebirdPagination(FResultCommand);
  Result := FResultCommand;
end;

function TCommandSelecter.GenerateSelectOneToMany(const AOwner: TObject;
  const AClass: TClass; const AAssociation: TAssociationMapping): String;
begin
  FResultCommand := FGeneratorCommand.GenerateSelectOneToOneMany(AOwner, AClass, AAssociation);
  Result := FResultCommand;
end;

function TCommandSelecter.GenerateSelectOneToOne(const AOwner: TObject;
  const AClass: TClass; const AAssociation: TAssociationMapping): String;
begin
  FResultCommand := FGeneratorCommand.GenerateSelectOneToOne(AOwner, AClass, AAssociation);
  Result := FResultCommand;
end;

function TCommandSelecter.GeneratorSelectWhere(const AClass: TClass;
  const AWhere, AOrderBy: String): String;
var
  LWhere: String;
begin
  FPageNext := 0;
  LWhere := StringReplace(AWhere,'%', '$', [rfReplaceAll]);
  FSelectCommand := FGeneratorCommand.GeneratorSelectWhere(AClass, LWhere, AOrderBy, FPageSize);
  FResultCommand := FGeneratorCommand.GeneratorPageNext(FSelectCommand, FPageSize, FPageNext);
  FResultCommand := StringReplace(FResultCommand, '$', '%', [rfReplaceAll]);
  FResultCommand := NormalizeFirebirdPagination(FResultCommand);
  Result := FResultCommand;
end;

function TCommandSelecter.GenerateSelectID(const AClass: TClass;
  const AID: TValue): String;
begin
  FPageNext := 0;
  FSelectCommand := FGeneratorCommand.GeneratorSelectAll(AClass, -1, AID);
  FResultCommand := FSelectCommand;
  Result := FResultCommand;
end;

function TCommandSelecter.GenerateNextPacket(const AClass: TClass;
  const APageSize, APageNext: Integer): String;
begin
  FSelectCommand := FGeneratorCommand.GeneratorSelectAll(AClass, APageSize, -1);
  FResultCommand := FGeneratorCommand.GeneratorPageNext(FSelectCommand, APageSize, APageNext);
  Result := FResultCommand;
end;

function TCommandSelecter.GenerateNextPacket(const AClass: TClass; const AWhere,
  AOrderBy: String; const APageSize, APageNext: Integer): String;
var
  LWhere: String;
  LCommandSelect: String;
begin
  LWhere := StringReplace(AWhere,'%', '$', [rfReplaceAll]);
  LCommandSelect := FGeneratorCommand.GeneratorSelectWhere(AClass, LWhere, AOrderBy, APageSize);
  FResultCommand := FGeneratorCommand.GeneratorPageNext(LCommandSelect, APageSize, APageNext);
  FResultCommand := StringReplace(FResultCommand, '$', '%', [rfReplaceAll]);
  Result := FResultCommand;
end;

end.
