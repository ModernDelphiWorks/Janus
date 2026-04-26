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

{ @abstract(Janus Binder Resolver — R22.1)
  @created(23 Apr 2026)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
}

unit Janus.Binder.Resolver;

interface

{$IFDEF DCC}

uses
  System.Classes;

type
  TJanusBinderResolver = class
  public
    class function Resolve(const AOwner: TComponent; const AName: string): TComponent;
  end;

{$ENDIF DCC}

implementation

{$IFDEF DCC}

class function TJanusBinderResolver.Resolve(const AOwner: TComponent; const AName: string): TComponent;
begin
  Result := AOwner.FindComponent(AName);
end;

{$ENDIF DCC}

end.
