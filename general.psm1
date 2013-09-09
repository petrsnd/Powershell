## General purpose Powershell functions

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


## Directories and Paths
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
function Which([string] $exe)
{
    Get-Command $exe | Select-Object -ExpandProperty Definition
}
function FindFileInDirectory([string] $file, [string] $directory)
{
    $private:files = @(Get-ChildItem -Path $directory -Filter $file -Recurse)
    if ($private:files.Count -gt 0)
    {
        $private:files | % { $_.FullName }
    }
    else
    {
        Write-Warning "Unable to find $file in $directory"
        @()
    }
}
function FindFirstFileInDirectory([string] $file, [string] $directory)
{
    $private:filepaths = (FindFileInDirectory $file $directory)
    if ($private:filepaths.Count -gt 0)
    {
        $private:filepaths[0]
    }
    else
    {
        $Null
    }
}
Export-ModuleMember -Function GetScriptDirectory
Export-ModuleMember -Function ChangeDirectory
Export-ModuleMember -Function Which
Export-ModuleMember -Function FindFileInDirectory
Export-ModuleMember -Function FindFirstFileInDirectory


## Networking
function GetNic()
{
    ## Results may vary on multi-homed machines
    $private:nics = @(Get-WmiObject Win32_NetworkAdapterConfiguration -Namespace "root\CIMV2" | where { $_.IPEnabled -eq "True" })
    if ($private:nics.Count -gt 0)
    {
        $private:nics[0]
    }
    else
    {
        $Null
    }
}
function GetIPv4Address()
{
    $private:nic = (GetNic)
    if ($private:nic)
    {
        $private:addrs = @($private:nic.IPAddress | where { $_.Contains(".") })
        if ($private:addrs.Count -gt 0)
        {
            $private:addrs[0]
        }
        else
        {
            $Null
        }
    }
    else
    {
        $Null
    }
}
function GetIPv6Address()
{
    $private:nic = (GetNic)
    if ($private:nic)
    {
        $private:addrs = @($private:nic.IPAddress | where { -Not $_.Contains(".") })
        if ($private:addrs.Count -gt 0)
        {
            $private:addrs[0]
        }
        else
        {
            $Null
        }
    }
    else
    {
        $Null
    }
}
function RunFirewalAddRuleCommand([string] $op, [string] $name, [string] $direction, [string] $proto, [string] $port, [string] $action)
{
    $private:netshbin = (Which "netsh.exe")
    if ($private:netshbin)
    {
        Write-Host $op.ToUpper() " Firewall Rule $name $direction $proto $port $action"
        & $private:netshbin advfirewall firewall $op rule name="$name" dir="$direction" protocol="$proto" `
                            localport="$port" action="$action"
    }
    else
    {
        Write-Warning "Unable to find netsh.exe in PATH"
    }
}
function AddTcpInFirewallRule([string] $name, [string] $port, [string] $action)
{
    RunFirewalAddRuleCommand "add" $name "in" "tcp" $port $action
}
function AddTcpOutFirewallRule([string] $name, [string] $port, [string] $action)
{
    RunFirewalAddRuleCommand "add" $name "out" "tcp" $port $action
}
function AddUdpInFirewallRule([string] $name, [string] $port, [string] $action)
{
    RunFirewalAddRuleCommand "add" $name "in" "udp" $port $action
}
function AddUdpOutFirewallRule([string] $name, [string] $port, [string] $action)
{
    RunFirewalAddRuleCommand "add" $name "out" "udp" $port $action
}
function DeleteFirewallRule([string] $name)
{
    $private:netshbin = (Which "netsh.exe")
    if ($private:netshbin)
    {
        & $private:netshbin advfirewall firewall delete rule name="$name"
    }
    else
    {
        Write-Warning "Unable to find netsh.exe in PATH"
    }
}
Export-ModuleMember -Function GetNic
Export-ModuleMember -Function GetIPv4Address
Export-ModuleMember -Function GetIPv6Address
Export-ModuleMember -Function AddTcpInFirewallRule
Export-ModuleMember -Function AddTcpOutFirewallRule
Export-ModuleMember -Function AddUdpInFirewallRule
Export-ModuleMember -Function AddUdpOutFirewallRule
Export-ModuleMember -Function DeleteFirewallRule
