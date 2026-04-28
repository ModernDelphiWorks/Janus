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

program Janus.Tests.Unit;

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
  Test.Janus.Mapping.Cache   in 'Unit\Core\Test.Janus.Mapping.Cache.pas',
  Test.Janus.RTTI.Singleton  in 'Unit\Core\Test.Janus.RTTI.Singleton.pas',
  Test.Janus.Types.Nullable       in 'Unit\Core\Test.Janus.Types.Nullable.pas',
  Test.Janus.Lazy.Smoke in 'Unit\Mapping.Lazy\Test.Janus.Lazy.Smoke.pas',
  Test.Janus.Container.ObjectSet.LazyProxy in 'Unit\Container\Test.Janus.Container.ObjectSet.LazyProxy.pas',
  Test.Janus.Mapping.Lazy    in 'Unit\Mapping.Lazy\Test.Janus.Mapping.Lazy.pas',
  Test.Janus.Lazy.Proxy.Base      in 'Unit\Mapping.Lazy\Test.Janus.Lazy.Proxy.Base.pas',
  Test.Janus.Container.DataSet.LazyProxy in 'Unit\Container\Test.Janus.Container.DataSet.LazyProxy.pas',
  Test.Janus.Lazy.Rest  in 'Integration\Test.Janus.Lazy.Rest.pas',
  Test.Janus.Lazy.Proxy.Multiplicity in 'Unit\Mapping.Lazy\Test.Janus.Lazy.Proxy.Multiplicity.pas',
  Test.Janus.Types.Lazy    in 'Unit\Core\Test.Janus.Types.Lazy.pas',
  Test.Janus.Mapping.Dictionary  in 'Unit\Core\Test.Janus.Mapping.Dictionary.pas',
  Test.Janus.Mapping.QueryCache     in 'Unit\Core\Test.Janus.Mapping.QueryCache.pas',
  Test.Janus.Container.DataSet.AutoLazy in 'Unit\Container\Test.Janus.Container.DataSet.AutoLazy.pas',
  /// Advanced Tests — SPRINT-14
  Test.Janus.Criteria.Advanced in 'Unit\Criteria\Test.Janus.Criteria.Advanced.pas',
  Test.Janus.Middleware.Pipeline in 'Unit\Middleware\Test.Janus.Middleware.Pipeline.pas',
  Test.Janus.DML.Generator.SQLite in 'Unit\Core\Test.Janus.DML.Generator.SQLite.pas',
  Test.Janus.FluentSQL.Integration in 'Unit\Criteria\Test.Janus.FluentSQL.Integration.pas',
  /// REST/Horse Tests — ESP-002
  Test.Janus.REST.QueryParse in 'RESTHorse\Test.Janus.REST.QueryParse.pas',
  /// Plugin/Middleware Tests — Demand A
  Test.Janus.Plugin.Registry in 'Unit\Middleware\Test.Janus.Plugin.Registry.pas',
  Test.Janus.Plugin.Integration in 'Integration\Test.Janus.Plugin.Integration.pas',
  Test.Janus.Crud.EndToEnd in 'Integration\Test.Janus.Crud.EndToEnd.pas',
  /// CodeGen Tests — Demand A
  Test.Janus.CodeGen.Engine in 'Unit\CodeGen\Test.Janus.CodeGen.Engine.pas',
  Test.Janus.CodeGen.Schemas in 'Unit\CodeGen\Test.Janus.CodeGen.Schemas.pas',
  Test.Janus.CodeGen.Template in 'Unit\CodeGen\Test.Janus.CodeGen.Template.pas',
  /// JSON Tests — Demand A
  Test.Janus.Json in 'Unit\Core\Test.Janus.Json.pas';

begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
  Exit;
{$ENDIF}
  System.ExitCode := TJanusTestRunner.Execute('.janus_smoke_write_probe.tmp', True);
end.
