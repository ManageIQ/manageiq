class GraphicalSummaryPresenter < SummaryPresenter
  def call_items(items)
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_advanced_settings
    num = @record.number_of(:advanced_settings)
    h = {:label => "Advanced Settings", :image => "advancedsetting", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'advanced_settings', :id => @record, :db => controller.controller_name}, :remote => @explorer, :title => "Show the #{pluralize(num, 'Advanced Setting')} on this VM")
    end
    h
  end

  def graphical_analyzed
    h = {:label => "Analyzed", :image => "extract"}
    h[:value] = @record.last_sync_on.nil? ? "Never" : "#{time_ago_in_words(@record.last_sync_on.in_time_zone(Time.zone)).titleize} Ago"
    h
  end

  def graphical_compliance_history
    h = {:image => "compliance_history"}
    if @record.number_of(:compliances) == 0
      h[:label] = "Compliance History"
      h[:value] = "Not Available"
    else
      h[:label] = "#{"Non-" unless @record.last_compliance_status}Compliance History"
      h[:value] = "Available"
      h[:link]  = link_to("", {:action => 'show', :id => @record, :display => 'compliance_history'}, :remote => @explorer, :title => "Show Compliance History of this VM (Last 10 Checks)")
    end
    h
  end

  def graphical_compliance_status
    h = {:image => "compliance"}
    if @record.number_of(:compliances) == 0
      h[:label] = "Compliance Status"
      h[:value] = "Never Verified"
    else
      h[:label] = "#{"Non-" unless @record.last_compliance_status}Compliance Status"
      h[:value] = "#{time_ago_in_words(@record.last_compliance.timestamp.in_time_zone(Time.zone)).titleize} Ago"
      h[:link]  = link_to("", {:action => 'show', :id => @record, :display => 'compliance_history'}, :remote => @explorer, :title => "Show Compliance History of this VM (Last 10 Checks)")
    end
    h
  end

  def graphical_container
    h = {:label => "Container"}
    vendor = @record.vendor
    if vendor.blank?
      h[:value] = "None"
    else
      h[:image] = vendor.downcase
      h[:value] = "#{vendor} (#{pluralize(@record.num_cpu, 'CPU')}, #{@record.mem_cpu} MB)"
      h[:link]  = link_to("", {:action => 'show', :id => @record, :display => 'hv_info'}, :remote => @explorer, :title => "Show VMM container information")
    end
    h
  end

  def graphical_discovered
    {:label => "Discovered", :image => "discovered", :value => "#{time_ago_in_words(@record.created_on.in_time_zone(Time.zone)).titleize} Ago"}
  end

  def graphical_drift
    return nil unless role_allows(:feature => "vm_drift")
    h = {:label => "Drift History", :image => "drift"}
    num = @record.number_of(:drift_states)
    if num == 0
      h[:value] = "None"
    else
      h[:value] = num
      h[:link]  = link_to("", {:action => 'drift_history', :id => @record}, :remote => @explorer, :title => "Show virtual machine drift history")
    end
    h
  end

  def graphical_event_logs
    num = @record.operating_system.nil? ? 0 : @record.operating_system.number_of(:event_logs)
    h = {:label => "Event Logs", :image => "event_logs", :value => (num == 0 ? "Not Available" : "Available")}
    if num > 0
      h[:link] = link_to("", {:action => 'event_logs', :id => @record}, :remote => @explorer, :title => "Show event logs on this VM")
    end
    h
  end

  def graphical_filesystem_drivers
    os = @record.os_image_name.downcase
    return nil if os == "unknown" || os =~ /linux/
    num = @record.number_of(:filesystem_drivers)
    h = {:label => "File System Drivers", :image => "filesystem_driver", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'filesystem_drivers', :id => @record}, :remote => @explorer, :title => "Show the #{pluralize(num, 'File System Driver')} installed on this VM")
    end
    h
  end

  def graphical_filesystems
    num = @record.number_of(:filesystems)
    h = {:label => "Files", :image => "filesystems", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'filesystems', :id => @record}, :title => "Show the #{pluralize(num, 'File')} installed on this VM")
    end
    h
  end

  def graphical_group_diagnostics
    items = %w{processes event_logs}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_group_lifecycle
    items = %w{discovered analyzed retirement_date}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_group_security
    items = %w{users groups patches}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_groups
    num = @record.number_of(:groups)
    h = {:label => "Groups", :image => "group", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'groups', :id => @record, :db => controller.controller_name}, :remote => @explorer, :title => "Show the #{pluralize(num, 'group')} defined on this VM")
    end
    h
  end

  def graphical_guest_applications
    os = @record.os_image_name.downcase
    return nil if os == "unknown"
    label = (os =~ /linux/) ? "Package" : "Application"
    num = @record.number_of(:guest_applications)
    h = {:label => label.pluralize, :image => "guest_application", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'guest_applications', :id => @record}, :remote => @explorer, :title => "Show the #{pluralize(num, label)} installed on this VM")
    end
    h
  end

  def graphical_init_processes
    os = @record.os_image_name.downcase
    return nil unless os =~ /linux/
    num = @record.number_of(:linux_initprocesses)
    h = {:label => "Init Processes", :image => "linuxinitprocesses", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'linux_initprocesses', :id => @record}, :remote => @explorer, :title => "Show the #{pluralize(num, 'Init Process')} installed on this VM")
    end
    h
  end

  def graphical_kernel_drivers
    os = @record.os_image_name.downcase
    return nil if os == "unknown" || os =~ /linux/
    num = @record.number_of(:kernel_drivers)
    h = {:label => "Kernel Drivers", :image => "kernel_driver", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'kernel_drivers', :id => @record}, :remote => @explorer, :title => "Show the #{pluralize(num, 'Kernel Driver')} installed on this VM")
    end
    h
  end

  def graphical_osinfo
    h = {:label => "OS", :image => @record.os_image_name.downcase}
    os = @record.operating_system.nil? ? nil : @record.operating_system.product_name
    if os.blank?
      h[:value] = "Unknown"
    else
      h[:value] = os.truncate(20)
      h[:link]  = link_to("", {:action => 'show', :id => @record, :display => 'os_info'}, :remote => @explorer, :title => "Show VM OS information '#{os}'")
    end
    h
  end

  def graphical_patches
    os = @record.os_image_name.downcase
    return nil if os == "unknown" || os =~ /linux/
    num = @record.number_of(:patches)
    h = {:label => "Patches", :image => "patch", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'patches', :id => @record, :db => controller.controller_name}, :remote => @explorer, :title => "Show the #{pluralize(num, 'Patch')} defined on this VM")
    end
    h
  end

  def graphical_power_state
    state = @record.current_state.to_s.downcase
    state = "unknown" if state.blank?
    h = {:label => "Power State", :value => state}
    h[:image] = @record.template? ? (@record.host ? "template" : "template-no-host") : state
    h
  end

  def graphical_processes
    h = {:label => "Running Processes", :image => "processes"}
    date = last_date(:processes)
    if date.nil?
      h[:value] = "Not Available"
    else
      # TODO: Why does this date differ in style from the compliance one?
      h[:value] = "From #{time_ago_in_words(date.in_time_zone(Time.zone)).titleize} Ago"
      h[:link]  = link_to("", {:action => 'processes', :id => @record}, :remote => @explorer, :title => "Show the last Collected Running Processes for this VM")
    end
    h
  end

  def graphical_registry_items
    os = @record.os_image_name.downcase
    return nil if os == "unknown" || os =~ /linux/
    num = @record.number_of(:registry_items)
    # TODO: Why is this label different from the link hover text?
    h = {:label => "Registry Entries", :image => "registry_item", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'registry_items', :id => @record}, :remote => @explorer, :title => "Show the #{pluralize(num, 'Registry Item')} installed on this VM")
    end
    h
  end

  def graphical_retirement_date
    {:label => "Retirement Date", :image => "retirement_date", :value => (@record.retires_on.nil? ? "Never" : @record.retires_on.to_time.strftime("%x"))}
  end

  def graphical_scan_history
    # TODO: Why is this image different than textual?
    h = {:label => "Analysis History", :image => "extract"}
    num = @record.number_of(:scan_histories)
    if num == 0
      h[:value] = "None"
    else
      h[:value] = num
      h[:link]  = link_to("", {:action => 'scan_histories', :id => @record}, :remote => @explorer, :title => "Show virtual machine analysis history")
    end
    h
  end

  def graphical_smart
    @record.smart? ? {:label => "Smart", :image => "smart"} : nil
  end

  def graphical_users
    num = @record.number_of(:users)
    h = {:label => "Users", :image => "user", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'users', :id => @record, :db => controller.controller_name}, :remote => @explorer, :title => "Show the #{pluralize(num, 'user')} defined on this VM")
    end
    h
  end

  def graphical_win32_services
    os = @record.os_image_name.downcase
    return nil if os == "unknown" || os =~ /linux/
    num = @record.number_of(:win32_services)
    h = {:label => "Win32 Services", :image => "win32service", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'win32_services', :id => @record}, :remote => @explorer, :title => "Show the #{pluralize(num, 'Win32 Service')} installed on this VM")
    end
    h
  end

end
