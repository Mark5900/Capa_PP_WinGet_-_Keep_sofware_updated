
[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    [string]$Packageroot,
    [Parameter(Mandatory = $true)]
    [string]$AppName,
    [Parameter(Mandatory = $true)]
    [string]$AppRelease,
    [Parameter(Mandatory = $true)]
    [string]$LogFile,
    [Parameter(Mandatory = $true)]
    [string]$TempFolder,
    [Parameter(Mandatory = $true)]
    [string]$DllPath,
    [Parameter(Mandatory = $false)]
    [Object]$InputObject = $null
)
##############
# Parameters #
##############
$AllowInstallOfWinGet = $false # If $true, will install winget if not found
# Use https://winget.run to find the id of the apps
$AppsToUpdate = @(
    'Lenovo.SystemUpdate',
    'Microsoft.PowerToys'
)

#############
# FUNCTIONS #
#############
function Find-WinGet {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [bool]$AllowInstallOfWinGet = $false,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$cs
    )
    $cs.Log_SectionHeader('Exist-WinGet', 'o')

    if (Get-Command 'winget' -ErrorAction SilentlyContinue) {
        $cs.Job_WriteLog('WinGet was found!')
    } else {
        if ($AllowInstallOfWinGet) {
            # https://learn.microsoft.com/en-us/windows/package-manager/winget/#install-winget
            Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
        } else {
            $cs.Job_WriteLog('WinGet was not found!')
            Exit-PSScript 3327 # PACKAGE_CANCELLED_NOT_COMPLIANT
        }
    }
}

function Invoke-UpdateAppWithWinGet {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppId,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$cs
    )
    try {
        $cs.Log_SectionHeader("Update-AppWithWinGet: $AppId", 'o')
    } catch {
        $cs.Log_SectionHeader('Update-AppWithWinGet', 'o')
        $cs.Job_WriteLog("Update-AppWithWinGet: $AppId", 'o')
    }

    # Will only update if apps is installed and there is a newer version
    try {
        $cs.Shell_Execute('winget', "upgrade --id $AppId")
    } catch {
        $cs.Job_WriteLog("Error: $($_.Exception.Message)")
    }
}

###############
# Script flow #
###############
try {
    ### Download package kit
    [bool]$global:DownloadPackage = $true

    ##############################################
    #load core PS lib - don't mess with this!
    if ($InputObject) { $pgkit = '' }else { $pgkit = 'kit' }
    Import-Module (Join-Path $Packageroot $pgkit 'PSlib.psm1') -ErrorAction stop
    #load Library dll
    $cs = Add-PSDll
    ##############################################

    #Begin
    $cs.Job_Start('WS', $AppName, $AppRelease, $LogFile, 'INSTALL')
    $cs.Job_WriteLog("[Init]: Starting package: '" + $AppName + "' Release: '" + $AppRelease + "'")
    if (!$cs.Sys_IsMinimumRequiredDiskspaceAvailable('c:', 1500)) { Exit-PSScript 3333 }
    if ($global:DownloadPackage -and $InputObject) { Start-PSDownloadPackage }

    $cs.Job_WriteLog("[Init]: `$PackageRoot:` '" + $Packageroot + "'")
    $cs.Job_WriteLog("[Init]: `$AppName:` '" + $AppName + "'")
    $cs.Job_WriteLog("[Init]: `$AppRelease:` '" + $AppRelease + "'")
    $cs.Job_WriteLog("[Init]: `$LogFile:` '" + $LogFile + "'")
    $cs.Job_WriteLog("[Init]: `$TempFolder:` '" + $TempFolder + "'")
    $cs.Job_WriteLog("[Init]: `$DllPath:` '" + $DllPath + "'")
    $cs.Job_WriteLog("[Init]: `$global:DownloadPackage`: '" + $global:DownloadPackage + "'")

    ##########
    # SCRIPT #
    ##########
    Find-WinGet -AllowInstallOfWinGet $AllowInstallOfWinGet -cs $cs
    foreach ($App in $AppsToUpdate) {
        Invoke-UpdateAppWithWinGet -AppId $App -cs $cs
    }

    Exit-PSScript $Error

} catch {
    $line = $_.InvocationInfo.ScriptLineNumber
    $cs.Job_WriteLog('*****************', "Something bad happend at line $($line): $($_.Exception.Message)")
    Exit-PSScript $_.Exception.HResult
}
