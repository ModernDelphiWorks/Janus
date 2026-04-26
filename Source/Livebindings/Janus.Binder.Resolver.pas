{
                   Copyright (c) 2016, Isaque Pinheiro
                          All rights reserved.

                    GNU Lesser General Public License
                      Versão 3, 29 de junho de 2007

       Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
       A todos é permitido copiar e distribuir cópias deste documento de
       licença, mas mudá-lo não é permitido.

       Esta versão da GNU Lesser General Public License incorpora
       os termos e condições da versão 3 da GNU General Public License
       Licença, complementado pelas permissões adicionais listadas no
       arquivo LICENSE na pasta principal.
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
