$:.push("#{File.dirname(__FILE__)}/../util/win32")
require 'miq-powershell-daemon'
require 'platform'
require 'VdiVmwareEvents'

class VdiVmwareInventory
  def self.to_inv_h(ems_data)
    begin
      ems = {:vdi_controllers => [], :vdi_desktop_pools => [], :vdi_desktops => [], :vdi_users => [], :folders=>[], :vdi_sessions=>[],
             :vdi_endpoint_devices =>[], :uid_lookup => {}, :vdi_farm => nil}

      # Normalize data into arrays
      self.pre_process(ems_data)

      # Farm is the root element
      ems_data[:farm] = [ems_data[:controller][0]]
      props = ems_data[:farm][0][:MS]
      ems[:name] = props[:broker_id]
      ems[:uid_ems] = props[:broker_id]
      #ems[:edition] = props[:Edition]

      ems_data[:farm].each do |f|
        ems[:vdi_farm] = farm_to_inv_h(f)
      end

      ems[:uid_lookup][:folders]={}
      ems_data[:desktop_pool].each do |d|
        ci = folders_to_inv_h(d)
        next if ems[:folders].detect {|f| f[:uid_ems] == ci[:uid_ems]}
        ems[:folders] << ci
        ems[:uid_lookup][:folders][ci[:uid_ems]]=ci
      end

      # Process Users
      ems[:uid_lookup][:vdi_users]={}
      ems_data[:user].each do |name, sid|
        ci = vdi_user_to_inv_h(name.to_s, sid)
        ems[:vdi_users] << ci
        ems[:uid_lookup][:vdi_users][ci[:uid_ems]]=ci
      end

      ems[:uid_lookup][:vdi_controllers]={}
      ems_data[:controller].each do |d|
        ci = controllers_to_inv_h(d, ems_data[:monitor])
        ci[:vdi_farm] = ems[:vdi_farm]
        ci[:vdi_farm][:vdi_controllers] << ci
        ems[:vdi_controllers] << ci
        ems[:uid_lookup][:vdi_controllers][ci[:name]]=ci
      end

      ems[:uid_lookup][:vdi_desktop_pools]={}
      ems_data[:desktop_pool].each do |d|
        dp = desktop_pools_to_inv_h(d, ems_data[:monitor], ems_data[:ems])
        dp[:hosting_ipaddress] = ems_data[:hosting_server_address][dp[:hosting_server].to_sym] unless dp[:hosting_server].blank?
        dp[:vdi_farm] = ems[:vdi_farm]
        dp[:vdi_farm][:vdi_desktop_pools] << dp
        ems[:vdi_desktop_pools] << dp
        folder = dp[:folder] = ems[:uid_lookup][:folders][dp[:folder]]
        folder[:ems_children][:vdi_desktop_pools] ||= []
        folder[:ems_children][:vdi_desktop_pools] << dp
        ems[:uid_lookup][:vdi_desktop_pools][dp[:uid_ems]]=dp
      end

      ems_data[:desktop_pool_entitlement].each do |de|
        props = de[:MS]
        pool = ems[:uid_lookup][:vdi_desktop_pools][props[:pool_id]]
        uh = vdi_user_to_inv_h(props[:displayName], props[:sid])
        user = add_vdi_user(uh, ems, pool)
      end

      # Process Desktops
      ems[:uid_lookup][:vdi_desktops]={}
      ems_data[:desktop_vm].each do |dd|
        props = dd[:MS]
        # View 4.5 returns dup desktops, so skip them
        next if ems[:uid_lookup][:vdi_desktops].keys.include?(props[:Path])

        ci = vdi_desktops_to_inv_h(dd)
        ems[:vdi_desktops] << ci

        dp = ems[:uid_lookup][:vdi_desktop_pools][props[:pool_id]]
        ci[:vdi_desktop_pool] = dp
        dp[:vdi_desktops] << ci

        # TODO: Find relationship between desktop and controller (possible session object)
        #ci[:vdi_controller] = ems[:vdi_controllers].first
        #ci[:vdi_controller][:vdi_desktops] << ci unless ci[:vdi_controller].nil?

        user_sid = props[:user_sid]
        unless user_sid.nil?
          uh = ems[:uid_lookup][:vdi_users][user_sid]
          user = add_vdi_user(uh, ems, dp, ci)
        end

        ems[:uid_lookup][:vdi_desktops][ci[:vm_uid_ems]]=ci
      end

      ems[:uid_lookup][:vdi_endpoint_devices]={}
      ems_data[:session].each do |d|
        props = d[:MS]
        ci = sessions_to_inv_h(d)
        ems[:vdi_sessions] << ci
        ci[:vdi_controller] = ems[:vdi_controllers].first
        ci[:vdi_controller][:vdi_sessions] << ci unless ci[:vdi_controller].nil?
        pool_id = ci.delete(:pool_id)
        ci[:vdi_desktop_pool] = ems[:uid_lookup][:vdi_desktop_pools][pool_id]
        ci[:vdi_desktop_pool][:vdi_sessions] << ci
        ci[:vdi_desktop] = ci[:vdi_desktop_pool][:vdi_desktops].detect {|v| props[:DNSName] == v[:hostname]}
        ci[:vdi_desktop][:vdi_sessions] << ci unless ci.fetch_path(:vdi_desktop, :vdi_sessions).nil?

        vdi_user = ci[:vdi_desktop_pool][:vdi_users].detect {|u| u[:name] == props[:Username]}
        vdi_user = ems[:vdi_users].detect {|u| u[:name] == props[:Username]} if vdi_user.nil?
        unless vdi_user.nil?
          ci[:vdi_user] = vdi_user
          vdi_user[:vdi_sessions] << ci
          add_vdi_user(vdi_user, ems, ci[:vdi_desktop_pool], ci[:vdi_desktop])
        end
      end

      # Remove hostname key from desktop metadata
      ems[:vdi_desktops].each {|d| d.delete(:hostname)}

    rescue => err
      if $log
        $log.error "#{err}\n#{err.backtrace.join("\n")}"
      else
        STDERR.puts "#{err}\n#{err.backtrace.join("\n")}"
      end
    end

    return ems
  end

  def self.pre_process(ems_data)
    ems_data.each do |k,v|
      if [:global_settings, :hosting_server_address, :license, :user].include?(k)
        self.hash_fixup(v)
        next
      end
      ems_data[k] = v.to_miq_a unless v.kind_of?(Array)
      self.hash_fixup(ems_data[k])
    end
  end

  def self.hash_fixup(h)
    if h.kind_of?(Array)
      h.each {|a| self.hash_fixup(a)}
    else
      h[:MS] = h.fetch_path(:Obj, :MS) if h.has_key?(:Obj)
    end
  end

  def self.farm_to_inv_h(inv)
    props = inv[:MS]
    {
      #:name               => props[:broker_id],
      :vendor             => 'vmware',
      #:license_server_name => props[:LicenseServerName],
      #:enable_session_reliability => props[:EnableSessionReliability],
      #:edition            => props[:Edition],
      #:uid_ems            => props[:broker_id],
      :vdi_controllers    => [],
      :vdi_desktop_pools  => []
    }
  end

  def self.controllers_to_inv_h(inv, monitor_inv)
    log_header = "MIQ(#{self.class.name}.controllers_to_inv_h)"
    props = inv[:MS]
    monitor = monitor_inv.detect{|m| m[:MS][:monitor] == 'CBMonitor' && m[:MS][:id] == props[:broker_id]}

    if monitor.nil?
      # monitors = monitor_inv.collect {|m| "#{m.fetch_path(:MS, :monitor)}_#{m.fetch_path(:MS, :id)}_#{m.fetch_path(:MS, :build)}"}
      # $log.warn "#{log_header} Controller monitor not found for Broker ID:<#{props[:broker_id]}>  Monitors: <#{monitors.join(", ")}>"
      monitor = {}
    end

    {
      :name             => props[:broker_id],
      :version          => monitor.fetch_path(:MS, :build),
      #:zone_preference  => props[:ZoneElectionPreference][:ToString],
      :vdi_desktops     => [],
      :vdi_sessions     => []
    }
  end

  def self.desktop_pools_to_inv_h(inv, monitor_inv, ems_inv)
    props = inv[:MS]
    ems_server = nil

    hosting_provider = props[:desktopSource].to_s.downcase
    hosting_vendor = if !props[:vc_id].blank?
      ems = ems_inv.detect {|e| e[:MS][:vc_id] == props[:vc_id]}
      ems_server = ems[:MS][:serverUrl] unless ems.blank?
      "vmware"
    elsif hosting_provider == "unmanaged"
      "none"
    else
      "unknown"
    end

    assignment_type = if props[:persistence] == 'NonPersistent'
      'Pooled'
    else
      props[:assignOnFirstLogon].to_s == "true" ? 'AssignOnFirstUse' : 'PreAssigned'
    end

    name = props[:displayName].blank? ? props[:pool_id] : props[:displayName]
    descript = props[:description].to_s[0, 255]

    result = {
      :name             => name,
      :description      => descript,
      :vendor           => 'vmware',
      :uid_ems          => props[:pool_id],
      :enabled          => props[:enabled],
      :folder           => props[:folderId],
#      :default_color_depth => props[:DefaultColorDepth][:ToString],
#      :default_encryption_level => props[:DefaultEncryptionLevel][:ToString],
      :assignment_behavior => assignment_type,
      :hosting_server   => ems_server,
      :hosting_vendor   => hosting_vendor,
      :vdi_desktops     => [],
      :vdi_users        => [],
      :vdi_sessions     => []
    }
  end

  def self.vdi_desktops_to_inv_h(inv)
     props = inv[:MS]
     vm_uid_ems = "#{props[:id]}|#{props[:Path]}"  # Example: VirtualMachine-vm-10262|/Testing Environment/vm/Linked-V5/Linked-Win7-1
    {
      :name               => props[:Name],
      :connection_state   => props[:localState],
      #:power_state        => props[:PowerState],
      :assigned_username  => props[:user_displayname],
      #:maintenance_mode   => props[:MaintenanceMode],
      #:agent_version      => props[:AgentVersion],
      #:controller_name    => props[:Controller],
      :vm_uid_ems         => vm_uid_ems,
      :hostname           => props[:HostName],         # Used to sync with session then deleted
      :vdi_sessions       => [],
      :vdi_users          => []
    }
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

  def self.add_vdi_user(uh, ems, dp, desktop=nil)
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

    unless desktop.nil?
      existing_desktop = user[:vdi_desktops].detect {|d| d[:vm_uid_ems] == desktop[:vm_uid_ems]}
      user[:vdi_desktops] << desktop if existing_desktop.nil?
      desktop[:vdi_users] << user
    end

    return user
  end

  def self.sessions_to_inv_h(inv)
    props = inv[:MS]
    {
#      :controller_name  => props[:Controller],
#      :encryption_level => props[:EncryptionLevel],
      :protocol         => props[:protocol],
      :start_time       => Time.parse(props[:startTime]).utc,
      :state            => props[:state],
      :user_name        => props[:Username],
      :pool_id          => props[:pool_id],
      :uid_ems          => props[:session_id][0,255],
#      :horizontal_resolution => props[:HorizontalResolution],
#      :vertical_resolution => props[:VerticalResolution],
    }
  end

  def self.folders_to_inv_h(inv)
    props = inv[:MS]
    {
      :name         => props[:folderId],
      :uid_ems      => props[:folderId],
      :full_path    => props[:folderId],
      :ems_children => {}
    }
  end

  def self.inv_ps_script
<<-PS_SCRIPT
Clear-Host

$required_plugins = @("VMware.View.Broker")
foreach ($plugin in $required_plugins) {if ((Get-PSSnapin -Name $plugin -ErrorAction SilentlyContinue) -eq $null) {Add-PSSnapin $plugin -ErrorAction Stop}}

function to_h($object, $skip_names = @()) {
  $result = $null
  if   ($object -is [System.Array]) {$result = @(); $object | ForEach-Object {$result += to_h $_}}
  else {$result = @{}; $object | Get-Member -MemberType Property | ForEach-Object {if ($skip_names -notcontains $_.name) {$result.$($_.name) = $object.$($_.name)}}}
  return ,$result
}

function usersid_for_session($session) {
	$bc = [char]92    # backslash char
	$usersid = $null
	$domain, $username = $session.Username.split($bc)

  if ($session.session_id -imatch "$username$($bc)(cn=(S-$($bc)d-$($bc)d-$($bc)d{2}-$($bc)d{10}-$($bc)d{10}-$($bc)d{10}-$($bc)d{4})") {
		$usersid = $Matches[1].toString().ToUpper()
	}
	else {
		$domain_user = Get-User -domain $domain -name $username
		if ($domain_user -ne $null) { $usersid = $domain_user.sid }
	}
	return $usersid
}

$results = @{}
$start_time = Get-Date

# Obtains information about delivery controllers in a farm.
miq_logger "info" "Collecting Controller info"
$results["controller"] = Get-ConnectionBroker -ErrorAction SilentlyContinue

# $results["composer_domain"] = Get-ComposerDomain -ErrorAction SilentlyContinue

miq_logger "info" "Collecting License info"
$results["license"] = Get-License -ErrorAction SilentlyContinue

miq_logger "info" "Collecting Health Monitor info"
$results["monitor"] = Get-Monitor -ErrorAction SilentlyContinue

miq_logger "info" "Collecting Global Settings"
$results["global_settings"] = Get-GlobalSetting -ErrorAction SilentlyContinue

# miq_logger "info" "Collecting User info"
# $results["users"] = Get-User -ErrorAction SilentlyContinue

miq_logger "info" "Collecting Virtual Center info"
$results["ems"] = Get-ViewVC -ErrorAction SilentlyContinue

# Resolve the address of the Hosting Server
$results["hosting_server_address"] = @{}
$results["ems"] | ForEach-Object {
  $hosting_address = $_.serverUrl
  if ($hosting_address -imatch "https?://(.*)/") {
    $hosting_addr = $_.serverName
    try {
      $ip = [System.Net.Dns]::GetHostAddresses($hosting_addr)
      $results["hosting_server_address"][$_.ServerUrl] = $ip[0].IPAddressToString
    }
    catch {
      miq_logger "warn" "Failed to resolve hostname <$($hosting_addr)> for HostingServer Address: <$($hosting_address)>"
    }
  }
}

# Obtains details for desktop pool
miq_logger "info" "Collecting Desktop Pool info"
$results["desktop_pool"] = Get-Pool -ErrorAction SilentlyContinue

miq_logger "info" "Collecting Desktop Pool Entitlement info"
$results["desktop_pool_entitlement"] = Get-PoolEntitlement -ErrorAction SilentlyContinue

# Obtains details and settings for virtual desktops in published desktop groups.
miq_logger "info" "Collecting Virtual Desktop info"
$results["desktop_vm"] = Get-DesktopVM -isInPool $true -ErrorAction SilentlyContinue

# miq_logger "info" "Collecting Physical Desktop info"
# $results["desktop_physical_machine"] = Get-DesktopPhysicalMachine -ErrorAction SilentlyContinue

# Obtains details for all the current active (including disconnected) user sessions on all desktops in the farm.
# Use the -SessionDetails flag so we collect 'expensive' end-point device information such as name, address and ID,
# display details such as resolution, and connection details such as protocol and encryption settings for XdSession instances.
miq_logger "info" "Collecting Sessions info"
$results["session"] = Get-RemoteSession -ErrorAction SilentlyContinue
# $results["local_session"] = Get-LocalSession -ErrorAction SilentlyContinue
# $results["terminal_server"] = Get-TerminalServer -ErrorAction SilentlyContinue

miq_logger "info" "Collecting User info"
$results["user"] = @{}
$results["desktop_vm"] | ForEach-Object {
	if (($_.user_sid.length -ne 0) -and ($_.user_displayname -ne $null)) {
		$results["user"][$_.user_displayname] = $_.user_sid
	}
}
$results["session"] | ForEach-Object {
	if ($_ -ne $null -and $results["user"].Keys -notcontains $_.Username) {
		$usersid = usersid_for_session $_
		$results["user"][$_.Username] = $usersid
	}
}

miq_logger "info" "Data Collection Complete in $($(Get-Date) - $start_time)"

$results
PS_SCRIPT
  end

  def self.detect_script
    <<-PS_SCRIPT
    $result = $false
    $snapin = Get-PSSnapin -Registered -Name VMware.View.Broker -ErrorAction SilentlyContinue
    if ($snapin -ne $null) {$result = $true}
    $result
    PS_SCRIPT
  end

  def self.is_available?
    begin
      result = false
      ps = nil
      if Platform::OS == :win32 && self.pssnapin_registered?
        ps_script = VdiVmwareInventory.detect_script
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

    ps_snapin_reg_keys = %w{SOFTWARE\\Microsoft\\PowerShell\\1\\PowerShellSnapIns\\VMware.View.Broker
                          SOFTWARE\\wow6432node\\Microsoft\\PowerShell\\1\\PowerShellSnapIns\\VMware.View.Broker}

    found = false
    ps_snapin_reg_keys.each do |reg_path|
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
    ps_event_script = File.join(File.expand_path(File.dirname(__FILE__)), "VdiVmwareEvents.ps1")
    ps_log_idr = MiqPowerShell::Daemon.get_log_dir
    File.open(ps_event_script, 'w') {|f| f.write(self.inv_event_watcher_script(interval))}
    command = '-NoLogo -NonInteractive -NoProfile -ExecutionPolicy RemoteSigned'
    command += " -File \"#{ps_event_script}\" \"#{event_folder}\" \"#{ps_log_idr}\""
    pid = MiqPowerShell.execute_async(command)
    $log.info "VdiVmwareInventory.start_event_watcher VMware VDI watcher started with pid <#{pid}>.  Poll interval = <#{interval}>"
    return pid
  end

  def self.stop_process(pinfo)
    Process.kill(9, pinfo[:pid])
  end
end
