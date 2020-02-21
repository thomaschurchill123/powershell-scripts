<#

function to get high CPU processes and their asociated users.

#>

function Get-UserCPU {
    param([string]$ComputerName)
    $processes = Get-WmiObject Win32_PerfFormattedData_PerfProc_Process -Filter "idProcess != 0" -ComputerName $computername | sort PercentProcessorTime -Descending | select Name,PercentProcessorTime,idProcess -first 10
    $s = {Get-Process -Id $args[0] -IncludeUserName | select Username -ExpandProperty Username }
    $out_obj = foreach ($p in $processes) {
    [pscustomobject]@{
        Name = $p.Name
        "CPU Usage (%)" = $p.PercentProcessorTime
        "Process ID"  = $p.idProcess
        "User" = Invoke-Command -ScriptBlock $s -ComputerName $computername -ArgumentList $p.idProcess
        } # End custom object
    } # End foreach loop
    $out_obj | ft -AutoSize
} # End of function
