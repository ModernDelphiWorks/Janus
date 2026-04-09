unit Janus.Link.Reg;

interface

uses
  Classes,
  DesignIntf,
  DesignEditors,
  Janus.Driver.Link.Firebird,
  Janus.Driver.Link.InterBase,
  Janus.Driver.Link.MongoDB,
  Janus.Driver.Link.Oracle,
  Janus.Driver.Link.MySQL,
  Janus.Driver.Link.MSSQL,
  Janus.Driver.Link.PostgreSQL,
  Janus.Driver.Link.SQLDirect,
  Janus.Driver.Link.SQLite;

type
  TJanusDriverEditorFirebird = class(TSelectionEditor)
  public
    procedure RequiresUnits(Proc: TGetStrProc); override;
  end;

  TJanusDriverEditorInterbase = class(TSelectionEditor)
  public
    procedure RequiresUnits(Proc: TGetStrProc); override;
  end;

  TJanusDriverEditorMSSQL = class(TSelectionEditor)
  public
    procedure RequiresUnits(Proc: TGetStrProc); override;
  end;

  TJanusDriverEditorMySQL = class(TSelectionEditor)
  public
    procedure RequiresUnits(Proc: TGetStrProc); override;
  end;

  TJanusDriverEditorOracle = class(TSelectionEditor)
  public
    procedure RequiresUnits(Proc: TGetStrProc); override;
  end;

  TJanusDriverEditorMongoDB = class(TSelectionEditor)
  public
    procedure RequiresUnits(Proc: TGetStrProc); override;
  end;

  TJanusDriverEditorPostgreSQL = class(TSelectionEditor)
  public
    procedure RequiresUnits(Proc: TGetStrProc); override;
  end;

  TJanusDriverEditorSQLite = class(TSelectionEditor)
  public
    procedure RequiresUnits(Proc: TGetStrProc); override;
  end;

  TJanusDriverEditorSQLDirect = class(TSelectionEditor)
  public
    procedure RequiresUnits(Proc: TGetStrProc); override;
  end;

procedure register;

implementation

procedure register;
begin
  RegisterComponents('Janus-Links', [TJanusDriverLinkFirebird,
                                     TJanusDriverLinkInterbase,
                                     TJanusDriverLinkMSSQL,
                                     TJanusDriverLinkMYSQL,
                                     TJanusDriverLinkOracle,
                                     TJanusDriverLinkMongoDB,
                                     TJanusDriverLinkPostgreSQL,
                                     TJanusDriverLinkSQLite,
                                     TJanusDriverLinkSQLDirect
                                    ]);
  RegisterSelectionEditor(TJanusDriverLinkFirebird, TJanusDriverEditorFirebird);
  RegisterSelectionEditor(TJanusDriverLinkInterbase, TJanusDriverEditorInterbase);
  RegisterSelectionEditor(TJanusDriverLinkMSSQL, TJanusDriverEditorMSSQL);
  RegisterSelectionEditor(TJanusDriverLinkMYSQL, TJanusDriverEditorMySQL);
  RegisterSelectionEditor(TJanusDriverLinkOracle, TJanusDriverEditorOracle);
  RegisterSelectionEditor(TJanusDriverLinkMongoDB, TJanusDriverEditorMongoDB);
  RegisterSelectionEditor(TJanusDriverLinkPostgreSQL, TJanusDriverEditorPostgreSQL);
  RegisterSelectionEditor(TJanusDriverLinkSQLite, TJanusDriverEditorSQLite);
  RegisterSelectionEditor(TJanusDriverLinkSQLDirect, TJanusDriverEditorSQLDirect);
end;

{ TJanusDriverEditorFirebird }

procedure TJanusDriverEditorFirebird.RequiresUnits(Proc: TGetStrProc);
begin
  Proc('Janus.DML.Generator.Firebird');
end;

{ TJanusDriverEditorMSSQL }

procedure TJanusDriverEditorMSSQL.RequiresUnits(Proc: TGetStrProc);
begin
  Proc('Janus.DML.Generator.MSSQL');
end;

{ TJanusDriverEditorMongoDB }

procedure TJanusDriverEditorMongoDB.RequiresUnits(Proc: TGetStrProc);
begin
  Proc('Janus.DML.Generator.MongoDB');
end;

{ TJanusDriverEditorOracle }

procedure TJanusDriverEditorOracle.RequiresUnits(Proc: TGetStrProc);
begin
  Proc('Janus.DML.Generator.Oracle');
end;

{ TJanusDriverEditorMySQL }

procedure TJanusDriverEditorMySQL.RequiresUnits(Proc: TGetStrProc);
begin
  Proc('Janus.DML.Generator.MySQL');
end;

{ TJanusDriverEditorPostgreSQL }

procedure TJanusDriverEditorPostgreSQL.RequiresUnits(Proc: TGetStrProc);
begin
  Proc('Janus.DML.Generator.PostgreSQL');
end;

{ TJanusDriverEditorInterbase }

procedure TJanusDriverEditorInterbase.RequiresUnits(Proc: TGetStrProc);
begin
  Proc('Janus.DML.Generator.InterBase');
end;

{ TJanusDriverEditorSQLite }

procedure TJanusDriverEditorSQLite.RequiresUnits(Proc: TGetStrProc);
begin
  Proc('Janus.DML.Generator.SQLite');
end;

{ TJanusDriverEditorSQLDirect }

procedure TJanusDriverEditorSQLDirect.RequiresUnits(Proc: TGetStrProc);
begin
  Proc('Janus.DML.Generator.sqldirect');
end;

end.
