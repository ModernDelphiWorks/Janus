unit TestGetDictionary;

interface

uses
  DUnitX.TestFramework,
  Rtti,
  MetaDbDiff.Mapping.Attributes,
  MetaDbDiff.RTTI.Helper,
  Model.Exame;

type
  [TestFixture]
  TTestGetDictionary = class
  public
    [Test]
    procedure TestOverloadWithPreExtracted;
  end;

implementation

uses
  Janus.Objects.Utils;

{ TTestGetDictionary }

procedure TTestGetDictionary.TestOverloadWithPreExtracted;
var
  LRttiType: TRttiType;
  LProperty: TRttiProperty;
  LDictFromOriginal: Dictionary;
  LDictFromOverload: Dictionary;
  LPreExtracted: Dictionary;
  LAttribute: TCustomAttribute;
begin
  LRttiType := RttiSingleton.GetRttiType(TExame);
  Assert.IsNotNull(LRttiType, 'RTTI type for TExame must not be nil');

  for LProperty in LRttiType.GetProperties do
  begin
    if LProperty.Name <> 'Posto' then
      Continue;

    LDictFromOriginal := LProperty.GetDictionary;
    Assert.IsNotNull(LDictFromOriginal, 'GetDictionary() must return Dictionary for Posto');

    LPreExtracted := nil;
    for LAttribute in LProperty.GetAttributes do
    begin
      if LAttribute is Dictionary then
      begin
        LPreExtracted := Dictionary(LAttribute);
        Break;
      end;
    end;
    Assert.IsNotNull(LPreExtracted, 'Pre-extracted Dictionary must not be nil');

    LDictFromOverload := LProperty.GetDictionary(LPreExtracted);
    Assert.AreSame(TObject(LPreExtracted), TObject(LDictFromOverload),
      'GetDictionary(ADictionary) must return the pre-extracted instance');

    LDictFromOverload := LProperty.GetDictionary(nil);
    Assert.IsNotNull(LDictFromOverload,
      'GetDictionary(nil) must fall back to original GetDictionary');
    Assert.AreSame(TObject(LDictFromOriginal), TObject(LDictFromOverload),
      'GetDictionary(nil) must return same result as GetDictionary()');
    Exit;
  end;
  Assert.Fail('Property Posto not found on TExame');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestGetDictionary);

end.
