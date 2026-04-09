unit Janus.Dependencies.Command.DataEngine;

interface

uses
  Janus.Dependencies.Interfaces,
  Janus.Dependencies.Command.Base,
  System.StrUtils,
  System.SysUtils;

type TJanusDependenciesCommandDataEngine = class(TJanusDependenciesCommandBase, IJanusDependenciesCommand)

  protected
    function GetPath: String; override;
    function UrlDownloadFile: String; override;
    function ZipFileName: String; override;

end;

implementation

{ TJanusDependenciesCommandDataEngine }

function TJanusDependenciesCommandDataEngine.GetPath: String;
begin
  result := ExtractFilePath(GetModuleName(HInstance)) +
    'Source\Dependencies\DataEngine\';

  ForceDirectories(result);
end;

function TJanusDependenciesCommandDataEngine.UrlDownloadFile: String;
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
    result := Format('https://github.com/HashLoad/DataEngine/archive/refs/heads/%s.zip', [LVersion])
  else
    result := Format('https://github.com/HashLoad/DataEngine/archive/refs/tags/%s.zip', [LVersion]);
end;

function TJanusDependenciesCommandDataEngine.ZipFileName: String;
begin
  result := GetPath + 'DataEngine.zip';

  ForceDirectories(ExtractFilePath(result));
end;

end.
