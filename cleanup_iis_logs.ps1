<#
	 .SYNOPSIS
			 Automate clean up of iis logs.

	 .DESCRIPTION
			 Over time the logs in "C:\inetpub\logs\LogFiles\W3SVC1" can fill up local storage.
       This script removes the logs older than 90 days and should be set to a schedule.

	 .EXAMPLE
			 Call script from command line with ./cleanup_iis_logs.ps1

	 .LINK
			 Links to further documentation

	 .NOTES
	 		 Version:        1.0
			 Author:         Thomas Churchill
			 Creation Date:  18/03/19
			 Purpose/Change: Initial script development
#>

# Variables
$date_range = (Get-Date).AddDays(-90)
$path = "C:\inetpub\logs\LogFiles\W3SVC1"

# Main Script

Get-ChildItem -Path $path | where {$_.LastWriteTime -lt $date_range} | Remove-Item -Verbose
