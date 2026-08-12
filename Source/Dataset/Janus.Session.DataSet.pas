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
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
}

unit Janus.Session.DataSet;

interface

uses
  DB,
  Rtti,
  TypInfo,
  Classes,
  Variants,
  SysUtils,
  Generics.Collections,
  /// Janus
  Janus.Command.Executor,
  Janus.Session.Abstract,
  Janus.DataSet.Base.Adapter,
  // MetaDbDiff
  MetaDbDiff.mapping.classes,
  DataEngine.FactoryInterfaces;

type
  TSessionDataSet<M: class, constructor> = class(TSessionAbstract<M>)
  private
    FOwner: TDataSetBaseAdapter<M>;
    procedure _PopularDataSet(const ADBResultSet: IDBDataSet);
  protected
    FConnection: IDBConnection;
  public
    constructor Create(const AOwner: TDataSetBaseAdapter<M>;
      const AConnection: IDBConnection; const APageSize: Integer = -1); overload;
    destructor Destroy; override;
    procedure OpenID(const AID: TValue); override;
    procedure OpenSQL(const ASQL: String); override;
    procedure OpenWhere(const AWhere: String; const AOrderBy: String = ''); override;
    procedure NextPacket; override;
    procedure RefreshRecord(const AColumns: TParams); override;
    procedure RefreshRecordWhere(const AWhere: String); override;
    function SelectAssociation(const AObject: TObject): String; override;
  end;

const
  /// The colons and the T are quoted, and THE REASON THIS COMMENT USED TO GIVE
  /// WAS FALSE. It said an unquoted ':' "would come out swapped by the ambient
  /// locale" - which cannot happen, because TFormatSettings.Invariant is passed
  /// to every FormatDateTime call below and Invariant's TimeSeparator IS ':'.
  /// The two protections are REDUNDANT, and that is measured rather than
  /// argued: unquoting the colons alone kills nothing, dropping Invariant alone
  /// kills nothing, and doing BOTH turns a clause red. The four single
  /// mutations and the combined one are tabled in
  /// Test.Janus.RefreshRecord.KeyLiteral. Both are KEPT, because each is one
  /// edit away from being the only one left; what is removed is a reason that
  /// read like a measurement and was not one - the same class of defect #319
  /// corrected two files away.
  cISODATE     = 'yyyy-mm-dd';
  cISODATETIME = 'yyyy-mm-dd"T"hh":"nn":"ss';
  cISOTIME     = 'hh":"nn":"ss';
  /// The house's own idiom for a key that cannot identify a row - the same one
  /// Janus.DML.Generator and Janus.Server.Resource emit for an undetermined
  /// association value.
  cNOROWSGUARD = '1 = 0';

/// <summary> DECLARED IN THE INTERFACE SECTION, AND NOT BY CHOICE OF STYLE.
///  RefreshRecord is a method of a PARAMETERIZED type declared in the
///  interface section, and such a method may not name a symbol that lives
///  after `implementation`: dcc32 answers E2506 "Method of parameterized type
///  declared in interface section must not use local symbol '_KeyLiteral'" -
///  measured, twice in the same build, once for the function (which carried
///  the house's private-helper underscore at that moment, and lost it BECAUSE
///  of this error) and once for cNOROWSGUARD. An
///  untyped STRING constant does not escape it either, which is where this
///  differs from the cNoRowToken note in Janus.DataSet.Base.Adapter: that one
///  is an untyped INTEGER constant and the compiler folds it to a literal.
///
///  The side effect is worth naming, because it is the opposite of the two
///  siblings: this table is EXPORTED, so unlike _FilterLiteral and
///  _PrimaryKeyValueToSql it can be called - and therefore compared - from
///  another unit. </summary>
function KeyLiteralToSql(const AParam: TParam): String;

implementation

uses
  StrUtils,
  Janus.Bind;

/// <summary> THE VALUE OF ONE KEY COLUMN, IN THE FORM IT CAN ENTER A WHERE.
///  Issue #327.
///
///  WHAT IT REPLACES: TSessionDataSet&lt;M&gt;.RefreshRecord used to spell every
///  term as Name + '=' + AColumns[LFor].AsString - the value RAW, with no
///  quotes and no dispatch by type. Measured on the tree before this commit,
///  through the connection double's own SQL spy:
///
///    ... FROM rrtext   WHERE rtkey=A-1          (no dialect parses it)
///    ... FROM rrtext   WHERE rtkey=O'Brien      (the string ends mid-statement)
///    ... FROM rrdate   WHERE rdkey=11/08/2026   (the machine's ShortDateFormat)
///    ... FROM rrfloat  WHERE rfkey=10,5         (the machine's DecimalSeparator)
///    ... FROM rrbool   WHERE rbkey=True         (the bare Variant token)
///    ... FROM rrtext   WHERE rtkey=             (a NULL key: syntax error)
///
///  and the one shape it got right, kept green on purpose:
///
///    ... FROM rrint    WHERE rikey=7
///
///  THE VALUE HERE IS NOT A CONSUMER'S JSON, and that is the ONE difference
///  from the REST sibling this table follows. TDataSetBaseAdapter&lt;M&gt;.RefreshRecord
///  fills the TParams from the dataset's OWN fields, so nothing a remote caller
///  typed reaches this string directly and the injection reading of #320 is
///  weaker on this side. The BREAKAGE and the SILENCE are identical, and an
///  apostrophe typed into a text key by an operator is not remote.
///
///  THIS IS THE THIRD DISPATCH TABLE IN THE HOUSE AND IT WAS NOT ADDED BLIND.
///  Reusing either of the two that already existed was MEASURED, and both
///  answers are compiler errors. With Janus.RestDataSet.Adapter and
///  Janus.Server.Resource added to this unit's implementation uses and one call
///  to each written into RefreshRecord, dcc32 (Studio 37, Win32, Debug)
///  answered E2003 "Undeclared identifier: '_PrimaryKeyValueToSql'" - the
///  server's table is a unit-level routine declared after `implementation`, so
///  it is not exported at all - and E2361 "Cannot access private symbol
///  TRESTDataSetAdapter&lt;...&gt;._FilterLiteral" - the client's table is a private
///  method of a generic class, and Delphi's unit-scoped friendship does not
///  cross a unit boundary. Widening a visibility section would not be enough
///  either: the three sites hold three DIFFERENT things. The client reads a
///  TField, the server reads a TColumnMapping plus the object, and this one
///  holds a TParam.
///
///  SO THE DIVERGENCE IS DECLARED RATHER THAN CLOSED, AND IT IS DECLARED
///  AGAINST THE READING OF BOTH AT THIS COMMIT. This table is label-for-label
///  the SERVER's - the newest and most complete of the two - so a future
///  unification faces two agreeing tables and one outlier instead of a
///  three-way disagreement. The outlier is the CLIENT's _FilterLiteral, which
///  has no ftBoolean branch, puts ftDate and ftDateTime on ONE case ARM - and
///  then picks between cISODATE and cISODATETIME INSIDE that arm with an
///  ifThen, so what is fused is the BRANCH and not the mask, which an earlier
///  version of this sentence got wrong - carries neither DB.ftSingle nor
///  DB.ftExtended on its decimal branch,
///  and passes no TFormatSettings to FormatDateTime. Unifying the three means
///  a new shared unit under Source\Core AND a change of behaviour at that
///  client site, which belongs to the RESTful client family and is not this
///  issue's to make.
///
///  NOTHING ANYWHERE COMPARES THE THREE TABLES TO EACH OTHER, and no clause
///  added here does either - it cannot, because two of the three are
///  unreachable from a test unit for exactly the reasons measured above. What
///  is written down is a reading, and a reading goes stale.
///
///  DB.ftSingle AND DB.ftExtended ARE QUALIFIED, and not for style: TypInfo
///  declares a TFloatType whose members carry the SAME NAMES and it comes
///  after DB in this unit's uses, so the short name resolves to the wrong
///  enumerated type. Janus.DataSet.Base.Adapter records the same measurement
///  (E2010 'TFieldType' and 'TFloatType') for the same two labels.
///
///  THE EMPTY RESULT IS A SIGNAL, NOT A LITERAL. A key column the row left
///  NULL cannot identify a row and must not be allowed to identify an
///  arbitrary one; it comes back as '' and the caller replaces the WHOLE
///  predicate with cNOROWSGUARD. A partially determined key is not a weaker
///  key, it is no key.
///
///  WHICH LABELS ARE DEFENDED BY A CLAUSE, and which are only grouped by
///  argument: Test.Janus.RefreshRecord.KeyLiteral reaches ftString (plain and
///  quote-bearing), ftDate, ftDateTime, ftTime, ftFloat, DB.ftSingle,
///  DB.ftExtended, ftBoolean, ftInteger, a composite ftInteger + ftString key
///  and a composite ftDateTime + ftTime one. ftWideString, ftMemo, ftWideMemo,
///  ftFmtMemo, ftGuid, ftTimeStamp, ftOraTimeStamp, ftCurrency, ftBCD and
///  ftFMTBcd share a branch with a defended label and have no model of their
///  own under Test\ whose PRIMARY KEY carries them, so they are grouped by
///  argument and NOT measured.
///
///  THIS LIST HAS BEEN WRONG TWICE, IN THE SAME DIRECTION, AND BOTH TIMES
///  BECAUSE OF A LATER COMMIT OF THE SAME BRANCH. It named DB.ftExtended as
///  grouped-by-argument after TRefreshExtendedKey had already been written for
///  it, and ftDateTime / ftTime after TRefreshMomentKey had. A list of what is
///  NOT measured is a claim about the whole of Test\, so it goes stale from the
///  other side - nobody editing the fixture thinks to come back here.
///
///  THE DIALECT RESIDUE IS THE SAME ONE THE SERVER SIDE DECLARED. ISO-8601 is
///  not every dialect's date literal - TDMLGeneratorAbstract.FDateFormat holds
///  the dialect-correct mask and is not reachable from this layer, which sees
///  an IDBConnection and a command executor and nothing that exposes the
///  generator. On a dialect whose FDateFormat differs, a date key is now a
///  WELL-FORMED literal that finds nothing instead of a malformed statement.
///  That is an improvement and not a repair, and closing it means a new method
///  on IDMLGeneratorCommand - a contract change. </summary>
function KeyLiteralToSql(const AParam: TParam): String;
var
  LValue: Variant;
begin
  LValue := AParam.Value;
  if VarIsNull(LValue) or VarIsEmpty(LValue) then
    Exit('');
  case AParam.DataType of
    ftString, ftWideString, ftMemo, ftWideMemo, ftFmtMemo, ftGuid:
      Result := QuotedStr(VarToStr(LValue));
    ftDate:
      Result := QuotedStr(FormatDateTime(cISODATE, VarToDateTime(LValue),
                                         TFormatSettings.Invariant));
    ftDateTime:
      Result := QuotedStr(FormatDateTime(cISODATETIME, VarToDateTime(LValue),
                                         TFormatSettings.Invariant));
    ftTime, ftTimeStamp, ftOraTimeStamp:
      Result := QuotedStr(FormatDateTime(cISOTIME, VarToDateTime(LValue),
                                         TFormatSettings.Invariant));
    /// A numeric literal, and the decimal separator has to be the SQL one and
    /// not the machine's: VarToStr follows the ambient DecimalSeparator for
    /// varDouble, varSingle and varCurrency.
    ftCurrency, ftBCD, ftFMTBcd, ftFloat, DB.ftSingle, DB.ftExtended:
      Result := ReplaceStr(VarToStr(LValue), ',', '.');
    /// VarToStr renders a boolean as the bare token True, which is the very
    /// shape this repair exists to stop emitting.
    ftBoolean:
      Result := IfThen(Boolean(LValue), '1', '0');
  else
    /// Integer, 64-bit and unsigned 64-bit keys leave as bare digits - the one
    /// family the raw concatenation already got right.
    Result := VarToStr(LValue);
  end;
end;

{ TSessionDataSet<M> }

constructor TSessionDataSet<M>.Create(const AOwner: TDataSetBaseAdapter<M>;
  const AConnection: IDBConnection; const APageSize: Integer);
begin
  inherited Create(APageSize);
  FOwner := AOwner;
  FConnection := AConnection;
  FCommandExecutor := TSQLCommandExecutor<M>.Create(Self, AConnection, APageSize);
end;

destructor TSessionDataSet<M>.Destroy;
begin
  FCommandExecutor.Free;
  inherited;
end;

function TSessionDataSet<M>.SelectAssociation(const AObject: TObject): String;
begin
  inherited;
  Result := FCommandExecutor.SelectInternalAssociation(AObject);
end;

procedure TSessionDataSet<M>.OpenID(const AID: TValue);
var
  LDBResultSet: IDBDataSet;
begin
  inherited;
  LDBResultSet := FCommandExecutor.SelectInternalID(AID);
  _PopularDataSet(LDBResultSet);
end;

procedure TSessionDataSet<M>.OpenSQL(const ASQL: String);
var
  LDBResultSet: IDBDataSet;
begin
  inherited;
  if ASQL = '' then
    LDBResultSet := FCommandExecutor.SelectInternalAll
  else
    LDBResultSet := FCommandExecutor.SelectInternal(ASQL);
  _PopularDataSet(LDBResultSet);
end;

procedure TSessionDataSet<M>.OpenWhere(const AWhere: String;
  const AOrderBy: String);
begin
  inherited;
  OpenSQL(FCommandExecutor.SelectInternalWhere(AWhere, AOrderBy));
end;

procedure TSessionDataSet<M>.RefreshRecord(const AColumns: TParams);
var
  LDBResultSet: IDBDataSet;
  LWhere: String;
  LLiteral: String;
  LFor: Integer;
begin
  inherited;
  LWhere := '';
  for LFor := 0 to AColumns.Count -1 do
  begin
    // The value goes through KeyLiteralToSql - quoted, formatted and dispatched by
    // type - instead of the raw AsString this loop used to concatenate. See
    // the header of KeyLiteralToSql for what the raw form emitted and why the two
    // sibling tables could not be reused here. Issue #327.
    LLiteral := KeyLiteralToSql(AColumns[LFor]);
    if LLiteral = '' then
    begin
      // A key column the row left undetermined cannot identify a row, and a
      // partially determined key is no key: the WHOLE predicate becomes the
      // zero-rows guard rather than naming the columns that DO have a value.
      LWhere := cNOROWSGUARD;
      Break;
    end;
    LWhere := LWhere + AColumns[LFor].Name + '=' + LLiteral;
    if LFor < AColumns.Count -1 then
      LWhere := LWhere + ' AND ';
  end;
  LDBResultSet := FCommandExecutor.SelectInternal(FCommandExecutor.SelectInternalWhere(LWhere, ''));
  while not LDBResultSet.Eof do
  begin
    FOwner.FOrmDataSet.Edit;
    Bind.SetFieldToField(LDBResultSet, FOwner.FOrmDataSet);
    FOwner.FOrmDataSet.Post;
    // Avanca o cursor: sem isso o laco nunca atinge Eof e reaplica a mesma
    // linha infinitamente (loop infinito / hang).
    LDBResultSet.Next;
  end;
end;

procedure TSessionDataSet<M>.RefreshRecordWhere(const AWhere: String);
var
  LDBResultSet: IDBDataSet;
begin
  inherited;
  LDBResultSet := FCommandExecutor.SelectInternal(FCommandExecutor.SelectInternalWhere(AWhere, ''));
  while not LDBResultSet.Eof do
  begin
    FOwner.FOrmDataSet.Edit;
    Bind.SetFieldToField(LDBResultSet, FOwner.FOrmDataSet);
    FOwner.FOrmDataSet.Post;
    // Avanca o cursor: sem isso o laco nunca atinge Eof e reaplica a mesma
    // linha infinitamente (loop infinito / hang).
    LDBResultSet.Next;
  end;
end;

procedure TSessionDataSet<M>.NextPacket;
var
  LDBResultSet: IDBDataSet;
begin
  inherited;
  LDBResultSet := FCommandExecutor.NextPacket;
  if LDBResultSet.RecordCount > 0 then
    _PopularDataSet(LDBResultSet)
  else
    FFetchingRecords := True;
end;

procedure TSessionDataSet<M>._PopularDataSet(const ADBResultSet: IDBDataSet);
begin
//  FOrmDataSet.Locate(KeyFiels, KeyValues, Options);
//  { TODO -oISAQUE : Procurar forma de verificar se o registro nao ja se encontra em memoria
//  pela chave primaria }
  try
    while not ADBResultSet.Eof do
    begin
       FOwner.FOrmDataSet.Append;
       Bind.SetFieldToField(ADBResultSet, FOwner.FOrmDataSet);
       FOwner.FOrmDataSet.Fields[0].AsInteger := -1;
       FOwner.FOrmDataSet.Post;
       // Avanca o cursor: sem isso o laco nunca atinge Eof e anexa a mesma
       // linha infinitamente (loop infinito / OOM).
       ADBResultSet.Next;
    end;
  finally
    ADBResultSet.Close;
  end;
end;

end.
