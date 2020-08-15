 <#      
        .VERSION
            1.1

        .SYNOPSIS
            Retrieves ans outputs the stats of a go-e HOME+ charger in XML format.
            The available stats are shown in this screenshot:
            https://github.com/saxos1983/prtg/raw/master/go-e%20HOME%2B%20charger%20statistics/Screenshot.png

        .DESCRIPTION
            This script is intended to be used by a PRTG sensor of type 'EXE/Script Advanced'
            The script needs to be placed in the '<PRTG program directory>\Custom Sensors\EXEXML'
            folder to be available in PRTG.
        
        .AUTHOR
            Antoine Hauck
         
        .PARAMETER Token
            To access the API of the go-e charger, you need to provide the associated cloud token for the charger.
            The cloud token can be found on the RFID reset card.
            Please check the go-e HOME+ user manual for further information.
        .PARAMETER ShowAllChannels
            If this parameter is set, this additional data will be shown in the sensor output:
                - Current L1/L2/L3, Voltage L1/L2/L3/N, Power factor L1/L2/L3, Power L1/L2/L3/N, Firmware version
         
        .OUTPUT
            Shows the stats of the charger in XML format.
            Stats consist of charged energy, voltages, currents, error state, access control and much more.

        .LINK
            go-e charger user manual: https://go-e.co/operating-instructions-manual-en-go-echarger-home-11_22-kw/?lang=en
            go-e charger API documentation: https://github.com/goecharger/go-eCharger-API-v1
            PRTG Manual EXE/Script Advanced sensor: https://www.paessler.com/manuals/prtg/exe_script_advanced_sensor

        .EXAMPLE
            .\go-e_charger_stats.ps1 -Token '123456ABCD' [-ShowAllChannels]
#>
param(
	[string]$Token,
    [switch]$ShowAllChannels
)

$CloudUrl = "https://api.go-e.co/api_status?token=$Token"

function Write-Channel {
	Param(
        [parameter(Mandatory=$true)]
		$ChannelName,
        [parameter(Mandatory=$true)]
		$Value,
        [String]
        $CustomUnit,
        [String]
        $ValueLookup,
        [switch]
        $Float
	)

    Write-Host "<result>"
    Write-Host "<channel>$ChannelName</channel>"
    Write-Host "<value>$Value</value>"
    if($CustomUnit)
    {
        Write-Host "<CustomUnit>$CustomUnit</CustomUnit>"
    }
    if($ValueLookup)
    {
        Write-Host "<ValueLookup>$ValueLookup</ValueLookup>"
    }
    if($Float)
    {
        Write-Host "<float>1</float>"
    }
    Write-Host "</result>"
}

function Write-Error {
    Param(
        [parameter(Mandatory=$true)]
		$ErrorText
    )
    Write-Output "<prtg>"
	Write-Output "<error>1</error>"
	Write-Output "<text>$ErrorText</text>"
	Write-Output "</prtg>"
	Exit
}

if (!$Token)
{
    Write-Error "No token parameter provided."
}

if ($PSVersionTable.PSVersion.Major -lt 3) {
	Write-Error "Powershell Version is $($PSVersionTable.PSVersion.Major). Script requires at least Version 3."
}

try {
    $result = Invoke-RestMethod -Uri $CloudUrl -ContentType "application/json; charset=utf-8" -SessionVariable myWebSession
}catch{
    #$_.Exception | Format-List -Force
	Write-Output "<prtg>"
	Write-Output "<error>1</error>"
	Write-Output "<text>Error while obtaining API Result: $($_.Exception.Message)</text>"
	Write-Output "</prtg>"
	Exit
}

if(!$result -or !$result.success)
{
    $errorText = "Result not successful!"
    if($result.error)
    {
        $errorText += " Error: " + $result.error
    }
    Write-Error $errorText
}

$data = $result.data
# dws is in Deca-Watt seconds
$kWhChargedForSession = $($data.dws / 360000)
[Int]$AgeOfCloudUpdate = $($result.age / 1000)

# Write Results
Write-Host "<?xml version=`"1.0`" encoding=`"UTF-8`" ?>"
Write-Host "<prtg>"
Write-Channel "PWM vehicle state" $data.car -ValueLookup "go-e.apistatus.pwm.signaling"
Write-Channel "Charge access control" $data.ast -ValueLookup "go-e.apistatus.access.control"
Write-Channel "Allow charging" $data.alw -ValueLookup "go-e.apistatus.yesno"
Write-Channel "Last successful upload" $AgeOfCloudUpdate "secs"
Write-Channel "Charged energy for session" $([math]::Round($kWhChargedForSession,2)) "kWh" -Float
Write-Channel "Total charged energy" $($data.eto / 10) "kWh"
Write-Channel "Error" $data.err -ValueLookup "go-e.apistatus.error"
Write-Channel "Configured max. current" $data.amp "A"
Write-Channel "Cable max. current" $data.cbl "A"
if($ShowAllChannels)
{
    Write-Channel "Current L1" $($data.nrg[4] / 10) "A" -Float
    Write-Channel "Current L2" $($data.nrg[5] / 10) "A" -Float
    Write-Channel "Current L3" $($data.nrg[6] / 10) "A" -Float
    Write-Channel "Voltage L1" $data.nrg[0] "V"
    Write-Channel "Voltage L2" $data.nrg[1] "V"
    Write-Channel "Voltage L3" $data.nrg[2] "V"
    Write-Channel "Voltage N" $data.nrg[3] "V"
    Write-Channel "Power factor L1" $data.nrg[12] "%"
    Write-Channel "Power factor L2" $data.nrg[13] "%"
    Write-Channel "Power factor L3" $data.nrg[14] "%"
    Write-Channel "Power factor N" $data.nrg[15] "%"
    Write-Channel "Power L1" $($data.nrg[7] / 10) "kW" -Float
    Write-Channel "Power L2" $($data.nrg[8] / 10) "kW" -Float
    Write-Channel "Power L3" $($data.nrg[9] / 10) "kW" -Float
    Write-Channel "Power N" $($data.nrg[10] / 10) "kW" -Float
}
Write-Channel "Power total" $($data.nrg[11] / 100) "kW" -Float
Write-Channel "Controller temperature" $data.tmp "&#176;C"
Write-Channel "Cable lock mode" $data.ust -ValueLookup "go-e.apistatus.cable.lockmode"
if($ShowAllChannels)
{
    Write-Channel "Firmware version" $data.fwv
}
Write-Channel "Firmware update available" $data.upd -ValueLookup "prtg.standardlookups.boolean.statefalseok"
Write-Host "</prtg>"