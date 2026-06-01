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

{
  @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
}

unit Janus.DML.Commands;

interface

uses
  MetaDbDiff.Mapping.Classes;

type
  TDMLCommandAutoInc = class
  private
    FSequence: TSequenceMapping;
    FPrimaryKey: TPrimaryKeyMapping;
    FExistSequence: Boolean;
  public
    property Sequence: TSequenceMapping read FSequence write FSequence;
    property PrimaryKey: TPrimaryKeyMapping read FPrimaryKey write FPrimaryKey;
    property ExistSequence: Boolean read FExistSequence write FExistSequence;
  end;

implementation

end.
