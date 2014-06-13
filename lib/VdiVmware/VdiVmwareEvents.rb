class VdiVmwareInventory
  def self.inv_event_watcher_script(interval)
<<-PS_SCRIPT
param($event_folder, $miq_log_dir=$null)

$required_plugins = @("VMware.View.Broker")
foreach ($plugin in $required_plugins) {if ((Get-PSSnapin -Name $plugin -ErrorAction SilentlyContinue) -eq $null) {Add-PSSnapin $plugin -ErrorAction Stop}}

function logger($msg, $level="INFO ") {
  $miq_logger_date = Get-Date
  if ($miq_log_dir -ne $null) {
    Set-Content (Join-Path $miq_log_dir "$($PID)_$($miq_logger_date.ToFileTime()).log") "$($level[0]), [$($miq_logger_date.GetDateTimeFormats()[114]) \#$($pid)]  $($level) -- : $($msg)"
  }

  "[----] $($level[0]), [$($miq_logger_date.GetDateTimeFormats()[114]) $($pid)]  $($level) -- : $($msg)" | Write-Host
}

function to_obj($object, $to_string_names = @(), $skip_names = @()) {
	$result = $null
	if   ($object -is [System.Array]) {$result = @(); $object | ForEach-Object {$result += to_obj $_}}
	else {$result = New-Object Object; $object | Get-Member -MemberType NoteProperty | ForEach-Object {
		if ($to_string_names -contains $_.name) {Add-Member -InputObject $result -MemberType NoteProperty -Name $_.name -Value $object.$($_.name).ToString() }
		elseif ($skip_names -contains $_.name)  {} #Write-Host "Skipping Property <$($_.name)> with value <$($object.$($_.name))>"
		else {Add-Member -InputObject $result -MemberType NoteProperty -Name $_.name -Value $object.$($_.name)}
		}
	}
	return ,$result
}

function add_property($obj, $name, $value) {
	Add-Member -InputObject $obj -MemberType NoteProperty -Name $name -Value $value
}

function get_current_sessions {
	$s = Get-RemoteSession -ErrorAction SilentlyContinue
	return ,$s
}

function get_session_id($session) {
	return $session.session_id
}

function dump_session_object($session, $msg) {
	logger $msg
	$session | ft DNSName,State,StartTime
}

function session_polling($event_folder) {
	$sess_old = get_current_sessions
	dump_session_object $sess_old "Session States initialized"
	$sess_new = $null
	logger "Using event folder: <$event_folder>"
	logger "Watching for events..."

	$shouldProcess = $true
	while ($shouldProcess) {
		# Start-Sleep #{interval}
		# Start-Sleep 2
		# logger "Checking for events"
		$sess_new = get_current_sessions
		$diff = session_diff $sess_old $sess_new
		# Determine if there were any changes
		if (($diff["add"].Count -gt 0) -or ($diff["delete"].Count -gt 0) -or ($diff["update"].Count -gt 0)) {
			# $diff | ft
			generate_events $diff $event_folder
		}
		# else {Write-Host "Nothing changed: $(Get-Date)"}
		$sess_old = $sess_new
	}
}

function sessions_watcher($event_folder) {
	$counter = 0
	$timespan = New-Object System.TimeSpan(0, 0, 10)
	$scope = New-Object System.Management.ManagementScope("\\.\root\cimV2")
	$query = New-Object System.Management.WQLEventQuery `
		("__InstanceCreationEvent",$timespan, "TargetInstance ISA 'Win32_NTLogEvent' and TargetInstance.LogFile = 'application' and TargetInstance.EventCode = '103'")

	$sess_old = get_current_sessions
	dump_session_object $sess_old "Session States initialized"
	$sess_new = $null
	logger "Using event folder: <$event_folder>"
	logger "Watching for events..."

	# Start Event Watcher
	$watcher = New-Object System.Management.ManagementEventWatcher($scope, $query)
	logger "Watcher connected"
	do {
		$watcher_Result = $watcher.WaitForNextEvent()
		$target=$watcher_result.TargetInstance
		
		if ($target.Message -match "(\w*):") {
			logger "NTEvent: $($target.TimeGenerated) $($target.EventIdentifier):$($target.CategoryString)  Type: $($Matches[0])"

			$sess_new = get_current_sessions
			$diff = session_diff $sess_old $sess_new
			# Determine if there were any changes
			if (($diff["add"].Count -gt 0) -or ($diff["delete"].Count -gt 0) -or ($diff["update"].Count -gt 0)) {
				# $diff | ft
				generate_events $diff $event_folder
			}
			$sess_old = $sess_new
		}
	} while ($counter -ne 1)
}

function session_to_hash($sessions) {
	$result = @{}
	foreach ($s in $sessions) {
		if ($s -ne $null) {
			$sess_id = get_session_id $s
			$result[$sess_id] = $s
		}
	}
	return ,$result
}

function usersid_from_session($session) {
  $bc = [char]92    # backslash char
  $usersid = $null
  $domain, $username = $session.Username.split($bc)

  if ($session.session_id -imatch "$username$($bc)(cn=(S-$($bc)d-$($bc)d-$($bc)d{2}-$($bc)d{10}-$($bc)d{10}-$($bc)d{10}-$($bc)d{4})") {
    $usersid = $Matches[1].toString().ToUpper()
  }
  else
  {
    $domain_user = Get-User -domain $domain -name $username
    if ($domain_user -ne $null) { $usersid = $domain_user.sid}
  }
  return $usersid
}

function is_session_same($old, $new) {
	if ($old.State -eq $new.State) {return $true}
	logger "$($old.DNSName) - Updated State: $($old.State) -> $($new.State)"
	return $false
}

function session_diff($sess_old, $sess_new) {
	$result = @{"add"=@(); "delete"=@(); "update"=@(); "same"=@()}
	$old = session_to_hash $sess_old
	$new = session_to_hash $sess_new

	foreach ($key in $new.keys) {
		if ($old.ContainsKey($key)) {
			$x = $old[$key]
			$old.Remove($key)
			$s = $new[$key]
			if (is_session_same $x $new[$key]) {
				$result["same"] += $s
			}
			else {
				$result["update"] += $s
			}
		}
		else {
			$s = $new[$key]
			logger "$($s.DNSName) - New State: $($s.State)"
			$result["add"] += $s
		}
	}
	foreach ($key in $old.keys) {
		$s = $old[$key]
		if ($s -ne $null) {
			logger "$($s.DNSName) - Deleted State: $($s.State) -> LoggedOff"
			$result["delete"] += $s
		}
	}
	return ,$result
}

function get_uid_ems($desktop) {return "$($desktop.id)|$($desktop.Path)"}

function find_desktop($session) {
	$desktop = $null
	Get-DesktopVM -isInPool $true -pool_id $session.pool_id -ErrorAction SilentlyContinue | foreach {
		if ($_.HostName -eq $session.DNSName) { $desktop = $_ }
	}
	return $desktop
}

function generate_events($diff, $event_folder) {
	foreach ($sess in $diff["add"])    { generate_event $null $sess $event_folder}
	foreach ($sess in $diff["delete"]) { generate_event $sess $null $event_folder}
	foreach ($sess in $diff["update"]) { generate_event $sess $sess $event_folder}
}

# *AGENT_CONNECTED 			User ${UserDisplayName} has logged in to a new session on machine ${MachineName}
# *AGENT_DISCONNECTED 		User ${UserDisplayName} has disconnected from machine ${MachineName}
# *AGENT_ENDED 				User ${UserDisplayName} has logged off machine ${MachineName}
# *AGENT_PENDING 			The agent running on machine ${MachineName} has accepted an allocated session for user ${UserDisplayName}
# AGENT_PENDING_EXPIRED 	The pending session on machine ${MachineName} for user ${UserDisplayName} has expired
# AGENT_RECONFIGURED 		Machine ${MachineName} has been successfully reconfigured
# *AGENT_RECONNECTED 		User ${UserDisplayName} has reconnected to machine ${MachineName}
# *AGENT_RESUME 			The agent on machine ${MachineName} sent a resume message
# *AGENT_SHUTDOWN 			The agent running on machine ${MachineName} has shut down, this machine will be unavailable
# AGENT_STARTUP 			The agent running on machine ${MachineName} has contacted the connection server and sent a startup message
# AGENT_SUSPEND 			The agent on machine ${MachineName} sent a suspend message
function normalize_event_type($state) {
	$state = $sess.State
	
	# Default value
	$event = "Vdi$($state)SessionEvent"
	
	if     ($state -eq "Connected") 	{$event = "VdiLoginSessionEvent"		 }
	elseif ($state -eq "Disconnected") 	{$event = "VdiDisconnectedSessionEvent"	 }
	elseif ($state -eq "Ended") 		{$event = "VdiLogoffSessionEvent"		 }
	elseif ($state -eq "Pending") 		{$event = "VdiConnectingSessionEvent"	 }
	elseif ($state -eq "Reconnected") 	{$event = "VdiLoginSessionEvent"		 }
	elseif ($state -eq "Resume") 		{$event = "VdiLoginSessionEvent"		 }
	elseif ($state -eq "Shutdown")		{$event = "VdiLogoffSessionEvent"		 }
	
	logger "Returning event type: <$event> for session state: <$($sess.State)>"
	return $event
}

function generate_event($old, $new, $event_folder) {
	$sess  = $new
	$event = $null

	if ($new -eq $null) {
		# Logoff Event
		$sess = $old
		$event = "VdiLogoffSessionEvent"
	}
	else {
		# Status Update Event
		$event = normalize_event_type $sess
	}
	sendEvent $event $sess $event_folder
}

function sendEvent($event_type, $session, $event_folder) {
	$desktop = find_desktop $session
	$vm_uid_ems = get_uid_ems $desktop
	# Cut event record
	if ($vm_uid_ems -ne $null) {
		logger "Processing event <$event_type> for <$($session.Username)> on <$($session.DNSName)> with vm_uid_ems: <$vm_uid_ems>"

		# Convert some objects to string format if they cause the conversion to XML to fail
		$event_session = to_obj $session @("UserSid", "DesktopSid")

		# Add UserSid to session data
		add_property $event_session "UserSid" (usersid_from_session $session)

		$event = @{"session"=$event_session; "type" = $event_type; "vm_uid_ems" = $vm_uid_ems; "source" = "vdi-vmware"; "time" = Get-Date; "desktop" = $desktop}

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

if ($event_folder -ne $null) {
	# sessions_watcher $event_folder
	session_polling $event_folder
}
else {
	Write-Host "No event folder was passed."
}
PS_SCRIPT
  end
end