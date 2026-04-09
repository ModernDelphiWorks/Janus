unit Janus.Dependencies.Command.Base;

interface

uses
  Janus.Dependencies.Interfaces,
  Winapi.Windows,
  Winapi.UrlMon,
  System.SysUtils,
  System.IOUtils,
  System.Types,
  System.Zip;

type TJanusDependenciesCommandBase = class(TInterfacedObject, IJanusDependenciesCommand)

  protected
    FLog : TLog;
    FTag : String;

    procedure writeLog(AText: String);

    procedure MoveDirectories(ARootPath: String);
    procedure MoveFiles(ARootPath: String);

    function GetPath: String; virtual; abstract;
    function UrlDownloadFile: String; virtual; abstract;
    function ZipFileName: String; virtual; abstract;

    procedure Download; virtual;
    procedure Extract; virtual;

    procedure Execute;

  public
    constructor create(ATag: String; ALog: TLog);
    class function New(ATag: String; ALog: TLog): IJanusDependenciesCommand;
end;

implementation

{ TJanusDependenciesCommandBase }

constructor TJanusDependenciesCommandBase.create(ATag: String; ALog: TLog);
begin
  FTag := ATag;
  FLog := ALog;
end;

procedure TJanusDependenciesCommandBase.Download;
var
  LHResult: HRESULT;
begin
  writeLog(Format('Baixando arquivo %s...', [UrlDownloadFile]));
  LHResult := URLDownloadToFile(nil,
                                PChar(UrlDownloadFile),
                                PChar(ZipFileName),
                                0,
                                nil);
  if LHResult <> S_OK then
    raise Exception.CreateFmt('Falha ao baixar "%s". Código HRESULT: 0x%.8x',
      [UrlDownloadFile, LHResult]);

  writeLog('Arquivo baixado com sucesso.');
end;

procedure TJanusDependenciesCommandBase.Execute;
begin
  try
    Download;
    Extract;
  except
    on e: Exception do
    begin
      writeLog('ERRO: ' + e.Message);
      raise;
    end;
  end;
end;

procedure TJanusDependenciesCommandBase.Extract;
var
  zip : TZipFile;
  rootPath : String;
begin
  zip := TZipFile.Create;
  try
    writeLog('Extraindo Arquivos...');
    zip.ExtractZipFile(ZipFileName, ExtractFilePath(ZipFileName));
    zip.Open(ZipFileName, zmRead);
    try
      rootPath := GetPath + zip.FileNames[0].Replace('/', '\');
      MoveDirectories(rootPath);
      MoveFiles(rootPath);

      TDirectory.Delete(rootPath, True);
    finally
      zip.Close;
    end;
    writeLog('Extra�do com sucesso.');
  finally
    zip.Free;
    TFile.Delete(ZipFileName);
  end;
end;

procedure TJanusDependenciesCommandBase.MoveDirectories(ARootPath: String);
var
  i         : Integer;
  paths     : TStringDynArray;
  splitPath : TArray<String>;
begin
  paths := TDirectory.GetDirectories(ARootPath + 'Source\');
  for i := 0 to Pred(Length(paths)) do
  begin
    splitPath := paths[i].Split(['\']);
    TDirectory.Copy(paths[i], GetPath + splitPath[Length(splitPath) - 1]);
  end;
end;

procedure TJanusDependenciesCommandBase.MoveFiles(ARootPath: String);
var
  i     : Integer;
  files : TStringDynArray;
  splitFile: TArray<String>;
begin
  files := TDirectory.GetFiles(ARootPath + 'Source\');
  for i := 0 to Pred(Length(files)) do
  begin
    splitFile := files[i].Split(['\']);
    TFile.Copy(files[i], GetPath + splitFile[Length(splitFile) - 1], True);
  end;
end;

class function TJanusDependenciesCommandBase.New(ATag: String; ALog: TLog): IJanusDependenciesCommand;
begin
  result := Self.create(ATag, ALog);
end;

procedure TJanusDependenciesCommandBase.writeLog(AText: String);
begin
  if Assigned(FLog) then
    FLog(AText);
end;

end.
