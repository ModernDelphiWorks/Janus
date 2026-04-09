unit Janus.CodeGen.Options;

interface

uses
  SysUtils,
  IniFiles;

type
  TJanusCodeGenOptions = class
  private
    FLowerCaseNames: Boolean;
    FGenerateLazy: Boolean;
    FGenerateNullable: Boolean;
    FGenerateDictionary: Boolean;
    FProjectPrefix: String;
    FOutputPath: String;
  public
    constructor Create;
    procedure SaveToFile(const AFileName: String);
    procedure LoadFromFile(const AFileName: String);
    property LowerCaseNames: Boolean read FLowerCaseNames write FLowerCaseNames;
    property GenerateLazy: Boolean read FGenerateLazy write FGenerateLazy;
    property GenerateNullable: Boolean read FGenerateNullable write FGenerateNullable;
    property GenerateDictionary: Boolean read FGenerateDictionary write FGenerateDictionary;
    property ProjectPrefix: String read FProjectPrefix write FProjectPrefix;
    property OutputPath: String read FOutputPath write FOutputPath;
  end;

implementation

{ TJanusCodeGenOptions }

constructor TJanusCodeGenOptions.Create;
begin
  inherited Create;
  FLowerCaseNames := False;
  FGenerateLazy := False;
  FGenerateNullable := True;
  FGenerateDictionary := True;
  FProjectPrefix := '';
  FOutputPath := '';
end;

procedure TJanusCodeGenOptions.SaveToFile(const AFileName: String);
var
  LIni: TIniFile;
begin
  LIni := TIniFile.Create(AFileName);
  try
    LIni.WriteBool('CodeGen', 'LowerCaseNames', FLowerCaseNames);
    LIni.WriteBool('CodeGen', 'GenerateLazy', FGenerateLazy);
    LIni.WriteBool('CodeGen', 'GenerateNullable', FGenerateNullable);
    LIni.WriteBool('CodeGen', 'GenerateDictionary', FGenerateDictionary);
    LIni.WriteString('CodeGen', 'ProjectPrefix', FProjectPrefix);
    LIni.WriteString('CodeGen', 'OutputPath', FOutputPath);
  finally
    LIni.Free;
  end;
end;

procedure TJanusCodeGenOptions.LoadFromFile(const AFileName: String);
var
  LIni: TIniFile;
begin
  if not FileExists(AFileName) then
    Exit;
  LIni := TIniFile.Create(AFileName);
  try
    FLowerCaseNames := LIni.ReadBool('CodeGen', 'LowerCaseNames', False);
    FGenerateLazy := LIni.ReadBool('CodeGen', 'GenerateLazy', False);
    FGenerateNullable := LIni.ReadBool('CodeGen', 'GenerateNullable', True);
    FGenerateDictionary := LIni.ReadBool('CodeGen', 'GenerateDictionary', True);
    FProjectPrefix := LIni.ReadString('CodeGen', 'ProjectPrefix', '');
    FOutputPath := LIni.ReadString('CodeGen', 'OutputPath', '');
  finally
    LIni.Free;
  end;
end;

end.
