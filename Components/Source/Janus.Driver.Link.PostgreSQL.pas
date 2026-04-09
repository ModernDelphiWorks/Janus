unit Janus.Driver.Link.PostgreSQL;

interface

uses
  Classes;

type
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
  TJanusDriverLinkPostgreSQL = class(TComponent)
  end;

implementation

end.
