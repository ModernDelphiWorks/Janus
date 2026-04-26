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

{
  @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Janus.DML.Cache;

interface

uses
  Generics.Collections;

type
  TQueryCache = class
  public
    // Crescimento bounded: entradas limitadas pelo numero de entidades registradas
    // x operacoes DML (SELECT, INSERT, UPDATE, DELETE). Nao requer eviction.
    FQueryCache: TDictionary<String, String>;
  public
    constructor Create;
    destructor Destroy; override;
    /// <summary>
    ///   Lista para cache de comandos SQL, evitando loops toda
    ///   vez que for solicitado um SELECT e INSERT.
    /// </summary>
    /// <param name="String">
    ///   Key de localiza\u00e7\u00e3o por classe e comando
    /// </param>
    /// <param name="String">
    ///   Comando SQL pronto para SELECT e INSERT
    /// </param>
    function TryGetValue(const AKey: String; var AValue: String): Boolean;
    procedure AddOrSetValue(const AKey: String; const AValue: String);
    procedure Clear;
  end;

implementation

{ TQueryCache }

procedure TQueryCache.AddOrSetValue(const AKey: String;
  const AValue: String);
begin
  FQueryCache.AddOrSetValue(AKey, AValue);
end;

constructor TQueryCache.Create;
begin
  FQueryCache := TDictionary<String, String>.Create;
end;

destructor TQueryCache.Destroy;
begin
  FQueryCache.Free;
  inherited;
end;

function TQueryCache.TryGetValue(const AKey: String;
  var AValue: String): Boolean;
begin
  Result := FQueryCache.TryGetValue(AKey, AValue);
end;

procedure TQueryCache.Clear;
begin
  FQueryCache.Clear;
end;

end.
