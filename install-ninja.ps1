## Install the ninja build system (http://martine.github.io/ninja/manual.html)
## Download, build, and install ninja
Param([switch] $InstallPath)

$ScriptDir = (GetScriptDirectory)

## Prerequisites
Import-Module .\general.psm1 -Force -NoClobber -Scope Global
Import-Module .\vs.psm1 -Force -NoClobber -Scope Global

$PythonBin = (Which "python")
$GitUrl = "https://github.com/martine/ninja.git"
$ZipUrl = "https://github.com/martine/ninja/archive/master.zip"
$TargetPath = "${env:SystemDrive}\bin"
if ($InstallPath)
{
    $TargetPath = $InstallPath
}

if ([string]::IsNullOrEmpty($PythonBin))
{
    Write-Warning "Unable to find python in your path.`nPlease install python or add it to your path."
    break
}
(RequireAdministrativePrivilege)

## Download / Extract
$TmpZip = (GetTempFileName "zip")
Write-Host "Downloading to $TmpZip..."
(DownloadFile $ZipUrl $TmpZip)

$TmpDir = (GetTempFileName)
Write-Host "Extracting to $TmpDir..."
(UnzipFile $TmpZip $TmpDir)

## Build
(SetupVSEnvironment "x86")
(ChangeDirectory "$TmpDir\ninja-master")
& $PythonBin ".\bootstrap.py"

if (Test-Path -Path ".\ninja.exe")
{
    if (-Not (Test-Path -Path $TargetPath -PathType Container))
    {
        New-Item -ItemType directory -Path $TargetPath
    }
    Copy-Item -Path ".\ninja.exe" -Destination $TargetPath -Force
}
if (Test-Path -Path ".\ninja.bootstrap.exe")
{
    if (-Not (Test-Path -Path $TargetPath -PathType Container))
    {
        New-Item -ItemType directory -Path $TargetPath
    }
    Copy-Item -Path ".\ninja.bootstrap.exe" -Destination $TargetPath -Force
}

## Clean Up
(ChangeDirectory $ScriptDir)

## Result
if ((Test-Path -Path (Join-Path $TargetPath "ninja.exe")) `
    -and (Test-Path -Path (Join-Path $TargetPath "ninja.bootstrap.exe")))
{
    "SUCCESS -- " + (Join-Path $TargetPath "ninja.exe") + " and " `
                  + (Join-Path $TargetPath "ninja.bootstrap.exe")
}
else
{
    Write-Warning "FAIL"
    break
}
