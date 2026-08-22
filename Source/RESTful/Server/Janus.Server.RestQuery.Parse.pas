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
  @abstract(REST Componentes)
  @created(20 Jun 2018)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
  @abatract(oData : http://www.odata.org/getting-started/basic-tutorial/#queryData)
}

unit Janus.Server.RestQuery.Parse;

interface

uses
  Rtti,
  Classes,
  SysUtils,
  StrUtils,
  Variants,
  Types,
  Generics.Collections;

type
  TFilterTokenKind = (ftkWord, ftkStringLiteral, ftkOther);

  TFilterToken = record
    Kind: TFilterTokenKind;
    Value: String;
  end;

  // Querying Data
  TRESTQueryParse = class
  private
    FPath: String;
    FQuery: String;
    FPathTokens: TArray<String>;
    FQueryTokens: TDictionary<String, String>;
    FResourceName: String;
    /// The resolved answer of GetResourceName, and whether it has been
    /// computed for the CURRENT FResourceName. FResourceName is written in
    /// exactly one place - ParseResourceNameAndID, which only ParseQuery
    /// calls - so ParseQuery is the only point that can invalidate this.
    FResolvedName: String;
    FResolved: Boolean;
    FID: TValue;
    function GetSelect: String;
    function GetFilter: String;
    function GetExpand: String;
    function GetSearch: String;
    function GetOrderBy: String;
    function GetSkip: Integer;
    function GetTop: Integer;
    function GetCount: Boolean;
    function GetResourceName: String;
    function _ResolveResourceName(const ASegment: String): String;
    function SplitString(const AValue, ADelimiters: String): TStringDynArray;
    function ParseQueryingData(const AURI: String): String;
    function ParseOperator(const AParams: String): String;
    function ParsePathTokens(const APath: String): TArray<String>;
    procedure ParseResourceNameAndID(const AValue: String);
    procedure ParseQueryTokens;
    // Token-based filter parser (ADR-001)
    function _TokenizeFilter(const AFilter: String): TArray<TFilterToken>;
    function _EmitSQL(const ATokens: TArray<TFilterToken>): String;
    function _ExtractFuncArgTokens(const ATokens: TArray<TFilterToken>;
      const AStartPos: Integer; out AEndPos: Integer): TArray<TFilterToken>;
    function _EmitFunctionSQL(const AFuncName: String;
      const AArgTokens: TArray<TFilterToken>): String;
    function _FindCommaTokenIdx(const AArgTokens: TArray<TFilterToken>): Integer;
    function _JoinTokenSlice(const AArgTokens: TArray<TFilterToken>;
      const AFrom, ATo: Integer): String;
    // Reverse: SQL -> OData word-boundary safe replacement
    function _TokenizeSQL(const ASQL: String): TArray<TFilterToken>;
    function _EmitOData(const ATokens: TArray<TFilterToken>): String;
  protected
    const cPATH_SEPARATOR = '/';
    const cQUERY_SEPARATOR = '&';
    const cQUERY_INITIAL = '?';
    /// The refusal for a segment that two registered entities claim by
    /// [Table]. It is shaped like the refusals in Janus.Server.Resource -
    /// a JSON object under an "exception" key - because every server family
    /// turns an exception raised here into the body of the response.
    const cRESOURCEAMBIGUOUS =
      '{"exception":"Resource [%s] is ambiguous on the server: %d registered '
      + 'entities map a table spelled that way, among them [%s] and [%s]. '
      + 'Address one of them by its CLASS NAME instead, or give the tables '
      + 'distinct names - the server refuses to choose, because the choice '
      + 'would depend on the order a hash table enumerates class pointers."}';
  public
    constructor Create;
    destructor Destroy; override;
    procedure ParseQuery(const AURI: String);
    function ParseOperatorReverse(const AParams: String): String;
    procedure SetSelect(const Value: String);
    procedure SetExpand(const Value: String);
    procedure SetFilter(const Value: String);
    procedure SetSearch(const Value: String);
    procedure SetOrderBy(const Value: String);
    procedure SetSkip(const Value: TValue);
    procedure SetTop(const Value: TValue);
    procedure SetCount(const Value: TValue);
    property Path: String read FPath;
    property Query: String read FQuery;
    property ResourceName: String read GetResourceName;
    property ID: TValue read FID;
    property Select: String read GetSelect;
    property Expand: String read GetExpand;
    property Filter: String read GetFilter;
    property Search: String read GetSearch;
    property OrderBy: String read GetOrderBy;
    property Skip: Integer read GetSkip;
    property Top: Integer read GetTop;
    property Count: Boolean read GetCount;
  end;

implementation

uses
  System.NetEncoding,
  MetaDbDiff.Mapping.Classes,
  MetaDbDiff.Mapping.Explorer;

var
  GCompOps: TDictionary<String, String>;
  GLogOps:  TDictionary<String, String>;

{ TRESTQuery }

constructor TRESTQueryParse.Create;
begin
  FQueryTokens := TDictionary<String, String>.Create;
  FResourceName := '';
  FResolvedName := '';
  FResolved := False;
  FID := TValue.Empty;
end;

destructor TRESTQueryParse.Destroy;
begin
  FQueryTokens.Clear;
  FQueryTokens.Free;
  inherited;
end;

procedure TRESTQueryParse.SetExpand(const Value: String);
begin
  if Value = '' then
    Exit;

  if FQueryTokens.ContainsKey('$expand') then
    FQueryTokens.Items['$expand'] := Value
  else
    FQueryTokens.Add('$expand', Value);
end;

function TRESTQueryParse.GetCount: Boolean;
begin
  Result := False;
  if FQueryTokens.ContainsKey('$count') then
    Result := LowerCase(FQueryTokens.Items['$count']) = 'true';
end;

function TRESTQueryParse.GetExpand: String;
begin
  Result := '';
  if FQueryTokens.ContainsKey('$expand') then
    Result := FQueryTokens.Items['$expand'];
end;

function TRESTQueryParse.GetFilter: String;
begin
  Result := '';
  if FQueryTokens.ContainsKey('$filter') then
    Result := FQueryTokens.Items['$filter'];
end;

function TRESTQueryParse.GetOrderBy: String;
begin
  Result := '';
  if FQueryTokens.ContainsKey('$orderby') then
    Result := FQueryTokens.Items['$orderby'];
end;

/// Answers the CLASS NAME the path segment addresses - ISSUE #364.
///
/// It used to answer 'T' + the segment and let TMappingRepository
/// .FindEntityByName match that against ClassName, which made
/// `class = 'T' + table` a rule of the wire protocol that nothing declares
/// and nothing validates. The repository does not keep it: it is a
/// CONVENTION, not a constraint, and the eight models the RESTHorse suite
/// itself ships are all outside it - which
/// Premise_EveryModelThisSuiteShips_IsOffTheConvention measures against the
/// live registry rather than asserting from a count that would rot.
///
/// It mattered because the two halves of this framework named the resource
/// differently. TSessionRestFul<M>.Create, when the connection has
/// ServerUse, sends `Table(LTable).Name` - the TABLE name - so a Janus
/// client could only ever reach a model that happened to obey the
/// convention; every other one came back as
/// `Resource [T<table>] not registered on the server!`, naming a symbol
/// that exists in no source file.
///
/// MEMOISED, and not as a micro-optimisation. The resource layer reads this
/// property two to three times per request, and resolving now WALKS THE
/// REGISTRY calling TMappingExplorer.GetMappingTable - which enters a GLOBAL
/// critical section, once per entity. Before this issue the getter was a
/// string concatenation and took that lock ZERO times, so the cost is one
/// this repair introduces and has to answer for.
///
/// MEASURED with a counter in this unit, over one whole Janus.Tests.RESTHorse
/// run (179 requests, 37 registered entities), the same tree with and
/// without the memo:
///
///        memo off   481 resolutions (2.69/request)   9875 lock acquisitions
///        memo on    179 resolutions (1.00/request)   2699 lock acquisitions
///
/// Both runs are 188/188 GREEN, which is the point: deleting the memo cannot
/// change a single answer, only the cost. FResourceName is written in
/// ParseResourceNameAndID and nowhere else, and only ParseQuery calls it.
function TRESTQueryParse.GetResourceName: String;
begin
  if not FResolved then
  begin
    FResolvedName := _ResolveResourceName(FResourceName);
    FResolved := True;
  end;
  Result := FResolvedName;
end;

/// Resolves a path segment to a registered entity's ClassName.
///
/// ClassName wins over the table name, so no URL that resolved yesterday
/// can change meaning today - that is what keeps the whole RESTHorse suite,
/// which addresses every entity by its class name minus the 'T', reading
/// the same rows. Finding it ENDS the scan, which is also what keeps the
/// refusal below from ever swallowing a segment that already resolved.
/// The [Table] name is consulted second: it is not a guess about the
/// class's spelling, it is the string the client actually put on the wire,
/// already carried by the model.
///
/// WHEN TWO ENTITIES CLAIM THE SEGMENT BY [Table], IT REFUSES OUT LOUD.
///
/// Two classes mapping one table is a legitimate shape - a full entity and
/// a projection over it - and this tree already contains it. Picking one of
/// them would be picking in the ORDER TRepository._GetEntity hands the
/// classes over, which is `FEntitys.Keys` of a TObjectDictionary<TClass,..>
/// (MetaDbDiff.Mapping.Repository.pas): hash-bucket order over VMT
/// POINTERS, in an image linked /DYNAMICBASE.
///
/// MEASURED, with the silent choice put back and NOTHING else changed but
/// the ORDER OF TWO ADJACENT RegisterEntity LINES in a test fixture: one URL
/// answered two different entities - [{"akey":1,"atag":"iamambiguous"}] with
/// one order, [{"akey":1}] with the other. Stable per binary (six runs of
/// one build gave one answer), decided at LINK time by something no caller
/// can see. A silent wrong answer is worse than a refusal, so the refusal is
/// the answer, and it names both candidates.
///
/// The two it names are the lexical extremes of the claimant set, NOT the
/// first two the enumeration produced - a refusal whose TEXT depends on
/// hash order would have kept the very defect it reports.
///
/// When nothing claims the segment the answer is still 'T' + segment, so
/// the caller-visible refusal and the never-empty contract are both
/// unchanged. WHERE THOSE TWO ARE PINNED, and it is not where the directory
/// layout suggests: the four clauses that spell out the fallback -
/// ParseResourceName_Simple, _WithID, _WithQueryString and _PrefixedWithT -
/// are in Test.Janus.REST.QueryParse.pas, which SITS in the RESTHorse
/// directory of Test\Delphi but is linked by Janus.Tests.Units.dpr and runs
/// in Janus.Tests.Units, not in Janus.Tests.RESTHorse. The never-empty
/// contract is pinned separately, by Test.Janus.Server.Resource.MARS, in
/// Janus.Tests.RESTMARS.
function TRESTQueryParse._ResolveResourceName(const ASegment: String): String;
var
  LClass: TClass;
  LTable: TTableMapping;
  LName: String;
  LFirst: String;
  LLast: String;
  LClaimants: Integer;
begin
  Result := 'T' + ASegment;
  if ASegment = '' then
    Exit;
  LFirst := '';
  LLast := '';
  LClaimants := 0;
  for LClass in TMappingExplorer.GetRepositoryMapping.List.Entitys do
  begin
    if SameText(LClass.ClassName, Result) then
      Exit;
    LTable := TMappingExplorer.GetMappingTable(LClass);
    if LTable = nil then
      Continue;
    if not SameText(LTable.Name, ASegment) then
      Continue;
    LName := LClass.ClassName;
    Inc(LClaimants);
    if LFirst = '' then
    begin
      LFirst := LName;
      LLast := LName;
    end
    else
    begin
      if CompareText(LName, LFirst) < 0 then
        LFirst := LName;
      if CompareText(LName, LLast) > 0 then
        LLast := LName;
    end;
  end;
  // Two DIFFERENT answers for one segment. Same class name twice - the same
  // class registered from two units - is not an ambiguity: the answer does
  // not depend on which one is picked.
  if not SameText(LFirst, LLast) then
    raise Exception.CreateFmt(cRESOURCEAMBIGUOUS,
                              [ASegment, LClaimants, LFirst, LLast]);
  if LFirst <> '' then
    Result := LFirst;
end;

function TRESTQueryParse.GetSearch: String;
begin
  Result := '';
  if FQueryTokens.ContainsKey('$search') then
    Result := FQueryTokens.Items['$search'];
end;

function TRESTQueryParse.GetSelect: String;
begin
  Result := '';
  if FQueryTokens.ContainsKey('$select') then
    Result := FQueryTokens.Items['$select'];
end;

function TRESTQueryParse.GetSkip: Integer;
begin
  Result := 0;
  if FQueryTokens.ContainsKey('$skip') then
    Result := StrToIntDef(FQueryTokens.Items['$skip'], 0);
end;

function TRESTQueryParse.GetTop: Integer;
begin
  Result := 0;
  if FQueryTokens.ContainsKey('$top') then
    Result := StrToIntDef(FQueryTokens.Items['$top'], 0);
end;

procedure TRESTQueryParse.ParseQuery(const AURI: String);
var
  LQueryingData: String;
begin
  FPath := AURI;
  // The segment is about to be re-read, so any answer resolved from the
  // previous one is stale. This is the ONLY place FResourceName can change.
  FResolved := False;
  ParseResourceNameAndID(FPath);
  LQueryingData := ParseQueryingData(FPath);
  FPathTokens := ParsePathTokens(FPath);
  FQuery := ParseOperator(LQueryingData);
  ParseQueryTokens;
end;

function TRESTQueryParse.ParseQueryingData(const AURI: String): String;
var
  LPos: Integer;
begin
  Result := '';
  LPos := Pos(cQUERY_INITIAL, AURI);
  if LPos = 0 then
    Exit;
  Result := Copy(AURI, LPos + 1, MaxInt);
end;

procedure TRESTQueryParse.ParseResourceNameAndID(const AValue: String);
var
  LChar: Char;
  LFor: Integer;
  LCommand: String;
  LLength: Integer;
begin
  LCommand := '';
  LLength := Length(AValue);
  LFor := 0;
  repeat
    Inc(LFor);
    LChar := Char(AValue[LFor]);
    case LChar of
      #0: Continue;
      '(':
        begin
          FResourceName := LCommand;
          if LFor + 1 <= LLength then
            ParseResourceNameAndID(Copy(AValue, LFor + 1, LLength));
          Break;
        end;
      ')':
        begin
          FID := LCommand;
          if LFor + 1 <= LLength then
            ParseResourceNameAndID(Copy(AValue, LFor + 1, LLength));
          Break;
        end;
      '/':
        LCommand := '';
      '?', '$':
        Break;
    else
      LCommand := LCommand + LChar;
    end;
  until (LFor >= LLength);
  if Length(FResourceName) = 0 then
    FResourceName := LCommand;
end;

// Tokenize a filter/expression string into words, string-literals, and other chars.
// Words are letter/digit/underscore sequences starting with a letter or underscore.
// String literals are single-quoted ('...'), supporting doubled quotes for escaping.
function TRESTQueryParse._TokenizeFilter(const AFilter: String): TArray<TFilterToken>;
var
  LResult: TList<TFilterToken>;
  LToken: TFilterToken;
  LPos: Integer;
  LLen: Integer;
  LStart: Integer;
begin
  LResult := TList<TFilterToken>.Create;
  try
    LPos := 1;
    LLen := Length(AFilter);
    while LPos <= LLen do
    begin
      if AFilter[LPos] = '''' then
      begin
        LToken.Kind := ftkStringLiteral;
        LStart := LPos;
        Inc(LPos);
        while LPos <= LLen do
        begin
          if AFilter[LPos] = '''' then
          begin
            Inc(LPos);
            if (LPos <= LLen) and (AFilter[LPos] = '''') then
              Inc(LPos)
            else
              Break;
          end
          else
            Inc(LPos);
        end;
        LToken.Value := Copy(AFilter, LStart, LPos - LStart);
        LResult.Add(LToken);
      end
      else if CharInSet(AFilter[LPos], ['a'..'z', 'A'..'Z', '_']) then
      begin
        LToken.Kind := ftkWord;
        LStart := LPos;
        while (LPos <= LLen) and CharInSet(AFilter[LPos], ['a'..'z', 'A'..'Z', '0'..'9', '_']) do
          Inc(LPos);
        LToken.Value := Copy(AFilter, LStart, LPos - LStart);
        LResult.Add(LToken);
      end
      else
      begin
        LToken.Kind := ftkOther;
        if (LPos < LLen) and CharInSet(AFilter[LPos], ['<', '>']) then
        begin
          var LTwo := AFilter[LPos] + AFilter[LPos + 1];
          if (LTwo = '<>') or (LTwo = '>=') or (LTwo = '<=') then
          begin
            LToken.Value := LTwo;
            LResult.Add(LToken);
            Inc(LPos, 2);
            Continue;
          end;
        end;
        LToken.Value := AFilter[LPos];
        LResult.Add(LToken);
        Inc(LPos);
      end;
    end;
    Result := LResult.ToArray;
  finally
    LResult.Free;
  end;
end;

// Extracts tokens enclosed between a '(' and its matching ')'.
// AStartPos is the index immediately after the opening '(' token.
// AEndPos is set to the index immediately after the closing ')' token.
function TRESTQueryParse._ExtractFuncArgTokens(const ATokens: TArray<TFilterToken>;
  const AStartPos: Integer; out AEndPos: Integer): TArray<TFilterToken>;
var
  LResult: TList<TFilterToken>;
  LDepth: Integer;
  LPos: Integer;
  LCount: Integer;
begin
  LResult := TList<TFilterToken>.Create;
  try
    LDepth := 1;
    LPos := AStartPos;
    LCount := Length(ATokens);
    while (LPos < LCount) and (LDepth > 0) do
    begin
      if (ATokens[LPos].Kind = ftkOther) and (ATokens[LPos].Value = '(') then
        Inc(LDepth)
      else
      if (ATokens[LPos].Kind = ftkOther) and (ATokens[LPos].Value = ')') then
      begin
        Dec(LDepth);
        if LDepth = 0 then
        begin
          Inc(LPos);
          Break;
        end;
      end;
      LResult.Add(ATokens[LPos]);
      Inc(LPos);
    end;
    AEndPos := LPos;
    Result := LResult.ToArray;
  finally
    LResult.Free;
  end;
end;

// Returns index of the first ftkOther ',' token in AArgTokens; -1 if none.
function TRESTQueryParse._FindCommaTokenIdx(const AArgTokens: TArray<TFilterToken>): Integer;
var
  LFor: Integer;
begin
  Result := -1;
  for LFor := 0 to High(AArgTokens) do
  begin
    if (AArgTokens[LFor].Kind = ftkOther) and (AArgTokens[LFor].Value = ',') then
    begin
      Result := LFor;
      Break;
    end;
  end;
end;

// Concatenates .Value of tokens from AFrom to ATo (inclusive); returns '' when AFrom > ATo.
function TRESTQueryParse._JoinTokenSlice(const AArgTokens: TArray<TFilterToken>;
  const AFrom, ATo: Integer): String;
var
  LFor: Integer;
begin
  Result := '';
  for LFor := AFrom to ATo do
    Result := Result + AArgTokens[LFor].Value;
end;

// Transforms OData function call (arg tokens) to SQL equivalent.
// Handles: contains, startswith, endswith -> LIKE patterns; tolower, toupper -> SQL functions.
function TRESTQueryParse._EmitFunctionSQL(const AFuncName: String;
  const AArgTokens: TArray<TFilterToken>): String;
var
  LField: String;
  LValue: String;
  LCommaIdx: Integer;
begin
  if SameText(AFuncName, 'tolower') then
    Exit('LOWER(' + _JoinTokenSlice(AArgTokens, 0, High(AArgTokens)) + ')');
  if SameText(AFuncName, 'toupper') then
    Exit('UPPER(' + _JoinTokenSlice(AArgTokens, 0, High(AArgTokens)) + ')');

  LCommaIdx := _FindCommaTokenIdx(AArgTokens);

  if LCommaIdx < 0 then
    Exit(_JoinTokenSlice(AArgTokens, 0, High(AArgTokens)));

  LField := Trim(_JoinTokenSlice(AArgTokens, 0, LCommaIdx - 1));

  LValue := Trim(_JoinTokenSlice(AArgTokens, LCommaIdx + 1, High(AArgTokens)));
  if (Length(LValue) >= 2) and (LValue[1] = '''') and (LValue[Length(LValue)] = '''') then
    LValue := Copy(LValue, 2, Length(LValue) - 2);

  if SameText(AFuncName, 'contains') then
    Result := LField + ' LIKE ''%' + LValue + '%'''
  else if SameText(AFuncName, 'startswith') then
    Result := LField + ' LIKE ''' + LValue + '%'''
  else if SameText(AFuncName, 'endswith') then
    Result := LField + ' LIKE ''%' + LValue + ''''
  else
    Result := LField + ',' + LValue;
end;

// Emits SQL from a token list, replacing OData operators and functions.
// Operators are replaced only when they appear as standalone word tokens,
// preventing corruption of identifiers that contain operator substrings.
function TRESTQueryParse._EmitSQL(const ATokens: TArray<TFilterToken>): String;
const
  cFuncNames: array[0..4] of String = ('contains','startswith','endswith','tolower','toupper');
var
  LResult: TStringBuilder;
  LPos: Integer;
  LCount: Integer;
  LToken: TFilterToken;
  LMapped: String;
  LMapFor: Integer;
  LFound: Boolean;
  LArgTokens: TArray<TFilterToken>;
  LEndPos: Integer;
begin
  LResult := TStringBuilder.Create;
  try
    LPos := 0;
    LCount := Length(ATokens);
    while LPos < LCount do
    begin
      LToken := ATokens[LPos];

      if LToken.Kind = ftkWord then
      begin
        // Check for OData function: word followed immediately by '('
        if (LPos + 1 < LCount) and (ATokens[LPos + 1].Kind = ftkOther) and
           (ATokens[LPos + 1].Value = '(') then
        begin
          LFound := False;
          for LMapFor := 0 to High(cFuncNames) do
          begin
            if SameText(LToken.Value, cFuncNames[LMapFor]) then
            begin
              LArgTokens := _ExtractFuncArgTokens(ATokens, LPos + 2, LEndPos);
              LResult.Append(_EmitFunctionSQL(LToken.Value, LArgTokens));
              LPos := LEndPos;
              LFound := True;
              Break;
            end;
          end;
          if LFound then
            Continue;
        end;

        if GCompOps.TryGetValue(LowerCase(LToken.Value), LMapped) then
          LResult.Append(LMapped)
        else if GLogOps.TryGetValue(LowerCase(LToken.Value), LMapped) then
          LResult.Append(LMapped)
        else
          LResult.Append(LToken.Value);
      end
      else
        LResult.Append(LToken.Value);

      Inc(LPos);
    end;
    Result := LResult.ToString;
  finally
    LResult.Free;
  end;
end;

// Tokenizes SQL string for reverse mapping back to OData.
// Reuses the same token structure since SQL identifiers follow the same word rules.
function TRESTQueryParse._TokenizeSQL(const ASQL: String): TArray<TFilterToken>;
begin
  Result := _TokenizeFilter(ASQL);
end;

// Emits OData from a SQL token list, replacing SQL operators with OData equivalents.
function TRESTQueryParse._EmitOData(const ATokens: TArray<TFilterToken>): String;
const
  // Multi-char SQL operators must be checked before single-char ones
  cSQLOps:   array[0..9] of String  = ('<>','>=','<=','=','>','<','+','-','*','/');
  cODataOps: array[0..9] of String  = ('ne','ge','le','eq','gt','lt','add','sub','mul','div');
var
  LResult: TStringBuilder;
  LToken: TFilterToken;
  LMapFor: Integer;
  LFound: Boolean;
begin
  LResult := TStringBuilder.Create;
  try
    for LToken in ATokens do
    begin
      if LToken.Kind = ftkOther then
      begin
        LFound := False;
        for LMapFor := 0 to High(cSQLOps) do
        begin
          if LToken.Value = cSQLOps[LMapFor] then
          begin
            LResult.Append(' ' + cODataOps[LMapFor] + ' ');
            LFound := True;
            Break;
          end;
        end;
        if not LFound then
          LResult.Append(LToken.Value);
      end
      else
        LResult.Append(LToken.Value);
    end;
    Result := LResult.ToString;
  finally
    LResult.Free;
  end;
end;

// ParseOperator converts OData filter expression to SQL using safe word-boundary tokenization.
// This replaces the legacy StringReplace approach that could corrupt field names (ADR-001).
function TRESTQueryParse.ParseOperator(const AParams: String): String;
var
  LDecoded: String;
  LTokens: TArray<TFilterToken>;
begin
  if AParams = '' then
    Exit('');
  LDecoded := TNetEncoding.URL.Decode(AParams);
  LTokens := _TokenizeFilter(LDecoded);
  Result := _EmitSQL(LTokens);
end;

// ParseOperatorReverse converts SQL expression back to OData format.
function TRESTQueryParse.ParseOperatorReverse(const AParams: String): String;
var
  LTokens: TArray<TFilterToken>;
begin
  if AParams = '' then
    Exit('');
  LTokens := _TokenizeSQL(AParams);
  Result := _EmitOData(LTokens);
end;

function TRESTQueryParse.ParsePathTokens(const APath: String): TArray<String>;
begin
  Result := TArray<String>(SplitString(APath, cPATH_SEPARATOR));

  while (Length(Result) > 0) and (Result[0] = '') do
    Result := Copy(Result, 1);
  while (Length(Result) > 0) and (Result[High(Result)] = '') do
    SetLength(Result, High(Result));
end;

procedure TRESTQueryParse.ParseQueryTokens;
var
  LQuery: String;
  LQueryItems: TArray<String>;
  LQueryItem: String;
begin
  FQueryTokens.Clear;
  FQueryTokens.TrimExcess;
  if FQuery = '' then
    Exit;

  LQuery := FQuery;
  while StartsStr(LQuery, cQUERY_INITIAL) do
    LQuery := RightStr(LQuery, Length(LQuery) - 1);

  LQueryItems := SplitString(LQuery, cQUERY_SEPARATOR);
  for LQueryItem in LQueryItems do
    FQueryTokens.Add(LQueryItem.SubString(0, LQueryItem.IndexOf('=')),
                     LQueryItem.SubString(LQueryItem.IndexOf('=') + 1));
end;

procedure TRESTQueryParse.SetCount(const Value: TValue);
begin
  if Value.ToString = '' then
    Exit;

  if FQueryTokens.ContainsKey('$count') then
    FQueryTokens.Items['$count'] := Value.ToString
  else
    FQueryTokens.Add('$count', Value.ToString);
end;

procedure TRESTQueryParse.SetFilter(const Value: String);
begin
  if Value = '' then
    Exit;

  if FQueryTokens.ContainsKey('$filter') then
    FQueryTokens.Items['$filter'] := ParseOperator(Value)
  else
    FQueryTokens.Add('$filter', ParseOperator(Value));
end;

procedure TRESTQueryParse.SetTop(const Value: TValue);
begin
  if Value.ToString = '' then
    Exit;

  if FQueryTokens.ContainsKey('$top') then
    FQueryTokens.Items['$top'] := Value.ToString
  else
    FQueryTokens.Add('$top', Value.ToString);
end;

procedure TRESTQueryParse.SetSearch(const Value: String);
begin
  if Value = '' then
    Exit;

  if FQueryTokens.ContainsKey('$search') then
    FQueryTokens.Items['$search'] := Value
  else
    FQueryTokens.Add('$search', Value);
end;

procedure TRESTQueryParse.SetSelect(const Value: String);
begin
  if Value = '' then
    Exit;

  if FQueryTokens.ContainsKey('$select') then
    FQueryTokens.Items['$select'] := Value
  else
    FQueryTokens.Add('$select', Value);
end;

procedure TRESTQueryParse.SetSkip(const Value: TValue);
begin
  if Value.ToString = '' then
    Exit;

  if FQueryTokens.ContainsKey('$skip') then
    FQueryTokens.Items['$skip'] := Value.ToString
  else
    FQueryTokens.Add('$skip', Value.ToString);
end;

procedure TRESTQueryParse.SetOrderBy(const Value: String);
begin
  if Value = '' then
    Exit;

  if FQueryTokens.ContainsKey('$orderby') then
    FQueryTokens.Items['$orderby'] := Value
  else
    FQueryTokens.Add('$orderby', Value);
end;

function TRESTQueryParse.SplitString(const AValue, ADelimiters: String): TStringDynArray;
var
  LStartIdx: Integer;
  LFoundIdx: Integer;
  LSplitPoints: Integer;
  LCurrentSplit: Integer;
  LFor: Integer;
begin
  Result := nil;
  if AValue = '' then
    Exit;

  LSplitPoints := 1;
  for LFor := 1 to Length(AValue) do
    if IsDelimiter(ADelimiters, AValue, LFor) then
      Inc(LSplitPoints);

  SetLength(Result, LSplitPoints);

  LStartIdx := 1;
  LCurrentSplit := 0;
  repeat
    LFoundIdx := FindDelimiter(ADelimiters, AValue, LStartIdx);
    if LFoundIdx <> 0 then
    begin
      Result[LCurrentSplit] := Copy(AValue, LStartIdx, LFoundIdx - LStartIdx);
      Inc(LCurrentSplit);
      LStartIdx := LFoundIdx + 1;
    end;
  until LCurrentSplit = LSplitPoints - 1;

  Result[LSplitPoints - 1] := Copy(AValue, LStartIdx, Length(AValue) - LStartIdx + 1);
end;

initialization
  GCompOps := TDictionary<String, String>.Create;
  GCompOps.Add('eq',  '=');
  GCompOps.Add('ne',  '<>');
  GCompOps.Add('gt',  '>');
  GCompOps.Add('ge',  '>=');
  GCompOps.Add('lt',  '<');
  GCompOps.Add('le',  '<=');
  GCompOps.Add('add', '+');
  GCompOps.Add('sub', '-');
  GCompOps.Add('mul', '*');
  GCompOps.Add('div', '/');

  GLogOps := TDictionary<String, String>.Create;
  GLogOps.Add('and', 'AND');
  GLogOps.Add('or',  'OR');
  GLogOps.Add('not', 'NOT');

finalization
  GCompOps.Free;
  GLogOps.Free;

end.
