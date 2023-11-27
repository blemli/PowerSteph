#author: Stephan Graf
#date: 2021-05-28
#Inspiration: https://devblogs.microsoft.com/scripting/use-powershell-to-get-the-number-of-the-week-of-the-year/
#https://stackoverflow.com/a/61960610/8035636
#beware that Week 53 is possible since a year actually has 52.14 Weeks!
#todo: -toint()

function Get-Week(){
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]$date=(get-date),
        [Parameter()]$cultureName="de-CH"
    )
    $midnight=get-date -hour 0 -minute 0 -second 0 -Millisecond 000
    $monday=$midnight.AddDays(1 - $date.DayOfWeek.value__)
    $sunday=(get-date $monday -hour 23 -Minute 59 -Second 59 -Millisecond 999).AddDays(6)
    if((get-host).version.Major -lt 7){
        $culture=get-culture
	Write-Warning "Cannot get culture '$cultureName'. Please upgrade to powershell7. Continuing with $culture."
	# warning, if system is different culture than de-CH it will give wrong number!
    }else{
        $culture=get-culture -name $cultureName
    }
    Write-Verbose "Culture: $culture"
    $number= "{0:d1}" -f ($culture.Calendar.GetWeekOfYear($date,[System.Globalization.CalendarWeekRule]::FirstFourDayWeek, [DayOfWeek]::Monday))
    $week=[PSCustomObject]@{
        PSTypeName="Week"
        number=[Int32]$number
        start=$monday
        end=$sunday
    }
    Update-TypeData -TypeName "Week" -DefaultDisplayPropertySet "number" -force
    return $week
}

function Step-Week{
    [CmdletBinding()]
    param(
    [Parameter(ValueFromPipeline)]$date=(get-date)
    )
    return get-week -Date $date.AddDays(7)
}