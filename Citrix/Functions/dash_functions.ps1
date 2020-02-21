## Dashboard Functions

##
# Quick function to get service status for single or list of services on any given computer
# call with a . (eg . Test-Services) to access the "$service_counter" variable
##
function Test-Services{
param([string[]]$services,[string]$computername)
    $service_counter = $null
    $service_count = ($services).Count
    foreach($service in $services){
    $service_test = Get-Service -ComputerName $computername -Name $service
    $service_display_name = $service_test.DisplayName
        if($service_test.Status -eq "Running"){
        Write-Host -ForegroundColor Green "$service_display_name okay!"
        $service_counter++
                    }
        else{
         Write-Host -ForegroundColor Red "$service_display_name down/server not contactable."
            }
               }
    $service_results = "$service_counter/$service_count"
    return $service_results
}

##
# Average CPU usage over 5 seconds reported as a percentage
##
function Check-CPU(){
	param ($hostname)
	Try { $CpuUsage=(get-counter -ComputerName $hostname -Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 5 -ErrorAction Stop | select -ExpandProperty countersamples | select -ExpandProperty cookedvalue | Measure-Object -Average).average
    	$CpuUsage = [math]::round($CpuUsage, 2); return $CpuUsage
	} Catch { "Error returned while checking the CPU usage. Perfmon Counters may be fault" }
}

##
# Report mem usage as a percentage
##
function Check-Memory(){
	param ($hostname)
    Try{$SystemInfo = (Get-WmiObject -computername $hostname -Class Win32_OperatingSystem -ErrorAction Stop | Select-Object TotalVisibleMemorySize, FreePhysicalMemory)
    	$TotalRAM = $SystemInfo.TotalVisibleMemorySize/1MB
    	$FreeRAM = $SystemInfo.FreePhysicalMemory/1MB
    	$UsedRAM = $TotalRAM - $FreeRAM
    	$RAMPercentUsed = ($UsedRAM / $TotalRAM) * 100
    	$RAMPercentUsed = [math]::round($RAMPercentUsed, 2);
    	return $RAMPercentUsed
	} Catch { "Error returned while checking the Memory usage. Perfmon Counters may be fault"
 }
}

##
# Check hard disk usage, provide drive letter for $deviceID
##
function Check-HardDiskUsage(){
	param ($hostname, $deviceID)
    Try
	{
    	$HardDisk = $null
		$HardDisk = Get-WmiObject Win32_LogicalDisk -ComputerName $hostname -Filter "DeviceID='$deviceID'" -ErrorAction Stop | Select-Object Size,FreeSpace
        if ($HardDisk -ne $null)
		{
		$DiskTotalSize = $HardDisk.Size
        $DiskFreeSpace = $HardDisk.FreeSpace
        $frSpace=[Math]::Round(($DiskFreeSpace/1073741824),2)
		$PercentageDS = (($DiskFreeSpace / $DiskTotalSize ) * 100); $PercentageDS = [math]::round($PercentageDS, 2)

		Add-Member -InputObject $HardDisk -MemberType NoteProperty -Name PercentageDS -Value $PercentageDS
		Add-Member -InputObject $HardDisk -MemberType NoteProperty -Name frSpace -Value $frSpace
		}

    	return $HardDisk
	} Catch { "Error returned while checking the Hard Disk usage. Perfmon Counters may be fault"}
}

###
# Write Service Desk Dashboard HTML Header
###
function Write-SDDashboardHeader(){
    $htmlheader = '
        <!DOCTYPE html>
            <html>
            <head>
            <style>
            .dot-green{
        height: 20px;
        width: 20px;
        background-color: #ABFF00;
        border-radius: 50%;
        display: inline-block;
        float: right;
        margin: 15px;
        box-shadow: rgba(0, 0, 0, 0.2) 0 -1px 7px 1px, inset #304701 0 -1px 9px, #89FF00 0 2px 12px;
      }
      .dot-red{
        height: 20px;
        width: 20px;
        background-color: #F00;
        border-radius: 50%;
        display: inline-block;
        float: right;
        margin: 15px;
        box-shadow: rgba(0, 0, 0, 0.2) 0 -1px 7px 1px, inset #441313 0 -1px 9px, rgba(255, 0, 0, 0.5) 0 2px 12px;
      }
            .content{
  padding: 40px;
}
.topbar{
  overflow: hidden;
  background-color: #0e86e8;
  box-shadow: 0px 2px 5px lightgrey;
}
.topbar a{
  float: left;
  display: block;
  color: white;
  text-align: center;
  padding: 14px 25px;
  text-decoration: none;
  font-size: 200%;
}
.wrapper {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr 1fr;
  grid-template-rows: 4;
  color: #444;
  grid-gap: 15px;
  padding: 5px;
  width: 75%;
}
.wrapper > div {
  background: rgb(255,255,255);
  background: linear-gradient(0deg, rgba(255,255,255,1) 0%, rgba(244,244,244,1) 100%);
  color: black;
  border: 2px solid lightgrey;
  text-align: center;
  font-size: 100%;
  border-radius: 2px;
  box-shadow: 3px 3px 3px lightgrey;
}
body {
  margin: 0px;
  background: rgb(255,255,255);
  background: linear-gradient(0deg, rgba(255,255,255,1) 0%, rgba(244,244,244,1) 100%);
  background-repeat: no-repeat;
  font-family: Tahoma, Geneva, sans-serif;
}
.header-background {
  overflow: hidden;
  border-bottom: inherit;
}
.header-text {
  font-size: 150%;
  float: left;
  display: block;
  text-align: left;
  margin: 10px;
  color: grey;
}
.box-text{
  text-align: left;
  padding: 10px;
  font-size: 140%;
}
html{
  height: 100%
}

            </style>
            <title>Citrix Dashboard</title>
            <meta content="300" http-equiv="refresh"/>
            </head>
    '
    $htmlheader
}
###
# Write Service Desk Dashboard HTML Body
###
function Write-SDDashboardBody(){
    $htmlbody = '
    <body>
        <div class="topbar">
            <a>Sentinel Citrix Status</a>
        </div>
    <div class="content">
    <div class="wrapper">
    '
    $htmlbody
}
###
# Write Service Desk Dashboard HTML End
###
function Write-SDDashboardEnd(){
    $htmlend = "
            </div>
  </div>
</body>
</html>
    "
    $htmlend
}
