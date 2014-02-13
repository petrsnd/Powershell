## Functions for interacting with SQL Server 2012 (11.0)


## Prerequisites
Import-Module .\general.psm1 -Force -NoClobber -Scope Global


## Command line tools
function GetSqlPackageExe()
{
    $private:sqlspath = "C:\Program Files\Microsoft SQL Server\110\DAC"
    if ([Environment]::Is64BitProcess)
    {
        $private:sqlspath = "C:\Program Files (x86)\Microsoft SQL Server\110\DAC"
    }
	$private:sqlpackagebin = (general\FindFirstFileInDirectory "sqlpackage.exe" $private:sqlspath)
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
function GetSqlLocalDbExe()
{
    $private:sqlspath = "C:\Program Files\Microsoft SQL Server\110"
    $private:sqllocaldbbin = (general\FindFirstFileInDirectory "sqllocaldb.exe" $private:sqlspath)
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
Export-ModuleMember -Function GetSqlPackageExe
Export-ModuleMember -Function GetSqlLocalDbExe


## (localdb)
function DoesLocalDbInstanceExist([string] $name)
{
    $private:sqllocaldbbin = (GetSqlLocalDbExe)
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
function CreateLocalDbInstance([string] $name)
{
    $private:sqllocaldbbin = (GetSqlLocalDbExe)
    & ${private:sqllocaldbbin} create $name
}
function DeleteLocalDbInstance([string] $name)
{
    $private:sqllocaldbbin = (GetSqlLocalDbExe)
    & ${private:sqllocaldbbin} delete $name
}
function IsLocalDbInstanceRunning([string] $name)
{
    $private:sqllocaldbbin = (GetSqlLocalDbExe)
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
function StartLocalDbInstance([string] $name)
{
    $private:sqllocaldbbin = (GetSqlLocalDbExe)
    & ${private:sqllocaldbbin} start $name
}
function StopLocalDbInstance([string] $name)
{
    $private:sqllocaldbbin = (GetSqlLocalDbExe)
    & ${private:sqllocaldbbin} stop $name
}
function KillLocalDbInstance([string] $name)
{
    $private:sqllocaldbbin = (GetSqlLocalDbExe)
    & ${private:sqllocaldbbin} stop $name -i -k
}
Export-ModuleMember -Function DoesLocalDbInstanceExist
Export-ModuleMember -Function CreateLocalDbInstance
Export-ModuleMember -Function DeleteLocalDbInstance
Export-ModuleMember -Function IsLocalDbInstanceRunning
Export-ModuleMember -Function StartLocalDbInstance
Export-ModuleMember -Function StopLocalDbInstance
Export-ModuleMember -Function KillLocalDbInstance


## DACPAC
# Ex. PublishDacPac "(localdb)\Projects" "MyDB" "C:\temp\MyDB.dacpac"
function PublishDacPac([string] $server, [string] $database, [string] $dacpac, [bool] $recreate = $true)
{
    $private:sqlpackagebin = (GetSqlPackageExe)
    if ($recreate)
    {
        & ${private:sqlpackagebin} /Action:Publish /SourceFile:"$dacpac" /TargetServerName:$server /TargetDatabaseName:$database "/p:CreateNewDatabase=true"
    }
    else
    {
        & ${private:sqlpackagebin} /Action:Publish /SourceFile:"$dacpac" /TargetServerName:$server /TargetDatabaseName:$database
    }
}
Export-ModuleMember -Function PublishDacPac
