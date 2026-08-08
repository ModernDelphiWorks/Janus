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

unit Janus.DB.Reg;

interface

uses
  Classes,
  DesignIntf,
  DesignEditors,
  Janus.Manager.ClientDataSet,
  Janus.Manager.FDMemTable,
  Janus.DB.Manager.ObjectSet;

type
  TJanusManagerClientDataSetEditor = class(TSelectionEditor)
  public
    procedure RequiresUnits(Proc: TGetStrProc); override;
  end;

  TJanusManagerFDMemTableEditor = class(TSelectionEditor)
  public
    procedure RequiresUnits(Proc: TGetStrProc); override;
  end;

  TJanusManagerObjectSetEditor = class(TSelectionEditor)
  public
    procedure RequiresUnits(Proc: TGetStrProc); override;
  end;

procedure register;

implementation

procedure register;
begin
  RegisterComponents('Janus-DB', [TJanusManagerClientDataSet,
                                  TJanusManagerFDMemTable,
                                  TJanusManagerObjectSet
                                 ]);
  RegisterSelectionEditor(TJanusManagerClientDataSet, TJanusManagerClientDataSetEditor);
  RegisterSelectionEditor(TJanusManagerFDMemTable, TJanusManagerFDMemTableEditor);
  RegisterSelectionEditor(TJanusManagerObjectSet, TJanusManagerObjectSetEditor);
end;

{ TJanusManagerClientDataSetEditor }

procedure TJanusManagerClientDataSetEditor.RequiresUnits(Proc: TGetStrProc);
begin

end;

{ TJanusManagerObjectSetEditor }

procedure TJanusManagerObjectSetEditor.RequiresUnits(Proc: TGetStrProc);
begin

end;

{ TJanusManagerFDMemTableEditor }

procedure TJanusManagerFDMemTableEditor.RequiresUnits(Proc: TGetStrProc);
begin

end;

end.
