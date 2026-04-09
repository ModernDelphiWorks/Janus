unit Janus.Wizard.Main;

interface

uses
  SysUtils,
  ToolsAPI;

type
  TJanusModelWizard = class(TNotifierObject, IOTAWizard, IOTAMenuWizard)
  public
    { IOTAWizard }
    function GetIDString: String;
    function GetName: String;
    function GetState: TWizardState;
    procedure Execute;
    { IOTAMenuWizard }
    function GetMenuText: String;
  end;

procedure Register;

implementation

uses
  Janus.Wizard.Form;

{ TJanusModelWizard }

function TJanusModelWizard.GetIDString: String;
begin
  Result := 'Janus.ModelWizard';
end;

function TJanusModelWizard.GetName: String;
begin
  Result := 'Janus Model Generator';
end;

function TJanusModelWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

function TJanusModelWizard.GetMenuText: String;
begin
  Result := 'Janus Model Generator...';
end;

procedure TJanusModelWizard.Execute;
var
  LForm: TJanusWizardForm;
begin
  LForm := TJanusWizardForm.Create(nil);
  try
    LForm.ShowModal;
  finally
    LForm.Free;
  end;
end;

procedure Register;
begin
  RegisterPackageWizard(TJanusModelWizard.Create);
end;

end.
