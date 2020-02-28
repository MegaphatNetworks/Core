<#
	enum_LoggedOnUsers
	by Gabriel Polmar (gpolmar@megaphat.net), Megaphat Networks (https://www.megaphat.net)

	Purpose:
	Enumerate all logged on users on all computers within a AD domain.

	Remarks:
	Yes I know I could have done better with the object array portion but I was in a rush.
	I tried to use the following:
		Get-WmiObject -Class win32_computersystem -ComputerName $computername
	but I kept getting an error that the RPC server is unavailable
		
	So then I tried:	
		$Credentials = New-Object System.Management.Automation.PSCredential ('ADName\AdminName', 'AdminPassword')
		$Session = New-PSSession -ComputerName $ComputerName -credential $Credentials
		$Result = Invoke-Command -Session $Session -ScriptBlock {quser | select -skip 1} 
	But for some reason When trying to assign the $Session value (not even getting to $Result) I get the error:
		WinRM cannot complete the operation. Verify that the specified computer name is valid, that the computer is accessible
		over the network, and that a firewall exception for the WinRM service is enabled and allows access from this computer.
	even when WinRM is configured and running.  So I decided to use SysInternals PSExec only if quser returned no results due to permissions.

	So here is the output of quser format (after skipping the first 5 from psexec and 1 from quser)	
	0         1         2         3         4         5         6         7         8
	0123456789012345678901234567890123456789012345678901234567890123456789012345678901234
	 user1                                     4  Disc        13:11  2/26/2020 9:41 AM
	 user2                 console             6  Active      none   2/27/2020 8:56 AM
	 
	 
	 Name:    1,19
	 Method: 23,7
	 SID:    43,2
	 State:  46,6
	 Idle:   55,8
	 Date:   65,9
	 Time:   75,7
	 
	$oCU =@(
		[pscustomobject]@{UID="";Method="";SID="";State="";Idle="";Date="";Time=""},
		[pscustomobject]@{UID="";Method='';SID="";State="";Idle="";Date="";Time=""}
		)
	So I used a loop to build the array for the PSCustomObject then cleaned it up.  
	All in all the script is a bit slow because of the psexec but effective.

#>

function enumUsers ($ThisComputer) {
	$ThisComputer
	$pse = (quser /server:$ThisComputer | select -skip 1) | out-string
	if ($pse.trim().length -eq 0) {
		write-host "Retrying quser with PSExec"
		$pse = (.\psexec \\$ThisComputer quser | select -skip 6) | out-string
	}
	Start-Sleep 1
	if ($pse.trim().length -ne 0) {
		$lines = $pse.Split("`n")
		$sTemp =$null
		for ($i=0;$i -le ($lines.count-1);$i++) {
			if (!($lines[$i].length -lt 80)) {
				$sTemp = $sTemp + "[pscustomobject]@{UID='" + $lines[$i].subString(1,19).Trim() + "';"
				$sTemp = $sTemp + "Method='" + $lines[$i].subString(23,7).Trim() + "';"
				$sTemp = $sTemp + "SID='" + $lines[$i].subString(42,3).Trim() + "';"
				$sTemp = $sTemp + "State='" + $lines[$i].subString(46,6).Trim() + "';"
				$sTemp = $sTemp + "Idle='" + $lines[$i].subString(55,8).Trim() +"';"
				$sTemp = $sTemp + "Date='" + $lines[$i].subString(65,9).Trim() +"';"
				$sTemp = $sTemp + "Time='" + $lines[$i].subString(75,7).Trim() +"'}"
			}
		}
		$oCU =$null
		if ($sTemp.length -ne 0) {
			$sTemp = $sTemp.Replace("}[","},[")
			$inx = '$oCU = @(' + $sTemp + ')'
			Invoke-Expression $inx
			
			$oCU | ft
		}
		write-host ""
	}
}

Write-Progress -Activity "Retrieving Domain Computers" -Status "..."
$AllComputers = (Get-ADComputer -Filter * -Properties operatingsystem | sort name).Name	
$CompArray = $AllComputers.Split("`n")
$cnt = 0
foreach ($TComputer in $CompArray) {
	$cnt++
	If (test-connection -computername $TComputer -count 1 -quiet){
		$act = "Retrieving users for " + $TComputer
		$stat = ($cnt).ToString() +  "/" + ($CompArray.Count).ToString()
		Write-Progress -Activity $act -Status $stat
		enumUsers $TComputer
	}
}
	
