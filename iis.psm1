## Functions for interacting with IIS and IIS Express

## Prerequisites
Import-Module .\general.psm1 -Force


## SSL Certificates
function GetMakeCertExe()
{
    $private:sdkspath = "C:\Program Files\Microsoft SDKs"
    if ([Environment]::Is64BitProcess)
    {
        $private:sdkspath = "C:\Program Files (x86)\Microsoft SDKs"
    }
    $private:makecertbin = (FindFirstFileInDirectory "makecert.exe" $private:sdkspath)
    if ($private:makecertbin)
    {
        $private:makecertbin
    }
    else
    {
        Write-Warning "Unable to find makecert.exe in SDKs directory, hoping it's in your path."
        "makecert.exe"
    }
}
function CreateSelfSignedSSLCertificate([string] $name, [bool] $user, [string] $store)
{
    if ([string]::IsNullOrEmpty($name))
    {
        Write-Warning "You must specify the name of the SSL certificate to create"
        break
    }
    ## Please note that importing to local machine requires administrative privilege
    ## general.psm1 has a function for checking for administrative privilege
    $private:storeloc = "LocalMachine" 
    if ($user)
    {
        $private:storeloc = "CurrentUser"
    }
    $private:st = "my"
    if (-Not [string]::IsNullOrEmpty($store))
    {
        $private:st = $store
    }
    $private:makecertbin = (GetMakeCertExe)
    & $private:makecertbin -r -pe -n "CN=$name" -b 01/01/2000 -e 01/01/2036 -eku 1.3.6.1.5.5.7.3.1 -ss "${private:st}" `
                           -sr "${private:storeloc}" -sky exchange -sp "Microsoft RSA SChannel Cryptographic Provider" -sy 12
}
function GetCertificateByCn([string] $name, [bool] $user, [string] $store)
{
    $private:storeloc = "LocalMachine" 
    if ($user)
    {
        $private:storeloc = "CurrentUser"
    }
    $private:st = "my"
    if (-Not [string]::IsNullOrEmpty($store))
    {
        $private:st = $store
    }
    Get-ChildItem "cert:/${private:storeloc}/${private:st}" | where { $_.Subject -eq "CN=$name" }
}
function GetCertificateThumbprintByCn([string] $name, [bool] $user, [string] $store)
{
    $private:cert = (GetCertificateByCn $name $user $store)
    if ($private:cert)
    {
        $private:cert.Thumbprint
    }
    else
    {
        $Null
    }
}
Export-ModuleMember -Function GetMakeCertExe
Export-ModuleMember -Function CreateSelfSignedSSLCertificate
Export-ModuleMember -Function GetCertificateByCn
Export-ModuleMember -Function GetCertificateThumbprintByCn


## General Http
function CreateUrlAclReservation([string] $urlbase, [string] $user)
{
    $private:netshbin = (Which "netsh.exe")
    if ($private:netshbin)
    {
        & $private:netshbin http add urlacl url="$urlbase" user="$user"
    }
    else
    {
        Write-Warning "Unable to find netsh.exe in PATH"
    }
}
function BindSSLCertificateToPort([string] $ipport, [string] $certfingerprint, [string] $appguid)
{
    $private:netshbin = (Which "netsh.exe")
    if ($private:netshbin)
    {
        $private:guid = [guid]::NewGuid().ToString()
        if ($appguid)
        {
            $private:guid = $appguid
        }
        & $private:netshbin http add sslcert ipport="$ipport" appid="${private:guid}" certhash="$certfingerprint"
    }
    else
    {
        Write-Warning "Unable to find netsh.exe in PATH"
    }
}
Export-ModuleMember -Function CreateUrlAclReservation
Export-ModuleMember -Function BindSSLCertificateToPort


## IIS Express
function GetAppCmdExe()
{
    $private:keypath = (Join-Path (GetHKLMSoftware32Bit) "Microsoft\IISExpress\8.0")
    $private:dir = ReadRegistryKeyValue $private:keypath "InstallPath" "C:\Program Files (x86)\IIS Express"
    FindFirstFileInDirectory "appcmd.exe" $private:dir
}
function GetIISExpressExe()
{
    $private:keypath = (Join-Path (GetHKLMSoftware32Bit) "Microsoft\IISExpress\8.0")
    $private:dir = ReadRegistryKeyValue $private:keypath "InstallPath" "C:\Program Files (x86)\IIS Express"
    FindFirstFileInDirectory "iisexpress.exe" $private:dir
}
function ParseSiteObject([string] $sitestr)
{
    if ($private:sitestr)
    {
        $private:name = "$($sitestr.Split(' ')[1])" -replace "`""
        $private:str = "$($sitestr.Split(' ')[2])"
        if ($private:str -match "^\(id:([0-9]+),bindings:(.*),state:(.*)\)$")
        {
            $private:id = [int]$matches[1]
            $private:bindings = $matches[2] -split ","
            $private:obj = New-Object -TypeName PSObject
            Add-Member -InputObject $private:obj -MemberType NoteProperty -Name "Id" -Value $private:id
            Add-Member -InputObject $private:obj -MemberType NoteProperty -Name "Name" -Value $private:name
            Add-Member -InputObject $private:obj -MemberType NoteProperty -Name "Bindings" -Value $private:bindings
            Add-Member -InputObject $private:obj -MemberType NoteProperty -Name "Status" -Value $matches[3]
            $private:obj
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
function GetNextSiteId()
{
    $private:appcmdbin = (GetAppCmdExe)
    $private:sites = (& $private:appcmdbin list sites)
    if ($private:sites)
    {
        $private:siteid = ($private:sites | % { (ParseSiteObject $_).Id } | Sort -desc | Select -first 1)
        [int]$private:siteid + 1
    }
    else
    {
        1
    }
}
function GetSiteIdForName([string] $sitename)
{
    $private:appcmdbin = (GetAppCmdExe)
    $private:sitestr = (& $private:appcmdbin list site "/name:$sitename")
    $private:siteobj = (ParseSiteObject $private:sitestr)
    if ($private:siteobj)
    {
        $private:siteobj.Id
    }
    else
    {
        $Null
    }
}
function GetNextSiteId()
{
    $private:appcmdbin = (GetAppCmdExe)
    $private:sites = (& $private:appcmdbin list sites)
    if ($private:sites)
    {
        $private:siteid = ($private:sites | % { (ParseSiteObject $_).Id } | Sort -desc | Select -first 1)
        [int]$private:siteid + 1
    }
    else
    {
        1
    }
}
function GetSiteIdForName([string] $sitename)
{
    $private:appcmdbin = (GetAppCmdExe)
    $private:sitestr = (& $private:appcmdbin list site "/name:$sitename")
    if ($private:sitestr)
    {
        (ParseSiteObject $private:sitestr).Id
    }
    else
    {
        $Null
    }
}
function GetIISExpressSite([string] $sitename)
{
    $private:appcmdbin = (GetAppCmdExe)
    if ($sitename)
    {
        $private:sitestr = (& $private:appcmdbin list site "/name:$sitename")
        (ParseSiteObject $private:sitestr)
    }
    else
    {
        (& $private:appcmdbin list sites) | % { (ParseSiteObject $_) }
    }
}
function AddIISExpressSite([string] $sitename, [string]$physicalpath)
{
    $private:appcmdbin = (GetAppCmdExe)
    $private:siteid = (GetNextSiteId)
    & $private:appcmdbin add site "/id:${private:siteid}" "/name:'$sitename" "/physicalPath:'$physicalpath'"
}
function RemoveIISExpressSite([string] $sitename)
{
    $private:appcmdbin = (GetAppCmdExe)
    $private:siteid = (GetSiteIdForName $sitename)
    if ($private:siteid)
    {
        & $private:appcmdbin delete site "/id:${private:siteid}"
    }
    else
    {
        Write-Warning "Unable to find site '$sitename'"
    }
}
function AddIISExpressBinding([string] $sitename, [string] $proto, [string] $bindinginfo)
{
    $private:appcmdbin = (GetAppCmdExe)
    & $private:appcmdbin set site "/site.name:$sitename" "/+bindings.[protocol='$proto',bindingInformation='$bindinginfo']"
}
function RemoveIISExpressBinding([string] $sitename, [string] $proto, [string] $bindinginfo)
{
    $private:appcmdbin = (GetAppCmdExe)
    & $private:appcmdbin set site "/site.name:$sitename" "/-bindings.[protocol='$proto',bindingInformation='$bindinginfo']"
}
function RunIISExpressSite([string] $sitename)
{
    $private:iisexpressbin = (GetIISExpressExe)
    & $private:iisexpressbin "/site:$sitename"
}
Export-ModuleMember -Function GetAppCmdExe
Export-ModuleMember -Function GetIISExpressExe
Export-ModuleMember -Function GetIISExpressSite
Export-ModuleMember -Function AddIISExpressSite
Export-ModuleMember -Function RemoveIISExpressSite
Export-ModuleMember -Function AddIISExpressBinding
Export-ModuleMember -Function RemoveIISExpressBinding
Export-ModuleMember -Function RunIISExpressSite
