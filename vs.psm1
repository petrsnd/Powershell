## Functions for interacting with Visual Studio 2013

## Prerequisites
Import-Module .\general.psm1 -Force -NoClobber -DisableNameChecking -Scope Global


## Private functions
function InternalNoDuplicatePaths([string] $pathlist)
{
    ($pathlist -split ";" | select -uniq) -join ";"
}
function InternalModifyEnvironment([string] $batscript)
{
    ## Run script and store the output of set command in a temp file
    $private:tempfile = [IO.Path]::GetTempFileName()
    cmd.exe /c " `"$batscript`" && set > `"$private:tempfile`" "
    Get-Content $private:tempfile | % {
        if ($_ -match "^(.*?)=(.*)$")
        {
            ## The VCVARS scripts aren't very smart about modifying path variables
            ## These just keep growing and growing if you don't unique them manually
            $private:val = ""
            if ($matches[1] -eq "PATH" -or $matches[1] -eq "INCLUDE" -or $matches[1] -eq "LIBPATH")
            {
                $private:val = (InternalNoDuplicatePaths $matches[2])
            }
            else
            {
                $private:val = $matches[2]
            }
            Set-Content "env:\$($matches[1])" $private:val
        }
    }
    (Remove-Item $private:tempfile)
}

## Public functions
function Get-VSInstallPath()
{
    $private:keypath = (Join-Path (general/Get-HKLMSoftware32Bit) "Microsoft\VisualStudio\12.0")
    general/Read-RegistryKeyValue $private:keypath "ShellFolder" "C:\Program Files (x86)\Microsoft Visual Studio 12.0"
}
function Setup-VSEnvironment([string] $arch)
{
    $private:batpath = (Get-VSInstallPath)
    if (([string]::Compare($arch, "x64", $True) -eq 0) `
        -or ([string]::Compare($arch, "Win64", $True) -eq 0) `
        -or ([string]::Compare($arch, "amd64", $True) -eq 0))
    {
        Write-Host "Setting up Visual Studio environment for x64"
        $private:batpath = (Join-Path $private:batpath "VC\bin\amd64\vcvars64.bat")
    }
    elseif (([string]::Compare($arch, "ARM", $True) -eq 0) `
            -or ([string]::Compare($arch, "x86_ARM", $True)) -eq 0)
    {
        # Cross compile
        Write-Host "Setting up Visual Studio environment for ARM"
        $private:batpath = (Join-Path $private:batpath "VC\bin\x86_arm\vcvarsx86_arm.bat")
    }
    else
    {
        Write-Host "Setting up Visual Studio environment for x86"
        $private:batpath = (Join-Path $private:batpath "VC\bin\vcvars32.bat")
    }
    (InternalModifyEnvironment $private:batpath)
}
function Build-VSSolution([string] $slnpath, [string] $arch, [string] $config, [string] $buildargs)
{
    (Setup-VSEnvironment $arch)
    $private:configparam = "/p:Configuration='" + $config + "'"
    $private:archparam = ""
    if (-Not [string]::IsNullOrEmpty($arch))
    {
        $private:archparam = "/p:Platform='" + $arch + "'"
    }
    Invoke-Expression "msbuild.exe $slnpath ${private:configparam} ${private:archparam} $buildargs"
}
function Clean-VSSolution([string] $slnpath, [string] $arch, [string] $config)
{
    (Setup-VSEnvironment $arch)
    $private:configparam = "/p:Configuration='" + $config + "'"
    $private:archparam = ""
    if (-Not [string]::IsNullOrEmpty($arch))
    {
        $private:archparam = "/p:Platform='" + $arch + "'"
    }
    Invoke-Expression "msbuild.exe $slnpath /t:Clean ${private:configparam} ${private:archparam}"
}
Export-ModuleMember -Function Get-VSInstallPath
Export-ModuleMember -Function Setup-VSEnvironment
Export-ModuleMember -Function Build-VSSolution
Export-ModuleMember -Function Clean-VSSolution
