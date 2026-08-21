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

{
  @abstract(Janus Framework.)
  @created(20 Aug 2026)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
}

/// <summary> WHICH COLUMNS AN INSERT CARRIES, DECIDED ONCE. Issue #352.
///
///  WHY THIS UNIT EXISTS AT ALL. Two places used to answer this question and
///  they answered it differently. TDMLGeneratorAbstract.GeneratorInsert wrote
///  the COLUMN LIST of the statement; TCommandInserter.GenerateInsert built the
///  PARAMS for it. The generator skipped a column on four tests, the inserter
///  on those four AND on IsJoinColumn, and nothing downstream compared the two
///  answers. What that bought, measured against SQLite through the public
///  container API:
///
///    a marker with no param  - FireDAC's Params.Assign REPLACES the collection
///      it built from the SQL text, so the markers that survive are filled BY
///      POSITION. One column's value lands in ANOTHER COLUMN and nothing
///      raises. Reproduced with an EMPTY cache, on a single object, by a
///      [JoinColumn] that was not also NoInsert.
///    a param with no marker  - matched by name, dropped in silence. The
///      client's column is simply gone.
///
///  So the two loops are now ONE loop, and it lives here rather than in either
///  of them, because a shared function that lives in one of the two callers is
///  a shared function until someone edits its home.
///
///  THE SIGNATURE IS THE SECOND HALF OF THE SAME REPAIR. The statement a class
///  needs is not a property of the CLASS - it is a property of the OBJECT, and
///  two objects of one class disagree the moment one of them leaves an
///  optional column empty. Plan therefore returns, beside the list, a string
///  that says which columns this object contributed. GeneratorInsert caches
///  that string next to the SQL and takes the cache hit only when the object in
///  hand produces the same one.
///
///  WHY A BITMAP AND NOT A HASH. It is exact - there is no second pattern that
///  collides with it - and it costs one character per mapped column with no
///  allocation per column. A hash would need a collision story; a list of names
///  would cost the names. It is also readable in a debugger, which is what you
///  want from the value that decides whether a statement gets reused.
///
///  WHAT IT COSTS, MEASURED, AND WHY THE NUMBER IS A RATIO AND NOT A DURATION.
///  Over 20000 renders of a four-column entity against SQLite, on the tree at
///  723812a: Plan alone 0.0031 ms, a cache hit including Plan 0.0045 ms, a full
///  render with a fresh generator 0.0481 ms. So the repair costs roughly 0.0042
///  ms per insert over the old bare-key hit - about a fifteenth of what not
///  caching would cost, and far below any round trip a real database charges.
///
///  READ THE RATIO, NOT THE MILLISECONDS. The same harness on the same machine
///  put a full render at 0.0716 ms in one run and 0.0325 ms in another, so the
///  absolute figures move by a factor of two between runs and only numbers
///  taken in ONE run may be compared. The investigation predicted 0.0021 ms for
///  this work from a standalone IsNullValue sweep; the honest report is that
///  Plan measured 0.0031 ms here, which is HIGHER than that prediction - and
///  that the same standalone sweep measured 0.0049 ms in this run, which puts
///  Plan below the thing it replaces. The prediction was not wrong about the
///  work; the run it came from was faster.
///
///  IT IS NOT A CACHE KEY. The key stays ClassName + '-INSERT', one entry per
///  class, and the signature rides INSIDE the entry. Making it part of the key
///  would have made the dictionary grow with the number of null patterns a
///  class can produce - up to two to the power of its column count - and
///  falsified the bounded-growth note in Janus.DML.Cache, which is still true
///  as written. </summary>
unit Janus.DML.Insert.Columns;

interface

uses
  DB,
  SysUtils,
  Janus.Types.Blob,
  MetaDbDiff.Mapping.Classes,
  MetaDbDiff.Mapping.Explorer,
  MetaDbDiff.Rtti.Helper;

type
  /// <summary> The columns ONE object contributes to ONE insert, and the
  ///  fingerprint of that choice. Columns and Signature are produced by the
  ///  same pass and must never be built apart. </summary>
  TInsertColumnPlan = record
    Columns: TArray<TColumnMapping>;
    Signature: String;
  end;

  TInsertColumns = class
  private
    const cINCLUDED = '1';
    const cSKIPPED  = '0';
    /// The signature alphabet is '0' and '1', so this character cannot occur
    /// inside a signature and the FIRST one is always the separator.
    const cSEPARATOR = '|';
  public
    /// <summary> The single answer to "which columns does this object insert".
    ///  Returns False when the class has no column mapping at all, which is the
    ///  condition TCommandInserter.GenerateInsert reports with
    ///  cMESSAGECOLUMNNOTFOUND; the plan is empty in that case. </summary>
    class function Plan(const AObject: TObject;
      out APlan: TInsertColumnPlan): Boolean; static;
    /// <summary> Signature and SQL as one cache entry. </summary>
    class function Pack(const ASignature, ASQL: String): String; static;
    class function Unpack(const APacked: String;
      out ASignature, ASQL: String): Boolean; static;
  end;

implementation

{ TInsertColumns }

class function TInsertColumns.Plan(const AObject: TObject;
  out APlan: TInsertColumnPlan): Boolean;
var
  LColumns: TColumnMappingList;
  LColumn: TColumnMapping;
  LSignature: TStringBuilder;
  LKeep: Boolean;
begin
  APlan.Columns := nil;
  APlan.Signature := '';
  LColumns := TMappingExplorer.GetMappingColumn(AObject.ClassType);
  Result := LColumns <> nil;
  if not Result then
    Exit;

  LSignature := TStringBuilder.Create(LColumns.Count);
  try
    for LColumn in LColumns do
    begin
      try
        /// THE ORDER OF THESE TESTS IS THE ORDER THEY WERE WRITTEN IN, and the
        /// cheap ones stay in front: the blob test READS the value and
        /// materialises the bytes, so it must not run for a column an earlier
        /// test already rejected.
        LKeep := False;
        if Assigned(LColumn.ColumnProperty) then
          if not LColumn.ColumnProperty.IsNullValue(AObject) then
            if not LColumn.IsNoInsert then
              /// A join column is a value READ from another table. The inserter
              /// has never bound one and the base row has no business
              /// receiving it, so it is not in the statement either. Skipping
              /// it here cannot lose a value that used to be written: the
              /// param for it was never built.
              if not LColumn.IsJoinColumn then
                if not ((LColumn.FieldType in [ftBlob, ftGraphic, ftOraBlob,
                                               ftOraClob]) and
                        (Length(LColumn.ColumnProperty
                                       .GetNullableValue(AObject)
                                       .AsType<TBlob>.ToBytes) = 0)) then
                  LKeep := True;

        if LKeep then
        begin
          APlan.Columns := APlan.Columns + [LColumn];
          LSignature.Append(cINCLUDED);
        end
        else
          LSignature.Append(cSKIPPED);
      except
        on E: Exception do
          raise Exception.CreateFmt(
            'DIAG InsertColumnPlan column=%s class=%s msg=%s',
            [LColumn.ColumnName, AObject.ClassName, E.Message]);
      end;
    end;
    APlan.Signature := LSignature.ToString;
  finally
    LSignature.Free;
  end;
end;

class function TInsertColumns.Pack(const ASignature, ASQL: String): String;
begin
  Result := ASignature + cSEPARATOR + ASQL;
end;

class function TInsertColumns.Unpack(const APacked: String;
  out ASignature, ASQL: String): Boolean;
var
  LAt: Integer;
begin
  ASignature := '';
  ASQL := '';
  LAt := Pos(cSEPARATOR, APacked);
  Result := LAt > 0;
  if not Result then
    Exit;
  ASignature := Copy(APacked, 1, LAt - 1);
  ASQL := Copy(APacked, LAt + 1, Length(APacked) - LAt);
end;

end.
