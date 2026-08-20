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
  // ISSUE #340 - NO Proc(...) HERE, AND THAT IS THE FIX.
  //
  // This used to call Proc with the literal 'Janus.DML.Generator.sqldirect',
  // naming a unit that does not exist anywhere in this repository (git ls-tree confirmed
  // 0 hits on origin/develop). The IDE would write that dead name into the
  // uses clause of whoever dropped TJanusDriverLinkSQLDirect on a form -
  // a uses clause that does not compile, in the CONSUMER's own project.
  //
  // RENAMING WAS CONSIDERED AND RULED OUT BY MEASUREMENT. Every one of the
  // other eight Janus-Links components (Firebird, InterBase, MSSQL, MySQL,
  // Oracle, MongoDB, PostgreSQL, SQLite) names ONE fixed SQL dialect, and
  // each RequiresUnits body below correctly points at that dialect's own
  // TDMLGeneratorXXX unit - confirmed by reading every one of the seven
  // surviving Janus.DML.Generator.*.pas units' `initialization` block,
  // which registers the matching TDriverName (e.g.
  // Janus.DML.Generator.Firebird.pas:206 registers dnFirebird,
  // Janus.DML.Generator.MSSQL.pas:231 registers dnMSSQL, and so on for all
  // seven). SQLDirect is not that: it is a third-party DATA ACCESS layer,
  // not a dialect. TDriverName (DataEngine.FactoryInterfaces.pas:50-53) has
  // no dnSQLDirect member at all, and Examples\Delphi\Data\SQLDirect\
  // uMainFormORM.pas:154 shows the factory taking the dialect as an
  // explicit PARAMETER - `TFactorySQLDirect.Create(SDDatabase1, dnFirebird)`
  // - with that same example importing Janus.DML.Generator.Firebird, not
  // any SQLDirect-specific generator. A SQLDirect-based project can target
  // ANY of the seven dialects above; which generator it needs is a fact
  // about the connection the DEVELOPER configures, not about the
  // TJanusDriverLinkSQLDirect component, so no single fixed unit name could
  // ever be correct here. Janus.Driver.Link.SQLDirect.pas itself confirms
  // this: like all nine siblings it is an empty TComponent marker with no
  // TDriverName property to read a dialect from.
  //
  // Leaving RequiresUnits empty is therefore not "unfinished" - it is
  // answering honestly that this component carries no fixed dialect
  // dependency to auto-require. A developer using SQLDirect against, say,
  // Firebird still gets the correct unit by also dropping
  // TJanusDriverLinkFirebird (or by adding the generator unit by hand),
  // exactly as every SQLDirect example in this repository already does.
  //
  // Guarded by Test.Janus.LinkReg.RequiresUnits.EveryRequiredUnitEqualsAFileUnderSource
  // (Test\Delphi\Unit\Core\Test.Janus.LinkReg.RequiresUnits.pas), which reads
  // every Proc(...) argument in this file and asserts a matching .pas exists
  // under Source\ - RED against the line this comment replaces, GREEN now
  // that it is gone.
end;

end.
