 <#      
        .VERSION
            1.0

        .SYNOPSIS
            Retrieves and outputs all channels of a opensense box.

        .DESCRIPTION
            This script is intended to be used by a PRTG sensor of type 'EXE/Script Advanced'
            The script needs to be placed in the '<PRTG program directory>\Custom Sensors\EXEXML'
            folder to be available in PRTG.
        
        .AUTHOR
            Antoine Hauck
         
        .PARAMETER SenseBoxId
            To access the API of the sensebox you need to register the box and obtain an sense box ID.
            Provide this ID in this parameter.
                     
        .OUTPUT
            Shows the stats of all retrieved environment channels
            For example the rel. humidity, Particulate Matter, temperature etc.

        .LINK
            Register a sensebox: https://opensensemap.org/register
            API Documentation: https://docs.opensensemap.org
            PRTG Manual EXE/Script Advanced sensor: https://www.paessler.com/manuals/prtg/exe_script_advanced_sensor

        .EXAMPLE
            .\sensebox_stats.ps1 -SenseBoxId '5f3d88bc17b6c5001b1750dd'
#>
param(
	[string]$SenseBoxId
)

Add-Type -AssemblyName System.Web
$CloudUrl = "https://api.opensensemap.org/boxes/$SenseBoxId"

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

function Write-TimeSecondsChannel {
	Param(
        [parameter(Mandatory=$true)]
		$ChannelName,
        [parameter(Mandatory=$true)]
		$Value
	)

    Write-Host "<result>"
    Write-Host "<channel>$ChannelName</channel>"
    Write-Host "<value>$Value</value>"
    Write-Host "<Unit>TimeSeconds</Unit>"
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

if (!$SenseBoxId)
{
    Write-Error "No SenseBoxId parameter provided."
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

if(!$result)
{
    $errorText = "Result not successful!"
    Write-Error $errorText
}

Write-Host "<?xml version=`"1.0`" encoding=`"UTF-8`" ?>"
Write-Host "<prtg>"
$LastUpdate=[datetime]::parseexact($result.updatedAt, 'yyyy-MM-ddTHH:mm:ss.fffZ',$null)
$TimeDiff = $(Get-Date) - $LastUpdate
Write-TimeSecondsChannel "Last Update" $([int]$TimeDiff.TotalSeconds)

# Write Results
foreach ($sensor in $result.sensors)
{
    $EncodedUnit = [System.Web.HttpUtility]::HtmlEncode($sensor.unit)
    Write-Channel $sensor.title $sensor.lastMeasurement.value $EncodedUnit -Float
}
Write-Host "</prtg>"