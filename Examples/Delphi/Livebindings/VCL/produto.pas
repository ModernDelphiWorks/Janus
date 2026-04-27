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

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit produto;

interface

uses
  Janus.Binder.Attributes;

type
  TProduto = class
  private
    FID: Integer;
    FPreco: Double;
    FSoma: Double;
    procedure SetID(const AValue: Integer);
    procedure SetPreco(const AValue: Double);
  public
    [Bind('EditID', 'Text')]
    [Bind('LabelID', 'Caption')]
    [Bind('ComboEditID', 'ItemIndex')]
    [Bind('ProgressBarID', 'Position')]
    property ID: Integer read FID write SetID;

    [Bind('EditPreco', 'Text')]
    [Bind('LabelPreco', 'Caption')]
    property Preco: Double read FPreco write SetPreco;

    [Bind('EditSoma', 'Text')]
    property Soma: Double read FSoma;
  end;

implementation

{ TProduto }

procedure TProduto.SetID(const AValue: Integer);
begin
  FID := AValue;
  FSoma := FID * FPreco;
end;

procedure TProduto.SetPreco(const AValue: Double);
begin
  FPreco := AValue;
  FSoma := FID * FPreco;
end;

end.
