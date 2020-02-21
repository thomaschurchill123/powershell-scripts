<#
	 .SYNOPSIS
			 Update all LXC containers.

	 .DESCRIPTION
			 This script queries LXC for a list of containers then updates each one with "apt update" and "apt ugrade".
       Only applicabple for Ubuntu based machines using apt.

	 .EXAMPLE
			 ./update_containers

	 .NOTES
      Version:        1.0
      Author:         Thomas Churchill
      Creation Date:  20/06/19
      Purpose/Change: Initial script development

#>
function Update-Containers {
#Parameters
param (
  [switch]$all, #When used will update all containers
  [string]$name #Specific container name
)
#Variables
$containers = ConvertFrom-Json -InputObject (lxc list --format json)

#Main script
If ($all){
  foreach ($c in $containers.name){
    Write-Host -ForegroundColor Yellow "Updating Container: $c"
    lxc exec $c apt-get -y update
    lxc exec $c apt-get -y upgrade
    lxc exec $c apt-get -y autoremove
  }
}Elseif ($name){
    lxc exec $name apt-get -y update
    lxc exec $name apt-get -y upgrade
    lxc exec $name apt-get -y autoremove
}Else {
  Write-Host -ForegroundColor Red "Please specificy the -all or -name parameter."
}
}
