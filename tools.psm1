## Powershell functions for specific tools

function Install-Chocolatey
{
    $private:cinst = (Get-Command "cinst" -EA SilentlyContinue)
    if (-Not $private:cinst)
    {
        Write-Warning "You do not have Chocolatey installed."
        Write-Host "Attempting to install Chocolatey..."
        $xp = (Get-ExecutionPolicy)
        if ($xp -ne "Unrestricted" -a $xp -ne "RemoteSigned")
        {
             Write-Warning "Your execution policy is '$xp'.`nIt must be set to 'Unrestricted' or 'RemoteSigned'."
             break
        }
        Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        $private:cinst = "${env:SystemDrive}\Chocolatey\bin\cinst.bat"
        if (-Not Test-Path $private:cinst)
        {
            Write-Error "Unable to find cinst"
            break
        }
    }
}
function Install-NuGet
{
    $private:nuget = (Get-Command "nuget" -EA SilentlyContinue)
    if (-Not $private:nuget)
    {
        $private:cinst = (Get-Command "cinst" -EA SilentlyContinue)
        if (-Not $private:cinst)
        {
            Write-Warning "You do not have Chocolatey installed."
            break
        }
        & $private:cinst NuGet.CommandLine
        $private:nuget = "${env:SystemDrive}\Chocolatey\bin\NuGet.bat"
        if (-Not Test-Path $private:nuget)
        {
            Write-Error "Unable to find NuGet"
            break
        }
    }
}
Export-ModuleMember -Function Install-Chocolatey
Export-ModuleMember -Function Install-NuGet

