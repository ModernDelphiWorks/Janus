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
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Janus.RestComponent;

interface

uses
  Classes,
  SysUtils;

type
  TJanusAboutInfo = (JanusAbout);

  {$IF CompilerVersion > 23}
  [ComponentPlatformsAttribute(pidWin32 or
                               pidWin64 or
                               pidWinArm64 or
                               pidOSX32 or
                               pidOSX64 or
                               pidOSXArm64 or
                               pidLinux32 or
                               pidLinux64 or
                               pidLinuxArm64)]
  {$IFEND}
  TJanusComponent = class(TComponent)
  private
    FAbout: TJanusAboutInfo;
  public
    constructor Create(AOwner: TComponent); overload; override;
  published
    property AboutInfo: TJanusAboutInfo read FAbout write FAbout stored False;
  end;

implementation

{ TJanusComponent }

constructor TJanusComponent.Create(AOwner: TComponent);
begin

end;

end.
