unit Janus.Dependencies.Command.RESTful;

// DECISAO: Este command NAO esta incluido no executor padrao de JanusDependencies.
// Janus-Restful-Components e um componente opcional do framework e nao e uma
// dependencia de compilacao do nucleo (diferente de FluentSQL, MetaDbDiff,
// DataEngine e JsonFlow). O destino tambem difere: extrai para Source\RESTFul\
// em vez de Source\Dependencies\. Para instala-lo, invoque este command
// explicitamente via NewExecutor.AddCommand(TJanusDependenciesCommandRESTFul.New(...)).

interface

uses
  Janus.Dependencies.Interfaces,
  Janus.Dependencies.Command.Base,
  System.StrUtils,
  System.SysUtils;

type TJanusDependenciesCommandRESTFul = class(TJanusDependenciesCommandBase, IJanusDependenciesCommand)

  protected
    function GetPath: String; override;
    function UrlDownloadFile: String; override;
    function ZipFileName: String; override;

end;

implementation

{ TJanusDependenciesCommandJsonFlow }

function TJanusDependenciesCommandRESTFul.GetPath: String;
begin
  result := ExtractFilePath(GetModuleName(HInstance)) +
    'Source\RESTFul\';

  ForceDirectories(result);
end;

function TJanusDependenciesCommandRESTFul.UrlDownloadFile: String;
var
  version: String;
begin
  version := IfThen(FTag.IsEmpty, 'master', FTag);

  if version = 'master' then
    result := 'https://github.com/HashLoad/Janus-Restful-Components/archive/refs/heads/master.zip'
  else
  if version = 'develop' then
    result := 'https://github.com/HashLoad/Janus-Restful-Components/archive/refs/heads/develop.zip'
  else
    result := Format('https://github.com/HashLoad/Janus-Restful-Components/archive/refs/tags/%s.zip',
      [version])
end;

function TJanusDependenciesCommandRESTFul.ZipFileName: String;
begin
  result := GetPath + 'restful.zip';

  ForceDirectories(ExtractFilePath(result));
end;

end.
