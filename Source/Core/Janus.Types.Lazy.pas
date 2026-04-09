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
}

unit Janus.Types.Lazy;

interface

uses
  Rtti,
  SysUtils,
  TypInfo;

const
  ObjCastGUID: TGUID = '{2B0E75F4-EB17-4995-B4DB-FE6D40F1189F}';

type
  ILazy<T> = interface(TFunc<T>)
    ['{CBBB4093-AF0A-4367-AC34-018A379BDE57}']
    function IsValueCreated: Boolean;
    property Value: T read Invoke;
  end;

  TLazy<T> = class(TInterfacedObject, ILazy<T>, IInterface)
  private
    FIsValueCreated: Boolean;
    FValue: T;
    FValueFactory: TFunc<T>;
    procedure Initialize;
    function Invoke: T;
  protected
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
  public
    constructor Create(ValueFactory: TFunc<T>);
    destructor Destroy; override;
    function IsValueCreated: Boolean;
    property Value: T read Invoke;
  end;

  Lazy<T> = record
  strict private
    FLazy: ILazy<T>;
    class function CreateDefaultValue: T; static;
    function GetValue: T;
  public
    class constructor Create;
    class operator Implicit(const Value: Lazy<T>): ILazy<T>; overload;
    class operator Implicit(const Value: Lazy<T>): T; overload;
    class operator Implicit(const Value: TFunc<T>): Lazy<T>; overload;
    property Value: T read GetValue;
  end;

  PObject = ^TObject;

implementation

uses
  MetaDbDiff.rtti.helper;

{ TLazy<T> }

constructor TLazy<T>.Create(ValueFactory: TFunc<T>);
begin
  FValueFactory := ValueFactory;
end;

destructor TLazy<T>.Destroy;
var
  LTypeInfo: PTypeInfo;
begin
  if FIsValueCreated then
  begin
    LTypeInfo := TypeInfo(T);
    if LTypeInfo.Kind = tkClass then
      PObject(@FValue)^.Free();
  end;
  inherited;
end;

procedure TLazy<T>.Initialize;
begin
  if not FIsValueCreated then
  begin
    FValue := FValueFactory();
    FIsValueCreated := True;
  end;
end;

function TLazy<T>.Invoke: T;
begin
  Initialize();
  Result := FValue;
end;

function TLazy<T>.IsValueCreated: Boolean;
begin
  Result := FIsValueCreated;
end;

function TLazy<T>.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
  if IsEqualGUID(IID, ObjCastGUID) then
  begin
    Initialize;
  end;
  Result := inherited;
end;

{ Lazy<T> }

class constructor Lazy<T>.Create;
begin

end;

class function Lazy<T>.CreateDefaultValue: T;
var
  LContext: TRttiContext;
  LRttiType: TRttiType;
  LMethod: TRttiMethod;
  LValue: TValue;
  LObject: TObject;
begin
  Result := Default(T);
  LRttiType := LContext.GetType(TypeInfo(T));
  if (LRttiType = nil) or (LRttiType.TypeKind <> tkClass) then
    Exit;

  LMethod := LRttiType.GetMethod('Create');
  if not Assigned(LMethod) then
    Exit;

  if (Length(LMethod.GetParameters) = 1) and LRttiType.IsList then
    LValue := LMethod.Invoke(LRttiType.AsInstance.MetaclassType, [True])
  else
    LValue := LMethod.Invoke(LRttiType.AsInstance.MetaclassType, []);

  if not LValue.IsEmpty then
  begin
    LObject := LValue.AsObject;
    if Assigned(LObject) then
      Result := LValue.AsType<T>;
  end;
end;

function Lazy<T>.GetValue: T;
begin
  if not Assigned(FLazy) then
    FLazy := TLazy<T>.Create(CreateDefaultValue);
  Result := FLazy();
end;

class operator Lazy<T>.Implicit(const Value: Lazy<T>): ILazy<T>;
begin
  Result := Value.FLazy;
end;

class operator Lazy<T>.Implicit(const Value: Lazy<T>): T;
begin
  Result := Value.Value;
end;

class operator Lazy<T>.Implicit(const Value: TFunc<T>): Lazy<T>;
begin
  Result.FLazy := TLazy<T>.Create(Value);
end;

end.

