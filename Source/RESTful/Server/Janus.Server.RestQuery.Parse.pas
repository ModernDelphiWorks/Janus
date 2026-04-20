{
      ORM Brasil é um ORM simples e descomplicado para quem utiliza Delphi

                   Copyright (c) 2018, Isaque Pinheiro
                          All rights reserved.
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
    function SplitString(const AValue, ADelimiters: String): TStringDynArray;
    function ParseQueryingData(const AURI: String): String;
    function ParseOperator(const AParams: String): String;
    function ParseOperatorReverse(const AParams: String): String;
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
    // Reverse: SQL → OData word-boundary safe replacement
    function _TokenizeSQL(const ASQL: String): TArray<TFilterToken>;
    function _EmitOData(const ATokens: TArray<TFilterToken>): String;
  protected
    const cPATH_SEPARATOR = '/';
    const cQUERY_SEPARATOR = '&';
    const cQUERY_INITIAL = '?';
  public
    constructor Create;
    destructor Destroy; override;
    procedure ParseQuery(const AURI: String);
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

{ TRESTQuery }

constructor TRESTQueryParse.Create;
begin
  FQueryTokens := TDictionary<String, String>.Create;
  FResourceName := '';
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

function TRESTQueryParse.GetResourceName: String;
begin
  Result := 'T' + FResourceName;
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

// Transforms OData function call (arg tokens) to SQL equivalent.
// Handles: contains, startswith, endswith → LIKE patterns; tolower, toupper → SQL functions.
function TRESTQueryParse._EmitFunctionSQL(const AFuncName: String;
  const AArgTokens: TArray<TFilterToken>): String;
var
  LRaw: String;
  LCommaPos: Integer;
  LField: String;
  LValue: String;
begin
  // Rebuild raw arg string to extract field and value
  LRaw := '';
  for var LArgTok in AArgTokens do
    LRaw := LRaw + LArgTok.Value;

  if SameText(AFuncName, 'tolower') then
    Exit('LOWER(' + LRaw + ')');
  if SameText(AFuncName, 'toupper') then
    Exit('UPPER(' + LRaw + ')');

  // contains / startswith / endswith — need two arguments: field, value
  LCommaPos := Pos(',', LRaw);
  if LCommaPos = 0 then
    Exit(LRaw);

  LField := Trim(Copy(LRaw, 1, LCommaPos - 1));
  LValue := Trim(Copy(LRaw, LCommaPos + 1, MaxInt));
  // Remove surrounding single quotes from value if present
  if (Length(LValue) >= 2) and (LValue[1] = '''') and (LValue[Length(LValue)] = '''') then
    LValue := Copy(LValue, 2, Length(LValue) - 2);

  if SameText(AFuncName, 'contains') then
    Result := LField + ' LIKE ''%' + LValue + '%'''
  else if SameText(AFuncName, 'startswith') then
    Result := LField + ' LIKE ''' + LValue + '%'''
  else if SameText(AFuncName, 'endswith') then
    Result := LField + ' LIKE ''%' + LValue + ''''
  else
    Result := LRaw;
end;

// Emits SQL from a token list, replacing OData operators and functions.
// Operators are replaced only when they appear as standalone word tokens,
// preventing corruption of identifiers that contain operator substrings.
function TRESTQueryParse._EmitSQL(const ATokens: TArray<TFilterToken>): String;
const
  cOpOData: array[0..9] of String  = ('eq','ne','gt','ge','lt','le','add','sub','mul','div');
  cOpSQL:   array[0..9] of String  = ('=', '<>','>','>=','<','<=','+','-','*','/');
  cLogOData: array[0..2] of String = ('and','or','not');
  cLogSQL:   array[0..2] of String = ('AND','OR','NOT');
  cFuncNames: array[0..4] of String = ('contains','startswith','endswith','tolower','toupper');
var
  LResult: TStringBuilder;
  LPos: Integer;
  LCount: Integer;
  LToken: TFilterToken;
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

        // Check comparison operators
        LFound := False;
        for LMapFor := 0 to High(cOpOData) do
        begin
          if SameText(LToken.Value, cOpOData[LMapFor]) then
          begin
            LResult.Append(cOpSQL[LMapFor]);
            LFound := True;
            Break;
          end;
        end;

        if not LFound then
        begin
          // Check logical operators
          for LMapFor := 0 to High(cLogOData) do
          begin
            if SameText(LToken.Value, cLogOData[LMapFor]) then
            begin
              LResult.Append(cLogSQL[LMapFor]);
              LFound := True;
              Break;
            end;
          end;
        end;

        if not LFound then
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
  LTokens: TArray<TFilterToken>;
begin
  if AParams = '' then
    Exit('');
  LTokens := _TokenizeFilter(AParams);
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

end.
