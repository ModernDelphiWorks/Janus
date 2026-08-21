<#
  compile-coverage-census.ps1

  CENSO DE COBERTURA DE COMPILACAO do Janus.

  Responde: para cada unit de Source/, quais dos sete projetos de Test/Delphi a
  COMPILAM - e quais nao sao compiladas por nenhum.

  Isto NAO mede se a unit e exercitada por um teste. Mede algo mais grosseiro e
  anterior: se o compilador sequer a le. Uma unit que nenhum projeto compila pode
  estar quebrada desde sempre e a suite continua verde (foi assim que a issue #323
  descobriu Janus.Client.DataSnap e Janus.Client.WS).

  METODO
    Compila cada projeto com /p:DCC_MapFile=3 e coleta DUAS medidas independentes:
      (a) MAP - os modulos citados como "M=<unit>" no .map;
      (b) DCU - os .dcu escritos no DCC_DcuOutput proprio do projeto
                (.\$(Platform)\$(Config)\$(MSBuildProjectName), desde o PR #272).
    A medida AUTORITATIVA e a (b). A (a) SUBESTIMA: o .map so nomeia um modulo
    quando ele emite segmento, entao unit so-constante, so-interface ou
    integralmente generica nao aparece - o codigo do generico sai no modulo que
    o instancia. Verificado neste repo: MAP e subconjunto ESTRITO de DCU nos sete
    projetos (MAP-sem-DCU = 0 em cada um). O script imprime a divergencia para
    que ela continue sendo checada, e nao escolhida.
    Para a (b) ser confiavel o diretorio de saida e APAGADO antes de cada build,
    senao .dcu de uma medicao anterior seria contado como cobertura.

  CONTROLES (o censo nao vale sem eles - o script os imprime e falha se quebrarem)
    positivo: Janus.Bind DEVE aparecer (e compilada por 5 dos 7).
    negativo: Janus.Client.DMVC e Janus.Server.DMVC NAO devem aparecer em
              nenhum dos 7. Nao e escolha de conveniencia: o DMVC desta maquina
              (D:\Delphi Tools\delphimvcframework-master, 3.4.0-neon-beta) NAO
              COMPILA no Studio 37 - MVCFramework.pas declara TWebSession em
              MVCFramework.Session.pas e a RTL declara outra em Web.HTTPApp, e
              o proprio MVCFramework.pas resolve para a errada. Medido na
              frente da #341. Enquanto isso for verdade, esses dois nao podem
              estar cobertos, e se aparecerem o metodo esta errado.

    O CONTROLE NEGATIVO ORIGINAL ERA OUTRO, e ele JA MUDOU uma vez: em 0546a51
    eram Janus.Client.DataSnap e Janus.Client.WS, que a #323 depois linkou no
    Janus.Tests.RESTfulDriver. Um controle negativo que o repositorio conserta
    deixa de ser controle - por isso o de hoje esta ancorado numa dependencia
    externa que ESTE repositorio nao pode consertar.

  ARMADILHAS DA RECEITA (todas custaram tempo; nao as desfaca)
    - /p:"DCC_UnitSearchPath=" e GLOBAL e SUPRIME a lista do .dproj. E preciso
      ler TODOS os nos DCC_UnitSearchPath do .dproj e concatena-los na ordem
      (quatro dos sete tem DOIS; o segundo prepende $(BDSLIB)).
    - A PODA e load-bearing: sem descartar as entradas que nao existem em disco
      (dedup + Test-Path, nunca regex) o RESTWiRL passa de 3200 chars e o build
      morre com MSB6003 "filename or extension is too long". Parece defeito do
      repo e nao e.
    - NAO absolutizar os caminhos relativos: os targets repetem a lista em
      -U/-I/-O/-R e o comando estoura de novo.
    - NUNCA passar /p:DCC_DcuOutput: a linha de comando vence o .dproj e os sete
      projetos voltam a colidir no mesmo diretorio, em silencio - e a medida (b)
      passa a contar cobertura alheia como propria.

  USO
    powershell -File Test\Delphi\Tools\compile-coverage-census.ps1
    powershell -File Test\Delphi\Tools\compile-coverage-census.ps1 -NoBuild   # so recoleta
#>

[CmdletBinding()]
param(
  # Raiz do repositorio. Vazio = tres niveis acima deste script.
  # (nao usar $PSScriptRoot no default: com `powershell -File` ele ainda nao
  #  esta ligado quando o param block e avaliado.)
  [string]$Root = '',

  # Pin do FluentSQL, RELATIVO a Test\Delphi. Sem ele o build quebra.
  [string]$PinRel = '..\..\..\_wt-fluentsql-pin265\Source',

  [string]$RsVars  = 'C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat',
  [string]$BdsLib  = 'C:\Program Files (x86)\Embarcadero\Studio\37.0\lib',
  [string]$MarsDir = 'D:\Delphi Tools\MARS',
  [string]$WirlDir = 'D:\Delphi Tools\WiRL',

  [string]$OutDir,
  [switch]$NoBuild
)

$ErrorActionPreference = 'Stop'

if ($Root -eq '') { $Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path }
$ProjDir = Join-Path $Root 'Test\Delphi'
if (-not $OutDir) { $OutDir = Join-Path $ProjDir 'Win32\Debug\_census' }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$Projects = @(
  'Janus.Tests.Units',
  'Janus.Tests.LiveBindings',
  'Janus.Tests.RESTfulDriver',
  'Janus.Tests.RESTHorse',
  'Janus.Tests.RESTMARS',
  'Janus.Tests.RESTOracle',
  'Janus.Tests.RESTWiRL'
)

# ---------------------------------------------------------------- search path
function Get-UnitSearchPath([string]$dprojPath) {
  [xml]$xdoc = Get-Content -LiteralPath $dprojPath
  $nodes = $xdoc.SelectNodes("//*[local-name()='DCC_UnitSearchPath']")
  $acc = ''
  foreach ($nd in $nodes) { $acc = $nd.InnerText.Replace('$(DCC_UnitSearchPath)', $acc) }
  # String.Replace, nunca [regex]::Escape - os valores tem parenteses e barras.
  $acc = $acc.Replace('$(BDSLIB)',  $BdsLib)
  $acc = $acc.Replace('$(MARSDIR)', $MarsDir)
  $acc = $acc.Replace('$(WIRLDIR)', $WirlDir)
  $acc = $acc.Replace('$(Platform)','Win32')
  $acc = $acc.Replace('$(Config)',  'Debug')

  # Pin do FluentSQL na FRENTE, para vencer o FluentSQL do repo.
  $entries = @("$PinRel\Core", "$PinRel\Drivers") + ($acc -split ';')

  $seen = New-Object 'System.Collections.Generic.HashSet[string]'
  $kept = New-Object System.Collections.ArrayList
  foreach ($entry in $entries) {
    $trimmed = $entry.Trim()
    if ($trimmed -eq '') { continue }
    $abs = if ([System.IO.Path]::IsPathRooted($trimmed)) { $trimmed } else { Join-Path $ProjDir $trimmed }
    try { $full = [System.IO.Path]::GetFullPath($abs) } catch { continue }
    if (-not (Test-Path -LiteralPath $full -PathType Container)) { continue }
    if (-not $seen.Add($full.ToLowerInvariant())) { continue }
    [void]$kept.Add($trimmed)
  }
  return ($kept -join ';')
}

# ---------------------------------------------------------------------- build
$failed = @()
foreach ($proj in $Projects) {
  $usp = Get-UnitSearchPath (Join-Path $ProjDir "$proj.dproj")
  Write-Host ("[{0,-26}] search path: {1} chars, {2} entradas" -f $proj, $usp.Length, ($usp -split ';').Count)
  Set-Content -LiteralPath (Join-Path $OutDir "$proj.searchpath.txt") -Value $usp -Encoding ASCII
  if ($NoBuild) { continue }

  $map = Join-Path $ProjDir "$proj.map"
  if (Test-Path -LiteralPath $map) { Remove-Item -LiteralPath $map -Force }
  $dcuDir = Join-Path $ProjDir "Win32\Debug\$proj"
  if (Test-Path -LiteralPath $dcuDir) { Remove-Item -LiteralPath $dcuDir -Recurse -Force }

  $bat = Join-Path $OutDir "build-$proj.bat"
  Set-Content -LiteralPath $bat -Encoding ASCII -Value @(
    '@echo off',
    "call `"$RsVars`" >nul",
    "cd /d `"$ProjDir`"",
    "msbuild `"$proj.dproj`" /t:Build /p:Config=Debug /p:Platform=Win32 /p:`"DCC_UnitSearchPath=$usp`" /p:DCC_MapFile=3",
    'exit /b %ERRORLEVEL%'
  )
  cmd /c "`"$bat`"" > (Join-Path $OutDir "build-$proj.log") 2>&1
  $rc = $LASTEXITCODE
  Write-Host ("                              build exit={0}  map={1}" -f $rc, (Test-Path -LiteralPath $map))
  if ($rc -ne 0) { $failed += $proj }
}
if ($failed.Count -gt 0) { throw "Build falhou em: $($failed -join ', '). Censo abortado - numero de build quebrado nao e medida." }

# -------------------------------------------------------------------- coleta
$srcUnits = @{}
foreach ($f in Get-ChildItem -LiteralPath (Join-Path $Root 'Source') -Recurse -Filter *.pas) {
  $key = $f.BaseName.ToLowerInvariant()
  if ($srcUnits.ContainsKey($key)) { throw "Basename duplicado em Source/: $($f.Name) - o casamento por nome deixa de ser valido." }
  $srcUnits[$key] = $f.FullName.Substring($Root.Length + 1).Replace('\','/')
}

$byMap = @{}; $byDcu = @{}
foreach ($proj in $Projects) {
  $set = New-Object 'System.Collections.Generic.HashSet[string]'
  $map = Join-Path $ProjDir "$proj.map"
  if (Test-Path -LiteralPath $map) {
    foreach ($m in ([regex]'(?m)\sM=(\S+)').Matches((Get-Content -LiteralPath $map -Raw))) {
      [void]$set.Add($m.Groups[1].Value.ToLowerInvariant())
    }
  }
  $byMap[$proj] = $set

  $set2 = New-Object 'System.Collections.Generic.HashSet[string]'
  $dcuDir = Join-Path $ProjDir "Win32\Debug\$proj"
  if (Test-Path -LiteralPath $dcuDir) {
    foreach ($d in Get-ChildItem -LiteralPath $dcuDir -Filter *.dcu) { [void]$set2.Add($d.BaseName.ToLowerInvariant()) }
  }
  $byDcu[$proj] = $set2
}

function Get-Hits([string]$unit, [hashtable]$table) {
  $k = $unit.ToLowerInvariant()
  @($Projects | Where-Object { $table[$_].Contains($k) })
}

# ------------------------------------------------------------------ controles
$ok = $true
$posMap = Get-Hits 'Janus.Bind' $byMap
$posDcu = Get-Hits 'Janus.Bind' $byDcu
"=== CONTROLE POSITIVO - Janus.Bind ==="
"  MAP: " + ($posMap -join ', ')
"  DCU: " + ($posDcu -join ', ')
if ($posDcu.Count -eq 0) { $ok = $false; Write-Warning 'CONTROLE POSITIVO FALHOU: Janus.Bind nao aparece em projeto nenhum. O metodo esta errado.' }

"=== CONTROLE NEGATIVO - a familia DMVC (esperado: nenhum; o DMVC nao compila no Studio 37) ==="
foreach ($u in @('Janus.Client.DMVC','Janus.Server.DMVC')) {
  $hm = Get-Hits $u $byMap; $hd = Get-Hits $u $byDcu
  "  {0,-24} MAP=[{1}]  DCU=[{2}]" -f $u, ($hm -join ', '), ($hd -join ', ')
  if ($hd.Count -gt 0) { $ok = $false; Write-Warning "CONTROLE NEGATIVO FALHOU para $u - o DMVC teria de compilar para isso ser possivel; confira o commit medido (git rev-parse HEAD)." }
}
"  commit medido: " + (git -C $Root rev-parse HEAD)

# --------------------------------------------------------------------- matriz
$rows = foreach ($key in ($srcUnits.Keys | Sort-Object)) {
  $row = [ordered]@{ Unit = $srcUnits[$key] }
  $nMap = 0; $nDcu = 0
  foreach ($proj in $Projects) {
    $inMap = $byMap[$proj].Contains($key); $inDcu = $byDcu[$proj].Contains($key)
    if ($inMap) { $nMap++ }; if ($inDcu) { $nDcu++ }
    $row[$proj] = if ($inMap -and $inDcu) { 'X' } elseif ($inDcu) { 'd' } elseif ($inMap) { 'm!' } else { '' }
  }
  $row['NMap'] = $nMap; $row['NDcu'] = $nDcu
  [pscustomobject]$row
}
$csv = Join-Path $OutDir 'census-matrix.csv'
$rows | Export-Csv -Path $csv -NoTypeInformation

$mSemD = @($rows | Where-Object { $_.NMap -gt 0 -and $_.NDcu -eq 0 })
if ($mSemD.Count -gt 0) {
  Write-Warning "MAP nao e subconjunto de DCU em $($mSemD.Count) units - a premissa do metodo caiu, investigue antes de usar os numeros:"
  $mSemD | ForEach-Object { Write-Warning ("  " + $_.Unit) }
}

# -------------------------------------------------------------------- numeros
$cov   = @($rows | Where-Object { $_.NDcu -gt 0 })
$uncov = @($rows | Where-Object { $_.NDcu -eq 0 })
$only1 = @($rows | Where-Object { $_.NDcu -eq 1 })
$ext   = @($rows | Where-Object { $_.Unit -like 'Source/External/*' })

""
"=== NUMEROS (medida autoritativa: DCU) ==="
"  units .pas em Source/ (recursivo) ........ {0}" -f $rows.Count
"    das quais em Source/External/ .......... {0}  (terceiro, vendorizado)" -f $ext.Count
"  compiladas por >= 1 projeto .............. {0}" -f $cov.Count
"  compiladas por NENHUM .................... {0}   (excluindo External: {1})" -f $uncov.Count, ($uncov.Count - @($ext | Where-Object { $_.NDcu -eq 0 }).Count)
"  compiladas por EXATAMENTE 1 projeto ...... {0}   (frageis)" -f $only1.Count
"  divergencia MAP vs DCU ................... {0}   (esperado > 0: o .map subestima)" -f @($rows | Where-Object { ($_.NMap -gt 0) -ne ($_.NDcu -gt 0) }).Count
""
"=== COBERTURA POR PROJETO (units de Source/) ==="
foreach ($proj in $Projects) {
  "  {0,-28} {1}" -f $proj, @($srcUnits.Keys | Where-Object { $byDcu[$proj].Contains($_) }).Count
}
""
"=== NAO COMPILADAS POR NENHUM DOS SETE ({0}) ===" -f $uncov.Count
$uncov | ForEach-Object { "  " + $_.Unit }
""
"=== COMPILADAS POR UM SO PROJETO ({0}) ===" -f $only1.Count
$only1 | ForEach-Object {
  $k = [System.IO.Path]::GetFileNameWithoutExtension($_.Unit).ToLowerInvariant()
  "  {0,-62} <- {1}" -f $_.Unit, ((Get-Hits $k $byDcu) -join ',')
}
""
"matriz completa: $csv"
if (-not $ok) { exit 1 }
