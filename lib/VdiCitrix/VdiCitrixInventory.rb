$:.push("#{File.dirname(__FILE__)}/../util/win32")
require 'miq-powershell-daemon'
require 'platform'
require 'VdiCitrixEvents'

class VdiCitrixInventory
  def self.to_inv_h(ems_data)
    data_version = ems_data.delete(:plugin_version) || 4
    data_version = data_version.to_i
    db_version = ems_data.delete(:db_version).to_i || 4

    [:folder, :tag].each {|key| ems_data[key] = nil unless ems_data.has_key?(key)}
    ems_data.keys.each do |k,v|
      next if k == :hosting_server_address  # This is a hash of EMS URL addresses resolved to IPs
      ems_data[k] = ems_data[k].to_miq_a
    end

    ems = {:vdi_controllers => [], :vdi_desktop_pools => [], :vdi_desktops => [], :vdi_users => [], :folders=>[], :vdi_sessions=>[],
           :vdi_endpoint_devices =>[], :uid_lookup => {}, :vdi_farm => nil}

    begin
      # Farm is the root element
      props = ems_data[:farm][0][:Props]
      ems[:name] = props[:Name]
      ems[:uid_ems] = props[:BaseOU]  || props[:BrokerServiceGroupUid]
      ems[:edition] = props[:Edition] || props[:DesktopLicenseEdition]

      ems_data[:farm].each do |f|
        ems[:vdi_farm] = farm_to_inv_h(f)
      end

      ems[:uid_lookup][:folders]={}
      ems_data[:folder].each do |f|
        ci = folders_to_inv_h(f)
        ems[:folders] << ci
        ems[:uid_lookup][:folders][ci[:uid_ems]]=ci
      end

      ems[:uid_lookup][:vdi_controllers]={}
      ems_data[:controller].each do |d|
        ci = controllers_to_inv_h(d)
        ci[:vdi_farm] = ems[:vdi_farm]
        ci[:vdi_farm][:vdi_controllers] << ci
        ems[:vdi_controllers] << ci
        ems[:uid_lookup][:vdi_controllers][ci[:name]]=ci
      end

      ems[:uid_lookup][:vdi_desktop_pools]={}
      ems[:uid_lookup][:vdi_desktops]={}
      ems[:uid_lookup][:vdi_users]={}

      data_version == 4 ? parse_version_4(ems_data, ems) : parse_version_5(ems_data, ems)

    rescue => err
      if $log
        $log.error err
        $log.error err.backtrace.join("\n")
      else
        puts err
        puts err.backtrace.join("\n")
      end
    end

    return ems

  end

  def self.farm_to_inv_h(inv)
    props = inv[:Props]
    {
      :name               => props[:Name],
      :vendor             => 'citrix',
      :license_server_name => props[:LicenseServerName],
      :enable_session_reliability => props[:EnableSessionReliability],
      :edition            => props[:Edition] || props[:DesktopLicenseEdition],
      :uid_ems            => props[:BaseOU]  || props[:BrokerServiceGroupUid],
      :vdi_controllers    => [],
      :vdi_desktop_pools  => []
    }
  end

  def self.controllers_to_inv_h(inv)
    props = inv[:Props]
    {
      :name             => props[:Name] || props[:DNSName],
      :version          => props[:Version] || props[:ControllerVersion],
      :zone_preference  => props.fetch_path(:ZoneElectionPreference, :ToString),
      :vdi_desktops     => [],
      :vdi_sessions     => []
    }
  end

  def self.parse_version_4(ems_data, ems)
    ems_data[:desktop_pool].each do |d|
      dp = desktop_pools_to_inv_ver_4_h(d)
      dp[:hosting_ipaddress] = ems_data[:hosting_server_address][dp[:hosting_server].to_sym] unless dp[:hosting_server].blank?
      dp[:vdi_farm] = ems[:vdi_farm]
      dp[:vdi_farm][:vdi_desktop_pools] << dp
      ems[:vdi_desktop_pools] << dp
      folder = dp[:folder] = ems[:uid_lookup][:folders][dp[:folder]]
      folder[:ems_children][:vdi_desktop_pools] ||= []
      folder[:ems_children][:vdi_desktop_pools] << dp
      ems[:uid_lookup][:vdi_desktop_pools][dp[:uid_ems]]=dp

      # Process Users
      d[:Users].each do |u|
        uh = vdi_users_to_inv_h(u)
        user = add_vdi_user(uh, ems, dp)
      end

      # Process Desktops
      d[:Desktops].each do |dd|
        ci = vdi_desktops_to_inv_ver_4_h(dd)
        ems[:vdi_desktops] << ci
        ci[:vdi_desktop_pool] = dp
        dp[:vdi_desktops] << ci

        controller_name = ci.delete(:controller_name)
        ci[:vdi_controller] = ems[:uid_lookup][:vdi_controllers][controller_name]
        ci[:vdi_controller][:vdi_desktops] << ci unless ci[:vdi_controller].nil?

        user_sid = dd.fetch_path(:Props, :AssignedUserSid, :ToString)
        unless user_sid.nil?
          uh = vdi_desktop_users_to_inv_h(dd)
          user = add_vdi_user(uh, ems, dp)
          user[:vdi_desktops] << ci
          ci[:vdi_users] << user
        end

        ems[:uid_lookup][:vdi_desktops][ci[:vm_uid_ems]]=ci
      end
    end

    ems[:uid_lookup][:vdi_endpoint_devices]={}
    ems_data[:session].each do |d|
      ci = sessions_to_inv_ver_4_h(d)
      ems[:vdi_sessions] << ci
      controller_name = ci.delete(:controller_name)
      ci[:vdi_controller] = ems[:uid_lookup][:vdi_controllers][controller_name]
      ci[:vdi_controller][:vdi_sessions] << ci unless ci[:vdi_controller].nil?
      pool_id = ci.delete(:pool_id)
      ci[:vdi_desktop_pool] = ems[:uid_lookup][:vdi_desktop_pools][pool_id]
      ci[:vdi_desktop_pool][:vdi_sessions] << ci
      vm_name = ci.delete(:desktop_name)
      ci[:vdi_desktop] = ci[:vdi_desktop_pool][:vdi_desktops].detect {|v| v[:name] == vm_name}
      ci[:vdi_desktop][:vdi_sessions] << ci unless ci[:vdi_desktop][:vdi_sessions].nil?

      vdi_user = ci[:vdi_desktop_pool][:vdi_users].detect {|u| u[:name] == d[:UserName]}
      unless vdi_user.nil?
        ci[:vdi_user] = vdi_user
        vdi_user[:vdi_sessions] << ci
      end

      epd = end_point_device_to_inv_ver_4_h(d, ems)
      unless epd.nil?
        ci[:vdi_endpoint_device] = epd
        epd[:vdi_sessions] << ci
      end
    end

    # Do linkups
    # :link_desktops_to_pools
    [:link_folders_to_folders]. each do |meth_name|
      self.send(meth_name, ems)
    end
  end

  def self.parse_version_5(ems_data, ems)
    user_hash = {}
    ems_data[:user].each {|u| user_hash[u.fetch_path(:Props, :Name)] = u}

    ems_data[:desktop_pool].each do |d|
      dp = desktop_pools_to_inv_ver_5_h(d, ems_data)
      dp[:hosting_ipaddress] = ems_data[:hosting_server_address][dp[:hosting_server].to_sym] unless dp[:hosting_server].blank?
      dp[:vdi_farm] = ems[:vdi_farm]
      dp[:vdi_farm][:vdi_desktop_pools] << dp
      ems[:vdi_desktop_pools] << dp
      ems[:uid_lookup][:vdi_desktop_pools][dp[:uid_ems]]=dp

      # Entitlement returns users assigned to pooled desktop groups
      # Assignment returns users in Assign-on-first-user desktop groups
      (ems_data[:desktop_pool_user_entitlement] + ems_data[:desktop_pool_user_assignment]).each do |dp_entitle|
        group_id = dp_entitle.fetch_path(:Props, :DesktopGroupUid)
        next if group_id.nil? || group_id != d.fetch_path(:Props, :Uid)
        dp_entitle.fetch_path(:Props, :IncludedUsers).to_miq_a.each do |user_props|
          u = user_hash[user_props.fetch_path(:Props, :Name)]
          unless u.nil?
            uh = vdi_users_to_inv_h(u)
            user = add_vdi_user(uh, ems, dp)
          end
        end
      end

      # Process Desktops
      dp_uid = d.fetch_path(:Props, :Uid)
      ems_data[:desktop].each do |dd|
        next unless dp_uid == dd.fetch_path(:Props, :DesktopGroupUid)

        ci = vdi_desktops_to_inv_ver_5_h(dd)
        ems[:vdi_desktops] << ci
        ci[:vdi_desktop_pool] = dp
        dp[:vdi_desktops] << ci

        controller_name = ci.delete(:controller_name)
        ci[:vdi_controller] = ems[:uid_lookup][:vdi_controllers][controller_name]
        ci[:vdi_controller][:vdi_desktops] << ci unless ci[:vdi_controller].nil?

        # Process Users
        users = dd.fetch_path(:Props, :AssociatedUserNames).to_miq_a
        session_user_name = dd.fetch_path(:Props, :SessionUserName)  #|| dd.fetch_path(:Props, :LastConnectionUser)
        users << session_user_name unless session_user_name.nil?

        users.uniq.each do |user|
          u = user_hash[user]
          unless u.nil?
            uh = vdi_users_to_inv_h(u)
            user = add_vdi_user(uh, ems, dp)
            user[:vdi_desktops] << ci
            ci[:vdi_users] << user

          end
        end

        ems[:uid_lookup][:vdi_desktops][dd.fetch_path(:Props, :Uid)]=ci
      end
    end

    ems[:uid_lookup][:vdi_endpoint_devices]={}
    ems_data[:session].each do |d|
      ci = sessions_to_inv_ver_5_h(d)
      ems[:vdi_sessions] << ci
      controller_name = ci.delete(:controller_name).to_s.downcase
      ems[:uid_lookup][:vdi_controllers].each do |c_name, c_hash|
        if c_name.downcase == controller_name
          ci[:vdi_controller] = c_hash
          break
        end
      end
      ci[:vdi_controller][:vdi_sessions] << ci unless ci[:vdi_controller].nil?

      desktop = ems[:uid_lookup][:vdi_desktops][d.fetch_path(:Props, :DesktopUid)]
      unless desktop.nil?
        ci[:vdi_desktop] = desktop
        ci[:vdi_desktop][:vdi_sessions] << ci unless ci[:vdi_desktop][:vdi_sessions].nil?

        ci[:vdi_desktop_pool] = desktop[:vdi_desktop_pool]
        ci[:vdi_desktop_pool][:vdi_sessions] << ci
      end

      vdi_user = ci[:vdi_desktop_pool][:vdi_users].detect {|u| u[:name] == ci[:user_name]}
      unless vdi_user.nil?
        ci[:vdi_user] = vdi_user
        vdi_user[:vdi_sessions] << ci
      end

      epd = end_point_device_to_inv_ver_5_h(d, ems)
      unless epd.nil?
        ci[:vdi_endpoint_device] = epd
        epd[:vdi_sessions] << ci
      end
    end
  end

  def self.desktop_pools_to_inv_ver_4_h(inv)
    props = inv
    host  = props.fetch_path(:HostingSettings, :Props, :HostingServer, :Props) || {}

    hosting_provider = host[:Provider].to_s.downcase
    hosting_vendor = if hosting_provider.include?('vmware')
      "vmware"
    elsif hosting_provider.include?('xen')
      "xen"
    elsif hosting_provider.blank?
      "none"
    else
      "unknown"
    end

    {
      :name             => props[:Name],
      :description      => props[:Description],
      :vendor           => 'citrix',
      :uid_ems          => props[:Id],
      :enabled          => props[:Enabled],
      :folder           => props.fetch_path(:Folder, :Props, :Path),
      :default_color_depth => props.fetch_path(:DefaultColorDepth, :ToString),
      :default_encryption_level => props.fetch_path(:DefaultEncryptionLevel, :ToString),
      :assignment_behavior => props.fetch_path(:AssignmentBehavior, :ToString),
      :hosting_server   => host[:Address],
      :hosting_vendor   => hosting_vendor,
      :vdi_desktops     => [],
      :vdi_users        => [],
      :vdi_sessions     => []
    }
  end

  def self.desktop_pools_to_inv_ver_5_h(inv, ems_data)
    props = inv[:Props]

    connection = {}
    hosting_provider = ""

    # Find the hosting and connection instances for this desktop pool
    desktop = ems_data[:desktop].detect { |d| d.fetch_path(:Props, :DesktopGroupUid) == props[:Uid]}
    unless desktop.nil?
      connection_name = desktop.fetch_path(:Props, :HypervisorConnectionName)
      connection = ems_data[:connection].detect {|h| h.fetch_path(:Props, :HypervisorConnectionName) == connection_name}
      connection = connection[:Props]
      hosting_provider = connection[:PluginId].to_s.downcase
    end

    hosting_vendor = if hosting_provider.include?('vmware')
      "vmware"
    elsif hosting_provider.include?('xen')
      "xen"
    elsif hosting_provider.blank?
      "none"
    else
      "unknown"
    end

    {
      :name             => props[:Name],
      :description      => props[:Description],
      :vendor           => 'citrix',
      :uid_ems          => props[:UUID],
      :enabled          => props[:Enabled],
      :default_color_depth      => props.fetch_path(:ColorDepth, :ToString),
      :default_encryption_level => props.fetch_path(:DefaultEncryptionLevel, :ToString),
      :assignment_behavior      => props.fetch_path(:DesktopKind, :ToString),
      :hosting_server   => connection[:HypervisorAddress].to_miq_a.first,
      :hosting_vendor   => hosting_vendor,
      :vdi_desktops     => [],
      :vdi_users        => [],
      :vdi_sessions     => []
    }
  end

  def self.vdi_desktops_to_inv_ver_4_h(inv)
    props = inv[:Props]
    {
      :name               => props[:Name],
      :connection_state   => props[:State][:ToString],
      :power_state        => props[:PowerState],
      :assigned_username  => props[:AssignedUserName],
      :maintenance_mode   => props[:MaintenanceMode],
      :agent_version      => props[:AgentVersion],
      :controller_name    => props[:Controller],
      :vm_uid_ems         => props[:HostingId],
      :vdi_sessions       => [],
      :vdi_users          => []
    }
  end

  def self.vdi_desktops_to_inv_ver_5_h(inv)
    props = inv[:Props]

    users = props[:AssociatedUserNames].to_miq_a
    assigned_username = users.length == 1 ? users.first : nil

    {
      :name               => props[:MachineName],
      :connection_state   => props[:MachineInternalState][:ToString],
      :power_state        => props[:PowerState][:ToString],
      :assigned_username  => assigned_username,
      :maintenance_mode   => props[:InMaintenanceMode],
      :agent_version      => props[:AgentVersion],
      :controller_name    => props[:ControllerNDSName],
      :vm_uid_ems         => props[:HostedMachineId],
      :vdi_sessions       => [],
      :vdi_users          => []
    }
  end

  def self.vdi_users_to_inv_h(inv)
    props = inv[:Props]
    vdi_user_to_inv_h(props[:Name], props.fetch_path(:SID) || props.fetch_path(:Sid, :ToString))
  end

  def self.vdi_desktop_users_to_inv_h(inv)
    vdi_user_to_inv_h(inv[:Props][:AssignedUserName], inv[:Props][:AssignedUserSid][:ToString])
  end

  def self.vdi_user_to_inv_h(name, uid_ems)
    {
      :name               => name,
      :uid_ems            => uid_ems,
      :vdi_desktop_pools  => [],
      :vdi_desktops       => [],
      :vdi_sessions       => []
    }
  end

  def self.add_vdi_user(uh, ems, dp)
    user = ems[:uid_lookup][:vdi_users][uh[:uid_ems]]
    if user.nil?
      ems[:vdi_users] << uh
      ems[:uid_lookup][:vdi_users][uh[:uid_ems]] = uh
      user = uh
    end

    existing_user = dp[:vdi_users].detect {|u| u[:uid_ems] == user[:uid_ems]}
    dp[:vdi_users] << user if existing_user.nil?

    existing_dp = user[:vdi_desktop_pools].detect {|d| d[:uid_ems] == dp[:uid_ems]}
    user[:vdi_desktop_pools] << dp if existing_dp.nil?

    return user
  end

  def self.sessions_to_inv_ver_4_h(inv)
    props = inv[:Props] || inv
    {
      :controller_name  => props[:Controller],
      :desktop_name     => props[:DesktopName],
      :encryption_level => props[:EncryptionLevel],
      :protocol         => props[:Protocol],
      :start_time       => props[:StartTime],
      :state            => props[:State][:ToString],
      :user_name        => props[:UserName],
      :pool_id          => props[:GroupId],
      :uid_ems          => "#{props[:StartTime].to_i}_#{props[:DesktopName]}",
      :horizontal_resolution => props[:HorizontalResolution],
      :vertical_resolution => props[:VerticalResolution],
    }
  end

  def self.sessions_to_inv_ver_5_h(inv)
    props = inv[:Props] || inv
    user_name = props[:Username].blank? ? props[:BrokeringUserName] : props[:Username]
    {
      :controller_name  => props[:LaunchedViaHostName],
      :protocol         => props[:Protocol],
      :start_time       => props[:StartTime],
      :state            => props[:SessionState][:ToString],
      :user_name        => user_name,
      :uid_ems          => "#{props[:StartTime].to_i}_#{props[:DesktopUid]}",
    }
  end

  def self.end_point_device_to_inv_ver_4_h(inv, ems)
    props = inv[:Props] || inv
    endpoint_id = props[:EndpointId]

    return nil if endpoint_id.nil?
    return ems[:uid_lookup][:vdi_endpoint_devices][endpoint_id] if ems[:uid_lookup][:vdi_endpoint_devices].has_key?(endpoint_id)

    result = {
      :name         => props[:EndpointName],
      :ipaddress    => props[:EndpointAddress],
      :uid_ems      => endpoint_id,
      :vdi_sessions => []
    }
    ems[:uid_lookup][:vdi_endpoint_devices][endpoint_id] = result
    ems[:vdi_endpoint_devices] << result
    return result
  end

  def self.end_point_device_to_inv_ver_5_h(inv, ems)
    props = inv[:Props] || inv
    sess_type = props.fetch_path(:SessionState, :ToString).to_s.downcase
    if sess_type.include?('nonbrokered')
      endpoint_id = props[:HardwareId] || props[:ConnectedViaIP]
    else
      endpoint_id = props[:HardwareId]
    end

    return nil if endpoint_id.nil?
    return ems[:uid_lookup][:vdi_endpoint_devices][endpoint_id] if ems[:uid_lookup][:vdi_endpoint_devices].has_key?(endpoint_id)

    result = {
      :name         => props[:ConnectedViaHostName] || props[:ClientName],
      :ipaddress    => props[:ConnectedViaIP]       || props[:ClientAddress],
      :uid_ems      => endpoint_id,
      :vdi_sessions => []
    }
    ems[:uid_lookup][:vdi_endpoint_devices][endpoint_id] = result
    ems[:vdi_endpoint_devices] << result
    return result
  end

  def self.folders_to_inv_h(inv)
    props = inv[:Props]
    {
      :name         => props[:Name],
      :uid_ems      => props[:Path],
      :full_path    => props[:Path],
      :ems_children => {}
    }
  end

  def self.link_folders_to_folders(ems)
    ems[:folders].each do |f|
      ems[:folders].each do |cf|
        parent_path = File.dirname(cf[:full_path])
        next if parent_path == cf[:full_path]
        if parent_path == f[:full_path]
          f[:ems_children][:folders] ||= []
          f[:ems_children][:folders] << cf
        end
      end

      # Mark root folder as ems starting point
      ems[:ems_root] = f if f[:full_path].split('\\').length == 0
    end
    ems[:folders].each {|f| f.delete(:full_path)}
  end

  def self.inv_ps_script
<<-PS_SCRIPT
function to_h($object, $skip_names = @()) {
  $result = $null
  if   ($object -is [System.Array]) {$result = @(); $object | ForEach-Object {$result += to_h $_}}
  else {$result = @{}; $object | Get-Member -MemberType Property | ForEach-Object {if ($skip_names -notcontains $_.name) {$result.$($_.name) = $object.$($_.name)}}}
  return ,$result
}

function load_citrix_plugin($raise_error = $true, $log_result = $true) {
  $plugin_version = $null

  $requested_plugins = @("XDCommands", "Citrix.Broker.Admin.V1", "Citrix.Host.Admin.V1")
  foreach ($plugin in $requested_plugins) {if ((Get-PSSnapin -Name $plugin -ErrorAction SilentlyContinue) -eq $null) {Add-PSSnapin $plugin -ErrorAction SilentlyContinue}}

  if ((Get-PSSnapin     -Name "Citrix.Broker.Admin.V1" -ErrorAction SilentlyContinue) -ne $null) {$plugin_version = 5}
  elseif ((Get-PSSnapin -Name "XDCommands"             -ErrorAction SilentlyContinue) -ne $null) {$plugin_version = 4}

  if ($plugin_version -eq $null -and $raise_error -eq $true) {throw "No Citrix plug-in found"}
  if ($log_result) {
    if ($plugin_version -eq $null) {miq_logger "warn" "Citrix XenDesktop plugin not found"}
    else                           {miq_logger "info" "Citrix XenDesktop version $($plugin_version) plugin found"}
  }

  return $plugin_version
}

function resolve_ip_locally($url, $description, $result) {
  if ($url -imatch "https?://(.*)/") {
    $hosting_addr = $Matches[1]
    try {
      $ip = [System.Net.Dns]::GetHostAddresses($hosting_addr)
      $result[$url] = $ip[0].IPAddressToString
    }
    catch {
      miq_logger "warn" "$($description) - Failed to resolve hostname <$($hosting_addr)> for HostingServer Address: <$($url)>"
    }
  }
}

function collect_inventory_data($plugin_version) {
  if ($plugin_version -eq 4) {return collect_inventory_data_v4}
  else                       {return collect_inventory_data_v5}
}

function collect_inventory_data_v4 {
  $results = @{}
  $results['plugin_version'] = 4
  $results["hosting_server_address"] = @{}

  miq_logger "info" "Connection to local farm"
  # Forms a connection to a farm by selecting a delivery controller in that farm
  $farm = New-XdAdminConnection 127.0.0.1

  trap {
    if ($farm -ne $null) {
      Disconnect-XdAdminConnection -AdminConnection $farm
      $farm = $null
    }
    break
  }

  # Obtains details and settings for the farm.
  miq_logger "info" "Collecting Farm info"
  $results["farm"] = Get-XdFarm -AdminConnection $farm

  # Obtains information about delivery controllers in a farm.
  miq_logger "info" "Collecting Controller info"
  $results["controller"] = Get-XdController -AdminConnection $farm

  # Obtains details for desktop groups that are currently published.
  miq_logger "info" "Collecting Desktop Group info"
  $desktop_pool = Get-XdDesktopGroup -HostingDetails -AdminConnection $farm

  # Resolve the address of the Hosting Server
  miq_logger "info" "Resolving Hosting Server addresses"
  $results["hosting_server_address"] = @{}
  $desktop_pool | ForEach-Object {
    resolve_ip_locally $_.HostingSettings.HostingServer.Address "Desktop Pool: <$($_.Name)>" $results["hosting_server_address"]
  }

  $results["desktop_pool"] = to_h $desktop_pool

  # Obtains details of available folders for published desktop groups in the farm.
  miq_logger "info" "Collecting Folder info"
  $results["folder"] = Get-XdFolder -AdminConnection $farm

  # Obtains details for all the current active (including disconnected) user sessions on all desktops in the farm.
  # Use the -SessionDetails flag so we collect 'expensive' end-point device information such as name, address and ID,
  # display details such as resolution, and connection details such as protocol and encryption settings for XdSession instances.
  miq_logger "info" "Collecting Sessions info"
  $results["session"] = @()
  Get-XdSession -AdminConnection $farm -SessionDetails | ForEach-Object {$results["session"] += to_h $_ @("UserSid", "DesktopSid")}

  miq_logger "info" "Disconnecting from Farm"
  Disconnect-XdAdminConnection -AdminConnection $farm

  return $results
}

function collect_inventory_data_v5 {
  $results = @{}
  $results['plugin_version'] = 5
  $results['db_version'] = (Get-BrokerInstalledDbVersion).ToString()
  $results["hosting_server_address"] = @{}
  $backslash_char = [char]92

  # Obtains details and settings for the site.
  miq_logger "info" "Collecting Site info"
  $results["farm"] = Get-BrokerSite

  # Obtains information about delivery controllers
  miq_logger "info" "Collecting Controller info"
  $results["controller"] = Get-BrokerController

  # Obtains information about delivery controllers
  miq_logger "info" "Collecting Catalog info"
  $results["catalog"] = Get-BrokerCatalog

  # Obtains details for desktop groups that are currently published.
  miq_logger "info" "Collecting Desktop Group info"
  $results["desktop_pool"] = Get-BrokerDesktopGroup

  # Obtains details for pooled destkop group user assignment
  miq_logger "info" "Collecting Desktop Group User entitlement info"
  $results["desktop_pool_user_entitlement"] = Get-BrokerEntitlementPolicyRule

  # Obtains details for Assign-on-first-use destkop group user assignment
  miq_logger "info" "Collecting Desktop Group User Assignment info"
  $results["desktop_pool_user_assignment"] = Get-BrokerAssignmentPolicyRule

  # Obtains settings for virtual server connections
  miq_logger "info" "Collecting Connection info"
  $results["connection"] = (Get-ChildItem ("xdhyp:" + $backslash_char + "Connections"))

  # Resolve the address of the server connections
  miq_logger "info" "Resolving Connection Server addresses"
  $results["connection"] | ForEach-Object {
    $_.HypervisorAddress | ForEach-Object {
      resolve_ip_locally $_ "VDI Connection: <$($ems.HypervisorConnectionName)>" $results["hosting_server_address"]
    }
  }

  # Obtains details and settings for hosting servers
  miq_logger "info" "Collecting Hosting info"
  $results["host"] = (Get-ChildItem ("xdhyp:" + $backslash_char + "HostingUnits"))

#  # Obtains details of available tags
#  miq_logger "info" "Collecting Tag info"
#  $results["tag"] = Get-BrokerTag

  # Obtains details and settings for virtual desktops in published desktop groups.
  miq_logger "info" "Collecting Desktop info"
  $results["desktop"] = Get-BrokerDesktop

  # Obtains details and settings for users.
  miq_logger "info" "Collecting User info"
  $results["user"] = Get-BrokerUser

  # Obtains details for all the current active (including disconnected) user sessions on all desktops in the site.
  miq_logger "info" "Collecting Sessions info"
  $results["session"] = Get-BrokerSession

  return $results
}

$start_time = Get-Date
$plugin_version = load_citrix_plugin
$results = collect_inventory_data $plugin_version
miq_logger "info" "Data Collection Complete in $($(Get-Date) - $start_time)"
$results
PS_SCRIPT
  end

  def self.detect_script
<<-PS_SCRIPT
  function load_citrix_plugin($raise_error = $true, $log_result = $true) {
    $plugin_version = $null

    $requested_plugins = @("XDCommands", "Citrix.Broker.Admin.V1", "Citrix.Host.Admin.V1")
    foreach ($plugin in $requested_plugins) {if ((Get-PSSnapin -Name $plugin -ErrorAction SilentlyContinue) -eq $null) {Add-PSSnapin $plugin -ErrorAction SilentlyContinue}}

    if ((Get-PSSnapin     -Name "Citrix.Broker.Admin.V1" -ErrorAction SilentlyContinue) -ne $null) {$plugin_version = 5}
    elseif ((Get-PSSnapin -Name "XDCommands"             -ErrorAction SilentlyContinue) -ne $null) {$plugin_version = 4}

    if ($plugin_version -eq $null -and $raise_error -eq $true) {throw "No Citrix plug-in found"}
    if ($log_result) {
      if ($plugin_version -eq $null) {miq_logger "warn" "Citrix XenDesktop plugin not found"}
      else                           {miq_logger "info" "Citrix XenDesktop version $($plugin_version) plugin found"}
    }

    return $plugin_version
  }

  $result = $false
  # Register the Citrix XDCommands Snapin with the 64-bit version of Powershell if available
  copy-Item -Path Registry::HKLM\\SOFTWARE\\wow6432node\\Microsoft\\PowerShell\\1\\PowerShellSnapIns\\XDCommands -Destination Registry::HKLM\\SOFTWARE\\Microsoft\\PowerShell\\1\\PowerShellSnapIns -ErrorAction SilentlyContinue
  $snapin = load_citrix_plugin $false $false
  if ($snapin -ne $null) {$result = $true}
  $result
PS_SCRIPT
  end

  def self.is_available?
    begin
      result = false
      ps = nil
      if Platform::OS == :win32 && self.pssnapin_registered?
        ps_script = VdiCitrixInventory.detect_script
        ps = MiqPowerShell::Daemon.new()
        result = ps.run_script(ps_script, 'object')
        result = result[0] if result.kind_of?(Array) && result.length == 1
      end
    ensure
      ps.disconnect unless ps.nil?
    end
    result
  end

  def self.pssnapin_registered?
    require 'win32/registry'
    #KEY_WOW64_64KEY = 0x100
    key_wow64_64key = 0x100

    citrix_vdi_paths = %w{SOFTWARE\\Microsoft\\PowerShell\\1\\PowerShellSnapIns\\XDCommands
                          SOFTWARE\\wow6432node\\Microsoft\\PowerShell\\1\\PowerShellSnapIns\\XDCommands
                          SOFTWARE\\Microsoft\\PowerShell\\1\\PowerShellSnapIns\\Citrix.Broker.Admin.V1
                          SOFTWARE\\Wow6432Node\\Microsoft\\PowerShell\\1\\PowerShellSnapIns\\Citrix.Broker.Admin.V1}

    found = false
    citrix_vdi_paths.each do |reg_path|
      begin
        break if found == true
        Win32::Registry::HKEY_LOCAL_MACHINE.open(reg_path, Win32::Registry::KEY_ALL_ACCESS | key_wow64_64key) {|reg| found = true}
      rescue Win32::Registry::Error
      end
    end

    return found
  end

  def self.start_event_watcher(event_folder, interval = 60)
    interval = interval.to_i
    interval = 60 if interval <= 4  # Don't allow a poll interval less then 5 sec
    ps_event_script = File.join(File.expand_path(File.dirname(__FILE__)), "VdiCitrixEvents.ps1")
    ps_log_idr = MiqPowerShell::Daemon.get_log_dir
    File.open(ps_event_script, 'w') {|f| f.write(self.inv_event_watcher_script(interval))}
    command = '-NoLogo -NonInteractive -NoProfile -ExecutionPolicy RemoteSigned'
    command += " -File \"#{ps_event_script}\" \"#{event_folder}\" \"#{ps_log_idr}\""
    pid = MiqPowerShell.execute_async(command)
    $log.info "VdiCitrixInventory.start_event_watcher Citrix VDI watcher started with pid <#{pid}>.  Poll interval = <#{interval}>"
    return pid
  end

  def self.stop_process(pinfo)
    Process.kill(9, pinfo[:pid])
  end
end
