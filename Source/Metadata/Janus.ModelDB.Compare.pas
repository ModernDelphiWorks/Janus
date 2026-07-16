{
  ------------------------------------------------------------------------------
  Janus ORM
  State-of-the-art Object-Relational Mapping (ORM) framework for Delphi.

  SPDX-License-Identifier: MIT
  Copyright (c) 2025-2026 Isaque Pinheiro

  Licensed under the MIT License.
  See the LICENSE file in the project root for full license information.
  ------------------------------------------------------------------------------
}

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)

  THIN COMPATIBILITY SUBCLASS (frente-8, 16 Jul 2026): TModelDbCompare no
  longer carries its own "decorated classes vs database" logic. That logic
  moved to MetaDbDiff (see MetaDbDiff.Database.ModelCompare.TModelDatabaseCompare
  and MetaDbDiff.Metadata.Model.Factory.TMetadataModelFactory), which is where
  it belongs conceptually - it only compares MetaDbDiff catalogs, so Janus
  depending on it (rather than owning it) is the correct direction. This unit
  keeps the public name TModelDbCompare so existing Janus consumers (the
  FireDAC/Firemonkey and Object-Lazy examples, and anything else built against
  this unit) keep compiling unchanged.

  NEW DEFAULT BEHAVIOUR - restricted policy: unlike the old TModelDbCompare
  (and unlike MetaDbDiff.Database.ModelCompare.TModelDatabaseCompare, whose own
  default is FullProfile), THIS class sets

    Policy := TComparePolicy.JanusOrmProfile

  in its constructor, right after inherited construction. JanusOrmProfile is
  the intentionally restricted profile: it only lets the diff CREATE a new
  table, a new column, a new primary key or a new foreign key. It will NEVER
  generate (or execute) a DROP or an ALTER of any kind - not DROP TABLE, not
  DROP/ALTER COLUMN, not a PK/FK/index/check/trigger/view recreate pair. This
  is a deliberate product decision: Janus embeds this comparator to grow a
  database schema alongside a growing set of decorated classes, and growing a
  schema should never risk destroying a user's data or an existing column/index
  the diff doesn't fully understand. Operations the restricted policy blocks
  are NOT silently dropped - each one is appended, with a human-readable
  description, to SuppressedCommands (inherited from TDatabaseAbstract), so the
  caller can audit exactly what the diff wanted to do and chose not to.

  HOW TO GO BACK TO THE FULL (unrestricted) PROFILE: assign the whole record to
  the Policy property AFTER construction, before calling BuildDatabase - e.g.:

    LCompare := TModelDbCompare.Create(AConnection);
    LCompare.Policy := TComparePolicy.FullProfile; // opt back into DROP/ALTER
    LCompare.BuildDatabase;

  (TComparePolicy is a record - see the "uso correto" note in
  MetaDbDiff.Compare.Options.pas: always assign the whole record to Policy,
  never try to mutate Policy.Operations in place, that mutates only the getter's
  temporary and silently no-ops.)

  HOW TO EXECUTE THE GENERATED COMMANDS: generation is decoupled from execution
  (inherited from MetaDbDiff's TDatabaseFactory.BuildDatabase - see its header).
  CommandsAutoExecute now DEFAULTS TO FALSE (again, inherited - this is not
  something this subclass changes), so BuildDatabase always generates the DDL
  command list and builds their command text, but by default runs nothing
  against the target database. Two ways to actually apply the commands:
    1) Set CommandsAutoExecute := True BEFORE calling BuildDatabase, so
       BuildDatabase both generates and executes them in one call; or
    2) Leave CommandsAutoExecute at its False default, call BuildDatabase,
       inspect GetCommandList (and SuppressedCommands) to review what would
       run, and only then call ExecuteCommands to execute the previously
       generated list (ExecuteCommands re-validates the policy before running
       anything - see TDatabaseAbstract.ExecuteCommands / ValidateCommandsPolicy).

  Everything else - ExtractDatabase, ExecuteDDLCommands, the single FConnection
  field, its lifecycle - now lives in the parent, MetaDbDiff.Database.ModelCompare.
  TModelDatabaseCompare. This subclass adds nothing but the constructor's Policy
  assignment; see that unit's header for the full design rationale (why the
  connection is never disconnected here, the DROP+CREATE pairing rules for
  triggers/views/indexes/FKs/PKs, etc).

  DEPRECATED marker: grepped across the whole developer-friends-backend tree
  (application code + every sibling .modules/* repo) on 16 Jul 2026 - the only
  references to TModelDbCompare / this unit are inside Janus itself (this unit,
  and the two Examples\Delphi FireDAC/Object-Lazy forms). No consumer outside
  Janus uses this class, so the deprecated hint below cannot generate warning
  noise anywhere else in the ecosystem; it only nudges Janus' own examples.
}

unit Janus.ModelDB.Compare;

interface

uses
  DataEngine.FactoryInterfaces,
  MetaDbDiff.Compare.Options,
  MetaDbDiff.Database.ModelCompare;

type
  TModelDbCompare = class(TModelDatabaseCompare)
  public
    constructor Create(AConnTarget: IDBConnection); overload;
  end deprecated 'Use TModelDatabaseCompare from MetaDbDiff.Database.ModelCompare';

implementation

{ TModelDbCompare }

constructor TModelDbCompare.Create(AConnTarget: IDBConnection);
begin
  inherited Create(AConnTarget);
  // Product decision (frente-8): Janus' embedded comparator defaults to the
  // restricted profile - additive schema growth only, never DROP/ALTER. See
  // the unit header above for how to opt back into TComparePolicy.FullProfile.
  Policy := TComparePolicy.JanusOrmProfile;
end;

end.
