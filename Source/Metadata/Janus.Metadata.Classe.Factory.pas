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

  THIN COMPATIBILITY SUBCLASSES (frente-8, 16 Jul 2026): the "decorated-class
  metadata factory" logic that used to live here moved to MetaDbDiff (see
  MetaDbDiff.Metadata.Model.Factory.TMetadataModelAbstract/TMetadataModelFactory),
  for the same reason TModelDbCompare's logic moved out of Janus.ModelDB.Compare
  - this code only ever produced/consumed MetaDbDiff catalog types, so it
  belongs next to the rest of the comparison engine, not inside Janus.

  This unit is kept ONLY so the old type names (TMetadataClasseAbstract,
  TMetadataClasseFactory) still resolve for anyone who referenced them
  directly by name. Grepped across the whole developer-friends-backend tree
  (application code + every sibling .modules/* repo) on 16 Jul 2026: nothing
  outside Janus referenced these two names, and inside Janus the only former
  consumer (Janus.ModelDB.Compare) no longer needs them either - it now
  inherits its metadata-factory field from MetaDbDiff.Database.ModelCompare.
  TModelDatabaseCompare, which builds its own TMetadataModelFactory internally.
  Test.Janus.Metadata.Compare.pas was retargeted (frente-8) to exercise
  TMetadataModelFactory from MetaDbDiff.Metadata.Model.Factory directly, since
  that is the real, canonical implementation - testing the deprecated alias
  here would just be indirection with no extra coverage. Given that, these two
  classes are marked `deprecated` below: nothing in this ecosystem is expected
  to emit a warning because of it.

  Both classes below are empty subclasses - no fields, no overrides, nothing
  reimplemented. All behaviour (ExtractMetadata, ModelMetadata, the
  constructor/destructor pair) is inherited verbatim from MetaDbDiff.
}

unit Janus.Metadata.Classe.Factory;

interface

uses
  MetaDbDiff.Metadata.Model.Factory;

type
  TMetadataClasseAbstract = class abstract(TMetadataModelAbstract)
  end deprecated 'Use TMetadataModelAbstract from MetaDbDiff.Metadata.Model.Factory';

  TMetadataClasseFactory = class(TMetadataModelFactory)
  end deprecated 'Use TMetadataModelFactory from MetaDbDiff.Metadata.Model.Factory';

implementation

end.
