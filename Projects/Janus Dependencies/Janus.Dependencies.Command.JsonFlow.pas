unit Janus.Dependencies.Command.JsonFlow;

interface

uses
  Janus.Dependencies.Interfaces,
  Janus.Dependencies.Command.Base,
  System.StrUtils,
  System.SysUtils;

type TJanusDependenciesCommandJsonFlow = class(TJanusDependenciesCommandBase, IJanusDependenciesCommand)

  protected
    function GetPath: String; override;
    function UrlDownloadFile: String; override;
    function ZipFileName: String; override;

end;

implementation

{ TJanusDependenciesCommandJsonFlow }

function TJanusDependenciesCommandJsonFlow.GetPath: String;
begin
  result := ExtractFilePath(GetModuleName(HInstance)) +
    'Source\Dependencies\JsonFlow\';

  ForceDirectories(result);
end;

function TJanusDependenciesCommandJsonFlow.UrlDownloadFile: String;
var
  LVersion: String;
begin
  if FTag.StartsWith('http') then
  begin
    result := FTag;
    Exit;
  end;

  LVersion := IfThen(FTag.IsEmpty, 'master', FTag);

  if (LVersion = 'master') or (LVersion = 'develop') then
    result := Format('https://github.com/HashLoad/JsonFlow/archive/refs/heads/%s.zip', [LVersion])
  else
    result := Format('https://github.com/HashLoad/JsonFlow/archive/refs/tags/%s.zip', [LVersion]);
end;

function TJanusDependenciesCommandJsonFlow.ZipFileName: String;
begin
  result := GetPath + 'JsonFlow.zip';

  ForceDirectories(ExtractFilePath(result));
end;

end.
