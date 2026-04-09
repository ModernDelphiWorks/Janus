unit TestRttiSingleton;

interface

uses
  DUnitX.TestFramework,
  Rtti,
  MetaDbDiff.Mapping.Explorer,
  MetaDbDiff.Mapping.Classes,
  Janus.Objects.Utils,
  Model.Atendimento;

type
  [TestFixture]
  TTestRttiSingleton = class
  public
    [Test]
    procedure TestGetRttiType_ReturnsValidType;
    [Test]
    procedure TestGetInstance_ReturnsSameInstance;
    [Test]
    procedure TestMappingExplorer_RttiPathRemainsConsistent;
  end;

implementation

{ TTestRttiSingleton }

procedure TTestRttiSingleton.TestGetRttiType_ReturnsValidType;
var
  LType: TRttiType;
begin
  LType := RttiSingleton.GetRttiType(TAtendimento);
  Assert.IsNotNull(LType, 'RttiType must not be nil');
  Assert.AreEqual('TAtendimento', LType.Name);
end;

procedure TTestRttiSingleton.TestGetInstance_ReturnsSameInstance;
var
  LInstance1: IRttiSingleton;
  LInstance2: IRttiSingleton;
begin
  LInstance1 := TRttiSingleton.GetInstance;
  LInstance2 := TRttiSingleton.GetInstance;
  Assert.IsTrue(LInstance1 = LInstance2, 'Must return the same singleton instance');
end;

procedure TTestRttiSingleton.TestMappingExplorer_RttiPathRemainsConsistent;
var
  LRttiType: TRttiType;
  LTableMapping: TTableMapping;
begin
  LRttiType := RttiSingleton.GetRttiType(TAtendimento);
  Assert.IsNotNull(LRttiType, 'RttiSingleton must provide RTTI for mapped classes');

  LTableMapping := TMappingExplorer.GetMappingTable(TAtendimento);
  Assert.IsNotNull(LTableMapping, 'TMappingExplorer must resolve mapping for the same RTTI type');
  Assert.AreEqual('ATENDIMENTOS', LTableMapping.Name);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRttiSingleton);

end.
