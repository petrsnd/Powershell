## Functions for interacting with IIS and IIS Express

## SSL Certificates
function GetMakeCertExe()
{
    $private:sdkspath = "C:\Program Files\Microsoft SDKs"
    if ([Environment]::Is64BitProcess)
    {
        $private:sdkspath = "C:\Program Files (x86)\Microsoft SDKs"
    }
    $private:makecertbin = @(Get-ChildItem -Path $private:sdkspath -Filter makecert.exe -Recurse)
    if ($private:makecertbin.Count -gt 0)
    {
        $private:makecertbin[0].FullName
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
    & $private:makecertbin -r -pe -n "CN=$name" -b 01/01/2000 -e 01/01/2036 -eku 1.3.6.1.5.5.7.3.1 -ss $private:st `
                           -sr $private:storeloc -sky exchange -sp "Microsoft RSA SChannel Cryptographic Provider" -sy 12
}
Export-ModuleMember -Function GetMakeCertExe
Export-ModuleMember -Function CreateSelfSignedSSLCertificate