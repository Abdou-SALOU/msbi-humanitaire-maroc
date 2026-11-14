# Installation de la chaine MSBI (projet Pr Hanine) - a lancer en administrateur
# SQL Server 2025 Enterprise Developer (moteur + SSAS multidimensionnel + SSIS), SSMS 22,
# Visual Studio 2022 Community + extensions SSIS et Analysis Services, Tableau Desktop.
$ErrorActionPreference = 'Continue'
$base  = Split-Path -Parent $MyInvocation.MyCommand.Path
$log   = Join-Path $base 'installation_log.txt'
$media = 'C:\SQL2025_Media'
$user  = "$env:USERDOMAIN\$env:USERNAME"
function Log($m) { $l = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Write-Host $l; Add-Content -Path $log -Value $l }
function Installer-Paquet($id, $extra) {
    Log "winget $id ..."
    $a = @('install','--id',$id,'-e','--silent','--accept-package-agreements','--accept-source-agreements') + $extra
    & winget.exe @a | Out-Null
    Log "winget $id -> code $LASTEXITCODE"
}

Log "=== Debut (utilisateur $user) ==="

# 1. SQL Server 2025 Enterprise Developer (le SSEI 2022 est refuse par Microsoft depuis 2026)
if (-not (Get-Service MSSQLSERVER -ErrorAction SilentlyContinue)) {
    New-Item -ItemType Directory -Force $media | Out-Null
    $ssei = Join-Path $media 'SQL2025-SSEI-EntDev.exe'
    Log "Telechargement de l'installateur SQL Server 2025 Enterprise Developer"
    Invoke-WebRequest 'https://download.microsoft.com/download/4ba126fc-a6a0-4810-80e9-c0182d3e1f62/SQL2025-SSEI-EntDev.exe' -OutFile $ssei -UseBasicParsing
    Log "Telechargement du media complet (CAB, ~1,5 Go)"
    Start-Process $ssei -ArgumentList "/Action=Download /MediaPath=$media /MediaType=CAB /Language=en-US /Quiet" -Wait
    $box = Get-ChildItem $media -Filter 'SQLServer2025*.exe' | Select-Object -First 1
    Log "Extraction de $($box.Name)"
    Start-Process $box.FullName -ArgumentList "/q /x:$media\Setup" -Wait
    Log "Installation SQL Server : moteur + SSAS multidimensionnel + SSIS"
    $args = "/Q /ACTION=Install /IACCEPTSQLSERVERLICENSETERMS /SUPPRESSPRIVACYSTATEMENTNOTICE " +
            "/FEATURES=SQLENGINE,AS,IS /INSTANCENAME=MSSQLSERVER /UPDATEENABLED=0 /TCPENABLED=1 " +
            "/SQLSYSADMINACCOUNTS=`"$user`" /ASSYSADMINACCOUNTS=`"$user`" /ASSERVERMODE=MULTIDIMENSIONAL"
    $p = Start-Process "$media\Setup\setup.exe" -ArgumentList $args -Wait -PassThru
    Log "setup.exe SQL Server -> code $($p.ExitCode) (0 ou 3010 = OK)"
} else { Log "SQL Server deja installe" }

# 2. SSMS 22
Installer-Paquet 'Microsoft.SQLServerManagementStudio.22' @()

# 3. Visual Studio 2022 Community (charge de travail Donnees)
$vsPath  = 'C:\Program Files\Microsoft Visual Studio\2022\Community'
$vsSetup = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\setup.exe"
if (Test-Path "$vsPath\Common7\IDE\devenv.exe") {
    Log "Visual Studio 2022 deja installe"
} elseif (Test-Path $vsPath) {
    Log "Visual Studio 2022 incomplet (installation interrompue) : reprise"
    $p = Start-Process $vsSetup -ArgumentList "resume --installPath `"$vsPath`" --quiet --norestart" -Wait -PassThru
    Log "Reprise Visual Studio -> code $($p.ExitCode) (0 ou 3010 = OK)"
    $p = Start-Process $vsSetup -ArgumentList "modify --installPath `"$vsPath`" --add Microsoft.VisualStudio.Workload.Data --includeRecommended --quiet --norestart" -Wait -PassThru
    Log "Ajout charge de travail Donnees -> code $($p.ExitCode) (0 ou 3010 = OK)"
} else {
    Installer-Paquet 'Microsoft.VisualStudio.2022.Community' @('--override','--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.Data --includeRecommended')
}
if (-not (Test-Path "$vsPath\Common7\IDE\devenv.exe")) { Log "ATTENTION : Visual Studio toujours absent, les extensions vont echouer" }

# 4. Extension SSIS
Installer-Paquet 'Microsoft.DataTools.IntegrationServices' @()

# 5. Extension Analysis Services (VSIX de la Marketplace)
$vsix = Join-Path $env:TEMP 'AnalysisServicesProjects.vsix'
$vsixUrl = 'https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ProBITools/vsextensions/MicrosoftAnalysisServicesModelingProjects2022/latest/vspackage'
try {
    Log "Telechargement de l'extension Analysis Services"
    Invoke-WebRequest $vsixUrl -OutFile $vsix -UseBasicParsing
    $inst = 'C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\VSIXInstaller.exe'
    $p = Start-Process $inst -ArgumentList "/q `"$vsix`"" -Wait -PassThru
    Log "VSIX Analysis Services -> code $($p.ExitCode) (0 = OK, 1001 = deja installe)"
} catch { Log "ERREUR extension Analysis Services : $_" }

# 6. Tableau Desktop (essai 14 jours, puis cle etudiante)
Installer-Paquet 'Tableau.Desktop' @()

Log "=== Fin ==="
Get-Service MSSQLSERVER, MSSQLServerOLAPService, MsDtsServer* -ErrorAction SilentlyContinue | ForEach-Object { Log ("Service {0} : {1}" -f $_.Name, $_.Status) }
