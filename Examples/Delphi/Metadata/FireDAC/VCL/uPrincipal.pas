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
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef, FireDAC.Stan.ExprFuncs, FireDAC.FMXUI.Wait,
  FireDAC.Phys.MSSQLDef, FireDAC.Phys.PGDef, FireDAC.Phys.MySQLDef,
  FireDAC.Phys.FBDef, FireDAC.Phys.IBDef, FireDAC.Phys.OracleDef,
  FireDAC.Phys.Oracle, FireDAC.Phys.IB, FireDAC.Phys.IBBase, FireDAC.Phys.FB,
  FireDAC.Phys.MySQL, FireDAC.Phys.PG, FireDAC.Phys.ODBCBase,
  FireDAC.Phys.MSSQL, FireDAC.Comp.UI, Data.DB, FireDAC.Comp.Client,
  Vcl.StdCtrls,
  /// orm factory
  DataEngine.FactoryInterfaces, // TJanusConnectionFireDAC
  DataEngine.FactoryFireDac,

  // BUG FIX (frente-8, 16 Jul 2026): this example connects both sides with
  // dnFirebird (see FormCreate below) but never referenced the two units
  // whose `initialization` sections register the Firebird driver into
  // TSQLDriverRegister/TMetadataRegister. With them absent from every uses
  // clause in this project, the linker drops them entirely, so at runtime
  // TDatabaseAbstract.Create raised "driver not registered" the first time
  // Button1Click ran. The sibling FMX example (Examples\Delphi\Metadata\
  // FireDAC\Firemonkey\uPrincipal.pas) already included them correctly - this
  // was a copy/paste gap between the two examples, not a MetaDbDiff bug.
  MetaDbDiff.DDL.Generator.Firebird,
  MetaDbDiff.Metadata.Firebird,

  MetaDbDiff.Database.Compare,  // TJanusDatabaseCompareLink
  MetaDbDiff.Database.Interfaces, // TJanusDatabaseCompareLink

  MetaDbDiff.DDL.Commands,

  FireDAC.Stan.Param, FireDAC.DatS, FireDAC.DApt.Intf,
  FireDAC.DApt, FireDAC.Comp.DataSet;

type
  TForm1 = class(TForm)
    Memo1: TMemo;
    Button1: TButton;
    FDGUIxWaitCursor1: TFDGUIxWaitCursor;
    FDPhysMSSQLDriverLink1: TFDPhysMSSQLDriverLink;
    FDPhysPgDriverLink1: TFDPhysPgDriverLink;
    FDPhysMySQLDriverLink1: TFDPhysMySQLDriverLink;
    FDPhysFBDriverLink1: TFDPhysFBDriverLink;
    FDPhysSQLiteDriverLink1: TFDPhysSQLiteDriverLink;
    FDPhysIBDriverLink1: TFDPhysIBDriverLink;
    FDPhysOracleDriverLink1: TFDPhysOracleDriverLink;
    FDConnection1: TFDConnection;
    FDConnection2: TFDConnection;
    Button2: TButton;
    FDMetaInfoQuery1: TFDMetaInfoQuery;
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
    oManager: IDatabaseCompare;
    oConnMaster: IDBConnection;
    oConnTarget: IDBConnection;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

uses
  MetaDbDiff.Database.Mapping;

{$R *.dfm}

procedure TForm1.FormCreate(Sender: TObject);
begin
  oConnMaster := TFactoryFireDAC.Create(FDConnection1, dnFirebird);
  oConnTarget := TFactoryFireDAC.Create(FDConnection2, dnFirebird);
end;

procedure TForm1.Button1Click(Sender: TObject);
var
  cDDL: TDDLCommand;
  sSuppressed: String;
begin
  oManager := TDatabaseCompare.Create(oConnMaster, oConnTarget);
  // CommandsAutoExecute now DEFAULTS TO FALSE (frente-8: generation is
  // decoupled from execution in MetaDbDiff's TDatabaseFactory.BuildDatabase),
  // so no explicit assignment is needed anymore to get preview-only behaviour
  // - BuildDatabase below always generates+builds the command text, it just
  // won't run any of it against oConnTarget. Set oManager.CommandsAutoExecute
  // := True before BuildDatabase (or call oManager.ExecuteCommands afterwards)
  // to actually apply the reviewed commands.
  oManager.BuildDatabase;
  for cDDL in oManager.GetCommandList do
      Memo1.Lines.Add(cDDL.Command);
  // oManager.SuppressedCommands lists every mutation the diff wanted to make
  // but the active Policy blocked (TDatabaseCompare defaults to
  // TComparePolicy.FullProfile, so nothing is suppressed here unless Policy
  // was narrowed - e.g. oManager.Policy := TComparePolicy.JanusOrmProfile).
  for sSuppressed in oManager.SuppressedCommands do
    Memo1.Lines.Add('(suppressed by policy) ' + sSuppressed);
end;

end.
