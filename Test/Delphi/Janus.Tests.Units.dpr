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
  Test.Janus.Model.NotIncKey in 'Common\Test.Janus.Model.NotIncKey.pas',
  Test.Janus.Model.AsymKey in 'Common\Test.Janus.Model.AsymKey.pas',
  /// The composite association whose seven columns are seven different types -
  /// the only model in the repo with a ftGuid column next to siblings. Issue
  /// #284 needs it here; until now it was linked only in RESTfulDriver.
  Test.Janus.Model.RestLazyKeys in 'Common\Test.Janus.Model.RestLazyKeys.pas',
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
  /// A SECOND dialect, linked for issue #284: with one generator only, "the
  /// GUID literal is chosen per dialect" would be an assertion held by
  /// nothing. Forgetting the link does NOT raise an Access Violation -
  /// Janus.Driver.Register.pas:64-66 raises a named exception naming the unit.
  Janus.DML.Generator.PostgreSQL in '..\..\Source\Core\Janus.DML.Generator.PostgreSQL.pas',
  /// THE SEVEN DISTRIBUTED GENERATORS - issue #341, Level 1.
  /// They sit in the `uses` clause of `library JanusFramework` (see
  /// Source\Janus\JanusFramework.dpr) and three of them - InterBase, MongoDB
  /// and MySQL - are also injected into the CLIENT's own project by the
  /// design-time package. Until now NO test project compiled a single one of
  /// them: the compile-coverage census measured 0 of 7 across all seven
  /// projects. Linking alone is not coverage, so each one is claimed by
  /// Test.Janus.DML.Generator.Distributed - the registration it promises and
  /// the dialect token its SELECT carries.
  Janus.DML.Generator.AbsoluteDB in '..\..\Source\Core\Janus.DML.Generator.AbsoluteDB.pas',
  Janus.DML.Generator.ElevateDB in '..\..\Source\Core\Janus.DML.Generator.ElevateDB.pas',
  Janus.DML.Generator.InterBase in '..\..\Source\Core\Janus.DML.Generator.InterBase.pas',
  /// NoSQL is the base class, not a dialect: it has NO initialization section
  /// and registers NOTHING. It is linked because MongoDB descends from it and
  /// the whole criteria body lives here.
  Janus.DML.Generator.NoSQL in '..\..\Source\Core\Janus.DML.Generator.NoSQL.pas',
  Janus.DML.Generator.MongoDB in '..\..\Source\Core\Janus.DML.Generator.MongoDB.pas',
  Janus.DML.Generator.MySQL in '..\..\Source\Core\Janus.DML.Generator.MySQL.pas',
  Janus.DML.Generator.NexusDB in '..\..\Source\Core\Janus.DML.Generator.NexusDB.pas',
  /// THE DataSnap SERVER PAIR - issue #341, Level 2. Compiled by none of the
  /// seven, yet #338 argues the crossed client verbs against the method table
  /// that lives here. Claimed by Test.Janus.Server.DataSnapResource.
  Janus.Server.DataSnap in '..\..\Source\RESTful\Server\Janus.Server.DataSnap.pas',
  Janus.Server.Resource.DataSnap in '..\..\Source\RESTful\Server\Janus.Server.Resource.DataSnap.pas',
  /// The embedded schema comparator - issue #341, Level 2. One class whose
  /// only content is a safety default, compiled by none of the seven.
  Janus.ModelDB.Compare in '..\..\Source\Metadata\Janus.ModelDB.Compare.pas',
  Janus.Form.Monitor in '..\..\Source\Monitor\Janus.Form.Monitor.pas',
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
  Test.Janus.DML.Dialect.Wiring in 'Unit\Core\Test.Janus.DML.Dialect.Wiring.pas',
  /// The SECOND dialect map - the REST view one - issue #357
  Test.Janus.RestView.Dialect.Map in 'Unit\Core\Test.Janus.RestView.Dialect.Map.pas',
  /// The seven distributed generators - issue #341, Level 1
  Test.Janus.DML.Generator.Distributed in 'Unit\Core\Test.Janus.DML.Generator.Distributed.pas',
  Test.Janus.Server.DataSnapResource in 'Unit\RESTful\Test.Janus.Server.DataSnapResource.pas',
  Test.Janus.ModelDB.Compare in 'Unit\Core\Test.Janus.ModelDB.Compare.pas',
  Test.Janus.Form.Monitor in 'Unit\Core\Test.Janus.Form.Monitor.pas',
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
  /// The INSERT against the null pattern of the object written - issue #352
  Test.Janus.Insert.CacheVsNullness in 'Integration\Test.Janus.Insert.CacheVsNullness.pas',
  /// Whether the child of a 1:1 association gets its own constructor run — issue #369
  Test.Janus.ObjectSet.OneToOneChildCtor in 'Integration\Test.Janus.ObjectSet.OneToOneChildCtor.pas',
  /// What a real close costs against what emptying costs — issue #246
  Test.Janus.Close.VsEmpty in 'Unit\Container\Test.Janus.Close.VsEmpty.pas',
  /// The reopen, and the cursor count that shows the lazy path is alive — #248
  Test.Janus.Reopen.Lazy in 'Unit\Container\Test.Janus.Reopen.Lazy.pas',
  /// AddAdapter<T, M> on the branch a stock Janus.inc produces — issue #226
  Test.Janus.Manager.AddAdapter in 'Unit\Core\Test.Janus.Manager.AddAdapter.pas',
  /// The encoding convention for Source\, and its baseline ratchet — issue #214
  Test.Janus.Source.Encoding in 'Unit\Core\Test.Janus.Source.Encoding.pas',
  /// Reading .Current of a grandparent must not destroy grandchild rows - #276
  Test.Janus.Grandchild.Read in 'Unit\Core\Test.Janus.Grandchild.Read.pas',
  /// The cascade must not carry a key the generator has not produced - #262
  Test.Janus.AutoInc.UngeneratedKey in 'Unit\Core\Test.Janus.AutoInc.UngeneratedKey.pas',
  /// A single-object association left nil must stay nil, not raise - #296
  Test.Janus.OneToOne.NilAssociation in 'Unit\Core\Test.Janus.OneToOne.NilAssociation.pas',
  /// And the SIBLING branch: a LIST association left nil - issue #307
  Test.Janus.OneToMany.NilList in 'Unit\Core\Test.Janus.OneToMany.NilList.pas',
  /// The WHERE RefreshRecord builds for the row under the cursor - issue #327
  Test.Janus.RefreshRecord.KeyLiteral in 'Unit\Core\Test.Janus.RefreshRecord.KeyLiteral.pas',
  /// The #295 filter over the repository's own ftBCD association - issue #319
  Test.Janus.Association.BcdColumn in 'Unit\Core\Test.Janus.Association.BcdColumn.pas',
  /// The predicate GetGeneratorWhere builds from a single AID - issue #326
  Test.Janus.DML.KeyPredicate in 'Unit\Core\Test.Janus.DML.KeyPredicate.pas',
  /// The fluent method that never assigned its Result - issue #332
  Test.Janus.Manager.AutoNextPacket in 'Unit\Core\Test.Janus.Manager.AutoNextPacket.pas',
  /// The width of the by-id API, and the guards that read it back - issue #333
  Test.Janus.KeyWidth.ByIdApi in 'Unit\Core\Test.Janus.KeyWidth.ByIdApi.pas',
  /// Compile gate for Components\Source\: every RequiresUnits entry in
  /// Janus.Link.Reg.pas must name a unit that actually exists - issue #340
  Test.Janus.LinkReg.RequiresUnits in 'Unit\Core\Test.Janus.LinkReg.RequiresUnits.pas';

begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
  Exit;
{$ENDIF}
  System.ExitCode := TJanusTestRunner.Execute('.janus_smoke_write_probe.tmp', True);
end.
