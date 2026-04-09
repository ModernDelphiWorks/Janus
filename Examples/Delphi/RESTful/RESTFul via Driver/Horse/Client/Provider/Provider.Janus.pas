unit Provider.Janus;

interface

uses
  DB,
  SysUtils,
  Provider.DataModule,
  // Janus Manager
  Janus.Manager.DataSet,
  Janus.Client.Methods;

type
  TRESTRequestMethodType = Janus.Client.Methods.TRESTRequestMethodType;
  TProviderJanus<T: class, constructor> = class
  private
    FManager: TManagerDataSet;
    FProviderDM: TProviderDM;
  protected
  public
    constructor Create;
    destructor Destroy; override;
    procedure Open;
    procedure OpenWhere(const AWhere: String);
    procedure ApplyUpdates(MaxErros: Integer);
    procedure MonitorShow;
    function Execute(const AURL: String;
      const ARequestMethod: TRESTRequestMethodType;
      const AParamsProc: TProc): String;
    function ProviderDM: TProviderDM;
    function DataSet<D: class, constructor>: TDataSet;
    function AddAdapter(const ADataSet: TDataSet;
      const APageSize: Integer = -1): TProviderJanus<T>; overload;
    function AddAdapter<A: class, constructor>(const ADataSet: TDataSet;
      const APageSize: Integer = -1): TProviderJanus<T>; overload;
    function AddChild<C: class, constructor>(
      const ADataSet: TDataSet): TProviderJanus<T>;
  end;

implementation

uses
  Janus.Form.Monitor;

{ TProviderClient }

function TProviderJanus<T>.AddAdapter(const ADataSet: TDataSet;
  const APageSize: Integer): TProviderJanus<T>;
begin
  Result := Self;
  FManager.AddAdapter<T>(ADataSet, APageSize);
end;

function TProviderJanus<T>.AddChild<C>(
  const ADataSet: TDataSet): TProviderJanus<T>;
begin
  Result := Self;
  FManager.AddAdapter<C, T>(ADataSet);
end;

function TProviderJanus<T>.AddAdapter<A>(const ADataSet: TDataSet;
  const APageSize: Integer): TProviderJanus<T>;
begin
  Result := Self;
  FManager.AddAdapter<A>(ADataSet, APageSize);
end;

procedure TProviderJanus<T>.ApplyUpdates(MaxErros: Integer);
begin
  FManager.ApplyUpdates<T>(0);
end;

constructor TProviderJanus<T>.Create;
begin
  FProviderDM := TProviderDM.Create(nil);
  FProviderDM.RESTClientHorse1
             .AsConnection
             .SetCommandMonitor(TCommandMonitor.GetInstance);
  // Manager
  FManager := TManagerDataSet.Create(FProviderDM
                             .RESTClientHorse1
                             .AsConnection);
end;

destructor TProviderJanus<T>.Destroy;
begin
  FManager.Free;
  FProviderDM.Free;
  inherited;
end;

function TProviderJanus<T>.Execute(const AURL: String;
  const ARequestMethod: TRESTRequestMethodType;
  const AParamsProc: TProc): String;
begin
  Result := ProviderDM.RESTClientHorse1
                      .Execute(AURL, ARequestMethod, AParamsProc);
end;

function TProviderJanus<T>.DataSet<D>: TDataSet;
begin
  Result := FManager.DataSet<D>;
end;

procedure TProviderJanus<T>.MonitorShow;
begin
  TCommandMonitor.GetInstance.Show;
end;

procedure TProviderJanus<T>.Open;
begin
  FManager.Open<T>;
end;

procedure TProviderJanus<T>.OpenWhere(const AWhere: String);
begin
  FManager.OpenWhere<T>(AWhere);
end;

function TProviderJanus<T>.ProviderDM: TProviderDM;
begin
  Result := FProviderDM;
end;

end.

