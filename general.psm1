## General purpose Powershell functions

## User Accounts and Elevation
function GetQualifiedUsername()
{
    if (-Not [string]::IsNullOrEmpty("${env:userdomain}"))
    {
        "${env:userdomain}\${env:username}".ToLower()
    }
    else
    {
        ".\${env:username}".ToLower()
    }
}
function HasAdministrativePrivilege()
{
    If (-Not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
        [Security.Principal.WindowsBuiltInRole] "Administrator"))
    {
        $False
    }
    else
    {
        $True
    }
}
function RequireAdministrativePrivilege()
{
    If (-Not (HasAdministrativePrivilege))
    {
        Write-Warning "You do not have Administrator rights to run this script.`nPlease re-run this script as an Administrator."
        Write-Host "Right-click on Powershell.exe to run as administrator."
        break
    }
}
Export-ModuleMember -Function GetQualifiedUsername
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
    $private:filepaths = @(FindFileInDirectory $file $directory)
    if ($private:filepaths.Count -gt 0)
    {
        $private:filepaths[0]
    }
    else
    {
        $Null
    }
}
function GetTempFileName([string] $ext)
{
    $private:tmppath = [System.IO.Path]::GetTempFileName()
    Remove-Item -Path $private:tmppath -Force
    if ([string]::IsNullOrEmpty($ext))
    {
        $private:tmppath
    }
    else
    {
        $private:tmppath + "." + $ext
    }
}
Export-ModuleMember -Function GetScriptDirectory
Export-ModuleMember -Function ChangeDirectory
Export-ModuleMember -Function Which
Export-ModuleMember -Function FindFileInDirectory
Export-ModuleMember -Function FindFirstFileInDirectory
Export-ModuleMember -Function GetTempFileName


## Registry
function GetHKLMSoftware32Bit()
{
    if ([Environment]::Is64BitProcess)
    {
        "HKLM:Software\Wow6432Node"
    }
    else
    {
        "HKLM:Software"
    }
}
function GetHKCUSoftware32Bit()
{
    if ([Environment]::Is64BitProcess)
    {
        "HKCU:Software\Wow6432Node"
    }
    else
    {
        "HKCU:Software"
    }
}
function ReadRegistryKeyValue([string] $keypath, [string] $valuename, [string] $default)
{
    $private:val = (Get-ItemProperty -Path "$keypath" -Name "$valuename" -ErrorAction SilentlyContinue)
    if ($private:val)
    {
        $private:val | Select -ExpandProperty $valuename
    }
    else
    {
        # Default
        if ($default)
        {
            Write-Host "Registry value '$valuename' not found, using default '$default"
            $default
        }
        else
        {
            Write-Warning "Registry value '$valuename' not found, no default specified"
            $Null
        }
    }
}
Export-ModuleMember -Function GetHKLMSoftware32Bit
Export-ModuleMember -Function GetHKCUSoftware32Bit
Export-ModuleMember -Function ReadRegistryKeyValue


## Windows Services
function CreateService([string] $cmdline, [string] $name, [string] $displayname, [string] $description, [switch] $automatic)
{
    $private:block = {
        Param($cmdline, $name, $displayname, $description, $automatic)
        if ($automatic)
        {
            New-Service -BinaryPathName "$cmdline" -Name "$name" -DisplayName "$displayname" -Description "$description" -StartupType Automatic
        }
        else
        {
            New-Service -BinaryPathName "$cmdline" -Name "$name" -DisplayName "$displayname" -Description "$description" -StartupType Manual
        }
    }
    if (HasAdministrativePrivilege)
    {
        Invoke-Command $private:block -ArgumentList $cmdline,$name,$displayname,$description,$automatic
    }
    else
    {
        $private:scr = $private:block.ToString()
        Start-Process $PSHOME\powershell.exe -Verb RunAs -ErrorAction SilentlyContinue `
                      -ArgumentList "-Command `"Invoke-Command {$private:scr} -ArgumentList '$cmdline','$name','$displayname','$description',$automatic`""
        Start-Sleep 2
    }
    $s = Get-Service $name -ErrorAction SilentlyContinue
    if ($s -eq $Null)
    {
        $False
    }
    else
    {
        $True
    }
}
function DeleteService([string] $name)
{
    $private:block = {
        Param($filter)
        $service = Get-WmiObject -Class Win32_Service -Filter $filter
        $service.delete()
    }
    if (HasAdministrativePrivilege)
    {
        Invoke-Command $private:block -ArgumentList "Name='$name'"
    }
    else
    {
        $private:scr = $private:block.ToString()
        Start-Process $PSHOME\powershell.exe -Verb RunAs -ErrorAction SilentlyContinue `
                      -ArgumentList "-Command `"Invoke-Command {$private:scr} -ArgumentList 'Name=''$name'''`""
        Start-Sleep 2
    }
    $s = Get-Service $name -ErrorAction SilentlyContinue
    if ($s -eq $Null)
    {
        $True
    }
    else
    {
        $False
    }
}
Export-ModuleMember -Function CreateService
Export-ModuleMember -Function DeleteService


## Networking
function GetHostname()
{
    "${env:computername}".ToLower()
}
function GetFQDN()
{
    $private:domain = "${env:userdnsname}".ToLower()
    if (-Not [string]::IsNullOrEmpty($private:domain))
    {
        (GetHostname) + ".${private:domain}"
    }
    else
    {
        (GetHostname)
    }
}
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
function RunFirewallAddRuleCommand([string] $op, [string] $name, [string] $direction, [string] $proto, [string] $port, [string] $action)
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
    RunFirewallAddRuleCommand "add" $name "in" "tcp" $port $action
}
function AddTcpOutFirewallRule([string] $name, [string] $port, [string] $action)
{
    RunFirewallAddRuleCommand "add" $name "out" "tcp" $port $action
}
function AddUdpInFirewallRule([string] $name, [string] $port, [string] $action)
{
    RunFirewallAddRuleCommand "add" $name "in" "udp" $port $action
}
function AddUdpOutFirewallRule([string] $name, [string] $port, [string] $action)
{
    RunFirewallAddRuleCommand "add" $name "out" "udp" $port $action
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
Export-ModuleMember -Function GetHostname
Export-ModuleMember -Function GetFQDN
Export-ModuleMember -Function GetNic
Export-ModuleMember -Function GetIPv4Address
Export-ModuleMember -Function GetIPv6Address
Export-ModuleMember -Function AddTcpInFirewallRule
Export-ModuleMember -Function AddTcpOutFirewallRule
Export-ModuleMember -Function AddUdpInFirewallRule
Export-ModuleMember -Function AddUdpOutFirewallRule
Export-ModuleMember -Function DeleteFirewallRule


## Internet
function DownloadFile([string] $url, [string] $targetpath)
{
    $private:webclient = (New-Object System.Net.WebClient)
    $private:webclient.DownloadFile($url, $targetpath)
}
Export-ModuleMember -Function DownloadFile


## Archives
function ZipFiles($zipfilepath, $sourcepath)
{
    [Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem")
    $private:compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
    [System.IO.Compression.ZipFile]::CreateFromDirectory($sourcepath, $zipfilepath, $private:compressionLevel, $false)
}
function UnzipFile($zipfilepath, $targetpath)
{
    [Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem")
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfilepath, $targetpath)
}
Export-ModuleMember -Function ZipFiles
Export-ModuleMember -Function UnzipFile