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

  ORM Brasil: um ORM simples e descomplicado para quem utiliza Delphi.
}

unit Janus.DataSet.Events;

interface

uses
  DB,
  Rtti,
  TypInfo;

type
  /// <summary> What the consumer wants done with child rows that are typed in
  ///  and not yet saved, at the moment the master is about to scroll.
  ///  pcaDiscard is the DEFAULT and is byte-for-byte what the framework has
  ///  always done: TDataSetAdapter<M>.DoAfterScroll re-opens the children from
  ///  the database and whatever was typed is gone. That still holds for the
  ///  OPERATOR scroll, which is the only move this enum is ever consulted for;
  ///  since issue #276 the same DoAfterScroll re-opens nothing while the mover
  ///  is the framework's own read walk - _ExecuteOneToMany AND
  ///  _ExecuteOneToOne, BOTH of them, so a read routed through the
  ///  single-object branch discards nothing either. OneToOne and ManyToOne both
  ///  route to that branch, by multiplicity; what is MEASURED is the BRANCH,
  ///  driven through a OneToOne - no test carries the ManyToOne label.
  ///  Neither walk is a scroll anybody chose. pcaPost saves the pending
  ///  children first. pcaCancel calls Abort, so the master never leaves the
  ///  row. Nothing here changes on its own: the enum is only read when a
  ///  handler is assigned to TDataSetBaseAdapter<M>.OnBeforeScrollPendingChilds
  ///  - with no handler the framework never even looks for pending rows. </summary>
  TPendingChildsAction = (pcaDiscard, pcaPost, pcaCancel);

  /// <summary> Fired by TDataSetAdapter<M>.DoBeforeScroll when the master is
  ///  about to move and at least one child dataset holds unsaved rows.
  ///  APendingChilds lists exactly those child datasets. AAction arrives
  ///  pre-seeded with pcaDiscard, so a handler that ignores it - or that only
  ///  logs - gets the historical behaviour and nothing else. </summary>
  TBeforeScrollPendingChildsEvent = procedure(const ASender: TObject;
    const APendingChilds: TArray<TDataSet>;
    var AAction: TPendingChildsAction) of object;

  TDataSetEvents = class abstract
  private
    FBeforeScroll: TDataSetNotifyEvent;
    FAfterScroll: TDataSetNotifyEvent;
    FBeforeOpen: TDataSetNotifyEvent;
    FAfterOpen: TDataSetNotifyEvent;
    FBeforeClose: TDataSetNotifyEvent;
    FAfterClose: TDataSetNotifyEvent;
    FBeforeInsert: TDataSetNotifyEvent;
    FAfterInsert: TDataSetNotifyEvent;
    FBeforeEdit: TDataSetNotifyEvent;
    FAfterEdit: TDataSetNotifyEvent;
    FBeforeDelete: TDataSetNotifyEvent;
    FAfterDelete: TDataSetNotifyEvent;
    FBeforePost: TDataSetNotifyEvent;
    FAfterPost: TDataSetNotifyEvent;
    FBeforeCancel: TDataSetNotifyEvent;
    FAfterCancel: TDataSetNotifyEvent;
    FOnNewRecord: TDataSetNotifyEvent;
  public
    property BeforeScroll: TDataSetNotifyEvent read FBeforeScroll write FBeforeScroll;
    property AfterScroll: TDataSetNotifyEvent read FAfterScroll write FAfterScroll;
    property BeforeOpen: TDataSetNotifyEvent read FBeforeOpen write FBeforeOpen;
    property AfterOpen: TDataSetNotifyEvent read FAfterOpen write FAfterOpen;
    property BeforeClose: TDataSetNotifyEvent read FBeforeClose write FBeforeClose;
    property AfterClose: TDataSetNotifyEvent read FAfterClose write FAfterClose;
    property BeforeInsert: TDataSetNotifyEvent read FBeforeInsert write FBeforeInsert;
    property AfterInsert: TDataSetNotifyEvent read FAfterInsert write FAfterInsert;
    property BeforeEdit: TDataSetNotifyEvent read FBeforeEdit write FBeforeEdit;
    property AfterEdit: TDataSetNotifyEvent read FAfterEdit write FAfterEdit;
    property BeforeDelete: TDataSetNotifyEvent read FBeforeDelete write FBeforeDelete;
    property AfterDelete: TDataSetNotifyEvent read FAfterDelete write FAfterDelete;
    property BeforePost: TDataSetNotifyEvent read FBeforePost write FBeforePost;
    property AfterPost: TDataSetNotifyEvent read FAfterPost write FAfterPost;
    property BeforeCancel: TDataSetNotifyEvent read FBeforeCancel write FBeforeCancel;
    property AfterCancel: TDataSetNotifyEvent read FAfterCancel write FAfterCancel;
    property OnNewRecord: TDataSetNotifyEvent read FOnNewRecord write FOnNewRecord;
  end;

implementation

end.
