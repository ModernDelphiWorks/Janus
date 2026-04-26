object ProviderDM: TProviderDM
  OldCreateOrder = False
  Height = 214
  Width = 341
  object FDConnection1: TFDConnection
    Params.Strings = (
      'Database=janus_rest_console_test.db'
      'LockingMode=Normal'
      'OpenMode=CreateUTF8'
      'DriverID=SQLite')
    LoginPrompt = False
    Left = 92
    Top = 46
  end
  object FDGUIxWaitCursor1: TFDGUIxWaitCursor
    Provider = 'Console'
    Left = 148
    Top = 126
  end
  object FDPhysSQLiteDriverLink1: TFDPhysSQLiteDriverLink
    Left = 208
    Top = 50
  end
end
