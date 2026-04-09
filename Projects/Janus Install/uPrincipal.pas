unit uPrincipal;

interface

uses
  JclIDEUtils, JclCompilerUtils,

  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, StdCtrls, ExtCtrls, Buttons, pngimage, ShlObj,
  uFrameLista, IOUtils, TypInfo,
  Types, JvComponentBase, JvCreateProcess, JvExControls, JvAnimatedImage,
  JvGIFCtrl, JvWizard, JvWizardRouteMapNodes, CheckLst;

type
  TDestino = (tdSystem, tdDelphi, tdNone);

  TfrmPrincipal = class(TForm)
    wizPrincipal: TJvWizard;
    wizMapa: TJvWizardRouteMapNodes;
    wizPgConfiguracao: TJvWizardInteriorPage;
    wizPgInstalacao: TJvWizardInteriorPage;
    wizPgFinalizar: TJvWizardInteriorPage;
    wizPgInicio: TJvWizardWelcomePage;
    Label4: TLabel;
    Label5: TLabel;
    Label2: TLabel;
    edtDirDestino: TEdit;
    Label6: TLabel;
    imgLogomarca: TImage;
    lstMsgInstalacao: TListBox;
    pnlTopo: TPanel;
    Label9: TLabel;
    btnSelecDirInstall: TSpeedButton;
    Label3: TLabel;
    pgbInstalacao: TProgressBar;
    lblUrl: TLabel;
    lblUrlForum1: TLabel;
    Label19: TLabel;
    Label20: TLabel;
    Label21: TLabel;
    Label10: TLabel;
    Label11: TLabel;
    Label12: TLabel;
    Label13: TLabel;
    Label14: TLabel;
    Label15: TLabel;
    Label16: TLabel;
    Label17: TLabel;
    Label18: TLabel;
    btnInstalar: TSpeedButton;
    btnVisualizarLogCompilacao: TSpeedButton;
    pnlInfoCompilador: TPanel;
    wizPgPacotes: TJvWizardInteriorPage;
    lbInfo: TListBox;
    chkDeixarSomenteLIB: TCheckBox;
    JvCreateProcess1: TJvCreateProcess;
    clbDelphiVersion: TCheckListBox;
    framePacotes1: TframePacotes;
    Label1: TLabel;
    Label8: TLabel;
    ckbUsarArquivoConfig: TCheckBox;
    Label7: TLabel;
    chkWin32: TCheckBox;
    LabelWin32: TLabel;
    LabelWin64: TLabel;
    chkWin64: TCheckBox;
    Label22: TLabel;
    FDMemTable: TRadioButton;
    ClientDataSet: TRadioButton;
    FDMemTableLabel: TLabel;
    ClientDataSetLabel: TLabel;
    procedure imgPropaganda1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure edtDelphiVersionChange(Sender: TObject);
    procedure wizPgInicioNextButtonClick(Sender: TObject; var Stop: Boolean);
    procedure URLClick(Sender: TObject);
    procedure btnSelecDirInstallClick(Sender: TObject);
    procedure wizPrincipalCancelButtonClick(Sender: TObject);
    procedure wizPrincipalFinishButtonClick(Sender: TObject);
    procedure wizPgConfiguracaoNextButtonClick(Sender: TObject;
      var Stop: Boolean);
    procedure btnSVNCheckoutUpdateClick(Sender: TObject);
    procedure btnInstalarClick(Sender: TObject);
    procedure wizPgObterFontesNextButtonClick(Sender: TObject;
      var Stop: Boolean);
    procedure wizPgInstalacaoNextButtonClick(Sender: TObject;
      var Stop: Boolean);
    procedure btnVisualizarLogCompilacaoClick(Sender: TObject);
    procedure wizPgInstalacaoEnterPage(Sender: TObject;
      const FromPage: TJvWizardCustomPage);
    procedure clbDelphiVersionClick(Sender: TObject);
    procedure Label8Click(Sender: TObject);
    procedure Label7Click(Sender: TObject);
    procedure LabelWin64Click(Sender: TObject);
    procedure LabelWin32Click(Sender: TObject);
    procedure ClientDataSetClick(Sender: TObject);
    procedure FDMemTableClick(Sender: TObject);
    procedure ClientDataSetLabelClick(Sender: TObject);
    procedure FDMemTableLabelClick(Sender: TObject);
  private
    FCountErros: Integer;
    oJanus: TJclBorRADToolInstallations;
    iVersion: Integer;
    tPlatform: TJclBDSPlatform;
    sDirRoot: String;
    sDirLibrary: String;
    sDirPackage: String;
    sDestino   : TDestino;
    sPathBin   : String;
    FPacoteAtual: TFileName;
    procedure BeforeExecute(Sender: TJclBorlandCommandLineTool);
    procedure AddLibrarySearchPath(const APlatform: TJclBDSPlatform);
    procedure OutputCallLine(const Text: String);
    procedure SetPlatformSelected(const APlatform: TJclBDSPlatform);
    procedure CreateDirectoryLibrarysNotExist;
    procedure GravarConfiguracoes;
    procedure LerConfiguracoes;
    function PathApp: String;
    function PathArquivoIni: String;
    function PathArquivoLog: String;
    function PathSystem: String;
    procedure CopiarArquivoTo(ADestino : TDestino; const ANomeArquivo: String);
    procedure ExtrairDiretorioPacote(NomePacote: String);
    procedure AddLibraryPathToDelphiPath(const APath, AProcurarRemover: String);
    procedure FindDirs(ADirRoot: String; bAdicionar: Boolean = True);
    procedure DeixarSomenteLib;
    procedure RemoverDiretoriosEPacotesAntigos(const APlatform: TJclBDSPlatform);
    {$IFNDEF DEBUG}
    function RunAsAdminAndWaitForCompletion(hWnd: HWND; filename: String): Boolean;
    {$ENDIF}
    procedure GetDriveLetters(AList: TStrings);
    procedure MostraDadosVersao(const APlatform: TJclBDSPlatform);
    function GetPathJanusInc: TFileName;
    procedure WriteToTXT( const ArqTXT : String; const ABinaryString : AnsiString;
       const AppendIfExists : Boolean = True; const AddLineBreak : Boolean = True;
       const ForceDirectory : Boolean = False);
    procedure RunInstall(const AIndex: Integer; const APlatform: TJclBDSPlatform);
    procedure Logar(const AString: String);
    procedure MostrarMensagemInstalado(const aMensagem: String; const aErro: String = '');
    function GetPlatformName: String;
  public

  end;

var
  frmPrincipal: TfrmPrincipal;

implementation

uses
  SVN_Class, FileCtrl, ShellApi, IniFiles, StrUtils, Math, Registry;

{$R *.dfm}

{$IFNDEF DEBUG}
function TfrmPrincipal.RunAsAdminAndWaitForCompletion(hWnd: HWND; filename: String): Boolean;
{
    See Step 3: Redesign for UAC Compatibility (UAC)
    http://msdn.microsoft.com/en-us/library/bb756922.aspx
}
var
  sei: TShellExecuteInfo;
  ExitCode: DWORD;
begin
  ZeroMemory(@sei, SizeOf(sei));
  sei.cbSize       := SizeOf(TShellExecuteInfo);
  sei.Wnd          := hwnd;
  sei.fMask        := SEE_MASK_FLAG_DDEWAIT or SEE_MASK_FLAG_NO_UI or SEE_MASK_NOCLOSEPROCESS;
  sei.lpVerb       := PWideChar('runas');
  sei.lpFile       := PWideChar(Filename);
  sei.lpParameters := PWideChar('');
  sei.nShow        := SW_HIDE;

  if ShellExecuteEx(@sei) then
  begin
    repeat
      Application.ProcessMessages;
      GetExitCodeProcess(sei.hProcess, ExitCode) ;
    until (ExitCode <> STILL_ACTIVE) or  Application.Terminated;
  end;
end;
{$ENDIF}

procedure TfrmPrincipal.RunInstall(const AIndex: Integer; const APlatform: TJclBDSPlatform);
var
  iDpk: Integer;
  iDcl: Integer;
  bRunOnly: Boolean;
  NomePacote: String;
  Cabecalho: String;

  procedure IncrementaBarraProgresso;
  begin
    pgbInstalacao.Position := pgbInstalacao.Position + 1;
    Application.ProcessMessages;
  end;

  procedure LigarDefineJanusInc(const ADefineName: String; const Aligar: Boolean);
  var
    F: TStringList;
    I: Integer;
  begin
    F := TStringList.Create;
    try
      F.LoadFromFile(GetPathJanusInc);
      for I := 0 to F.Count - 1 do
      begin
        if Pos(ADefineName.ToUpper, F[I].ToUpper) > 0 then
        begin
          if Aligar then
            F[I] := '{$DEFINE ' + ADefineName + '}'
          else
            F[I] := '{.$DEFINE ' + ADefineName + '}';

          Break;
        end;
      end;
      F.SaveToFile(GetPathJanusInc);
    finally
      F.Free;
    end;
  end;

begin
  LigarDefineJanusInc('DRIVERRESTFUL', False);
  LigarDefineJanusInc('USEFDMEMTABLE', FDMemTable.Checked);
  LigarDefineJanusInc('USECLIENTDATASET', ClientDataSet.Checked);

  FCountErros := 0;

  // Define dados da plataforna selecionada
  SetPlatformSelected(APlatform);

  // Mostra dados da vers�o na tela a ser instaladas
  MostraDadosVersao(APlatform);

  Cabecalho := 'Caminho: ' + edtDirDestino.Text + sLineBreak +
               'Vers�o do delphi: ' + clbDelphiVersion.Items[iVersion] + ' (' + IntToStr(iVersion)+ ')' + sLineBreak +
               'Plataforma: ' + GetEnumName(TypeInfo(TJclBDSPlatform), Integer(APlatform)) + '(' + IntToStr(Integer(tPlatform)) + ')' + sLineBreak +
               StringOfChar('=', 80);

  WriteToTXT(PathArquivoLog, Cabecalho, True);

  // Cria diret�rio de biblioteca da vers�o do delphi selecionada,
  // s� ser� criado se n�o existir
  Logar('Criando diret�rios de bibliotecas... [' + GetPlatformName + ']');
  CreateDirectoryLibrarysNotExist;
  IncrementaBarraProgresso;

  // Remover paths do delphi
  Logar('Removendo paths de pacotes antigos instalados... [' + GetPlatformName + ']');
  RemoverDiretoriosEPacotesAntigos(APlatform);
  IncrementaBarraProgresso;

  // Adiciona os paths dos fontes na vers�o do delphi selecionada
  Logar('Adicionando library paths... [' + GetPlatformName + ']');
  AddLibrarySearchPath(APlatform);
  IncrementaBarraProgresso;

  // Compilar os pacotes primeiramente
  Logar('');
  Logar('COMPILANDO OS PACOTES...  [' + GetPlatformName + ']');
  for iDcl := 0 to framePacotes1.Pacotes.Count - 1 do
  begin
    NomePacote := framePacotes1.Pacotes[iDcl].Hint;

    // Esse pacote � designer n�o ser� compilado no for abaixo.
    if (NomePacote = 'JanusLibrary.dpk') and (tPlatform = bpWin64) then
    begin
      IncrementaBarraProgresso;
      Continue;
    end;
    // Busca diret�rio do pacote
    ExtrairDiretorioPacote(NomePacote);

    if (IsDelphiPackage(NomePacote)) and (framePacotes1.Pacotes[iDcl].Checked) then
    begin
      WriteToTXT(PathArquivoLog, '');
      FPacoteAtual := sDirPackage + NomePacote;
      if oJanus.Installations[iVersion].CompilePackage(sDirPackage + NomePacote, sDirLibrary, sDirLibrary) then
        Logar(Format('Pacote "%s" compilado.', [NomePacote]))
      else
      begin
        Inc(FCountErros);
        Logar(Format('Erro ao compilar o pacote "%s".', [NomePacote]));

        // parar no primeiro erro para evitar de compilar outros pacotes que
        // precisam do pacote que deu erro
        Break
      end;
    end;
    IncrementaBarraProgresso;
  end;

  // Instalar os pacotes somente se n�o ocorreu erro na compila��o e plataforma for Win32
  if (APlatform = bpWin32) then
  begin
    for iDpk := 0 to framePacotes1.Pacotes.Count - 1 do
    begin
      NomePacote := framePacotes1.Pacotes[iDpk].Hint;
      // Esse pacote n�o tem vers�o runtime e designer, por isso n�o deve ter as iniciais DCL
      if MatchText(NomePacote, ['JanusLibrary.dpk',
                                'JanusCore.dpk',
                                'DataEngineCore.dpk',
                                'MetaDbDiffCore.dpk']) then
        Continue
      else
        NomePacote := 'dcl' + NomePacote;

      // Busca diret�rio do pacote
      ExtrairDiretorioPacote(NomePacote);

      if (IsDelphiPackage(NomePacote)) and (framePacotes1.Pacotes[iDpk].Checked) then
      begin
        WriteToTXT(PathArquivoLog, '');
        FPacoteAtual := sDirPackage + NomePacote;
        if oJanus.Installations[iVersion].CompilePackage(sDirPackage + NomePacote, sDirLibrary, sDirLibrary) then
          Logar(Format('Pacote "%s" compilado.', [NomePacote]))
        else
        begin
          Inc(FCountErros);
          Logar(Format('Erro ao compilar o pacote "%s".', [NomePacote]));

          // parar no primeiro erro para evitar de compilar outros pacotes que
          // precisam do pacote que deu erro
          Break
        end;
      end;
      IncrementaBarraProgresso;
    end;

    if (FCountErros <= 0) then
    begin
      Logar('');
      Logar('INSTALANDO OS PACOTES... [' + GetPlatformName + ']');

      for iDpk := 0 to framePacotes1.Pacotes.Count - 1 do
      begin
        NomePacote := framePacotes1.Pacotes[iDpk].Hint;

        // Esse pacote n�o tem vers�o runtime e designer, por isso n�o deve ter as iniciais DCL
        if not MatchText(NomePacote, ['JanusLibrary.dpk',
                                      'JanusCore.dpk',
                                      'DataEngineCore.dpk',
                                      'MetaDbDiffCore.dpk']) then
          NomePacote := 'dcl' + NomePacote;

        // Busca diret�rio do pacote
        ExtrairDiretorioPacote(NomePacote);

        if IsDelphiPackage(NomePacote) then
        begin
          FPacoteAtual := sDirPackage + NomePacote;
          // instalar somente os pacotes de designtime
          GetDPKFileInfo(sDirPackage + NomePacote, bRunOnly);
          if not bRunOnly then
          begin
            // se o pacote estiver marcado instalar, sen�o desinstalar
            if framePacotes1.Pacotes[iDpk].Checked then
            begin
              WriteToTXT(PathArquivoLog, '');

              if oJanus.Installations[iVersion].InstallPackage(sDirPackage + NomePacote, sDirLibrary, sDirLibrary) then
                Logar(Format('Pacote "%s" instalado.', [NomePacote]))
              else
              begin
                Inc(FCountErros);
                Logar(Format('Ocorreu um erro ao instalar o pacote "%s".', [NomePacote]));

                Break;
              end;
            end
            else
            begin
              WriteToTXT(PathArquivoLog, '');

              if oJanus.Installations[iVersion].UninstallPackage(sDirPackage + NomePacote, sDirLibrary, sDirLibrary) then
                Logar(Format('Pacote "%s" removido com sucesso...', [NomePacote]));
            end;
          end;
        end;
        IncrementaBarraProgresso;
      end;
    end
    else
    begin
      Logar('');
      Logar('Abortando... Ocorreram erros na compila��o dos pacotes.');
    end;
  end
  else
  if (APlatform = bpWin64) then
  begin
    Logar('');
    Logar('Para a plataforma de 64 bits os pacotes s�o somente compilados.');
  end;
end;

procedure TfrmPrincipal.ExtrairDiretorioPacote(NomePacote: String);

  procedure FindDirPackage(sDir, sPacote: String);
  var
    oDirList: TSearchRec;
    iRet: Integer;
  begin
    sDir := IncludeTrailingPathDelimiter(sDir);
    if not DirectoryExists(sDir) then
      Exit;

    if SysUtils.FindFirst(sDir + '*.*', faAnyFile, oDirList) = 0 then
    begin
      try
        repeat

          if (oDirList.Name = '.') or
             (oDirList.Name = '..') or
             (oDirList.Name = '__history') or
             (oDirList.Name = '__recovery') or
             (oDirList.Name = 'Win32') or
             (oDirList.Name = 'Win64') then
            Continue;

          //if oDirList.Attr = faDirectory then
          if DirectoryExists(sDir + oDirList.Name) then
            FindDirPackage(sDir + oDirList.Name, sPacote)
          else
          begin
            if UpperCase(oDirList.Name) = UpperCase(sPacote) then
              sDirPackage := IncludeTrailingPathDelimiter(sDir);
          end;

        until SysUtils.FindNext(oDirList) <> 0;
      finally
        SysUtils.FindClose(oDirList);
      end;
    end;
  end;

begin
   sDirPackage := '';
   FindDirPackage(IncludeTrailingPathDelimiter(sDirRoot) + 'Projects\Wizard', NomePacote);
   FindDirPackage(IncludeTrailingPathDelimiter(sDirRoot) + 'Components\Packages\Delphi', NomePacote);
   FindDirPackage(IncludeTrailingPathDelimiter(sDirRoot) + 'Source\MetaDbDiff\Components\Packages\Delphi', NomePacote);
   FindDirPackage(IncludeTrailingPathDelimiter(sDirRoot) + 'Source\DataEngine\Components\Packages\Delphi', NomePacote);
end;

// retornar o path do aplicativo
function TfrmPrincipal.PathApp: String;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
end;

// retornar o caminho completo para o arquivo .ini de configura��es
function TfrmPrincipal.PathArquivoIni: String;
var
  NomeApp: String;
begin
  NomeApp := ExtractFileName(ParamStr(0));
  Result := PathApp + ChangeFileExt(NomeApp, '.ini');
end;

// retornar o caminho completo para o arquivo de logs
function TfrmPrincipal.PathArquivoLog: String;
begin
  Result := PathApp + 'log_' + StringReplace(clbDelphiVersion.Items[iVersion], ' ', '_', [rfReplaceAll]) + '.txt';
end;

// retorna o diret�rio de sistema atual
function TfrmPrincipal.PathSystem: String;
var
  strTmp: array[0..MAX_PATH] of char;
  DirWindows: String;
const
  SYS_64 = 'SysWOW64';
  SYS_32 = 'System32';
begin
  Result := '';

  //SetLength(strTmp, MAX_PATH);
  if Windows.GetWindowsDirectory(strTmp, MAX_PATH) > 0 then
  begin
    DirWindows := Trim(StrPas(strTmp));
    DirWindows := IncludeTrailingPathDelimiter(DirWindows);

    if DirectoryExists(DirWindows + SYS_64) then
      Result := DirWindows + SYS_64
    else
    if DirectoryExists(DirWindows + SYS_32) then
      Result := DirWindows + SYS_32
    else
      raise EFileNotFoundException.Create('Diret�rio de sistema n�o encontrado.');
  end
  else
    raise EFileNotFoundException.Create('Ocorreu um erro ao tentar obter o diret�rio do windows.');
end;

procedure TfrmPrincipal.ClientDataSetClick(Sender: TObject);
begin
  FDMemTable.Checked := not ClientDataSet.Checked;
end;

procedure TfrmPrincipal.ClientDataSetLabelClick(Sender: TObject);
begin
  ClientDataSet.Checked := True;
  FDMemTable.Checked := False;
end;

procedure TfrmPrincipal.CopiarArquivoTo(ADestino : TDestino; const ANomeArquivo: String);
var
  PathOrigem: String;
  PathDestino: String;
  DirSystem: String;
  DirJanus: String;
begin
  case ADestino of
    tdSystem: DirSystem := Trim(PathSystem);
    tdDelphi: DirSystem := sPathBin;
  end;

  DirJanus := IncludeTrailingPathDelimiter(edtDirDestino.Text);

  if DirSystem <> EmptyStr then
    DirSystem := IncludeTrailingPathDelimiter(DirSystem)
  else
    raise EFileNotFoundException.Create('Diret�rio de sistema n�o encontrado.');

  PathOrigem  := DirJanus + 'DLLs\' + ANomeArquivo;
  PathDestino := DirSystem + ExtractFileName(ANomeArquivo);

  if FileExists(PathOrigem) and not(FileExists(PathDestino)) then
  begin
    if not CopyFile(PWideChar(PathOrigem), PWideChar(PathDestino), True) then
    begin
      raise EFilerError.CreateFmt(
        'Ocorreu o seguinte erro ao tentar copiar o arquivo "%s": %d - %s', [
        ANomeArquivo, GetLastError, SysErrorMessage(GetLastError)
      ]);
    end;
  end;
end;

// ler o arquivo .ini de configura��es e setar os campos com os valores lidos
procedure TfrmPrincipal.Label7Click(Sender: TObject);
begin
  ckbUsarArquivoConfig.Checked := not ckbUsarArquivoConfig.Checked;
end;

procedure TfrmPrincipal.Label8Click(Sender: TObject);
begin
  chkDeixarSomenteLIB.Checked := not chkDeixarSomenteLIB.Checked;
end;

procedure TfrmPrincipal.LabelWin32Click(Sender: TObject);
begin
  chkWin32.Checked := not chkWin32.Checked;
end;

procedure TfrmPrincipal.LabelWin64Click(Sender: TObject);
begin
  chkWin64.Checked := not chkWin64.Checked;
end;

procedure TfrmPrincipal.LerConfiguracoes;
var
  ArqIni: TIniFile;
  I: Integer;
begin
  ArqIni := TIniFile.Create(PathArquivoIni);
  try
    edtDirDestino.Text := ArqIni.ReadString('CONFIG', 'DiretorioInstalacao', ExtractFilePath(ParamStr(0)));
    chkWin32.Checked := ArqIni.ReadBool('CONFIG','Win32',False);
    chkWin64.Checked := ArqIni.ReadBool('CONFIG','Win64',False);
    chkDeixarSomenteLIB.Checked    := ArqIni.ReadBool('CONFIG','DexarSomenteLib',False);

    for I := 0 to framePacotes1.Pacotes.Count - 1 do
      if framePacotes1.Pacotes[I].Enabled then
        framePacotes1.Pacotes[I].Checked := ArqIni.ReadBool('PACOTES', framePacotes1.Pacotes[I].Hint, False);
  finally
    ArqIni.Free;
  end;
end;

procedure TfrmPrincipal.MostraDadosVersao(const APlatform: TJclBDSPlatform);
begin
  // Mostra ao usu�rio as informa��es de compila��o
  lbInfo.Clear;
  with lbInfo.Items do
  begin
    Clear;
    Add(clbDelphiVersion.Items[iVersion] + ' ' + GetEnumName(TypeInfo(TJclBDSPlatform), Integer(APlatform)));
    Add('Dir. Instala��o  : ' + edtDirDestino.Text);
    Add('Dir. Bibliotecas : ' + sDirLibrary);
  end;
end;

// gravar as configura��es efetuadas pelo usu�rio
procedure TfrmPrincipal.GravarConfiguracoes;
var
  ArqIni: TIniFile;
  I: Integer;
begin
  ArqIni := TIniFile.Create(PathArquivoIni);
  try
    ArqIni.WriteString('CONFIG', 'DiretorioInstalacao', edtDirDestino.Text);
    ArqIni.WriteBool('CONFIG', 'Win32', chkWin32.Checked);
    ArqIni.WriteBool('CONFIG', 'Win64', chkWin64.Checked);
    ArqIni.WriteBool('CONFIG','DexarSomenteLib', chkDeixarSomenteLIB.Checked);

    for I := 0 to framePacotes1.Pacotes.Count - 1 do
      if framePacotes1.Pacotes[I].Enabled then
        ArqIni.WriteBool('PACOTES', framePacotes1.Pacotes[I].Hint, framePacotes1.Pacotes[I].Checked);
  finally
    ArqIni.Free;
  end;
end;

// cria��o dos diret�rios necess�rios
procedure TfrmPrincipal.CreateDirectoryLibrarysNotExist;
begin
  // Checa se existe diret�rio da plataforma
  if not DirectoryExists(sDirLibrary) then
    ForceDirectories(sDirLibrary);
end;

procedure TfrmPrincipal.DeixarSomenteLib;

  procedure Copiar(const Extensao : String);
  var
    ListArquivos: TStringDynArray;
    Arquivo : String;
    i: integer;
  begin
    ListArquivos := TDirectory.GetFiles(IncludeTrailingPathDelimiter(sDirRoot) + 'Source', Extensao ,TSearchOption.soAllDirectories ) ;
    for i := Low(ListArquivos) to High(ListArquivos) do
    begin
      Arquivo := ExtractFileName(ListArquivos[i]);
      CopyFile(PWideChar(ListArquivos[i]), PWideChar(IncludeTrailingPathDelimiter(sDirLibrary) + Arquivo), False);
    end;
    ListArquivos := TDirectory.GetFiles(IncludeTrailingPathDelimiter(sDirRoot) + 'Components\Source', Extensao ,TSearchOption.soAllDirectories ) ;
    for i := Low(ListArquivos) to High(ListArquivos) do
    begin
      Arquivo := ExtractFileName(ListArquivos[i]);
      CopyFile(PWideChar(ListArquivos[i]), PWideChar(IncludeTrailingPathDelimiter(sDirLibrary) + Arquivo), False);
    end;
  end;

begin
  // Remover os path com o segundo parametro
  FindDirs(IncludeTrailingPathDelimiter(sDirRoot) + 'Source', False);
  FindDirs(IncludeTrailingPathDelimiter(sDirRoot) + 'Components\Source', False);

  Copiar('*.dcr');
  Copiar('*.res');
  Copiar('*.dfm');
  Copiar('*.ini');
  Copiar('*.inc');
end;

procedure TfrmPrincipal.AddLibraryPathToDelphiPath(const APath: String; const AProcurarRemover: String);
const
  cs: PChar = 'Environment Variables';
var
  lParam, wParam: Integer;
  aResult: Cardinal;
  ListaPaths: TStringList;
  I: Integer;
  PathsAtuais: String;
  PathFonte: String;
begin
  with oJanus.Installations[iVersion] do
  begin
    // tentar ler o path configurado na ide do delphi, se n�o existir ler
    // a atual para complementar e fazer o override
    PathsAtuais := Trim(EnvironmentVariables.Values['PATH']);
    if PathsAtuais = '' then
      PathsAtuais := GetEnvironmentVariable('PATH');

    // manipular as Strings
    ListaPaths := TStringList.Create;
    try
      ListaPaths.Clear;
      ListaPaths.Delimiter       := ';';
      ListaPaths.StrictDelimiter := True;
      ListaPaths.DelimitedText   := PathsAtuais;

      // verificar se existe algo do Janus e remover do environment variable PATH do delphi
      if Trim(AProcurarRemover) <> '' then
      begin
        for I := ListaPaths.Count - 1 downto 0 do
        begin
         if Pos(AnsiUpperCase(AProcurarRemover), AnsiUpperCase(ListaPaths[I])) > 0 then
           ListaPaths.Delete(I);
        end;
      end;

      // adicionar o path
      ListaPaths.Add(APath);

      // escrever a variavel no override da ide
      ConfigData.WriteString(cs, 'PATH', ListaPaths.DelimitedText);

      // enviar um broadcast de atualiza��o para o windows
      wParam := 0;
      lParam := LongInt(cs);
      SendMessageTimeout(HWND_BROADCAST, WM_SETTINGCHANGE, wParam, lParam, SMTO_NORMAL, 4000, aResult);
      if aResult <> 0 then
        raise Exception.create('Ocorreu um erro ao tentar configurar o path: ' + SysErrorMessage(aResult));
    finally
      ListaPaths.Free;
    end;
  end;
end;

procedure TfrmPrincipal.FDMemTableClick(Sender: TObject);
begin
  ClientDataSet.Checked := not FDMemTable.Checked;
end;

procedure TfrmPrincipal.FDMemTableLabelClick(Sender: TObject);
begin
  ClientDataSet.Checked := False;
  FDMemTable.Checked := True;
end;

procedure TfrmPrincipal.FindDirs(ADirRoot: String; bAdicionar: Boolean = True);
var
  oDirList: TSearchRec;

  function EProibido(const ADir: String): Boolean;
  const
    LISTA_PROIBIDOS: ARRAY[0..14] OF String = (
      'quick',
      'rave',
      'laz',
      'VerificarNecessidade',
      '__history',
      '__recovery',
      'Examples',
      'Packages',
      'Images',
      'Test Delphi',
      'Test Lazarus',
      'Projects',
      'Test Performance',
      'Win32',
      'Win64',
    );
  var
    Str: String;
  begin
    Result := False;
    for str in LISTA_PROIBIDOS do
    begin
      Result := Pos(AnsiUpperCase(str), AnsiUpperCase(ADir)) > 0;
      if Result then
        Break;
    end;
  end;

begin
  ADirRoot := IncludeTrailingPathDelimiter(ADirRoot);

  if FindFirst(ADirRoot + '*.*', faDirectory, oDirList) = 0 then
  begin
     try
       repeat
          if ((oDirList.Attr and faDirectory) <> 0) and
              (oDirList.Name <> '.')                and
              (oDirList.Name <> '..')               and
              (not EProibido(oDirList.Name)) then
          begin
             with oJanus.Installations[iVersion] do
             begin
               if bAdicionar then
               begin
                  AddToLibrarySearchPath(ADirRoot + oDirList.Name, tPlatform);
                  AddToLibraryBrowsingPath(ADirRoot + oDirList.Name, tPlatform);
               end
               else
                  RemoveFromLibrarySearchPath(ADirRoot + oDirList.Name, tPlatform);
             end;
             // Procura subpastas
             FindDirs(ADirRoot + oDirList.Name, bAdicionar);
          end;
       until FindNext(oDirList) <> 0;
     finally
       SysUtils.FindClose(oDirList)
     end;
  end;
end;

// Adicionar o paths ao library path do delphi
procedure TfrmPrincipal.AddLibrarySearchPath(const APlatform: TJclBDSPlatform);
begin
  FindDirs(IncludeTrailingPathDelimiter(sDirRoot) + 'Source');
  FindDirs(IncludeTrailingPathDelimiter(sDirRoot) + 'Components\Source');

  with oJanus.Installations[iVersion] do
  begin
    AddToLibraryBrowsingPath(sDirLibrary, APlatform);
    AddToLibrarySearchPath(sDirLibrary, APlatform);
    AddToDebugDCUPath(sDirLibrary, APlatform);
  end;

  // Adicionar a library path ao path do windows
  AddLibraryPathToDelphiPath(sDirLibrary, 'Janus');
end;

// Setar a plataforma de compila��o
procedure TfrmPrincipal.SetPlatformSelected(const APlatform: TJclBDSPlatform);
var
  sVersao: String;
  sTipo: String;
begin
  sVersao  := AnsiUpperCase(oJanus.Installations[iVersion].VersionNumberStr);
  sDirRoot := IncludeTrailingPathDelimiter(edtDirDestino.Text);

  tPlatform   := APlatform;

  sTipo := 'Lib\Delphi\';

  if tPlatform = bpWin32 then
    sDirLibrary := sDirRoot + sTipo + 'Lib' + sVersao + 'Win32'
  else
  if tPlatform = bpWin64 then
    sDirLibrary := sDirRoot + sTipo + 'Lib' + sVersao + 'Win64';
end;

// Evento disparado a cada a��o do instalador
procedure TfrmPrincipal.OutputCallLine(const Text: String);
begin
  // remover a warnings de convers�o de String (delphi 2010 em diante)
  // as diretivas -W e -H n�o removem estas mensagens
  if (pos('Warning: W1057', Text) <= 0) and ((pos('Warning: W1058', Text) <= 0)) then
    WriteToTXT(PathArquivoLog, Text);
end;

// evento para setar os par�metros do compilador antes de compilar
procedure TfrmPrincipal.BeforeExecute(Sender: TJclBorlandCommandLineTool);
var
  LArquivoCfg: TFilename;
begin
  // limpar os par�metros do compilador
  Sender.Options.Clear;

  // n�o utilizar o dcc32.cfg
  if (oJanus.Installations[iVersion].SupportsNoConfig) and (not ckbUsarArquivoConfig.Checked) then
    Sender.Options.Add('--no-config');

  // -B = Build all units
  Sender.Options.Add('-B');
  // O+ = Optimization
  Sender.Options.Add('-$O-');
  // W- = Generate stack frames
  Sender.Options.Add('-$W+');
  // Y+ = Symbol reference info
  Sender.Options.Add('-$Y-');
  // -M = Make modified units
  Sender.Options.Add('-M');
  // -Q = Quiet compile
  Sender.Options.Add('-Q');
  // n�o mostrar warnings
  Sender.Options.Add('-H-');
  // n�o mostrar hints
  Sender.Options.Add('-W-');
  // -D<syms> = Define conditionals
  Sender.Options.Add('-DRELEASE');
  // -U<paths> = Unit directories
  Sender.AddPathOption('U', oJanus.Installations[iVersion].LibFolderName[tPlatform]);
  Sender.AddPathOption('U', oJanus.Installations[iVersion].LibrarySearchPath[tPlatform]);
  Sender.AddPathOption('U', sDirLibrary);
  // -I<paths> = Include directories
  Sender.AddPathOption('I', oJanus.Installations[iVersion].LibrarySearchPath[tPlatform]);
  // -R<paths> = Resource directories
  Sender.AddPathOption('R', oJanus.Installations[iVersion].LibrarySearchPath[tPlatform]);
  // -N0<path> = unit .dcu output directory
  Sender.AddPathOption('N0', sDirLibrary);
  Sender.AddPathOption('LE', sDirLibrary);
  Sender.AddPathOption('LN', sDirLibrary);
  //
  with oJanus.Installations[iVersion] do
  begin
     // -- Path para instalar os pacotes do Rave no D7, nas demais vers�es
     // -- o path existe.
     if VersionNumberStr = 'd7' then
        Sender.AddPathOption('U', oJanus.Installations[iVersion].RootDir + '\Rave5\Lib');

     // -- Na vers�o XE2 por motivo da nova tecnologia FireMonkey, deve-se adicionar
     // -- os prefixos dos nomes, para identificar se ser� compilado para VCL ou FMX
     if VersionNumberStr = 'd16' then
        Sender.Options.Add('-NSData.Win;Datasnap.Win;Web.Win;Soap.Win;Xml.Win;Bde;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell;System;Xml;Data;Datasnap;Web;Soap;Winapi;System.Win');

     if MatchText(VersionNumberStr, ['d17','d18','d19','d20','d21','d22','d23','d24','d25','d26','d27','d28']) then
        Sender.Options.Add('-NSWinapi;System.Win;Data.Win;Datasnap.Win;Web.Win;Soap.Win;Xml.Win;Bde;System;Xml;Data;Datasnap;Web;Soap;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell,Ibx');
  end;
  if (ckbUsarArquivoConfig.Checked) then
  begin
    LArquivoCfg := ChangeFileExt(FPacoteAtual, '.cfg');
    Sender.Options.SaveToFile(LArquivoCfg);
    Sender.Options.Clear;
  end;
end;

procedure TfrmPrincipal.FormCreate(Sender: TObject);
var
  iFor: Integer;
begin
  iVersion    := -1;
  sDirRoot    := '';
  sDirLibrary := '';
  sDirPackage := '';

  oJanus := TJclBorRADToolInstallations.Create;

  // popular o combobox de vers�es do delphi instaladas na m�quina
  for iFor := 0 to oJanus.Count - 1 do
  begin
    if      oJanus.Installations[iFor].VersionNumberStr = 'd3' then
      clbDelphiVersion.Items.Add('Delphi 3')
    else if oJanus.Installations[iFor].VersionNumberStr = 'd4' then
      clbDelphiVersion.Items.Add('Delphi 4')
    else if oJanus.Installations[iFor].VersionNumberStr = 'd5' then
      clbDelphiVersion.Items.Add('Delphi 5')
    else if oJanus.Installations[iFor].VersionNumberStr = 'd6' then
      clbDelphiVersion.Items.Add('Delphi 6')
    else if oJanus.Installations[iFor].VersionNumberStr = 'd7' then
      clbDelphiVersion.Items.Add('Delphi 7')
    else if oJanus.Installations[iFor].VersionNumberStr = 'd9' then
      clbDelphiVersion.Items.Add('Delphi 2005')
    else if oJanus.Installations[iFor].VersionNumberStr = 'd10' then
      clbDelphiVersion.Items.Add('Delphi 2006')
    else if oJanus.Installations[iFor].VersionNumberStr = 'd11' then
      clbDelphiVersion.Items.Add('Delphi 2007')
    else if oJanus.Installations[iFor].VersionNumberStr = 'd12' then
      clbDelphiVersion.Items.Add('Delphi 2009')
    else if oJanus.Installations[iFor].VersionNumberStr = 'd14' then
      clbDelphiVersion.Items.Add('Delphi 2010')
    else if oJanus.Installations[iFor].VersionNumberStr = 'd15' then
      clbDelphiVersion.Items.Add('Delphi XE')
    else if oJanus.Installations[iFor].VersionNumberStr = 'd16' then
      clbDelphiVersion.Items.Add('Delphi XE2')
    else if oJanus.Installations[iFor].VersionNumberStr = 'd17' then
      clbDelphiVersion.Items.Add('Delphi XE3')
    else if oJanus.Installations[iFor].VersionNumberStr = 'd18' then
      clbDelphiVersion.Items.Add('Delphi XE4')
    else if oJanus.Installations[iFor].VersionNumberStr = 'd19' then
      clbDelphiVersion.Items.Add('Delphi XE5')
    else if oJanus.Installations[iFor].VersionNumberStr = 'd20' then
      clbDelphiVersion.Items.Add('Delphi XE6')
    else if oJanus.Installations[iFor].VersionNumberStr = 'd21' then
      clbDelphiVersion.Items.Add('Delphi XE7')
    else if oJanus.Installations[iFor].VersionNumberStr = 'd22' then
      clbDelphiVersion.Items.Add('Delphi XE8')
    else if oJanus.Installations[iFor].VersionNumberStr = 'd23' then
      clbDelphiVersion.Items.Add('Delphi 10 Seattle')
    else if oJanus.Installations[iFor].VersionNumberStr = 'd24' then
      clbDelphiVersion.Items.Add('Delphi 10.1 Berlin')
    else if oJanus.Installations[iFor].VersionNumberStr = 'd25' then
      clbDelphiVersion.Items.Add('Delphi 10.2 Tokyo')
    else if oJanus.Installations[iFor].VersionNumberStr = 'd26' then
      clbDelphiVersion.Items.Add('Delphi 10.3 Rio')
    else if oJanus.Installations[iFor].VersionNumberStr = 'd27' then
      clbDelphiVersion.Items.Add('Delphi 10.4 Sydney')
    else if oJanus.Installations[iFor].VersionNumberStr = 'd28' then
      clbDelphiVersion.Items.Add('Delphi 11.1 Alexandria');

    // -- Evento para saidas de mensagens.
    oJanus.Installations[iFor].OutputCallback := OutputCallLine;
  end;

  LerConfiguracoes;
end;

procedure TfrmPrincipal.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  oJanus.Free;
end;

procedure TfrmPrincipal.RemoverDiretoriosEPacotesAntigos(const APlatform: TJclBDSPlatform);
var
  ListaPaths: TStringList;
  I: Integer;
begin
  ListaPaths := TStringList.Create;
  try
    ListaPaths.StrictDelimiter := True;
    ListaPaths.Delimiter := ';';
    with oJanus.Installations[iVersion] do
    begin
      // remover do search path
      ListaPaths.Clear;
      ListaPaths.DelimitedText := RawLibrarySearchPath[APlatform];
      for I := ListaPaths.Count - 1 downto 0 do
      begin
        if Pos('JANUS', AnsiUpperCase(ListaPaths[I])) > 0 then
          ListaPaths.Delete(I);
      end;
      RawLibrarySearchPath[APlatform] := ListaPaths.DelimitedText;
      // remover do browse path
      ListaPaths.Clear;
      ListaPaths.DelimitedText := RawLibraryBrowsingPath[APlatform];
      for I := ListaPaths.Count - 1 downto 0 do
      begin
        if Pos('JANUS', AnsiUpperCase(ListaPaths[I])) > 0 then
          ListaPaths.Delete(I);
      end;
      RawLibraryBrowsingPath[APlatform] := ListaPaths.DelimitedText;
      // remover do Debug DCU path
      ListaPaths.Clear;
      ListaPaths.DelimitedText := RawDebugDCUPath[APlatform];
      for I := ListaPaths.Count - 1 downto 0 do
      begin
        if Pos('JANUS', AnsiUpperCase(ListaPaths[I])) > 0 then
          ListaPaths.Delete(I);
      end;
      RawDebugDCUPath[APlatform] := ListaPaths.DelimitedText;

      // Remover pacotes antigos da plataform Win32
      if APlatform = bpWin32 then
      begin
        for I := IdePackages.Count - 1 downto 0 do
        begin
          if Pos('JANUS', AnsiUpperCase(IdePackages.PackageFileNames[I])) > 0 then
            IdePackages.RemovePackage(IdePackages.PackageFileNames[I]);
        end;
      end;
    end;
  finally
    ListaPaths.Free;
  end;
end;

procedure TfrmPrincipal.GetDriveLetters(AList: TStrings);
var
  vDrivesSize: Cardinal;
  vDrives: array[0..128] of Char;
  vDrive: PChar;
  vDriveType: Cardinal;
begin
  AList.BeginUpdate;
  try
    // clear the list from possible leftover from prior operations
    AList.Clear;
    vDrivesSize := GetLogicalDriveStrings(SizeOf(vDrives), vDrives);
    if vDrivesSize = 0 then
      Exit;

    vDrive := vDrives;
    while vDrive^ <> #0 do
    begin
      // adicionar somente drives fixos
      vDriveType := GetDriveType(vDrive);
      if vDriveType = DRIVE_FIXED then
        AList.Add(StrPas(vDrive));

      Inc(vDrive, SizeOf(vDrive));
    end;
  finally
	  AList.EndUpdate;
  end;
end;

function TfrmPrincipal.GetPathJanusInc: TFileName;
begin
  Result := IncludeTrailingPathDelimiter(edtDirDestino.Text) + 'Source\Janus.inc';
end;

function TfrmPrincipal.GetPlatformName: String;
begin
  case tPlatform of
    bpWin32: Result := 'Win32';
    bpWin64: Result := 'Win64';
    bpOSX32: Result := '';
  end;
end;

// bot�o de compila��o e instala��o dos pacotes selecionados no treeview
procedure TfrmPrincipal.btnInstalarClick(Sender: TObject);
var
  LForListaVer: Integer;
begin
  // Limpar lista de mensagens
  btnInstalar.Enabled := False;
  wizPgInstalacao.EnableButton(bkNext, False);
  wizPgInstalacao.EnableButton(bkBack, False);
  wizPgInstalacao.EnableButton(TJvWizardButtonKind(bkCancel), False);

  lstMsgInstalacao.Clear;
  try
    for LForListaVer := 0 to clbDelphiVersion.Count -1 do
    begin
      // s� instala as vers�o marcadas para instalar.
      if clbDelphiVersion.Checked[LForListaVer] then
      begin
        iVersion := LForListaVer;
        sPathBin := IncludeTrailingPathDelimiter(oJanus.Installations[iVersion].BinFolderName);

        if FileExists(PathArquivoLog) then
          DeleteFile(PathArquivoLog);

        // Inicia barra de progresso
        pgbInstalacao.Position := 0;
        pgbInstalacao.Max := 0;

        if chkWin32.Checked then
        begin
          pgbInstalacao.Max := pgbInstalacao.Max + (framePacotes1.Pacotes.Count * 3);
          // CreateDirectoryLibrarysNotExist;
          // RemoverDiretoriosEPacotesAntigos(APlatform);
          // AddLibrarySearchPath(APlatform);
          pgbInstalacao.Max := pgbInstalacao.Max;
        end;

        if chkWin64.Checked then
        begin
          pgbInstalacao.Max := pgbInstalacao.Max + framePacotes1.Pacotes.Count;
          // CreateDirectoryLibrarysNotExist;
          // RemoverDiretoriosEPacotesAntigos(APlatform);
          // AddLibrarySearchPath(APlatform);
          pgbInstalacao.Max := pgbInstalacao.Max;
        end;

        // Win64
        if chkWin64.Checked then
        begin
          oJanus.Installations[LForListaVer].DCC := (oJanus.Installations[LForListaVer] as TJclBDSInstallation).DCC64;
          // Evento disparado antes de iniciar a execu��o do processo.
          oJanus.Installations[LForListaVer].DCC.OnBeforeExecute := BeforeExecute;
          //
          RunInstall(LForListaVer, bpWin64);
        end;

        // Salto de linha entre plataforma
        lstMsgInstalacao.Items.Add('');

        // Win32
        if chkWin32.Checked then
        begin
          oJanus.Installations[LForListaVer].DCC := oJanus.Installations[LForListaVer].DCC32;
          // Evento disparado antes de iniciar a execu��o do processo.
          oJanus.Installations[LForListaVer].DCC.OnBeforeExecute := BeforeExecute;
          //
          RunInstall(LForListaVer, bpWin32);
        end;
      end;
    end;
  finally
    btnInstalar.Enabled := True;
    wizPgInstalacao.EnableButton(bkBack, True);
    wizPgInstalacao.EnableButton(bkNext, FCountErros = 0);
    wizPgInstalacao.EnableButton(TJvWizardButtonKind(bkCancel), True);
  end;

  if FCountErros > 0 then
  begin
    if Application.MessageBox(PWideChar(
        'Ocorreram erros durante o processo de instala��o, '+sLineBreak+
        'para maiores informa��es verifique o arquivo de log gerado.'+sLineBreak+sLineBreak+
        'Deseja visualizar o arquivo de log gerado?'
      ),
      'Instala��o', MB_ICONQUESTION + MB_YESNO) = ID_YES then
    begin
      btnVisualizarLogCompilacao.Click;
      Exit;
    end;
  end;

  // N�o instalar outros requisitos se ocorreu erro anteriormente
  if FCountErros <= 0 then
  begin
    // Deixar somente a pasta lib se for configurado assim
    if chkDeixarSomenteLIB.Checked then
    begin
      Logar('');
      Logar('INSTALANDO OUTROS REQUISITOS...');
      try
        DeixarSomenteLib;

        MostrarMensagemInstalado('Limpeza library path com sucesso');
        MostrarMensagemInstalado('Copia dos arquivos necess�rio.');
      except
        on E: Exception do
        begin
          MostrarMensagemInstalado('Ocorreu erro ao limpas os path e copiar arquivos' + sLineBreak + E.Message)
        end;
      end;
    end;
  end;

  if FCountErros = 0 then
  begin
    Application.MessageBox(
      PWideChar(
        'Pacotes compilados e instalados com sucesso! '+sLineBreak+
        'Clique em "Pr�ximo" para finalizar a instala��o.'
      ),
      'Instala��o',
      MB_ICONINFORMATION + MB_OK
    );
  end;
end;

// chama a caixa de dialogo para selecionar o diret�rio de instala��o
// seria bom que a caixa fosse aquele que possui o bot�o de criar pasta
procedure TfrmPrincipal.btnSelecDirInstallClick(Sender: TObject);
var
  Dir: String;
begin
  if SelectDirectory('Selecione o diret�rio de instala��o', '', Dir, [sdNewFolder, sdNewUI, sdValidateDir]) then
    edtDirDestino.Text := Dir;
end;

// quando trocar a vers�o verificar se libera ou n�o o combo
// da plataforma de compila��o
procedure TfrmPrincipal.edtDelphiVersionChange(Sender: TObject);
begin
  // -- Plataforma s� habilita para Delphi XE2
  // -- Desabilita para vers�o diferente de Delphi XE2
  //edtPlatform.Enabled := oJanus.Installations[iVersion].VersionNumber >= 9;
  //if oJanus.Installations[iVersion].VersionNumber < 9 then
  //edtPlatform.ItemIndex := 0;
end;

// abrir o endere�o do Janus quando clicar na propaganda
procedure TfrmPrincipal.imgPropaganda1Click(Sender: TObject);
begin
  // ir para o endere�o do Janus
  ShellExecute(Handle, 'open', PWideChar(lblUrl.Caption), '', '', 1);
end;

// quando clicar em alguma das urls chamar o link mostrado no caption
procedure TfrmPrincipal.URLClick(Sender: TObject);
begin
  ShellExecute(Handle, 'open', PWideChar(TLabel(Sender).Caption), '', '', 1);
end;

procedure TfrmPrincipal.wizPgInicioNextButtonClick(Sender: TObject;
  var Stop: Boolean);
begin
  // Verificar se o delphi est� aberto
  {$IFNDEF DEBUG}
  if oJanus.AnyInstanceRunning then
  begin
    Stop := True;
    Application.MessageBox(
      'Feche a IDE do delphi antes de continuar.',
      PWideChar(Application.Title),
      MB_ICONERROR + MB_OK
    );
  end;
  {$ENDIF}
end;

procedure TfrmPrincipal.wizPgInstalacaoEnterPage(Sender: TObject;
  const FromPage: TJvWizardCustomPage);
var
  iFor: Integer;
begin
  lbInfo.Clear;
  for iFor := 0 to clbDelphiVersion.Count -1 do
  begin
     // S� pega os dados da 1a vers�o selecionada, para mostrar na tela qual vai iniciar
     if clbDelphiVersion.Checked[iFor] then
     begin
        lbInfo.Items.Add('Instalar : ' + clbDelphiVersion.Items[ifor]);
     end;
  end;
end;

procedure TfrmPrincipal.wizPgInstalacaoNextButtonClick(Sender: TObject;
  var Stop: Boolean);
begin
  if (lstMsgInstalacao.Count <= 0) then
  begin
    Stop := True;
    Application.MessageBox(
      'Clique no bot�o instalar antes de continuar.',
      'Erro.',
      MB_OK + MB_ICONERROR
    );
  end;

  if (FCountErros > 0) then
  begin
    Stop := True;
    Application.MessageBox(
      'Ocorreram erros durante a compila��o e instala��o dos pacotes, verifique.',
      'Erro.',
      MB_OK + MB_ICONERROR
    );
  end;
end;

procedure TfrmPrincipal.wizPgConfiguracaoNextButtonClick(Sender: TObject;
  var Stop: Boolean);
var
  iFor: Integer;
  bChk: Boolean;
  fDir: String;
begin
  bChk := False;
  for iFor := 0 to clbDelphiVersion.Count -1 do
  begin
     if clbDelphiVersion.Checked[iFor] then
        bChk := True;
  end;

  if not bChk then
  begin
    Stop := True;
    clbDelphiVersion.SetFocus;
    Application.MessageBox(
      'Para continuar escolha a vers�o do Delphi para a qual deseja instalar os Componentes.',
      'Erro.',
      MB_OK + MB_ICONERROR
    );
  end;

  // verificar se foi informado o diret�rio
  if Trim(edtDirDestino.Text) = EmptyStr then
  begin
    Stop := True;
    edtDirDestino.SetFocus;
    Application.MessageBox(
      'Diret�rio de instala��o n�o foi informado.',
      'Erro.',
      MB_OK + MB_ICONERROR
    );
  end;

  // precisa ser no mesmo diret�rio que os fontes do Janus esteja.
  fDir := IncludeTrailingPathDelimiter(edtDirDestino.Text);
  fDir := fDir + 'Source\Janus.inc';
  if not FileExists(fDir) then
  begin
    Stop := True;
    edtDirDestino.SetFocus;
    Application.MessageBox(
      'Diret�rio de instala��o selecionado, n�o cont�m os fontes do Janus.',
      'Erro.',
      MB_OK + MB_ICONERROR
    );
  end;

  // Tratar plataforma n�o selecionada
  if (not chkWin32.Checked) and (not chkWin64.Checked) then
  begin
    Stop := True;
    Application.MessageBox(
      'Plataforma de compila��o n�o foi informada.',
      'Erro.',
      MB_OK + MB_ICONERROR
    );
  end;
end;

procedure TfrmPrincipal.btnSVNCheckoutUpdateClick(Sender: TObject);
begin
  // chamar o m�todo de update ou checkout conforme a necessidade
  if TButton(Sender).Tag > 0 then
  begin
    // criar o diret�rio onde ser� baixado o reposit�rio
    if not DirectoryExists(edtDirDestino.Text) then
    begin
      if not ForceDirectories(edtDirDestino.Text) then
      begin
        raise EDirectoryNotFoundException.Create(
          'Ocorreu o seguinte erro ao criar o diret�rio' + sLineBreak +
            SysErrorMessage(GetLastError));
      end;
    end;
  end;
end;

procedure TfrmPrincipal.btnVisualizarLogCompilacaoClick(Sender: TObject);
begin
  ShellExecute(Handle, 'open', PWideChar(PathArquivoLog), '', '', 1);
end;

procedure TfrmPrincipal.clbDelphiVersionClick(Sender: TObject);
begin
  if clbDelphiVersion.ItemIndex = -1 then
    Exit;

  if MatchText(oJanus.Installations[clbDelphiVersion.ItemIndex].VersionNumberStr, ['d3','d4','d5','d6','d7','d9','d10','d11','d12','d13']) then
  begin
    Application.MessageBox(
      'Vers�o do delphi n�o suportada pelo Janus Components.',
      'Erro.',
      MB_OK + MB_ICONERROR
    );
  end;
end;

procedure TfrmPrincipal.wizPgObterFontesNextButtonClick(Sender: TObject;
  var Stop: Boolean);
var
  I: Integer;
  NomePacote: String;
begin
  GravarConfiguracoes;

  // verificar se os pacotes existem antes de seguir para o pr�ximo paso
  for I := 0 to framePacotes1.Pacotes.Count - 1 do
  begin
    if framePacotes1.Pacotes[I].Checked then
    begin
      sDirRoot   := IncludeTrailingPathDelimiter(edtDirDestino.Text);
      NomePacote := framePacotes1.Pacotes[I].Hint;

      // Busca diret�rio do pacote
      ExtrairDiretorioPacote(NomePacote);
      if Trim(sDirPackage) = '' then
        raise Exception.Create('N�o foi poss�vel retornar o diret�rio do pacote : ' + NomePacote);

      if IsDelphiPackage(NomePacote) then
      begin
        if not FileExists(IncludeTrailingPathDelimiter(sDirPackage) + NomePacote) then
        begin
          Stop := True;
          Application.MessageBox(PWideChar(Format(
            'Pacote "%s" n�o encontrado, efetue novamente o download do reposit�rio', [NomePacote])),
            'Erro.',
            MB_ICONERROR + MB_OK
          );
          Break;
        end;
      end;
    end;
  end;
end;

procedure TfrmPrincipal.wizPrincipalCancelButtonClick(Sender: TObject);
begin
  if Application.MessageBox(
    'Deseja realmente cancelar a instala��o?',
    'Fechar',
    MB_ICONQUESTION + MB_YESNO
  ) = ID_YES then
  begin
    Self.Close;
  end;
end;

procedure TfrmPrincipal.wizPrincipalFinishButtonClick(Sender: TObject);
begin
  // Gravar as configura��es em um .ini para utilizar depois
  GravarConfiguracoes;
  Self.Close;
end;


procedure TfrmPrincipal.WriteToTXT( const ArqTXT : String; const ABinaryString : AnsiString;
       const AppendIfExists : Boolean = True; const AddLineBreak : Boolean = True;
       const ForceDirectory : Boolean = False);
var
  FS : TFileStream ;
  LineBreak : AnsiString ;
  VDirectory : String;
  ArquivoExiste: Boolean;
begin
  if ArqTXT = '' then
    Exit;

  ArquivoExiste := FileExists(ArqTXT);

  if ArquivoExiste then
  begin
    if (Length(ABinaryString) = 0) then
      Exit;
  end
  else
  begin
     if ForceDirectory then
     begin
       VDirectory := ExtractFileDir(ArqTXT);
       if (VDirectory <> '') and (not DirectoryExists(VDirectory)) then
         ForceDirectories(VDirectory);
     end;
  end;

  FS := TFileStream.Create( ArqTXT,
               IfThen( AppendIfExists and ArquivoExiste,
                       Integer(fmOpenReadWrite), Integer(fmCreate)) or fmShareDenyWrite );
  try
     FS.Seek(0, soEnd);  // vai para EOF
     FS.Write(Pointer(ABinaryString)^,Length(ABinaryString));

     if AddLineBreak then
     begin
        LineBreak := sLineBreak;
        FS.Write(Pointer(LineBreak)^,Length(LineBreak));
     end ;
  finally
     FS.Free ;
  end;
end;

procedure TfrmPrincipal.Logar(const AString: String);
begin
  lstMsgInstalacao.Items.Add(AString);
  lstMsgInstalacao.ItemIndex := lstMsgInstalacao.Count - 1;
  Application.ProcessMessages;

  WriteToTXT(PathArquivoLog, AString);
end;

procedure TfrmPrincipal.MostrarMensagemInstalado(const aMensagem: String; const aErro: String);
var
  Msg: String;
begin

  if Trim(aErro) = EmptyStr then
  begin
    case sDestino of
      tdSystem: Msg := Format(aMensagem + ' em "%s"', [PathSystem]);
      tdDelphi: Msg := Format(aMensagem + ' em "%s"', [sPathBin]);
      tdNone:   Msg := 'Tipo de destino "nenhum" n�o aceito!';
    end;
  end
  else
  begin
    Inc(FCountErros);

    case sDestino of
      tdSystem: Msg := Format(aMensagem + ' em "%s": "%s"', [PathSystem, aErro]);
      tdDelphi: Msg := Format(aMensagem + ' em "%s": "%s"', [sPathBin, aErro]);
      tdNone:   Msg := 'Tipo de destino "nenhum" n�o aceito!';
    end;
  end;

  WriteToTXT(PathArquivoLog, '');
  Logar(Msg);
end;

end.
