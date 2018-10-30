<#
.SYNOPSIS
    Lists all present snapshots older than a specified amount of days.
.DESCRIPTION
    Lists all present snapshots for a given VMware vSphere.
    It shows for each snapshot the associated virtual machine name, name and description and the snapshot's age in days.
    
    IMPORTANT: Requires VMware PowerCLI be installed.
    See: http://thesolving.com/virtualization/how-to-install-and-configure-vmware-powercli-version-10/
.PARAMETER Server
    The name or ip address of the host or vCenter Server
.PARAMETER Username
    Name of the administrative account needed to authenticate to vSphere.
.PARAMETER Password
    The password for the given user.
.PARAMETER IgnoreVMNamesStartingWith
    If specified, snapshots associated to Virtual Machine names beginning with this parameter (e.g. "replica") will be filtered from the result.
    If no parameter is specified or the string is empty, all snapshots (matching the MinAgeInDays criteria) will be included in the result.
.PARAMETER MinAgeInDays
    Only list snapshots with an age of at least x days. If the value is 0, the age is not considered in the result.
.EXAMPLE
    .\CheckForPresentVMwareSnapshots.ps1 -Server %host -Username "MyUsername" -Password "MyPassword" -IgnoreVMNamesStartingWith = "replica" -MinAgeInDays 3
    Values with % will be replaced by PRTG automatically.
.NOTES
    Author:   Antoine Hauck
    Company:  Keynet AG | (c) 2018
.LINK
    http://www.keynet.ch
#>
param(
    [string]$Server = "vc01.domain.com",
    [string]$Username = "account@domain.com",
    [string]$Password = "SecurePassword",
    [string]$IgnoreVMNamesStartingWith = "replica",
    [int]$MinAgeInDays = 0
)

Try
{
    $conn = Connect-VIServer $Server -Username $Username -Password $Password -Force

    $Snapshots = Get-VM | Get-Snapshot | Select VM, Name,Description,@{Name="SizeGB";Expression={ [math]::Round($_.SizeGB,2) }},@{Name="Creator";Expression={ Get-SnapshotCreator -VM $_.VM -Created $_.Created }},Created,@{Name="Days";Expression={ (New-TimeSpan -End (Get-Date) -Start $_.Created).Days }} | where { $_.Days -ge $MinAgeInDays }

    $SnapshotsFiltered = @()
    Foreach ($Snapshot in $Snapshots)
    {
        If($IgnoreVMNamesStartingWith.Length -gt 0 -and $Snapshot.VM.ToString().StartsWith($IgnoreVMNamesStartingWith))
        {
            # Snapshot starts with ignored name. Skip entry.
        } else {
            $SnapshotsFiltered += $Snapshot
        }
    }

    Disconnect-VIServer $conn -Force -Confirm:$false

    if($SnapshotsFiltered.Length -eq 0)
    {
        Write-Host "0:No snapshots found with an age of at least $MinAgeInDays days."
        exit 0
    }

    $Result = $SnapshotsFiltered.Length.ToString() + ":"
    Foreach ($Snapshot in $SnapshotsFiltered)
    {
        $Result += "VM:" + $Snapshot.VM + ", Name:" + $Snapshot.Name + ", Description:" + $Snapshot.Description + ", Days: " + $Snapshot.Days + " ---- "
    }

    Write-Host $Result
    exit 1
}
catch
{
    Write-Host "-1:Error occurred while checking for snapshots:"$_.Exception.GetType().FullName, $_.Exception.Message. $_.Exception.Stacktrace
    exit 1
}