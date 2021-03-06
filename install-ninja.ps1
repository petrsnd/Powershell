## Install the ninja build system (http://martine.github.io/ninja/manual.html)
## Download, build, and install ninja
Param([switch] $InstallPath)

$ScriptDir = (GetScriptDirectory)

## Prerequisites
Import-Module .\general.psm1 -Force -NoClobber -DisableNameChecking -Scope Global
Import-Module .\vs.psm1 -Force -NoClobber -DisableNameChecking -Scope Global

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
(Confirm-AdministrativePrivilege)

## Download / Extract
$TmpZip = (Get-TempFileName "zip")
Write-Host "Downloading to $TmpZip..."
(Download-File $ZipUrl $TmpZip)

$TmpDir = (Get-TempFileName)
Write-Host "Extracting to $TmpDir..."
(Unzip-File $TmpZip $TmpDir)

## Build
(Setup-VSEnvironment "x86")
(Change-Directory "$TmpDir\ninja-master")
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
(Change-Directory $ScriptDir)

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
