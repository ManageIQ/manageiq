class VdiCitrixInventory
  def self.inv_event_watcher_script(interval)
<<-PS_SCRIPT
param($event_folder, $miq_log_dir=$null)

function logger($msg, $level="INFO ") {
  $miq_logger_date = Get-Date
  if ($miq_log_dir -ne $null) {
    Set-Content (Join-Path $miq_log_dir "$($PID)_$($miq_logger_date.ToFileTime()).log") "$($level[0]), [$($miq_logger_date.GetDateTimeFormats()[114]) \#$($pid)]  $($level) -- : $($msg)"
  }

  "[----] $($level[0]), [$($miq_logger_date.GetDateTimeFormats()[114]) $($pid)]  $($level) -- : $($msg)" | Write-Host
}

function load_citrix_plugin($raise_error = $true, $log_result = $true) {
  $plugin_version = $null

  $requested_plugins = @("XDCommands", "Citrix.Broker.Admin.V1", "Citrix.Host.Admin.V1")
  foreach ($plugin in $requested_plugins) {if ((Get-PSSnapin -Name $plugin -ErrorAction SilentlyContinue) -eq $null) {Add-PSSnapin $plugin -ErrorAction SilentlyContinue}}

  if ((Get-PSSnapin     -Name "Citrix.Broker.Admin.V1" -ErrorAction SilentlyContinue) -ne $null) {$plugin_version = 5}
  elseif ((Get-PSSnapin -Name "XDCommands"             -ErrorAction SilentlyContinue) -ne $null) {$plugin_version = 4}

  if ($plugin_version -eq $null -and $raise_error -eq $true) {throw "No Citrix plug-in found"}
  if ($log_result) {
    if ($plugin_version -eq $null) {logger "warn" "Citrix XenDesktop plugin not found"}
    else                           {logger "info" "Citrix XenDesktop version $($plugin_version) plugin found"}
  }

  return $plugin_version
}

function to_obj($object, $to_string_names = @(), $skip_names = @()) {
	$result = $null
	if   ($object -is [System.Array]) {$result = @(); $object | ForEach-Object {$result += to_obj $_}}
	else {$result = New-Object Object; $object | Get-Member -MemberType Property | ForEach-Object {
		if ($to_string_names -contains $_.name) { Add-Member -InputObject $result -MemberType NoteProperty -Name $_.name -Value $object.$($_.name).ToString() }
		elseif ($skip_names -contains $_.name)  {} #Write-Host "Skipping Property <$($_.name)> with value <$($object.$($_.name))>"
		else {Add-Member -InputObject $result -MemberType NoteProperty -Name $_.name -Value $object.$($_.name)}
		}
	}
	return ,$result
}

function get_session($plugin_version, $farm) {
  $sess = $null
  if ($plugin_version -eq 4) {$sess = Get-XdSession -AdminConnection $farm -SessionDetails}
  else {$sess = Get-BrokerSession}
  return ,$sess
}

function display_sessions($sess, $plugin_version) {
  if ($plugin_version -eq 4) { $sess | ft DesktopName,State,StartTime }
  else                       { $sess | ft DesktopUid,SessionState,StartTime }
}

function session_polling($farm, $event_folder, $plugin_version) {
	$sess_old = get_session $plugin_version $farm
	logger "Session States initialized"
	# $sess_old | ft DesktopName,State,StartTime
	display_sessions $sess_old $plugin_version
	$sess_new = $null
	logger "Using event folder: <$event_folder>"
	logger "Watching for events..."

	$shouldProcess = $true
	while ($shouldProcess) {
    Start-Sleep #{interval}
	 	# logger "Checking for events"
		$sess_new = get_session $plugin_version $farm
		$diff = session_diff $sess_old $sess_new $plugin_version
		# Determine if there were any changes
		if (($diff["add"].Count -gt 0) -or ($diff["delete"].Count -gt 0) -or ($diff["update"].Count -gt 0)) {
			# $diff | ft
			generate_events $diff $farm $event_folder $plugin_version
		}
		$sess_old = $sess_new
	}
}

function sessions_watcher($farm, $event_folder) {
	$counter = 0
	$timespan = New-Object System.TimeSpan(0, 0, 10)
	$scope = New-Object System.Management.ManagementScope("\\.\root\cimV2")
	$query = New-Object System.Management.WQLEventQuery `
		("__InstanceCreationEvent",$timespan, "TargetInstance ISA 'Win32_NTLogEvent' and TargetInstance.LogFile = 'security' and (TargetInstance.EventIdentifier = '538' or TargetInstance.EventIdentifier = '540')")

	$sess_old = Get-XdSession -AdminConnection $farm
	logger "Initial Session States"
	$sess_old | ft DesktopName,State,StartTime
	$sess_new = $null

	# Start Event Watcher
	$watcher = New-Object System.Management.ManagementEventWatcher($scope, $query)
	logger "Watcher connected"
	do {
		$watcher_Result = $watcher.WaitForNextEvent()
		$target=$watcher_result.TargetInstance
		$machineName=$target.InsertionStrings[0]
		$domainName=$target.InsertionStrings[1]
		logger "NTEvent: $($target.TimeGenerated) $($target.EventIdentifier):$($target.CategoryString)  Machine: $machineName  ($domainName)"

		$sess_new = Get-XdSession -AdminConnection $farm
		$diff = session_diff $sess_old $sess_new
		# Determine if there were any changes
		if (($diff["add"].Count -gt 0) -or ($diff["delete"].Count -gt 0) -or ($diff["update"].Count -gt 0)) {
			# $diff | ft
			generate_events $diff $farm $event_folder
		}
		$sess_old = $sess_new

	} while ($counter -ne 1)
}

function session_to_hash($sessions, $plugin_version) {
  $result = @{};
  if ($plugin_version -eq 4) { foreach ($s in $sessions) {$result["$($s.StartTime)-$($s.DesktopName)"] = $s}; }
  else                       { foreach ($s in $sessions) {$result["$($s.StartTime)-$($s.DesktopUid)"] = $s}; }
	return ,$result
}

function is_session_same($old, $new, $plugin_version) {
  if ($plugin_version -eq 4) {
  	if ($old.State -eq $new.State) {return $true}
  	logger "$($old.DesktopName) - Updated State: $($old.State) -> $($new.State)"
  }
  else {
  	if (($old.SessionState -eq $new.SessionState) -and (($old.UserName -eq $new.UserName))) {return $true}
  	logger "$($old.DesktopUid) - Updated State: $($old.SessionState) -> $($new.SessionState)"
  }
	return $false
}

function session_diff($sess_old, $sess_new, $plugin_version) {
	$result = @{"add"=@(); "delete"=@(); "update"=@(); "same"=@()}
	$old = session_to_hash $sess_old $plugin_version
	$new = session_to_hash $sess_new $plugin_version

	foreach ($key in $new.keys) {
		if ($old.ContainsKey($key)) {
			$x = $old[$key]
			$old.Remove($key)
			$s = $new[$key]
			if (is_session_same $x $new[$key] $plugin_version) {
				$result["same"] += $s
			}
			else {
				$result["update"] += $s
			}
		}
		else {
			$s = $new[$key]
      if ($s -ne $null) {
        if ($plugin_version -eq 4) { logger "$($s.DesktopName) - New State: $($s.State)" }
        else                       { logger "$($s.DesktopUid) - New State: $($s.SessionState)" }
  			$result["add"] += $s
      }
		}
	}
	foreach ($key in $old.keys) {
		$s = $old[$key]
		if ($s -ne $null) {
			if ($plugin_version -eq 4) { logger "$($s.DesktopName) - Deleted State: $($s.State) -> LoggedOff" }
			else                       { logger "$($s.DesktopUid) - Deleted State: $($s.SessionState) -> LoggedOff" }
			$result["delete"] += $s
		}
	}
	return ,$result
}

function get_uid_ems($session, $farm, $plugin_version) {
	$uid_ems = $null
  $desktop = $null

  if ($plugin_version -eq 4) {
  	$desktops = $null
  	try {
  		$desktops = Get-XdVirtualDesktop -AdminConnection $farm -HostingDetails -Group $session.GroupId
  	}
  	catch {
  		foreach ($dsk_group in Get-XdDesktopGroup) {
  		  if ($dsk_group.Id -eq $session.GroupId) {
  		  	$group = Get-XdDesktopGroup -Name $dsk_group.Name -AdminConnection $farm -HostingDetails
  			if ($group -ne $null) {	$desktops = $group.Desktops }
  		  }
  		}
  	}
  	$desktops | foreach { if ($_.Name -eq $session.DesktopName) { $uid_ems = $_.HostingId; $desktop = $_ }	}
  }
  else
  {
    $desktop = Get-BrokerDesktop -Uid $session.DesktopUid
    if ($desktop -ne $null) { $uid_ems = $desktop.HostedMachineId }
  }
	return $uid_ems, $desktop
}

function get_session_details($session, $farm, $plugin_version) {
  $result = $null
  if ($plugin_version -eq 4) {
    # Note: Testing in large environment has shown that the '-User' switch adds a long time to the Get-XdSession call.
    #       For now the get_session function is requesting -SessionDetails so there is no reason to perform the lookup here.
    # Get-XdSession -AdminConnection $farm -SessionDetails -Group $session.GroupId | where {$_.UserName -eq $session.UserName -and $_.StartTime -eq $session.StartTime} | foreach {
    #  $result = $_
    # }
    $result = $session
  }
  else { $result = $session }
  return ,$result
}

function generate_events($diff, $farm, $event_folder, $plugin_version) {
	foreach ($sess in $diff["add"])    { generate_event $null $sess $farm $event_folder $plugin_version}
	foreach ($sess in $diff["delete"]) { generate_event $sess $null $farm $event_folder $plugin_version}
	foreach ($sess in $diff["update"]) { generate_event $sess $sess $farm $event_folder $plugin_version}
}

function generate_event($old, $new, $farm, $event_folder, $plugin_version) {
	$sess  = $new
	$event = $null

	if ($new -eq $null) {
		# Logoff Event
		$sess = $old
		$event = "VdiLogoffSessionEvent"
	}
	else {
    if ($plugin_version -eq 4) {
      $connected_states    = @("Connected", "Active", "NonBrokeredSession")
      $connecting_states   = @("Connecting", "PreparingSession")
    }
    else {
      # In v5 the 'connected' state is before login is complete.  'Active' is the logged in state.
      $connected_states    = @("Active", "NonBrokeredSession")
      $connecting_states   = @("PreparingSession", "Connecting", "Connected")
    }

    $disconnected_states = @("Disconnected")

    $session_state = ""
    if ($plugin_version -eq 4) {$session_state = $sess.State} else {$session_state = $sess.SessionState}

		# Status Update Event
		if ($connected_states -icontains $session_state) 		   {$event = "VdiLoginSessionEvent"		         }
		elseif ($connecting_states -icontains $session_state)  {$event = "VdiConnectingSessionEvent"	     }
		elseif ($disconnected_states -contains $session_state) {$event = "VdiDisconnectedSessionEvent"	   }
		else   									                               {$event = "Vdi$($session_state)SessionEvent"}
	}
	sendEvent $event $sess $farm $event_folder $plugin_version
}

function sendEvent($event_type, $session, $farm, $event_folder, $plugin_version) {
  $vm_uid_ems, $desktop = get_uid_ems $session $farm $plugin_version

	# Cut event record
  if ($vm_uid_ems -ne $null)
  {
    $desktop_name = if ($plugin_version -eq 4) {$session.DesktopName}
                    else {if ($desktop -ne $null) {$desktop.HostedMachineName} else {$session.DesktopUid}}
		logger "Processing event <$event_type> for <$($session.Username)> on <$($desktop_name)> with vm_uid_ems: <$vm_uid_ems>"

		# If login event get session details so we can report endpoint device information
		if ($event_type -eq "VdiLoginSessionEvent")
    {
			$session_details = get_session_details $session $farm $plugin_version
			if ($session_details -ne $null) { $session = $session_details }
		}

		# Convert some objects to string format if they cause the conversion to XML to fail

    $event_session = if ($plugin_version -eq 4) {to_obj $session @("UserSid", "DesktopSid")} else {to_obj $session}
    # Duplicate v5 fields to look like v4
    if ($plugin_version -ne 4)
    {
      if ($desktop -ne $null)
      {
        Add-Member -InputObject $event_session -MemberType NoteProperty -Name "DesktopName" -Value $desktop.HostedMachineName
        $desktop_pool = Get-BrokerDesktopGroup -Uid $desktop.DesktopGroupUid
        if ($desktop_pool -ne $null)
        {
          Add-Member -InputObject $event_session -MemberType NoteProperty -Name "pool_id" -Value $desktop_pool.UUID
        }
      }
    }
    # $event_session | fl *
		$event = @{"session"=$event_session; "type" = $event_type; "vm_uid_ems" = $vm_uid_ems; "source" = "vdi-citrix"; "time" = Get-Date; "plugin_version" = $plugin_version}

		$event_file = (Get-Date).GetDateTimeFormats()[101].Replace(':','').Replace('.','')
		$event | export-clixml -Encoding UTF8 -Path (Join-Path -Path $event_folder ($event_file + ".xml"))
		# logger "Local event record has been written"
		logger ""
	}
	else
	{
		logger "Failed to get VM's uid_ems for event $event_type - $event_msg"
	}
}

# For testing
#while ($true) {write-host "Sleeping every 2 seconds"; Start-Sleep 2}

if ($event_folder -ne $null) {
	$plugin_version = load_citrix_plugin

  $farm = $null
  # Connect to local vdi farm
  if ($plugin_version -eq 4) { $farm = New-XdAdminConnection 127.0.0.1 }

  # sessions_watcher $farm
	session_polling $farm $event_folder $plugin_version
}
else {
	Write-Host "No event folder was passed."
}
PS_SCRIPT
  end
end
