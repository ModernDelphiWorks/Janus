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

{ @abstract(Janus Framework - the foreign-key filter of #295 over an
  association that REALLY EXISTS in this repository and whose child end is a
  ftBCD column. Issue #319.)

  THIS FIXTURE EXISTS BECAUSE OF A SENTENCE, NOT BECAUSE OF A DEFECT. The
  comment over TDataSetBaseAdapter<M>._FieldValuesMatch carried two claims that
  were not measurements and were not true:

    "ftBCD e ftFMTBcd FICAM NO AsString DE PROPOSITO ... NAO MEDIDO tambem:
     nenhum modelo do repositorio declara essa associacao."

    "O RAMO SO VALE COM OS DOIS LADOS NA MESMA FAMILIA. Par de tipos DIFERENTES
     cai no fundo, o que e a resposta conservadora e NAO ESTA MEDIDO - nao se
     procurou um modelo assim, e por isso aqui nao se afirma que nao existe."

  Both are falsified by ONE association, and it is the same one:

    Examples\Delphi\Data\Object Lazy\Model.Procedimento.pas
      [Association(TMultiplicity.OneToMany,'SETOR','SETORES','SETOR',True)]
      over  [Column('SETOR', ftInteger)]
    Examples\Delphi\Data\Object Lazy\Model.Setor.pas
      [Column('SETOR', ftBCD, 8, 0)]

  Both units are already linked into Janus.Tests.Units.dpr. Nothing had to be
  invented for this clause; what was missing was the clause.

  THE PAIR IS MIXED, AND THAT IS THE POINT. The master end is ftInteger and the
  child end is ftBCD, so this association does NOT drive a "both sides BCD"
  comparison - it drives the AsString BOTTOM, through the DIFFERENT-FAMILIES
  route the second sentence above said had never been looked for. So the
  correction to the comment is not "there is a BCD association after all, go
  and write the typed branch": it is that the repository ships an association
  whose ends are of different families, one of them BCD, and that shape now has
  a clause instead of two paragraphs saying nobody looked.

  WHAT IT DOES NOT SAY. It does not measure a ftBCD-to-ftBCD pair, because no
  model in the repository declares one, and inventing an entity to pin a branch
  that deliberately does not exist would be the alarm the comment already warns
  against. The reason the comment gives for BCD staying on AsString - that for
  a BCD the TEXT is the exact representation and any conversion to binary
  floating point would lose digits the BCD keeps - is untouched by this fixture
  and is not what #319 was about.

  TWO MASTER ROWS, ALWAYS. With ONE master row the walk takes the single-row
  slack in _ExecuteOneToMany and admits every child without asking anything, so
  a fixture with one master row would be green with the filter deleted.

  THIS FIXTURE WAS GREEN ON HEAD THE DAY IT WAS WRITTEN, and that is not a
  failure of red-first - #319 is a false SENTENCE, not a defect. What has to be
  shown instead is that the clauses are load-bearing, and the mutations were
  run with a MESSAGE WARN directive dcc32 echoed as W1054 in the same build:

    b1  the AsString bottom replaced by `Result := True`
        -> 10 red of 608. Three of them are this fixture's; the other seven
           belong to Test.Janus.Grandchild.Read, so b1 alone does NOT show that
           anything here is defended by these clauses and by nothing else.
    b2  the bottom given a SAME-FAMILY precondition -
        `(AMasterField.DataType = AChildField.DataType) and (...)`
        -> 3 red of 608, and they are exactly
           ABcdChildColumn_IsClaimedOnlyByItsOwnMaster,
           ..._ReversedRowOrder and ABcdChildColumnNoMasterNames_IsClaimedByNobody.
           Nothing else in any suite notices. That is the measurement that says
           the MIXED-FAMILY route through _FieldValuesMatch had no clause at all
           before this file, which is the whole of #319.

  The premise clause is not in either list because it reads the FIELD TYPES and
  not the walk; it goes red only if the models change.
}

unit Test.Janus.Association.BcdColumn;

interface

uses
  DB,
  Classes,
  SysUtils,
  Generics.Collections,
  DUnitX.TestFramework,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Param,
  FireDAC.Stan.Error,
  FireDAC.DatS,
  FireDAC.Phys.Intf,
  FireDAC.DApt.Intf,
  FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,
  DataEngine.FactoryInterfaces,
  Janus.DataSet.Base.Adapter,
  Janus.Container.FDMemTable,
  Janus.DataSet.FDMemTable,
  Janus.DML.Generator.SQLite,
  Model.Procedimento,
  Model.Setor,
  Test.Janus.Cursor.Double;

type
  TBcdScrollMute = record
    Before: TDataSetNotifyEvent;
    After: TDataSetNotifyEvent;
  end;

  [TestFixture]
  TTestAssociationBcdColumn = class
  private
    FConn: IDBConnection;
    FProcTable: TFDMemTable;
    FSetorTable: TFDMemTable;
    FProc: TFDMemTableAdapter<TProcedimento>;
    FSetor: TFDMemTableAdapter<TSetor>;
    procedure BuildPair;
    procedure AddProcedimento(const AMnemonico: String; const ASetor: Integer);
    procedure AddSetor(const ASetor: Double; const ANome: String);
    /// Parks on the SECOND master row and reports which SETOR rows that master
    /// object came back carrying. The SECOND and not the first, for the reason
    /// the sibling fixture gives: parked on the first, a repair that simply
    /// handed everyone the FIRST master's children would pass.
    function SetorNamesOfTheSecondProcedimento: String;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// THE PREMISE, and it is not decoration: if the two ends were not the
    /// types this fixture claims, everything below would measure some other
    /// question. Read off the FIELDS the ORM built from the mapping, not off
    /// the attributes.
    [Test]
    procedure Premise_TheTwoEndsAreOfDifferentFamiliesAndOneIsBcd;
    /// The claim the comment said had never been measured. Each master must
    /// come back carrying ITS OWN sector row and no other.
    [Test]
    procedure ABcdChildColumn_IsClaimedOnlyByItsOwnMaster;
    /// And the same walk with the child rows in the OPPOSITE order, so a filter
    /// that happens to keep the LAST row read cannot pass by luck.
    [Test]
    procedure ABcdChildColumn_IsClaimedOnlyByItsOwnMaster_ReversedRowOrder;
    /// A BCD value the master's Integer end can never equal must be claimed by
    /// NOBODY. This is the half of the comparison the clause above cannot see:
    /// it asserts what arrives, this one asserts what does not.
    [Test]
    procedure ABcdChildColumnNoMasterNames_IsClaimedByNobody;
  end;

implementation

const
  cMNEMONICO = 'MNEMONICO';
  cNOME      = 'NOME';
  cSETOR     = 'SETOR';
  cPROC      = 'PROCEDIMENTO';

function MuteBcdScroll(const ADataSet: TDataSet): TBcdScrollMute;
begin
  Result.Before := ADataSet.BeforeScroll;
  Result.After := ADataSet.AfterScroll;
  ADataSet.BeforeScroll := nil;
  ADataSet.AfterScroll := nil;
end;

procedure UnmuteBcdScroll(const ADataSet: TDataSet;
  const AMute: TBcdScrollMute);
begin
  ADataSet.BeforeScroll := AMute.Before;
  ADataSet.AfterScroll := AMute.After;
end;

{ TTestAssociationBcdColumn }

procedure TTestAssociationBcdColumn.Setup;
begin
  // Zero rows: any re-query the walk fires hands the child back EMPTY, which is
  // the sharpest possible statement that what the master carries came from the
  // rows in memory and not from a fetch.
  FConn := TRowsConnection.Create(dnSQLite, 0,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add(cSETOR, ftInteger);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName(cSETOR).AsInteger := AIndex;
    end,
    'bcd-association');
end;

procedure TTestAssociationBcdColumn.TearDown;
begin
  FreeAndNil(FSetor);
  FreeAndNil(FProc);
  FreeAndNil(FSetorTable);
  FreeAndNil(FProcTable);
  FConn := nil;
end;

procedure TTestAssociationBcdColumn.BuildPair;
begin
  FProcTable := TFDMemTable.Create(nil);
  FProc := TFDMemTableAdapter<TProcedimento>.Create(FConn, FProcTable, -1, nil);
  FSetorTable := TFDMemTable.Create(nil);
  FSetor := TFDMemTableAdapter<TSetor>.Create(FConn, FSetorTable, -1, FProc);
end;

procedure TTestAssociationBcdColumn.AddProcedimento(const AMnemonico: String;
  const ASetor: Integer);
begin
  FProcTable.Append;
  FProcTable.FieldByName(cMNEMONICO).AsString := AMnemonico;
  FProcTable.FieldByName(cNOME).AsString := 'P' + AMnemonico;
  FProcTable.FieldByName(cPROC).AsFloat := ASetor;
  FProcTable.FieldByName(cSETOR).AsInteger := ASetor;
  FProcTable.Post;
end;

procedure TTestAssociationBcdColumn.AddSetor(const ASetor: Double;
  const ANome: String);
begin
  FSetorTable.Append;
  FSetorTable.FieldByName(cSETOR).AsFloat := ASetor;
  FSetorTable.FieldByName(cNOME).AsString := ANome;
  FSetorTable.Post;
end;

function TTestAssociationBcdColumn.SetorNamesOfTheSecondProcedimento: String;
var
  LMaster: TProcedimento;
  LChild: TSetor;
  LMute: TBcdScrollMute;
begin
  LMute := MuteBcdScroll(FProcTable);
  try
    FProcTable.Last;
  finally
    UnmuteBcdScroll(FProcTable, LMute);
  end;
  LMaster := FProc.Current;
  Assert.AreEqual('M2', LMaster.MNEMONICO,
    'premise: the read really bound the SECOND master row');
  Result := '';
  for LChild in LMaster.SetoresList do
    Result := Result + LChild.NOME + ';';
end;

procedure TTestAssociationBcdColumn.Premise_TheTwoEndsAreOfDifferentFamiliesAndOneIsBcd;
begin
  BuildPair;
  Assert.AreEqual(Ord(ftInteger), Ord(FProcTable.FieldByName(cSETOR).DataType),
    'premise: the MASTER end of the association is ftInteger');
  Assert.AreEqual(Ord(ftBCD), Ord(FSetorTable.FieldByName(cSETOR).DataType),
    'premise: the CHILD end is ftBCD - this is the model the comment said the ' +
    'repository did not have');
end;

procedure TTestAssociationBcdColumn.ABcdChildColumn_IsClaimedOnlyByItsOwnMaster;
begin
  BuildPair;
  AddProcedimento('M1', 1);
  AddProcedimento('M2', 2);
  AddSetor(1, 'S1');
  AddSetor(2, 'S2');
  Assert.AreEqual('S2;', SetorNamesOfTheSecondProcedimento, False,
    'the second PROCEDIMENTO must carry only the SETOR row whose ftBCD key ' +
    'matches its own ftInteger one - a MIXED-family pair, which is the shape ' +
    'the comment declared as never looked for');
end;

procedure TTestAssociationBcdColumn.ABcdChildColumn_IsClaimedOnlyByItsOwnMaster_ReversedRowOrder;
begin
  BuildPair;
  AddProcedimento('M1', 1);
  AddProcedimento('M2', 2);
  AddSetor(2, 'S2');
  AddSetor(1, 'S1');
  Assert.AreEqual('S2;', SetorNamesOfTheSecondProcedimento, False,
    'and the answer must not depend on which order the child rows were typed');
end;

procedure TTestAssociationBcdColumn.ABcdChildColumnNoMasterNames_IsClaimedByNobody;
begin
  BuildPair;
  AddProcedimento('M1', 1);
  AddProcedimento('M2', 2);
  AddSetor(2, 'S2');
  AddSetor(7, 'S7');
  Assert.AreEqual('S2;', SetorNamesOfTheSecondProcedimento, False,
    'a SETOR row no PROCEDIMENTO names must be claimed by nobody - a row given ' +
    'to the wrong parent is invisible, a row given to no parent is not');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestAssociationBcdColumn);

end.
