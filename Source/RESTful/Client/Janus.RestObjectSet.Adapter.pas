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
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Janus.RestObjectSet.Adapter;

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
  Janus.ObjectSet.Base.Adapter,
  Janus.RestFactory.Interfaces,
  MetaDbDiff.mapping.classes,
  MetaDbDiff.types.mapping,
  Janus.Objects.Helper;

type
  TRESTObjectSetAdapter<M: class, constructor> = class(TObjectSetBaseAdapter<M>)
  private
    FConnection: IRESTConnection;
    /// <summary> Writes onto AObject the value the SERVER generated for
    ///  AColumn, taken from the insert answer.
    ///
    ///  WHY THIS EXISTS - issue #301. Insert POSTed the aggregate and went
    ///  straight to the cascade, so FSession.ResultParams - already parsed and
    ///  filled by TSessionRestFul<M>.Insert - was never read. The root kept the
    ///  AutoInc placeholder and the cascade handed that placeholder to the
    ///  children.
    ///
    ///  WHY IT IS SCOPED TO THE PRIMARY KEY AND MATCHED BY NAME. Because that
    ///  is exactly what the producer emits: Janus.Server.Resource.pas builds
    ///  the answer from a loop over the PRIMARY KEY COLUMNS of the inserted
    ///  entity, naming each one by ColumnProperty.Name. Nothing else is named,
    ///  so an answer carrying any other name must change nothing.
    ///
    ///  THIS IS NOT THE SAME CODE AS THE DATASET FAMILY'S, and the duplication
    ///  is deliberate - see the note over Insert.
    ///
    ///  IT MUST NOT BE ABLE TO RAISE. Before #301 no answer of any shape could
    ///  reach the client, so no answer could make an insert fail; reading the
    ///  answer must not have bought that. Every value arrives as TEXT, so the
    ///  rule is: write only what the declared type provably accepts, and leave
    ///  the property alone otherwise.
    ///
    ///  WHAT IT DOES NOT COVER, DECLARED. A key whose property is a Nullable, a
    ///  tkFloat or a tkEnumeration falls through the case untouched - which is
    ///  the behaviour that shipped, so nothing regresses. The Nullable branch
    ///  was written and then REMOVED: writing text into a Nullable goes through
    ///  SetValueNullable, which casts to the element type and raises on
    ///  anything that is not one, and there is no model in this repository with
    ///  such a key to hold the code honest. An untestable branch that can raise
    ///  is worth less than the placeholder it would have replaced.
    ///  NOT MEASURED against a live server. </summary>
    procedure _SetGeneratedKeyValue(const AObject: TObject;
      const AColumn: TColumnMapping);
  public
    constructor Create(const AConnection: IRESTConnection;
      const APageSize: Integer = -1); overload;
    destructor Destroy; override;
    function Find: TObjectList<M>; overload; override;
    function Find(const AID: Int64): M; overload; override;
    function Find(const AID: String): M; overload; override;
    {$IFDEF DRIVERRESTFUL}
    function Find(const AMethodName: String;
      const AParams: array of String): TObjectList<M>; overload; override;
    {$ENDIF}
    function FindWhere(const AWhere: String;
      const AOrderBy: String = ''): TObjectList<M>; overload; override;
    procedure Insert(const AObject: M); override;
    procedure Update(const AObject: M); override;
    procedure Delete(const AObject: M); override;
  end;

implementation

uses
  Janus.Session.RESTful,
  MetaDbDiff.mapping.explorer,
  Janus.Core.Consts;

{ TRESTObjectSetAdapter<M> }

constructor TRESTObjectSetAdapter<M>.Create(const AConnection: IRESTConnection;
  const APageSize: Integer = -1);
begin
  inherited Create;
  FConnection := AConnection;
  FSession := TSessionRestFul<M>.Create(AConnection, nil, APageSize);
end;

procedure TRESTObjectSetAdapter<M>.Delete(const AObject: M);
begin
  inherited;
  try
    // Executa comando delete em cascade
    CascadeActionsExecute(AObject, TCascadeAction.CascadeDelete);
    // Executa comando delete master
    FSession.Delete(AObject);
  except
    on E: Exception do
    begin
      raise Exception.Create(E.Message);
    end;
  end;
end;

destructor TRESTObjectSetAdapter<M>.Destroy;
begin
  FSession.Free;
  inherited;
end;

function TRESTObjectSetAdapter<M>.Find: TObjectList<M>;
begin
  inherited;
  Result := FSession.Find;
end;

function TRESTObjectSetAdapter<M>.Find(const AID: Int64): M;
begin
  inherited;
  Result := FSession.Find(AID);
end;

function TRESTObjectSetAdapter<M>.Find(const AID: String): M;
begin
  inherited;
  Result := FSession.Find(AID);
end;

function TRESTObjectSetAdapter<M>.FindWhere(const AWhere,
  AOrderBy: String): TObjectList<M>;
begin
  inherited;
  Result := FSession.FindWhere(AWhere, AOrderBy);
end;

procedure TRESTObjectSetAdapter<M>._SetGeneratedKeyValue(const AObject: TObject;
  const AColumn: TColumnMapping);
var
  LProperty: TRttiProperty;
  LParam: TParam;
  LFor: Integer;
  LText: String;
  LInteger: Integer;
  LInt64: Int64;
begin
  LProperty := AColumn.ColumnProperty;
  // Mirrors TBind.SetFieldToProperty, which skips a column whose property is
  // not writable rather than letting SetValue raise on it.
  if not LProperty.IsWritable then
    Exit;
  for LFor := 0 to FSession.ResultParams.Count -1 do
  begin
    LParam := FSession.ResultParams.Items[LFor];
    // The answer names the key by PROPERTY name, which is what the producer
    // wrote. Case-insensitively, for the same reason the DataSet family reads
    // it through FindField: a third party server is not obliged to echo the
    // spelling back.
    if not SameText(LParam.Name, LProperty.Name) then
      Continue;

    // EVERYTHING THAT ARRIVES HERE IS TEXT, and that is not an assumption -
    // Janus.Session.RESTful.pas builds every param with `DataType := ftString`
    // and assigns `JsonValue.Value`. A JSON null arrives as the EMPTY STRING,
    // never as a Null or an Empty variant, so the shape of guard that asks
    // VarIsNull/VarIsEmpty can never fire; it was written here, it never ran,
    // and the empty text went straight on to TParam.AsInteger, which raised
    // `Could not convert variant of type (UnicodeString) into type (Integer)`.
    //
    // BEFORE #301 NOTHING READ THIS ANSWER, so no answer of any shape could
    // make an insert fail. Reading it must not have bought that. The rule is
    // therefore: write only what the property's declared type provably accepts,
    // and otherwise leave the property exactly as it was - which is the
    // behaviour that shipped.
    LText := VarToStr(LParam.Value);
    case LProperty.PropertyType.TypeKind of
      tkInteger:
        if TryStrToInt(LText, LInteger) then
          LProperty.SetValue(AObject, TValue.From<Integer>(LInteger));
      tkInt64:
        if TryStrToInt64(LText, LInt64) then
          LProperty.SetValue(AObject, TValue.From<Int64>(LInt64));
      tkString, tkLString, tkWString, tkUString:
        if LText <> '' then
          LProperty.SetValue(AObject, TValue.From<String>(LText));
    end;
    // The FIRST param that names this key decides, whether or not its value
    // could be used. The shipped contract emits one object per primary key
    // column and so cannot produce a second one naming the same key; pinning
    // the reading here is what keeps a later edit from silently making the
    // LAST one win instead.
    Exit;
  end;
end;

procedure TRESTObjectSetAdapter<M>.Insert(const AObject: M);
var
  LPrimaryKey: TPrimaryKeyColumnsMapping;
  LColumn: TColumnMapping;
begin
  inherited;
  try
    FSession.Insert(AObject);
    if FSession.ExistSequence then
    begin
      LPrimaryKey := TMappingExplorer
                       .GetMappingPrimaryKeyColumns(AObject.ClassType);
      if LPrimaryKey = nil then
        raise Exception.Create(cMESSAGEPKNOTFOUND);

      // ISSUE #301 - READ THE ANSWER BEFORE CASCADING, AND THE ORDER IS THE
      // WHOLE POINT. SetAutoIncValueChilds copies the ROOT's key property into
      // the children's foreign keys; with the root still on the AutoInc
      // placeholder it copied the placeholder, so the client came out of a save
      // holding an aggregate whose every key names a row nobody has - the root
      // included. Two loops rather than one so that no column can be cascaded
      // before every column has been reconciled.
      //
      // THE DATASET FAMILY HAS ITS OWN COPY OF THIS READ, in
      // TRESTDataSetAdapter<M>.ApplyInserter, and the duplication STAYS. The
      // two do not write the same thing: that one sets any FIELD the answer
      // names on the row under the cursor, this one sets a typed PROPERTY and
      // only for a primary key column. The two families share no ancestor -
      // TDataSetAbstract<M> and TObjectSetAbstract<M> are both `class abstract`
      // with nothing above them - so a single point would have to be a new unit
      // parameterised over WHERE to write, which is a branch per family dressed
      // up as sharing. Measured cost of the alternative: three files, one of
      // them Janus.RestDataSet.Adapter.pas, which #309 has just rewritten.
      for LColumn in LPrimaryKey.Columns do
        _SetGeneratedKeyValue(AObject, LColumn);

      for LColumn in LPrimaryKey.Columns do
        SetAutoIncValueChilds(AObject, LColumn);
    end;
  except
    on E: Exception do
    begin
      raise Exception.Create(E.Message);
    end;
  end;
end;

procedure TRESTObjectSetAdapter<M>.Update(const AObject: M);
var
  LObjectList: TObjectList<M>;
begin
  inherited;
  LObjectList := TObjectList<M>.Create;
  try
    LObjectList.Add(AObject);
    FSession.Update(LObjectList);
  finally
    LObjectList.Clear;
    LObjectList.Free;
  end;
end;

{$IFDEF DRIVERRESTFUL}
function TRESTObjectSetAdapter<M>.Find(const AMethodName: String;
  const AParams: array of String): TObjectList<M>;
begin
  inherited;
  Result := FSession.Find(AMethodName, AParams);
end;
{$ENDIF}

end.
