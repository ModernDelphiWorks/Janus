{
  ------------------------------------------------------------------------------
  Janus
  Modern Object-Relational Mapping (ORM) framework for Delphi.

  SPDX-License-Identifier: MIT
  Copyright (c) 2016-2026 Isaque Pinheiro

  Licensed under the MIT License.
  See the LICENSE file in the project root for full license information.
  ------------------------------------------------------------------------------
}

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

program JanusSmoke;

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}
{$STRONGLINKTYPES ON}

uses
  System.Classes,
  System.SysUtils,
  System.IOUtils,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ENDIF}
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  Janus.Test.Runner in 'Common\Janus.Test.Runner.pas',
  /// Models
  MetaDbDiff.Mapping.Register,
  Model.Atendimento in '..\..\Examples\Delphi\Data\Object Lazy\Model.Atendimento.pas',
  Model.Exame       in '..\..\Examples\Delphi\Data\Object Lazy\Model.Exame.pas',
  Model.Procedimento in '..\..\Examples\Delphi\Data\Object Lazy\Model.Procedimento.pas',
  Model.Setor       in '..\..\Examples\Delphi\Data\Object Lazy\Model.Setor.pas',
  Janus.Model.Client in '..\..\Examples\Delphi\Data\Models\Janus.Model.Client.pas',
  Janus.Model.Detail in '..\..\Examples\Delphi\Data\Models\Janus.Model.Detail.pas',
  Janus.Model.Lookup in '..\..\Examples\Delphi\Data\Models\Janus.Model.Lookup.pas',
  Janus.Model.Master in '..\..\Examples\Delphi\Data\Models\Janus.Model.Master.pas',
  Janus.DML.Generator.SQLite in '..\..\Source\Core\Janus.DML.Generator.SQLite.pas',
  /// Tests
  TestMappingCache   in 'Tests\TestMappingCache.pas',
  TestRttiSingleton  in 'Tests\TestRttiSingleton.pas',
  TestNullable       in 'Tests\TestNullable.pas',
  TestSmokeLazyLoading in 'Tests\TestSmokeLazyLoading.pas',
  TestObjectSetLazyProxy in 'Tests\TestObjectSetLazyProxy.pas',
  TestLazyMapping    in 'Tests\TestLazyMapping.pas',
  TestLazyProxy      in 'Tests\TestLazyProxy.pas',
  TestDataSetLazyProxy in 'Tests\TestDataSetLazyProxy.pas',
  TestRestLazyProxy  in 'Tests\TestRestLazyProxy.pas',
  TestLazyProxyMultiplicity in 'Tests\TestLazyProxyMultiplicity.pas',
  TestLazyWrapper    in 'Tests\TestLazyWrapper.pas',
  TestGetDictionary  in 'Tests\TestGetDictionary.pas',
  TestQueryCache     in 'Tests\TestQueryCache.pas',
  TestDataSetAutoLazy in 'Tests\TestDataSetAutoLazy.pas',
  /// Advanced Tests — SPRINT-14
  TestCriteriaAdvanced in 'Tests\TestCriteriaAdvanced.pas',
  TestMiddlewarePipeline in 'Tests\TestMiddlewarePipeline.pas',
  TestDMLGenerator in 'Tests\TestDMLGenerator.pas',
  TestFluentSQLIntegration in 'Tests\TestFluentSQLIntegration.pas',
  /// REST/Horse Tests — ESP-002
  TestJanusRESTQueryParse in 'Tests\TestJanusRESTQueryParse.pas',
  /// Plugin/Middleware Tests — Demand A
  TestPluginRegistry in 'Tests\TestPluginRegistry.pas',
  TestPluginIntegration in 'Tests\TestPluginIntegration.pas',
  TestCrudEndToEnd in 'Tests\TestCrudEndToEnd.pas',
  /// CodeGen Tests — Demand A
  TestCodeGenEngine in 'Tests\TestCodeGenEngine.pas',
  TestCodeGenComplex in 'Tests\TestCodeGenComplex.pas',
  TestCodeGenTemplate in 'Tests\TestCodeGenTemplate.pas',
  /// JSON Tests — Demand A
  TestJanusJson in 'Tests\TestJanusJson.pas';

begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
  Exit;
{$ENDIF}
  System.ExitCode := TJanusTestRunner.Execute('.janus_smoke_write_probe.tmp', True);
end.
