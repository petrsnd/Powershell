## Functions for interacting with SQL Server 2012 (11.0)


## Prerequisites
Import-Module .\general.psm1 -Force -NoClobber -Scope Global


## Command line tools
function Find-SqlPackageExe()
{
    $private:sqlspath = "C:\Program Files\Microsoft SQL Server\110\DAC"
    if ([Environment]::Is64BitProcess)
    {
        $private:sqlspath = "C:\Program Files (x86)\Microsoft SQL Server\110\DAC"
    }
	$private:sqlpackagebin = (general\Find-FirstFileInDirectory "sqlpackage.exe" $private:sqlspath)
    if ($private:sqlpackagebin)
    {
        $private:sqlpackagebin
    }
    else
    {
        Write-Warning "Unable to find sqlpackage.exe in Program Files directory, hoping it's in your path."
        "sqlpackage.exe"
    }
}
function Find-SqlLocalDbExe()
{
    $private:sqlspath = "C:\Program Files\Microsoft SQL Server\110"
    $private:sqllocaldbbin = (general\Find-FirstFileInDirectory "sqllocaldb.exe" $private:sqlspath)
    if ($private:sqllocaldbbin)
    {
        $private:sqllocaldbbin
    }
    else
    {
        Write-Warning "Unable to find sqllocaldb.exe in Program Files directory, hoping it's in your path."
        "sqllocaldb.exe"
    }
}
Export-ModuleMember -Function Find-SqlPackageExe
Export-ModuleMember -Function Find-SqlLocalDbExe


## (localdb)
function Confirm-LocalDbInstanceExists([string] $name)
{
    $private:sqllocaldbbin = (Find-SqlLocalDbExe)
    $private:match = ((& ${private:sqllocaldbbin} info $name) | Select-String "doesn't exist")
    if ($private:match)
    {
        $false
    }
    else
    {
        $true
    }
}
function Create-LocalDbInstance([string] $name)
{
    $private:sqllocaldbbin = (Find-SqlLocalDbExe)
    & ${private:sqllocaldbbin} create $name
}
function Delete-LocalDbInstance([string] $name)
{
    $private:sqllocaldbbin = (Find-SqlLocalDbExe)
    & ${private:sqllocaldbbin} delete $name
}
function Confirm-LocalDbInstanceRunning([string] $name)
{
    $private:sqllocaldbbin = (Find-SqlLocalDbExe)
    $private:match = ((& ${private:sqllocaldbbin} info $name) | Select-String "State:" | Select-String "Running")
    if ($private:match)
    {
        $true
    }
    else
    {
        $false
    }
}
function Start-LocalDbInstance([string] $name)
{
    $private:sqllocaldbbin = (Find-SqlLocalDbExe)
    & ${private:sqllocaldbbin} start $name
}
function Stop-LocalDbInstance([string] $name)
{
    $private:sqllocaldbbin = (Find-SqlLocalDbExe)
    & ${private:sqllocaldbbin} stop $name
}
function Kill-LocalDbInstance([string] $name)
{
    $private:sqllocaldbbin = (Find-SqlLocalDbExe)
    & ${private:sqllocaldbbin} stop $name -i -k
}
Export-ModuleMember -Function Confirm-LocalDbInstanceExists
Export-ModuleMember -Function Create-LocalDbInstance
Export-ModuleMember -Function Delete-LocalDbInstance
Export-ModuleMember -Function Confirm-LocalDbInstanceRunning
Export-ModuleMember -Function Start-LocalDbInstance
Export-ModuleMember -Function Stop-LocalDbInstance
Export-ModuleMember -Function Kill-LocalDbInstance


## DACPAC
# Ex. Publish-DacPac "(localdb)\Projects" "MyDB" "C:\temp\MyDB.dacpac"
function Publish-DacPac([string] $server, [string] $database, [string] $dacpac, [bool] $recreate = $true)
{
    $private:sqlpackagebin = (Find-SqlPackageExe)
    if ($recreate)
    {
        & ${private:sqlpackagebin} /Action:Publish /SourceFile:"$dacpac" /TargetServerName:$server /TargetDatabaseName:$database "/p:CreateNewDatabase=true"
    }
    else
    {
        & ${private:sqlpackagebin} /Action:Publish /SourceFile:"$dacpac" /TargetServerName:$server /TargetDatabaseName:$database
    }
}
Export-ModuleMember -Function Publish-DacPac
