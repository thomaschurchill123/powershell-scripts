<#
	 .SYNOPSIS
			 Running Citrix report on total connected users.

	 .DESCRIPTION
			 This script collects data on current connected Citrix sessions on a per delivery group basis.
       These numbers are logged in a separate CSV for reporting purposes and are
       also written to a HTML file for monitoring. Furthermore, the total servers per-delivery
       group are also listed with a quick capacity check against the largest number of concurrent
       connections at 25 users per server. This is highlighted on the resulting dashboard.

	 .EXAMPLE
			 ./citrix_connection_report.ps1

	 .NOTES
      Version:        3.0
      Author:         Thomas Churchill
      Creation Date:  04/01/19
      Purpose/Change: Rewrote script to generate HTML  file on foreach loop from customer list.
                      This means that script does not need to be adjusted around customer changes.

#>

# Load citrix snap-ins
if ((gsnp "Citrix.*" -EA silentlycontinue) -eq $null) {
try { asnp Citrix.* -ErrorAction Stop }
catch { write-error "Error Get Citrix.* Powershell snapin"; Return }
}
#Functions
    #Get total number of servers in a given delivery group.
        function Get-DGTotalServers{
            param([string]$DGID,[string]$DCName)
            Get-BrokerMachine -AdminAddress $DCName | Where-Object {$_.DesktopGroupUid -eq "$DGID"}
        }
    #Get total number of connected session in a given delivery group.
        function Get-DGTotalUsers{
            param([string]$DGID,[string]$DCName)
            (Get-BrokerSession -AdminAddress $DCName -MaxRecordCount 2000 -DesktopGroupUid $DGID).count
        }
#Variables
    #Reporting Dates
        $ReportDate = (Get-Date -UFormat "%A, %d %B %Y %R")
        $ExcelDate = (Get-Date -Format "dd/MM/yyyy HH:mm")
    #HTML Output Path
        $HTMPath = "path/to/HTML"

    #CSV Output path
        $CSVPath = "path/to/CSV"

    #HTML File Name
        $fileName = "Citrix_User_Totals.html"
    #HTML Title
        $title ="Citrix User Connection Totals"
    #Import customer matrix
        $CustomerMatrix = Import-Csv -Path 'path/to/customer/list.csv'
    #Date Range
        $DateRange = (get-date).AddDays(-5).ToString("dd/MM/yyyy HH:mm")
    #Total Customer Count
    $total_customer_count = 0
    #Total Server Count
    $total_server_count = 0

#Gather data.
    #Total user count per delivery group.
    $Data = foreach($cust in $CustomerMatrix){
        $customername = $cust.customer
        $connectedusers = Get-DGTotalUsers -DGID $cust.DeliveryGroupID -DCName $cust.DeliveryController
        [PSCustomObject]@{
            Date = $ExcelDate
            Customer = $customername
            Users = $connectedusers}
        }
    #Gather capacity planning data.
    $CSVImport = Import-Csv -Path $CSVPath | Where-Object {$_.Date -gt $DateRange}
    $CapacityData = foreach($cust1 in $CustomerMatrix){
        $customername1 = $cust1.customer
        $DGServerTotal = (Get-DGTotalServers -DGID $cust1.DeliveryGroupID -DCName $cust1.DeliveryController).count
        $Maximum = $CSVImport.$customername1 | Measure-Object -Maximum | Select-Object Maximum -ExpandProperty Maximum
        $ProjectedServers = (($Maximum / 25)+1)
        [PSCustomObject]@{
            Customer = $customername1
            MaxUsers = $Maximum
            CurrentServers = $DGServerTotal
            ProjectedServers = [math]::Ceiling($ProjectedServers)}
        }
#CSV Export for historic data.
    $CSVExport = New-Object psobject -Property @{}
    $CSVExport | Add-Member -MemberType NoteProperty -Name Date -Value $ExcelDate
        foreach ($D in $Data){
            $CSVExport | Add-Member -MemberType NoteProperty -Name $D.Customer -Value $D.Users}
    $CSVExport | Export-Csv $CSVPath -NoClobber -nti -Append
#HTML Generation
    $Header = @"
<html>
<head>
<meta http-equiv='Content-Type' content='text/html; charset=iso-8859-1'>
<meta http-equiv='refresh' content='300'>
<title>$title</title>
<STYLE TYPE='text/css'>
<!--
body {margin-left: 5px;margin-top: 5px;margin-right: 0px;margin-bottom: 10px;}
table{table-layout:fixed;}
td{font-family: Tahoma;font-size: 38px; text-shadow: 2px 2px #000; border-width: 1px; padding: 0px; border-style: solid; border-color: #999; background-color: #3333ff;overflow: hidden;}
td.main{border-width: 1px; padding: 0px; border-style: double; border-color: #999; background: #ffffff url("image1.png") no-repeat;  background-size: 100% 100%; overflow: hidden;}
td.Red{font-family: Tahoma;font-size: 38px; text-shadow: 2px 2px #000; border-width: 1px; padding: 0px; border-style: solid; border-color: #999; background-color: #ff3300;overflow: hidden;}
td.Blue{font-family: Tahoma;font-size: 38px; text-shadow: 2px 2px #000; border-width: 1px; padding: 0px; border-style: solid; border-color: #999; background-color: #3333ff;overflow: hidden;}
td.Green{font-family: Tahoma;font-size: 38px; text-shadow: 2px 2px #000; border-width: 1px; padding: 0px; border-style: solid; border-color: #999; background-color: #33cc33;overflow: hidden;}
td.Total{font-family: Tahoma;font-size: 38px; text-shadow: 2px 2px #000; border-width: 1px; padding: 0px; border-style: solid; border-color: #999; background-color: #0FB6DA;overflow: hidden;}
-->
</style>
</head>
"@
    $Body = @"
    <table height=100% align=center>
    <tr>
    <td class='main'>
    <table width=90% align=center>
	    <tr bgcolor='#CCCCCC'>
		    <td colspan='7' height='68' align='center' valign='middle'>
			    <font face='tahoma' color='#e1e1ea' size='6'><strong>$title - $ReportDate</strong></font>
		    </td>
	    </tr>
    </table>
    <table width=90% align=center>
	    <tr bgcolor='#CCCCCC'>
"@
    foreach ($D0 in $Data){
        $N = $D0.Customer
        $NShort = $N.Substring(0, [System.Math]::Min(5, $N.Length))
        $Body += "<td align=center>
			    <font face='tahoma' color='#e1e1ea' size='6'><strong> $NShort </strong></font>
		    </td>"  }
    $Body += "<td align=center class='Total'>
			    <font face='tahoma' color='#e1e1ea' size='6'><strong> Total </strong></font>
		    </td>"
    $Body += "</tr>
    <tr bgcolor='#CCCCCC'>"
    foreach ($D1 in $Data){
        $UsersCount = $D1.Users
        $total_customer_count += $UsersCount
        $Body += "<td align=center>
    		    <font face='tahoma' color='#e1e1ea' size='6'><strong> $UsersCount </strong></font>
		    </td>"}
$Body += "<td align=center class='Total'>
			    <font face='tahoma' color='#e1e1ea' size='6'><strong> $total_customer_count </strong></font>
		    </td>"
    $Body += "	    </tr>
    </table>
    <table width=90% align=center>
	    <tr bgcolor='#CCCCCC'>
		    <td colspan='7' height='55' align='center' valign='middle'>
			    <font face='tahoma' color='#e1e1ea' size='6'><strong>Total Server Count per Customer</strong></font>
		    </td>
	    </tr>
    </table>
    <table width=90% align=center>
        <tr bgcolor='#CCCCCC'>
    "

    foreach ($D3 in $CapacityData){
    $CurrentServers = $D3.CurrentServers
    $total_server_count += $CurrentServers
        if ($D3.CurrentServers -lt $D3.ProjectedServers){
            $Body += "<td align=center class='Red'>
    		    <font face='tahoma' color='#e1e1ea' size='6'><strong> $CurrentServers </strong></font>
		    </td>"}
            elseif ($D3.CurrentServers -eq $D3.ProjectedServers){
                $Body += "<td align=center class='Blue'>
    		    <font face='tahoma' color='#e1e1ea' size='6'><strong> $CurrentServers </strong></font>
		    </td>"}
                elseif ($D3.CurrentServers -gt $D3.ProjectedServers){
                    $Body += "<td align=center class='Blue'>
    		    <font face='tahoma' color='#e1e1ea' size='6'><strong> $CurrentServers </strong></font>
		    </td>"}
}
$Body += "<td align=center class='Total'>
    		    <font face='tahoma' color='#e1e1ea' size='6'><strong> $total_server_count </strong></font>
		    </td>"


    $Body += "
                </tr>
            </table>
    </td>
    </tr>
</table>
</body>
</html>"
    $Header + $Body | Out-File -FilePath $HTMPath
