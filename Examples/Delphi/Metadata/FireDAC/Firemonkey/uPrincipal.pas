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

unit uPrincipal;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls, FireDAC.Stan.Intf,
  FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys,
  FireDAC.FMXUI.Wait, FireDAC.Phys.MSSQLDef, FMX.ScrollBox, FMX.Memo,
  FireDAC.Phys.ODBCBase, FireDAC.Phys.MSSQL, FireDAC.Comp.UI, Data.DB,
  FireDAC.Comp.Client, FireDAC.DApt,

  /// orm factory
  DataEngine.FactoryInterfaces,
  DataEngine.FactoryFireDac,
  MetaDbDiff.DDL.Generator.Firebird,
  MetaDbDiff.Metadata.Firebird,
  MetaDbDiff.DDL.Commands,
  MetaDbDiff.Database.Compare,
  MetaDbDiff.Database.Interfaces,
  Janus.ModelDB.Compare,

  FireDAC.Phys.FB, FireDAC.Phys.FBDef, FireDAC.Phys.MySQL,
  FireDAC.Phys.MySQLDef, FireDAC.Stan.Param, FireDAC.DatS, FireDAC.DApt.Intf,
  FireDAC.Phys.MongoDBDataSet, FireDAC.Comp.DataSet, FireDAC.Phys.PG,
  FireDAC.Phys.PGDef, FireDAC.Stan.ExprFuncs, FireDAC.Phys.SQLiteDef,
  FireDAC.Phys.IBDef, FireDAC.Phys.IB, FireDAC.Phys.SQLite, FireDAC.Phys.IBBase,
  Data.DBXMSSQL, Data.FMTBcd, Data.SqlExpr, FireDAC.Comp.ScriptCommands,
  FireDAC.Stan.Util, FireDAC.Comp.Script, FireDAC.Phys.Oracle,
  FireDAC.Phys.OracleDef, FMX.Memo.Types;

type
  TForm4 = class(TForm)
    Button1: TButton;
    FDGUIxWaitCursor1: TFDGUIxWaitCursor;
    FDPhysMSSQLDriverLink1: TFDPhysMSSQLDriverLink;
    Memo1: TMemo;
    FDPhysPgDriverLink1: TFDPhysPgDriverLink;
    FDPhysMySQLDriverLink1: TFDPhysMySQLDriverLink;
    FDPhysFBDriverLink1: TFDPhysFBDriverLink;
    FDPhysSQLiteDriverLink1: TFDPhysSQLiteDriverLink;
    FDPhysIBDriverLink1: TFDPhysIBDriverLink;
    FDPhysOracleDriverLink1: TFDPhysOracleDriverLink;
    FDConnection1: TFDConnection;
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
    oManager: TModelDbCompare;
    oConnection: IDBConnection;
  public
    { Public declarations }
  end;

var
  Form4: TForm4;

implementation

{$R *.fmx}

procedure TForm4.Button1Click(Sender: TObject);
var
  cDDL: TDDLCommand;
begin
  oManager := TModelDbCompare.Create(oConnection);
//  oManager := TDatabaseCompare.Create(oConnection, oConnection);
  // CommandsAutoExecute now DEFAULTS TO FALSE (frente-8: generation is
  // decoupled from execution in MetaDbDiff's TDatabaseFactory.BuildDatabase),
  // so this assignment is only kept here as documentation of intent - preview
  // only, nothing gets executed against oConnection. Also note oManager's
  // Policy defaults to TComparePolicy.JanusOrmProfile (set by TModelDbCompare's
  // constructor): the command list below will only ever contain CREATE TABLE /
  // CREATE COLUMN / CREATE PRIMARY KEY / CREATE FOREIGN KEY, never a DROP or
  // ALTER - see Janus.ModelDB.Compare.pas' header for how to opt back into
  // TComparePolicy.FullProfile, and oManager.SuppressedCommands for what the
  // restricted policy blocked.
  oManager.CommandsAutoExecute := False;
  oManager.BuildDatabase;
  for cDDL in oManager.GetCommandList do
      Memo1.Lines.Add(cDDL.Command);
end;

procedure TForm4.FormCreate(Sender: TObject);
begin
  // Inst�ncia da class de conex�o via FireDAC
  oConnection := TFactoryFireDAC.Create(FDConnection1, dnFirebird);
end;

end.
