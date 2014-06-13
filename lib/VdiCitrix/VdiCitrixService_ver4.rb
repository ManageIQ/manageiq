module VdiCitrixService::Version4
  def ps_methods
    <<-PS_SCRIPT
#
# VDI Citrix Version 4 Functions
#
function get_xd_desktop_group($desktop_pool_name, $desktop_pool_id) {
  $dg = Get-XdDesktopGroup -Name $desktop_pool_name
  if ($dg -eq $null) {Get-XdDesktopGroup | Where-Object {$_.Id -eq $desktop_pool_id} | ForEach-Object { $dg = $_}}
  return $dg
}

function add_user_to_desktop_pool($user_name, $user_sid, $desktop_pool_name, $desktop_pool_id) {
  $dg = get_xd_desktop_group $desktop_pool_name $desktop_pool_id
  $user = New-XdUser -Sid $user_sid
  if ($dg.Users.Contains($user) -eq $false) {
    miq_logger "info" "Adding User <$($user)> to Desktop Group <$($dg.name)>"
    $dg.Users.Add($user) | Out-Null
    Set-XdDesktopGroup $dg | Out-Null
  }
  return $dg, $user
}

function remove_user_from_desktop_pool($user_name, $user_sid, $desktop_pool_name, $desktop_pool_id) {
  $dg = get_xd_desktop_group $desktop_pool_name $desktop_pool_id
  $user = New-XdUser -Sid $user_sid
  if ($dg.Users.Contains($user) -eq $true) {
    miq_logger "info" "Removing User <$($user)> from Desktop Group <$($dg.name)>"
    $dg.Users.Remove($user) | Out-Null
    Set-XdDesktopGroup $dg | Out-Null
  }

  # Remove user from all desktops in this pool
  $dg.Desktops | foreach {
    if ($_.AssignedUserSid -eq $user_sid) {
      miq_logger "info" "Removing User <$($user.name)> from Desktop <$($_.Name)> for Pool <$($dg.name)>"
      $_.set_AssignedUserName($null)
      Set-XdVirtualDesktop $_ | Out-Null
    }
  }

  return $dg, $user
}

function add_user_to_desktop_and_pool($user_name, $user_sid, $desktop_pool_name, $desktop_pool_id, $desktop_name, $desktop_id) {
  $dg, $user = add_user_to_desktop_pool $user_name $user_sid $desktop_pool_name $desktop_pool_id
  if ($dg.AssignmentBehavior -eq "PreAssigned") {
    $dg.Desktops | Where-Object {$_.name -eq $desktop_name} | ForEach-Object {
      if ($_.AssignedUserSid -ne $user_sid) {
        miq_logger "info" "Adding User <$($user)> to Desktop <$($dg)>"
        $_.set_AssignedUserName($user) | Out-Null
        Set-XdVirtualDesktop($_) | Out-Null
      }
    }
  }
}

function remove_user_from_desktop($user_name, $user_sid, $desktop_pool_name, $desktop_pool_id, $desktop_name, $desktop_id) {
  $dg = get_xd_desktop_group $desktop_pool_name $desktop_pool_id
  $user = New-XdUser -Sid $user_sid
  $dg.Desktops | Where-Object {$_.name -eq $desktop_name} | ForEach-Object {
    if ($_.AssignedUserSid -eq $user_sid) {
      miq_logger "info" "Removing User <$($user)> from Desktop <$($dg)>"
      $_.set_AssignedUserName($null)
      Set-XdVirtualDesktop($_) | Out-Null
    }
  }
}

function remove_desktop_pool($desktop_pool_name, $desktop_pool_id) {
  $dg = get_xd_desktop_group $desktop_pool_name $desktop_pool_id
  if ($dg -ne $null) {
    miq_logger "info" "Removing Desktop Group <$($dg)>"
    $removed_dp = Remove-XdDesktopGroup -Group $dg
  }
  else {
    miq_logger "info" "Unable to removing Desktop Group <$($desktop_pool_name)>.  Desktop Group not found."
  }
}

function modify_desktop_pool($desktop_pool_name, $desktop_pool_id, $settings) {
  $dg = get_xd_desktop_group $desktop_pool_name $desktop_pool_id

  foreach ($key in $settings.Keys) {
    miq_logger "info" "Processing setting <$key> with value <$($settings[$key])> for Desktop Group <$($desktop_pool_name)>."
    switch ($key)
      {
          "name"        {$dg.name = $settings[$key]}
          "description" {$dg.description = $settings[$key]}
          "enabled"     {
            switch ($settings[$key])
              {
                "true"  {$dg.enabled = $true}
                "false" {$dg.enabled = $false}
              }
          }
          default       {miq_logger "info" "Unsupported setting <$key> skipped for Desktop Group <$($desktop_pool_name)>."}
      }
  }

  $dg = Set-XdDesktopGroup $dg
  return $dg
}

function create_desktop_pool($settings) {
    $desktop_pool_name = $settings["name"]
    $desktop_pool_id   = $null
    $dg = get_xd_desktop_group $desktop_pool_name $desktop_pool_id

    if ($dg -ne $null) {
      # Error Desktop group already exists
      miq_logger "error" "Desktop group <$desktop_pool_name> already exists"
      throw "Desktop group <$desktop_pool_name> already exists"
    }

    $ems_url = if ($settings["use_ssl"] -eq "true") {"https"} else {"http"}
    $ems_url += "://$($settings["ems_hostname"])/sdk"
    miq_logger "info" "Creating Desktop Group:<$desktop_pool_name>  Assignment:<$($settings["assignment_behavior"])> on EMS: <$($ems_url)>"

    $creds = new-object -typename System.Management.Automation.PSCredential -argumentlist $settings["user_name"], (ConvertTo-SecureString $settings["user_pwd"] -AsPlainText -Force)
    $hs = New-XdHostingServer -address $ems_url -provider ( Get-XdHostingProvider -name "VMware virtualization" ) -credential $creds

    # Define the hosting infrastructure settings for the desktop group
    $hgs = New-XdGroupHostingSettings -hostingserver $hs

    miq_logger "info" "Creating Desktop Group:<$desktop_pool_name>  Assignment:<$($settings["assignment_behavior"])>"
    $xdgroup = New-XdDesktopGroup -Publish $desktop_pool_name -Description $settings["description"] -AdminConnection $farm -hostingsettings $hgs -AssignmentBehavior $settings["assignment_behavior"]
    Set-XdDesktopGroup $xdgroup | Out-Null

    miq_logger "info" "Desktop Group <$desktop_pool_name> was created."

    @("user_name", "user_pwd", "assignment_behavior", "name", "description", "ems_ipaddress") | foreach { $settings.Remove($_) }
    modify_desktop_pool $desktop_pool_name $xdgroup.id $settings

    $xdgroup
}
    PS_SCRIPT
  end
end
