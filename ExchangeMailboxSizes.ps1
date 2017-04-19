#===========================
# ___ ___ _____ ___
#| _ \ _ \_  _/ __|
#|  _/   / | ||(_ |
#|_| |_|_\ |_|\___|
#    NETWORK MONITOR
#-------------------
# Description:     This script will iterate through all available Exchange mailboxes and return all mailboxes that are bigger than the corresponding trigger
# limit for that mailbox. The trigger limit results from the defined warning quota for that mailbox minus the provided limit offset (default: 0.2 GB).
# If no warning quota is defined for a mailbox, the database default quota will be used for that mailbox.
# Explanation: If a mailbox has a size of 1.9 GB, the warning quota for that mailbox is 2.0 GB and the limit offset is 0.2 GB, an error will be issued because
# the mailbox exceeds the trigger limit of 1.8 GB (Warning Quota 2.0 GB - Limit Offset 0.2 GB).
# 
# Parameters:
# - ComputerName - The name of the Exchange Server you want to check for its mailbox sizes
# - Username: The username and the domain/computer used for the request.
# - Password: The password for the given user.
# - WarnBelowQuotaInGB: This defines the offset in GB below the warning quota. Default is 0.2 GB.
# Example: 
# ExchangeMailboxSizes.ps1 -ComputerName %host -UserName "%windowsdomain\%windowsuser" -Password "%windowspassword" -WarnBelowQuotaInGB 0.2
# Values with % will be replaced by PRTG automatically.
# ------------------
# (c) 2017 Antoine Hauck | Keynet AG
param(
    [string]$ComputerName = "localhost",
    [string]$UserName = "DOMAIN\Administrator",
    [string]$Password = "",
    [float]$WarnBelowQuotaInGB = 0.2
)
$SecPasswd  = ConvertTo-SecureString $Password -AsPlainText -Force
$Credentials= New-Object System.Management.Automation.PSCredential ($UserName, $SecPasswd)
$uri = "http://" + $ComputerName + "/powershell"
$s = New-PSSession -ConfigurationName microsoft.exchange -ConnectionUri $uri -Authentication Kerberos -Credential $Credentials
Import-PSSession $s -AllowClobber

Function GetMailboxSizeInGB($value)
{
    Try
    {
        return [math]::Round($value.Split("(")[1].Split(" ")[0].Replace(",","")/1GB, 3)
    }
    Catch
    {
        return 0
    }
}

Function GetAssignedOrDefaultSizeInGB($UseDefault, $DefaultValue, $AssignedValue)
{
    $result = $DefaultValue
    if($UseDefault -ne "True")
    {
        $result = GetMailboxSizeInGB $AssignedValue.ToString()
    }

    return $result
}

Function RemoveLastCommaFromString($InputString)
{
    If( ($InputString.Length -ge 2) -and ($InputString.Substring($InputString.Length - 2) -eq ", ") )
    {
        return $InputString.Substring(0, $InputString.Length - 2)
    }

    return $InputString
}

$DefaultWarningQuota = GetMailboxSizeInGB (Get-MailboxDatabase).IssueWarningQuota.ToString()
$MailBoxes = Get-Mailbox -ResultSize unlimited | Select-Object DisplayName, Identity, Alias, UseDatabaseQuotaDefaults, IssueWarningQuota, ProhibitSendQuota, ProhibitSendReceiveQuota
$InfoArray = @{}
Foreach ($entry in $MailBoxes)
{
    Try 
    {
        $InfoArray.Add(($entry.Identity),(@{
            "Alias" = ($entry.Alias)
            "DisplayName" = ($entry.DisplayName)
            "DefaultLimits" = ($entry.UseDatabaseQuotaDefaults)
            "WarningQuota" = (GetAssignedOrDefaultSizeInGB $entry.UseDatabaseQuotaDefaults $DefaultWarningQuota $entry.IssueWarningQuota)
            "TotalItemSizeGB" = (GetMailboxSizeInGB (Get-MailboxStatistics $entry.Identity).TotalItemSize.ToString())
        }))
    }
    Catch 
    { 
        continue 
    }  
}

$UsersHittingSizingLimit = ""
$Count = 0
Foreach($entry in $InfoArray.GetEnumerator())
{
    $WarningQuota = $entry.Value["WarningQuota"]
    $TriggerLimit = [math]::Round(($WarningQuota - $WarnBelowQuotaInGB), 3)
    $CurrentSize = $entry.Value["TotalItemSizeGB"]
    If ( ($WarningQuota -ne 0) -and ($CurrentSize -ge $TriggerLimit) )
    {
        $Count++
        $UsersHittingSizingLimit += $entry.Value["Alias"] + " (" + $entry.Value["DisplayName"] + ") [" + $CurrentSize + " GB / " + $WarningQuota + " GB], "
    }

}

$UsersHittingSizingLimit = RemoveLastCommaFromString($UsersHittingSizingLimit)
Remove-PSSession -Session $s

If ($Count -gt 0)
{
    Write-Host $Count":The following mailboxes are bigger than their Warning Quota - Limit Offset of "$WarnBelowQuotaInGB "GB [Current Size GB / Warning Quota GB]: "$UsersHittingSizingLimit
    exit 1
} 
else 
{
    Write-Host "0:No mailbox is bigger than its Warning Quota - Limit Offset of "$WarnBelowQuotaInGB "GB"
    exit 0    
}
