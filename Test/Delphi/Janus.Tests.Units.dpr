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

program Janus.Tests.Units;

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
  Test.Janus.Cursor.Double in 'Common\Test.Janus.Cursor.Double.pas',
  Test.Janus.Model.FieldShapes in 'Common\Test.Janus.Model.FieldShapes.pas',
  /// Models
  MetaDbDiff.Mapping.Register,
  Test.Janus.Model.KeyOnly in 'Common\Test.Janus.Model.KeyOnly.pas',
  Test.Janus.Model.AutoIncTree in 'Common\Test.Janus.Model.AutoIncTree.pas',
  Test.Janus.Model.AsymKey in 'Common\Test.Janus.Model.AsymKey.pas',
  Test.Janus.Model.Nested in 'Common\Test.Janus.Model.Nested.pas',
  Test.Janus.Model.ReservedColumn in 'Common\Test.Janus.Model.ReservedColumn.pas',
  Test.Janus.Model.Moment in 'Common\Test.Janus.Model.Moment.pas',
  Model.Atendimento in '..\..\Examples\Delphi\Data\Object Lazy\Model.Atendimento.pas',
  Model.Exame       in '..\..\Examples\Delphi\Data\Object Lazy\Model.Exame.pas',
  Model.Procedimento in '..\..\Examples\Delphi\Data\Object Lazy\Model.Procedimento.pas',
  Model.Setor       in '..\..\Examples\Delphi\Data\Object Lazy\Model.Setor.pas',
  Janus.Model.Client in '..\..\Examples\Delphi\Data\Models\Janus.Model.Client.pas',
  Janus.Model.Detail in '..\..\Examples\Delphi\Data\Models\Janus.Model.Detail.pas',
  Janus.Model.Lookup in '..\..\Examples\Delphi\Data\Models\Janus.Model.Lookup.pas',
  Janus.Model.Master in '..\..\Examples\Delphi\Data\Models\Janus.Model.Master.pas',
  Janus.DML.Generator.SQLite in '..\..\Source\Core\Janus.DML.Generator.SQLite.pas',
  Janus.DML.Generator.ADS in '..\..\Source\Core\Janus.DML.Generator.ADS.pas',
  /// Linked for the locale test: a dialect whose date mask carries '/'
  Janus.DML.Generator.MSSQL in '..\..\Source\Core\Janus.DML.Generator.MSSQL.pas',
  /// Tests
  Test.Janus.Driver.Register in 'Unit\Core\Test.Janus.Driver.Register.pas',
  Test.Janus.Mapping.Cache   in 'Unit\Core\Test.Janus.Mapping.Cache.pas',
  Test.Janus.RTTI.Singleton  in 'Unit\Core\Test.Janus.RTTI.Singleton.pas',
  Test.Janus.RTTI.Singleton.Concurrency in 'Unit\Core\Test.Janus.RTTI.Singleton.Concurrency.pas',
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
  Test.Janus.Metadata.Compare in 'Unit\Core\Test.Janus.Metadata.Compare.pas',
  Test.Janus.Container.DataSet.AutoLazy in 'Unit\Container\Test.Janus.Container.DataSet.AutoLazy.pas',
  /// Advanced Tests — SPRINT-14
  Test.Janus.Criteria.Advanced in 'Unit\Criteria\Test.Janus.Criteria.Advanced.pas',
  Test.Janus.Middleware.Pipeline in 'Unit\Middleware\Test.Janus.Middleware.Pipeline.pas',
  Test.Janus.DML.Generator.SQLite in 'Unit\Core\Test.Janus.DML.Generator.SQLite.pas',
  /// The ADS date literal: 'CC' is not a FormatDateTime specifier
  Test.Janus.DML.Generator.ADS in 'Unit\Core\Test.Janus.DML.Generator.ADS.pas',
  /// An unregistered driver must reach the user as the registry message
  Test.Janus.Command.UnregisteredDriver in 'Unit\Core\Test.Janus.Command.UnregisteredDriver.pas',
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
  Test.Janus.Json in 'Unit\Core\Test.Janus.Json.pas',
  /// Cursor advance regression — sibling of 1ad296b
  Test.Janus.Cursor.Advance in 'Unit\Core\Test.Janus.Cursor.Advance.pas',
  Test.Janus.AutoInc.Childs in 'Unit\Core\Test.Janus.AutoInc.Childs.pas',
  /// Issue #261 - the cascade must reach the children of the parent row they
  /// were typed under, in all four DataSet families
  Test.Janus.AutoInc.Distribution in 'Unit\Core\Test.Janus.AutoInc.Distribution.pas',
  Test.Janus.Apply.Loops in 'Unit\Core\Test.Janus.Apply.Loops.pas',
  /// RESTful\Common property/getter wiring — first coverage of that folder
  Test.Janus.RestFactory.MethodToken in 'Unit\RESTful\Test.Janus.RestFactory.MethodToken.pas',
  /// REST client master-detail wiring — first coverage of TRESTClientDataSetAdapter
  Test.Janus.MasterDetail.Link in 'Unit\RESTful\Test.Janus.MasterDetail.Link.pas',
  /// Nested-dataset clearing on delete — the opposite family from #207
  Test.Janus.Nested.Delete in 'Unit\Core\Test.Janus.Nested.Delete.pas',
  /// The scroll contract for unsaved child rows — issue #217
  Test.Janus.Scroll.PendingChilds in 'Unit\Core\Test.Janus.Scroll.PendingChilds.pas',
  /// Clearing a nested dataset from wherever the cursor is — issue #222
  Test.Janus.Bind.ClearNested in 'Unit\Core\Test.Janus.Bind.ClearNested.pas',
  /// Three levels with every key column spelled once — issue #225
  Test.Janus.Model.AsymTree in 'Common\Test.Janus.Model.AsymTree.pas',
  /// Whether the update leg of the ObjectSet OneToMany cascade propagates at
  /// all, and whether the master key reaches a child added on update — #242
  Test.Janus.ObjectSet.CascadeUpdateList in 'Integration\Test.Janus.ObjectSet.CascadeUpdateList.pas',
  /// Whether the MASTER key reaches a child added on update — issue #242
  Test.Janus.ObjectSet.UpdateMasterKey in 'Integration\Test.Janus.ObjectSet.UpdateMasterKey.pas',
  /// The base adapter's cascade DELETE order under an enforced FK — issue #240
  Test.Janus.ObjectSet.CascadeDeleteOrder in 'Integration\Test.Janus.ObjectSet.CascadeDeleteOrder.pas',
  /// What a real close costs against what emptying costs — issue #246
  Test.Janus.Close.VsEmpty in 'Unit\Container\Test.Janus.Close.VsEmpty.pas',
  /// The reopen, and the cursor count that shows the lazy path is alive — #248
  Test.Janus.Reopen.Lazy in 'Unit\Container\Test.Janus.Reopen.Lazy.pas',
  /// AddAdapter<T, M> on the branch a stock Janus.inc produces — issue #226
  Test.Janus.Manager.AddAdapter in 'Unit\Core\Test.Janus.Manager.AddAdapter.pas',
  /// The encoding convention for Source\, and its baseline ratchet — issue #214
  Test.Janus.Source.Encoding in 'Unit\Core\Test.Janus.Source.Encoding.pas';

begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
  Exit;
{$ENDIF}
  System.ExitCode := TJanusTestRunner.Execute('.janus_smoke_write_probe.tmp', True);
end.
