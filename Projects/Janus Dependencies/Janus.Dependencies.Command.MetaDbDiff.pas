unit Janus.Dependencies.Command.MetaDbDiff;

interface

uses
  Janus.Dependencies.Interfaces,
  Janus.Dependencies.Command.Base,
  System.StrUtils,
  System.SysUtils;

type TJanusDependenciesCommandMetaDbDiff = class(TJanusDependenciesCommandBase, IJanusDependenciesCommand)

  protected
    function GetPath: String; override;
    function UrlDownloadFile: String; override;
    function ZipFileName: String; override;

end;

implementation

{ TJanusDependenciesCommandMetaDbDiff }

function TJanusDependenciesCommandMetaDbDiff.GetPath: String;
begin
  result := ExtractFilePath(GetModuleName(HInstance)) +
    'Source\Dependencies\MetaDbDiff\';

  ForceDirectories(result);
end;

function TJanusDependenciesCommandMetaDbDiff.UrlDownloadFile: String;
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
    result := Format('https://github.com/HashLoad/MetaDbDiff/archive/refs/heads/%s.zip', [LVersion])
  else
    result := Format('https://github.com/HashLoad/MetaDbDiff/archive/refs/tags/%s.zip', [LVersion]);
end;

function TJanusDependenciesCommandMetaDbDiff.ZipFileName: String;
begin
  result := GetPath + 'MetaDbDiff.zip';

  ForceDirectories(ExtractFilePath(result));
end;

end.
