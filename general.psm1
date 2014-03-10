## General purpose Powershell functions

## User Accounts and Elevation
function Get-QualifiedUsername()
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
function Confirm-AdministrativePrivilege()
{
    If (-Not (HasAdministrativePrivilege))
    {
        Write-Warning "You do not have Administrator rights to run this script.`nPlease re-run this script as an Administrator."
        Write-Host "Right-click on Powershell.exe to run as administrator."
        break
    }
}
Export-ModuleMember -Function Get-QualifiedUsername
Export-ModuleMember -Function Confirm-AdministrativePrivilege


## Directories and Paths
function Get-ScriptDirectory()
{
    $private:cwd = (Get-Location).Path
    if ($MyInvocation -and $MyInvocation.MyCommand.Path)
    {
        $private:cwd = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    $private:cwd
}
function Change-Directory([string] $dir)
{
    # By default directory changes don't change the current working directory in the environment
    Set-Location $dir 
    [Environment]::CurrentDirectory = Get-Location -PSProvider FileSystem
}
function Which([string] $exe)
{
    Get-Command $exe | Select-Object -ExpandProperty Definition
}
function Find-FileInDirectory([string] $file, [string] $directory)
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
function Find-FirstFileInDirectory([string] $file, [string] $directory)
{
    $private:filepaths = @(Find-FileInDirectory $file $directory)
    if ($private:filepaths.Count -gt 0)
    {
        $private:filepaths[0]
    }
    else
    {
        $Null
    }
}
function Get-TempFileName([string] $ext)
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
Export-ModuleMember -Function Get-ScriptDirectory
Export-ModuleMember -Function Change-Directory
Export-ModuleMember -Function Which
Export-ModuleMember -Function Find-FileInDirectory
Export-ModuleMember -Function Find-FirstFileInDirectory
Export-ModuleMember -Function Get-TempFileName


## Registry
function Get-HKLMSoftware32Bit()
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
function Get-HKCUSoftware32Bit()
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
function Read-RegistryKeyValue([string] $keypath, [string] $valuename, [string] $default)
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
Export-ModuleMember -Function Get-HKLMSoftware32Bit
Export-ModuleMember -Function Get-HKCUSoftware32Bit
Export-ModuleMember -Function Read-RegistryKeyValue


## Windows Services
function Create-Service([string] $cmdline, [string] $name, [string] $displayname, [string] $description,
                        [switch] $automatic, [switch] $start)
{
    $private:block = {
        Param($cmdline, $name, $displayname, $description, $automatic, $start)
        if ($automatic -eq $True)
        {
            New-Service -BinaryPathName "$cmdline" -Name "$name" -DisplayName "$displayname" -Description "$description" -StartupType Automatic
        }
        else
        {
            New-Service -BinaryPathName "$cmdline" -Name "$name" -DisplayName "$displayname" -Description "$description" -StartupType Manual
        }
        if ($start -eq $True)
        {
            Start-Service -Name $name
        }
    }
    if (HasAdministrativePrivilege)
    {
        Invoke-Command $private:block -ArgumentList $cmdline,$name,$displayname,$description,$automatic,$start
    }
    else
    {
        $private:scr = $private:block.ToString()
        Start-Process $PSHOME\powershell.exe -Verb RunAs -ErrorAction SilentlyContinue `
                      -ArgumentList "-Command `"Invoke-Command {$private:scr} -ArgumentList '$cmdline','$name','$displayname','$description',$automatic,$start`""
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
function Delete-Service([string] $name)
{
    $private:block = {
        Param($name, $filter)
        Stop-Service $name
        $service = Get-WmiObject -Class Win32_Service -Filter $filter
        $service.delete()
    }
    if (HasAdministrativePrivilege)
    {
        Invoke-Command $private:block -ArgumentList $name,"Name='$name'"
    }
    else
    {
        $private:scr = $private:block.ToString()
        Start-Process $PSHOME\powershell.exe -Verb RunAs -ErrorAction SilentlyContinue `
                      -ArgumentList "-Command `"Invoke-Command {$private:scr} -ArgumentList '$name','Name=''$name'''`""
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
Export-ModuleMember -Function Create-Service
Export-ModuleMember -Function Delete-Service


## Networking
function Get-Hostname()
{
    "${env:computername}".ToLower()
}
function Get-FQDN()
{
    $private:domain = "${env:userdnsname}".ToLower()
    if (-Not [string]::IsNullOrEmpty($private:domain))
    {
        (Get-Hostname) + ".${private:domain}"
    }
    else
    {
        (Get-Hostname)
    }
}
function Get-NIC()
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
function Get-IPv4Address()
{
    $private:nic = (Get-NIC)
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
function Get-IPv6Address()
{
    $private:nic = (Get-NIC)
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
function Add-TcpInFirewallRule([string] $name, [string] $port, [string] $action)
{
    RunFirewallAddRuleCommand "add" $name "in" "tcp" $port $action
}
function Add-TcpOutFirewallRule([string] $name, [string] $port, [string] $action)
{
    RunFirewallAddRuleCommand "add" $name "out" "tcp" $port $action
}
function Add-UdpInFirewallRule([string] $name, [string] $port, [string] $action)
{
    RunFirewallAddRuleCommand "add" $name "in" "udp" $port $action
}
function Add-UdpOutFirewallRule([string] $name, [string] $port, [string] $action)
{
    RunFirewallAddRuleCommand "add" $name "out" "udp" $port $action
}
function Delete-FirewallRule([string] $name)
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
Export-ModuleMember -Function Get-Hostname
Export-ModuleMember -Function Get-FQDN
Export-ModuleMember -Function Get-NIC
Export-ModuleMember -Function Get-IPv4Address
Export-ModuleMember -Function Get-IPv6Address
Export-ModuleMember -Function Add-TcpInFirewallRule
Export-ModuleMember -Function Add-TcpOutFirewallRule
Export-ModuleMember -Function Add-UdpInFirewallRule
Export-ModuleMember -Function Add-UdpOutFirewallRule
Export-ModuleMember -Function Delete-FirewallRule


## Internet
function Disable-SSLVerification()
{
    try 
    {
        Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@ -EA SilentlyContinue
    } catch {}
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}
function Download-File([string] $url, [string] $targetpath)
{
    $private:webclient = (New-Object System.Net.WebClient)
    $private:webclient.DownloadFile($url, $targetpath)
}
Export-ModuleMember -Function Disable-SSLVerification
Export-ModuleMember -Function Download-File


## Archives
function Zip-Files([string] $zipfilepath, [string] $sourcepath)
{
    [Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem")
    $private:compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
    [System.IO.Compression.ZipFile]::CreateFromDirectory($sourcepath, $zipfilepath, $private:compressionLevel, $false)
}
function Unzip-File([string] $zipfilepath, [string] $targetpath)
{
    [Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem")
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfilepath, $targetpath)
}
Export-ModuleMember -Function Zip-Files
Export-ModuleMember -Function Unzip-File

## Miscellaneous
function Get-RandomString([int] $length)
{
    $private:set = "abcdefghijklmnopqrstuvwxyz0123456789".ToCharArray()
    for ($private:i = 1; $private:i -le $length; $private:i++)
    {
        $private:result += $private:set | Get-Random
    }
    $private:result
}
function Confirm-Member($object, [string] $property)
{
    $private:members = Get-Member -InputObject $object;
    if ($private:members -ne $null -and $private:members.count -gt 0)
    {
        foreach ($private:member in $private:members)
        {
            if (($private:member.MemberType -eq "Property") -and ($private:member.Name -eq $property))
            {
                return $true
            }
        }
        return $false
    }
    else
    {
        return $false;
    }
}
function Press-AnyKeyToContinue()
{
    Write-Host "Press any key to continue..."
    ([Console]::Out.Flush())
    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
}
Export-ModuleMember -Function Get-RandomString
Export-ModuleMember -Function Has-Member
Export-ModuleMember -Function Press-AnyKeyToContinue
