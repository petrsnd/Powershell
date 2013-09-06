## General purpose Powershell functions and snippets

## Elevation
function RequireAdministrativePrivilege()
{
    If (-Not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
        [Security.Principal.WindowsBuiltInRole] "Administrator"))
    {
        Write-Warning "You do not have Administrator rights to run this script.`nPlease re-run this script as an Administrator."
        Write-Host "Right-click on Powershell.exe to run as administrator."
        break
    }
}
Export-ModuleMember -Function RequireAdministrativePrivilege


## Directories
function GetScriptDirectory()
{
    $private:cwd = (Get-Location).Path
    if ($MyInvocation -and $MyInvocation.MyCommand.Path)
    {
        $private:cwd = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    $private:cwd
}
function ChangeDirectory($dir)
{
    # By default directory changes don't change the current working directory in the environment
    Set-Location $dir 
    [Environment]::CurrentDirectory = Get-Location -PSProvider FileSystem
}
Export-ModuleMember -Function GetScriptDirectory
Export-ModuleMember -Function ChangeDirectory


## Networking
function GetNic()
{
    ## Results may vary on multi-homed machines
    $private:nic = Get-WmiObject Win32_NetworkAdapterConfiguration -Namespace "root\CIMV2" | where { $_.IPEnabled -eq "True" }
    if ($private:nic -is [system.array])
    {
        $private:nic = $private:nic[0]
    }
    $private:nic
}
function GetIPv4Address()
{
    $private:nic = (GetNic)
    $private:addr = $private:nic.IPAddress | where { $_.Contains(".") }
    if ($private:addr -is [system.array])
    {
        $private:addr = $private:addr[0]
    }
    $private:addr
}
function GetIPv6Address()
{
    $private:nic = (GetNic)
    $private:addr = $private:nic.IPAddress | where { -Not $_.Contains(".") }
    if ($private:addr -is [system.array])
    {
        $private:addr = $private:addr[0]
    }
    $private:addr
}
Export-ModuleMember -Function GetNic
Export-ModuleMember -Function GetIPv4Address
Export-ModuleMember -Function GetIPv6Address