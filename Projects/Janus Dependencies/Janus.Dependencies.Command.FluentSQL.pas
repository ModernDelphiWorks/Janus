unit Janus.Dependencies.Command.FluentSQL;

interface

uses
  Janus.Dependencies.Interfaces,
  Janus.Dependencies.Command.Base,
  System.StrUtils,
  System.SysUtils;

type TJanusDependenciesCommandFluentSQL = class(TJanusDependenciesCommandBase, IJanusDependenciesCommand)

  protected
    function GetPath: String; override;
    function UrlDownloadFile: String; override;
    function ZipFileName: String; override;

end;

implementation

{ TJanusDependenciesCommandFluentSQL }

function TJanusDependenciesCommandFluentSQL.GetPath: String;
begin
  result := ExtractFilePath(GetModuleName(HInstance)) +
    'Source\Dependencies\FluentSQL\';

  ForceDirectories(result);
end;

function TJanusDependenciesCommandFluentSQL.UrlDownloadFile: String;
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
    result := Format('https://github.com/HashLoad/FluentSQL/archive/refs/heads/%s.zip', [LVersion])
  else
    result := Format('https://github.com/HashLoad/FluentSQL/archive/refs/tags/%s.zip', [LVersion]);
end;

function TJanusDependenciesCommandFluentSQL.ZipFileName: String;
begin
  result := GetPath + 'FluentSQL.zip';

  ForceDirectories(ExtractFilePath(result));
end;

end.
