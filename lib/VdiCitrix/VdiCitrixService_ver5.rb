module VdiCitrixService::Version5
  def ps_methods
    <<-PS_SCRIPT
#
# VDI Citrix Version 5 Functions
#
function get_desktop_group($desktop_pool_name, $desktop_pool_id) {
  $dg = Get-BrokerDesktopGroup -UUID $desktop_pool_id -ErrorAction SilentlyContinue
  if ($dg -eq $null) {$dg = Get-BrokerDesktopGroup -Name $desktop_pool_name -ErrorAction SilentlyContinue}
  return $dg
}

function add_users_to_desktop_pool($policy_type, $strDesktopGroupUserList, $policy_rule) {
  $strDesktopGroupUserList.Split(",") | foreach {
    try {
      $user = $_.Trim()
      if ($user.Length -ne 0) {
        miq_logger "info" "Adding User <$user> to group"
        if ($policy_rule -is [System.Array]) {$policy_rule = $policy_rule[0]}
        if ($policy_type -eq 'Assignment') { $policy_rule | Set-BrokerAssignmentPolicyRule  -AddIncludedUsers $_ }
        else                               { $policy_rule | Set-BrokerEntitlementPolicyRule -AddIncludedUsers $_ }
      }
    }
    catch { miq_logger "warn" "Failed to add user: $($user).  Error: $($_)" }
  }
}

function add_user_to_desktop_pool($user_name, $user_sid, $desktop_pool_name, $desktop_pool_id) {
  $dg = Get-BrokerDesktopGroup -UUID $desktop_pool_id
  $strDesktopGroupUserList = $user_sid
  $user = New-BrokerUser -SID $user_sid

  if ($dg.DesktopKind -icontains "Shared") {
    $policy_rule = Get-BrokerEntitlementPolicyRule -DesktopGroupUid $dg.Uid
    add_users_to_desktop_pool 'Entitlement' $strDesktopGroupUserList $policy_rule
  }
  else {
    $policy_rule = Get-BrokerAssignmentPolicyRule -DesktopGroupUid $dg.Uid
    add_users_to_desktop_pool 'Assignment' $strDesktopGroupUserList $policy_rule
  }
  return $dg, $user
}

function remove_user_from_desktop_pool($user_name, $user_sid, $desktop_pool_name, $desktop_pool_id) {
  $dg = Get-BrokerDesktopGroup -UUID $desktop_pool_id
  $user = New-BrokerUser -SID $user_sid
  if ($dg.DesktopKind -icontains "Shared") {
    Get-BrokerEntitlementPolicyRule -DesktopGroupUid $dg.Uid | ForEach-Object {
      miq_logger "info" "Removing User <$($user.name)> from Desktop Group <$($dg.name)>"
      $_ | Set-BrokerEntitlementPolicyRule -RemoveIncludedUsers $user_sid
    }
  }
  else {
    Get-BrokerAssignmentPolicyRule -DesktopGroupUid $dg.Uid | ForEach-Object {
      miq_logger "info" "Removing User <$($user.name)> from Desktop Group <$($dg.name)>"
      $_ | Set-BrokerAssignmentPolicyRule -RemoveIncludedUsers $user_sid
    }
  }

  # Remove user from all desktops in this pool
  Get-BrokerDesktop -AssociatedUserName $user.Name -DesktopGroupUid $dg.Uid | foreach {
    miq_logger "info" "Removing User <$($user.name)> from Desktop <$($_.MachineName)>"
    Remove-BrokerUser -Name $user.Name -Machine $_.MachineName
  }
  return $dg, $user
}

function add_user_to_desktop_and_pool($user_name, $user_sid, $desktop_pool_name, $desktop_pool_id, $desktop_name, $desktop_id) {
  $dg, $user = add_user_to_desktop_pool $user_name $user_sid $desktop_pool_name $desktop_pool_id
  if ($dg.DesktopKind -eq "Private") {
    $d = Get-BrokerDesktop -HostedMachineId $desktop_id
    miq_logger "info" "Adding User <$($user.name)> to Desktop <$($d.MachineName)> in pool <$($d.DesktopGroupName)>"
    Add-BrokerUser -Machine $d.MachineName -Name $user.Name | Out-Null
  }
}

function remove_user_from_desktop($user_name, $user_sid, $desktop_pool_name, $desktop_pool_id, $desktop_name, $desktop_id) {
  $d = Get-BrokerDesktop -HostedMachineId $desktop_id
  $users = Get-BrokerUser -MachineUid $d.MachineUid
  $users | Where-Object {$_.SID -ieq $user_sid} | foreach-Object {
    miq_logger "info" "Removing User <$($_.name)> from Desktop <$($d.MachineName)> in pool <$($d.DesktopGroupName)>"
    Remove-BrokerUser -Machine $d.MachineName -Name $_.Name
  }
}

function remove_desktop_pool($desktop_pool_name, $desktop_pool_id) {
  $dg = Get-BrokerDesktopGroup -UUID $desktop_pool_id
  if ($dg -ne $null) {
    miq_logger "info" "Removing Desktop Group <$($dg.name)>"
    $removed_dp = Remove-BrokerDesktopGroup $dg
  }
  else {
    miq_logger "info" "Unable to removing Desktop Group <$($desktop_group_name)>.  Desktop Group not found."
  }
}

function modify_desktop_pool($desktop_pool_name, $desktop_pool_id, $settings) {
  $dg = Get-BrokerDesktopGroup -UUID $desktop_pool_id

  foreach ($key in $settings.Keys) {
    miq_logger "info" "Processing setting <$key> with value <$($settings[$key])> for Desktop Group <$($desktop_group_name)>."
    switch ($key)
      {
          "name" {
            $dg | Rename-BrokerDesktopGroup -NewName $settings[$key] | Out-Null
            Set-BrokerDesktopGroup -InputObject $dg -PublishedName $settings[$key] | Out-Null
          }
          "description" {Set-BrokerDesktopGroup -InputObject $dg -Description $settings[$key] | Out-Null}
          "enabled"     {
            switch ($settings[$key])
              {
                "true"  {Set-BrokerDesktopGroup -InputObject $dg -Enabled $true  | Out-Null}
                "false" {Set-BrokerDesktopGroup -InputObject $dg -Enabled $false | Out-Null}
              }
          }
          default       {miq_logger "info" "Unsupported setting <$key> skipped for Desktop Group <$($desktop_group_name)>."}
      }
  }

  return $dg
}

function create_desktop_pool($settings) {
    $desktop_pool_name = $settings["name"]
    $desktop_pool_id   = $null
    $dg = get_desktop_group $desktop_pool_name $desktop_pool_id

    if ($dg -ne $null) {
      # Error Desktop group already exists
      miq_logger "error" "Desktop group <$desktop_pool_name> already exists"
      throw "Desktop group <$desktop_pool_name> already exists"
    }

    miq_logger "info" "Creating Desktop Group:<$desktop_pool_name>  Assignment:<$($settings["assignment_behavior"])>"

    if ($settings["assignment_behavior"] -eq 'Pooled') { $desktop_group_type = 'Shared' }
    else                                               { $desktop_group_type = 'Private' }

    $strDesktopGroupName = $desktop_pool_name
    $dg = New-BrokerDesktopGroup -DesktopKind $desktop_group_type -Name $strDesktopGroupName -Description $strDesktopGroupDescription

    $apr = Get-BrokerAccessPolicyRule -Name "$($strDesktopGroupName)_Direct" -ErrorAction SilentlyContinue
    if ($apr -eq $null) {$pr = New-BrokerAccessPolicyRule -Name "$($strDesktopGroupName)_Direct" -IncludedDesktopGroups @($strDesktopGroupName) -AllowedConnections 'NotViaAG' -AllowedProtocols @('RDP','HDX') -AllowedUsers 'AnyAuthenticated' -AllowRestart $True -Enabled $True -IncludedDesktopGroupFilterEnabled $True -IncludedSmartAccessFilterEnabled $True -IncludedUserFilterEnabled $True}
    else { $apr | Set-BrokerAccessPolicyRule -AddIncludedDesktopGroups @($strDesktopGroupName)}

    $apr = Get-BrokerAccessPolicyRule -Name "$($strDesktopGroupName)_AG" -ErrorAction SilentlyContinue
    if ($apr -eq $null) {$pr = New-BrokerAccessPolicyRule -Name "$($strDesktopGroupName)_AG" -IncludedDesktopGroups @($strDesktopGroupName) -AllowedConnections 'ViaAG' -AllowedProtocols @('RDP','HDX') -AllowedUsers 'AnyAuthenticated' -AllowRestart $True -Enabled $True -IncludedDesktopGroupFilterEnabled $True -IncludedSmartAccessFilterEnabled $True -IncludedUserFilterEnabled $True}
    else {$apr | Set-BrokerAccessPolicyRule -AddIncludedDesktopGroups @($strDesktopGroupName)}

    if ($dg.DesktopKind -icontains "Shared") {
      $policy_rule = Get-BrokerEntitlementPolicyRule -DesktopGroupUid $dg.Uid
      if ($policy_rule -eq $null) { $policy_rule = New-BrokerEntitlementPolicyRule $strDesktopGroupName -DesktopGroupUid $dg.Uid -PublishedName $strDesktopGroupName }
    }
    else {
      $policy_rule = Get-BrokerAssignmentPolicyRule -DesktopGroupUid $dg.Uid
      if ($policy_rule -eq $null) { $policy_rule = New-BrokerAssignmentPolicyRule $strDesktopGroupName -DesktopGroupUid $dg.Uid -PublishedName $strDesktopGroupName }
    }

    miq_logger "info" "Desktop Group <$desktop_pool_name> was created."


    $bc_name = $dg.name + " Catalog"
    $bc = Get-BrokerCatalog -Name $bc_name -ErrorAction SilentlyContinue
    if ($bc -eq $null) {
      if ($dg.DesktopKind -icontains "Shared") {$allocation_type = 'Random'}
      else                                     {$allocation_type = 'Permanent'}
      miq_logger "info" "Creating Machine Catalog <$($bc_name)> with AllocationType <$($allocation_type)>"
      $bc = New-BrokerCatalog -AllocationType $allocation_type -CatalogKind PowerManaged -Name $bc_name
    }
    else {
      miq_logger "info" "Using existing Machine Catalog <$($bc.name)> with AllocationType <$($bc.AllocationType)>"
    }

    @("user_name", "user_pwd", "assignment_behavior", "name", "description", "ems_ipaddress") | foreach { $settings.Remove($_) }
    modify_desktop_pool $desktop_pool_name $dg.UUID $settings

    $dg
}
    PS_SCRIPT
  end
end
