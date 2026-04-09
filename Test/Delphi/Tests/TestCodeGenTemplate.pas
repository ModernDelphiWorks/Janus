unit TestCodeGenTemplate;

interface

uses
  DUnitX.TestFramework,
  SysUtils,
  Generics.Collections,
  Janus.CodeGen.Template,
  Janus.CodeGen.Options;

type
  [TestFixture]
  TTestCodeGenTemplate = class
  public
    [Test]
    procedure TestApply_ReplacesPlaceholders;

    [Test]
    procedure TestApply_NoPlaceholders_ReturnsOriginal;

    [Test]
    procedure TestApply_MultiplePlaceholders;

    [Test]
    procedure TestApply_UnknownPlaceholderPreserved;

    [Test]
    procedure TestOptions_DefaultValues;

    [Test]
    procedure TestOptions_SaveAndLoad;
  end;

implementation

uses
  IniFiles;

{ TTestCodeGenTemplate }

procedure TTestCodeGenTemplate.TestApply_ReplacesPlaceholders;
var
  LPlaceholders: TDictionary<String, String>;
  LResult: String;
begin
  LPlaceholders := TDictionary<String, String>.Create;
  try
    LPlaceholders.Add('Name', 'Janus');
    LResult := TJanusCodeTemplate.Apply('Hello {{Name}}!', LPlaceholders);
    Assert.AreEqual('Hello Janus!', LResult);
  finally
    LPlaceholders.Free;
  end;
end;

procedure TTestCodeGenTemplate.TestApply_NoPlaceholders_ReturnsOriginal;
var
  LPlaceholders: TDictionary<String, String>;
  LResult: String;
begin
  LPlaceholders := TDictionary<String, String>.Create;
  try
    LResult := TJanusCodeTemplate.Apply('No placeholders here', LPlaceholders);
    Assert.AreEqual('No placeholders here', LResult);
  finally
    LPlaceholders.Free;
  end;
end;

procedure TTestCodeGenTemplate.TestApply_MultiplePlaceholders;
var
  LPlaceholders: TDictionary<String, String>;
  LResult: String;
begin
  LPlaceholders := TDictionary<String, String>.Create;
  try
    LPlaceholders.Add('A', '1');
    LPlaceholders.Add('B', '2');
    LResult := TJanusCodeTemplate.Apply('{{A}} + {{B}} = 3', LPlaceholders);
    Assert.AreEqual('1 + 2 = 3', LResult);
  finally
    LPlaceholders.Free;
  end;
end;

procedure TTestCodeGenTemplate.TestApply_UnknownPlaceholderPreserved;
var
  LPlaceholders: TDictionary<String, String>;
  LResult: String;
begin
  LPlaceholders := TDictionary<String, String>.Create;
  try
    LPlaceholders.Add('Known', 'Value');
    LResult := TJanusCodeTemplate.Apply('{{Known}} and {{Unknown}}', LPlaceholders);
    Assert.AreEqual('Value and {{Unknown}}', LResult);
  finally
    LPlaceholders.Free;
  end;
end;

procedure TTestCodeGenTemplate.TestOptions_DefaultValues;
var
  LOptions: TJanusCodeGenOptions;
begin
  LOptions := TJanusCodeGenOptions.Create;
  try
    Assert.IsFalse(LOptions.LowerCaseNames);
    Assert.IsFalse(LOptions.GenerateLazy);
    Assert.IsTrue(LOptions.GenerateNullable);
    Assert.IsTrue(LOptions.GenerateDictionary);
    Assert.AreEqual('', LOptions.ProjectPrefix);
    Assert.AreEqual('', LOptions.OutputPath);
  finally
    LOptions.Free;
  end;
end;

procedure TTestCodeGenTemplate.TestOptions_SaveAndLoad;
var
  LSave, LLoad: TJanusCodeGenOptions;
  LFileName: String;
begin
  LFileName := ExtractFilePath(ParamStr(0)) + 'test_options.ini';
  LSave := TJanusCodeGenOptions.Create;
  LLoad := TJanusCodeGenOptions.Create;
  try
    LSave.LowerCaseNames := True;
    LSave.GenerateLazy := True;
    LSave.GenerateNullable := False;
    LSave.GenerateDictionary := False;
    LSave.ProjectPrefix := 'Model.';
    LSave.OutputPath := 'C:\Output';
    LSave.SaveToFile(LFileName);

    LLoad.LoadFromFile(LFileName);

    Assert.IsTrue(LLoad.LowerCaseNames);
    Assert.IsTrue(LLoad.GenerateLazy);
    Assert.IsFalse(LLoad.GenerateNullable);
    Assert.IsFalse(LLoad.GenerateDictionary);
    Assert.AreEqual('Model.', LLoad.ProjectPrefix);
    Assert.AreEqual('C:\Output', LLoad.OutputPath);
  finally
    LLoad.Free;
    LSave.Free;
    if FileExists(LFileName) then
      DeleteFile(LFileName);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestCodeGenTemplate);

end.
