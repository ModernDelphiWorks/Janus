{
      ORM Brasil � um ORM simples e descomplicado para quem utiliza Delphi

                   Copyright (c) 2016, Isaque Pinheiro
                          All rights reserved.

                    GNU Lesser General Public License
                      Vers�o 3, 29 de junho de 2007

       Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
       A todos � permitido copiar e distribuir c�pias deste documento de
       licen�a, mas mud�-lo n�o � permitido.

       Esta vers�o da GNU Lesser General Public License incorpora
       os termos e condi��es da vers�o 3 da GNU General Public License
       Licen�a, complementado pelas permiss�es adicionais listadas no
       arquivo LICENSE na pasta principal.
}

{
  @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Janus.DataSet.Adapter;

interface

uses
  DB,
  Rtti,
  TypInfo,
  Classes,
  SysUtils,
  StrUtils,
  Variants,
  Generics.Collections,
  /// orm
  FluentSQL,
  Janus.Bind,
  Janus.Session.DataSet,
  Janus.DataSet.Base.Adapter,
  MetaDbDiff.mapping.classes,
  MetaDbDiff.types.mapping,
  DataEngine.FactoryInterfaces;

type
  TDataSetHack = class(TDataSet)
  end;

  TDataSetAdapter<M: class, constructor> = class(TDataSetBaseAdapter<M>)
  private
    procedure _ExecuteCheckNotNull;
    procedure _InjectLazyProxiesOnScroll;
  protected
    FConnection: IDBConnection;
    procedure OpenDataSetChilds; override;
    procedure RefreshDataSetOneToOneChilds(AFieldName: String); override;
    procedure DoAfterScroll(DataSet: TDataSet); override;
    procedure DoBeforePost(DataSet: TDataSet); override;
    procedure DoBeforeDelete(DataSet: TDataSet); override;
    procedure DoNewRecord(DataSet: TDataSet); override;
  public
    constructor Create(AConnection: IDBConnection; ADataSet:
      TDataSet; APageSize: Integer; AMasterObject: TObject); overload;
    destructor Destroy; override;
    procedure NextPacket; override;
    procedure LoadLazy(const AOwner: M); override;
  end;

implementation

uses
  Janus.DataSet.Fields,
  Janus.Objects.Helper,
  Janus.RTTI.Helper,
  MetaDbDiff.mapping.explorer,
  MetaDbDiff.mapping.exceptions;

{ TDataSetAdapter<M> }

constructor TDataSetAdapter<M>.Create(AConnection: IDBConnection;
  ADataSet: TDataSet; APageSize: Integer; AMasterObject: TObject);
begin
  FConnection := AConnection;
  inherited Create(ADataSet, APageSize, AMasterObject);
  FSession := TSessionDataSet<M>.Create(Self, AConnection, APageSize);
end;

destructor TDataSetAdapter<M>.Destroy;
begin
  FSession.Free;
  inherited;
end;

procedure TDataSetAdapter<M>.DoAfterScroll(DataSet: TDataSet);
begin
  if DataSet.State in [dsBrowse] then
    if not FOrmDataSet.Eof then
    begin
      OpenDataSetChilds;
      _InjectLazyProxiesOnScroll;
    end;
  inherited;
end;

procedure TDataSetAdapter<M>.DoBeforeDelete(DataSet: TDataSet);
var
  LDataSet: TDataSet;
  LFor: Integer;
begin
  inherited DoBeforeDelete(DataSet);
  // Alimenta a lista com registros deletados
  FSession.DeleteList.Add(M.Create);
  Bind.SetFieldToProperty(FOrmDataSet, TObject(FSession.DeleteList.Last));

  // Deleta registros de todos os DataSet filhos
  EmptyDataSetChilds;
  // Exclui os registros dos NestedDataSets linkados ao FOrmDataSet
  // Recurso usado em banco NoSQL
  for LFor := 0 to TDataSetHack(FOrmDataSet).NestedDataSets.Count - 1 do
  begin
    LDataSet := TDataSetHack(FOrmDataSet).NestedDataSets.Items[LFor];
    LDataSet.DisableControls;
    LDataSet.First;
    try
      repeat
        LDataSet.Delete;
      until LDataSet.Eof;
    finally
      LDataSet.EnableControls;
    end;
  end;
end;

procedure TDataSetAdapter<M>.DoBeforePost(DataSet: TDataSet);
begin
  inherited DoBeforePost(DataSet);
  // Rotina de valida��o se o campo foi deixado null
  _ExecuteCheckNotNull;
end;

procedure TDataSetAdapter<M>._ExecuteCheckNotNull;
var
  LColumn: TColumnMapping;
  LColumns: TColumnMappingList;
begin
  LColumns := TMappingExplorer.GetMappingColumn(FCurrentInternal.ClassType);
  for LColumn in LColumns do
  begin
    if LColumn.IsNoInsert then
      Continue;
    if LColumn.IsNoUpdate then
      Continue;
    if LColumn.IsJoinColumn then
      Continue;
    if LColumn.IsNoValidate then
      Continue;
    if LColumn.IsNullable then
      Continue;
    if LColumn.FieldType in [ftDataSet, ftADT, ftBlob] then
      Continue;
    if LColumn.IsNotNull then
      if FOrmDataSet.FieldValues[LColumn.ColumnName] = Null then
        raise EFieldValidate.Create(FCurrentInternal.ClassName + '.' + LColumn.ColumnName,
                                  FOrmDataSet.FieldByName(LColumn.ColumnName).ConstraintErrorMessage);
  end;
end;

procedure TDataSetAdapter<M>._InjectLazyProxiesOnScroll;
var
  LCurrentPK: String;
begin
  if not Assigned(FSession) then
    Exit;
  if FOrmDataSet.RecordCount = 0 then
    Exit;

  LCurrentPK := _GetCurrentPKAsString;
  if LCurrentPK = FLastPKValue then
    Exit;

  FLastPKValue := LCurrentPK;
  FProxiesInjectedForCurrentRow := False;

  Bind.SetFieldToProperty(FOrmDataSet, TObject(FCurrentInternal));

  FSession.InjectLazyProxies(TObject(FCurrentInternal));
  FProxiesInjectedForCurrentRow := True;
end;

procedure TDataSetAdapter<M>.OpenDataSetChilds;
var
  LDataSetChild: TDataSetBaseAdapter<M>;
  LSQL: String;
  LObject: TObject;
  LChildKey: String;
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LIsLazy: Boolean;
begin
  inherited;
  if not FOrmDataSet.Active then
    Exit;
  if FOrmDataSet.RecordCount = 0 then
    Exit;
  // Se Count > 0, identifica-se que � o objeto � o Master
  if FMasterObject.Count = 0 then
    Exit;

  LAssociations := TMappingExplorer.GetMappingAssociation(M);

  // Popula o objeto com o registro atual do dataset Master para filtar
  // os filhos com os valores das chaves.
  LObject := M.Create;
  try
    Bind.SetFieldToProperty(FOrmDataSet, LObject);
    for LChildKey in FMasterObject.Keys do
    begin
      // Verifica se a associa��o correspondente ao child � lazy
      LIsLazy := False;
      if LAssociations <> nil then
      begin
        for LAssociation in LAssociations do
        begin
          if SameText(LAssociation.ClassNameRef, LChildKey) and LAssociation.Lazy then
          begin
            LIsLazy := True;
            Break;
          end;
        end;
      end;
      // Pula filhos lazy — ser�o resolvidos via proxy transparente
      if LIsLazy then
        Continue;

      LDataSetChild := FMasterObject[LChildKey];
      LSQL := LDataSetChild.FSession.SelectAssociation(LObject);
      // Monta o comando SQL para abrir registros filhos
      if Length(LSQL) > 0 then
        LDataSetChild.OpenSQLInternal(LSQL);
    end;
  finally
    LObject.Free;
  end;
end;

procedure TDataSetAdapter<M>.LoadLazy(const AOwner: M);
var
  LOwnerObject: TDataSetBaseAdapter<M>;
  LSQL: String;
begin
  inherited;
  if AOwner <> nil then
  begin
    if FOwnerMasterObject <> nil then
      Exit;
    if FOrmDataSet.Active then
      Exit;

    SetMasterObject(AOwner);
    LOwnerObject := TDataSetBaseAdapter<M>(FOwnerMasterObject);
    if LOwnerObject <> nil then
    begin
      // Popula o objeto com o registro atual do dataset Master para filtar
      // os filhos com os valores das chaves.
      Bind.SetFieldToProperty(LOwnerObject.FOrmDataSet,
                      TObject(LOwnerObject.FCurrentInternal));
      LSQL := FSession.SelectAssociation(LOwnerObject.FCurrentInternal);
      if Length(LSQL) > 0 then
        OpenSQLInternal(LSQL);
    end;
  end
  else
  begin
    if FOwnerMasterObject = nil then
      Exit;

    if not TDataSetBaseAdapter<M>(FOwnerMasterObject).FOrmDataSet.Active then
      Exit;

    SetMasterObject(nil);
    Close;
  end;
end;

procedure TDataSetAdapter<M>.NextPacket;
var
  LBookMark: TBookmark;
begin
  inherited;
  if FSession.FetchingRecords then
    Exit;
  FOrmDataSet.DisableControls;
  // Desabilita os eventos dos TDataSets
  DisableDataSetEvents;
  LBookMark := FOrmDataSet.Bookmark;
  try
    FSession.NextPacket;
  finally
    FOrmDataSet.GotoBookmark(LBookMark);
    FOrmDataSet.EnableControls;
    EnableDataSetEvents;
  end;
end;

procedure TDataSetAdapter<M>.RefreshDataSetOneToOneChilds(AFieldName: String);
var
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LDataSetChild: TDataSetBaseAdapter<M>;
  LSQL: String;
  LObject: TObject;
begin
  inherited;
  if not FOrmDataSet.Active then
    Exit;
  LAssociations := TMappingExplorer.GetMappingAssociation(FCurrentInternal.ClassType);
  if LAssociations = nil then
    Exit;
  for LAssociation in LAssociations do
  begin
    if not (LAssociation.Multiplicity in [TMultiplicity.OneToOne, TMultiplicity.ManyToOne]) then
      Continue;
    // Checa se o campo que recebeu a altera��o, � um campo de associa��o
    // Se for � feito um novo select para atualizar a propriedade associada.
    if LAssociation.ColumnsName.IndexOf(AFieldName) = -1 then
      Continue;
    if not FMasterObject.ContainsKey(LAssociation.ClassNameRef) then
      Continue;
    LDataSetChild := FMasterObject.Items[LAssociation.ClassNameRef];
    if LDataSetChild = nil then
      Continue;
    // Popula o objeto com o registro atual do dataset Master para filtar
    // os filhos com os valores das chaves.
    LObject := M.Create;
    try
      Bind.SetFieldToProperty(FOrmDataSet, LObject);
      LSQL := LDataSetChild.FSession.SelectAssociation(LObject);
      if Length(LSQL) > 0 then
        LDataSetChild.OpenSQLInternal(LSQL);
    finally
      LObject.Free;
    end;
  end;
end;

procedure TDataSetAdapter<M>.DoNewRecord(DataSet: TDataSet);
begin
  // Limpa registros do dataset em mem�ria antes de receber os novos registros
  EmptyDataSetChilds;
  inherited DoNewRecord(DataSet);
end;

end.
