module StorageHelper::GraphicalSummary
  #
  # Groups
  #

  def graphical_group_properties
    items = %w{store_type free_used_space}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_group_relationships
    items = %w{hosts managed_vms managed_miq_templates registered_vms unregistered_vms unmanaged_vms}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_group_content
    return nil if @record["total_space"].nil?
    items = %w{files disk_files snapshot_files vm_ram_files vm_misc_files debris_files}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_group_storage_relationships
    items = %w{storage_systems storage_volumes logical_disk file_share}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_store_type
    value = @record.store_type.nil? ? "unknown" : @record.store_type
    {:label => "#{ui_lookup(:table=>"storages")} Type", :image=>value.downcase , :value => value}
  end

  def graphical_free_used_space
    space_percent = (@record.free_space_percent_of_total.to_i + 4) / 5
    total_space = number_to_human_size(@record["total_space"],:precision=>1)
    {:label => ["Free","Used"], :image=>["summary_screen_freespace","summary_screen_usedspace"] , :space_percent => space_percent, :total_space => total_space,
        :value => [number_to_human_size(@record.free_space,:precision=>1),number_to_human_size(@record.used_space,:precision=>1)]}

  end

  def graphical_hosts
    label = "Hosts"
    num = @record.number_of(:hosts)
    h = {:label => label, :image => "host", :value => num}
    if num > 0 && role_allows(:feature => "host_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => 'hosts'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_managed_vms
    label = "Managed VMs"
    num   = @record.number_of(:all_vms)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => 'all_vms'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_managed_miq_templates
    label = "Managed #{ui_lookup(:tables=>"miq_template")}"
    num   = @record.number_of(:all_miq_templates)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "miq_template_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => 'all_miq_templates'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_unmanaged_vms
    label = "Unmanaged VMs"
    num   = @record.number_of(:total_unmanaged_vms)
    {:label => label, :image => "vm", :value => num}
  end

  def graphical_registered_vms
    label = "Managed / Registered VMs"
    num   = @record.number_of(:total_managed_registered_vms)
    {:label => label, :image => "vm", :value => num}
  end

  def graphical_unregistered_vms
    label = "Managed / UnRegistered VMs"
    num   = @record.number_of(:total_managed_unregistered_vms)
    {:label => label, :image => "vm", :value => num}
  end

  def graphical_files
    label = "Files"
    num = @record.number_of(:files)
    h = {:label => label, :image => "storage_files", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'files', :id => @record},
          :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_disk_files
    label = "Disk Files"
    num = @record.number_of(:disk_files)
    h = {:label => label, :image => "storage_disk_files", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'disk_files', :id => @record},
          :title => "Show VM Provisioned Disk Files on this #{ui_lookup(:table=>"storages")}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_snapshot_files
    label = "Snapshot Files"
    num = @record.number_of(:snapshot_files)
    h = {:label => label, :image => "storage_snapshot_files", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'snapshot_files', :id => @record},
          :title => "Show VM snapshot files on this #{ui_lookup(:table=>"storages")}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_vm_ram_files
    label = "Memory Files"
    num = @record.number_of(:vm_ram_files)
    h = {:label => label, :image => "storage_memory_files", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'vm_ram_files', :id => @record},
          :title => "Show VM memory files on this #{ui_lookup(:table=>"storages")}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_vm_misc_files
    label = "Other VM Files"
    num = @record.number_of(:vm_misc_files)
    h = {:label => label, :image => "storage_other_vm_files", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'vm_misc_files', :id => @record},
          :title => "Show other VM files on this #{ui_lookup(:table=>"storages")}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_debris_files
    label = "Non-VM Files"
    num = @record.number_of(:debris_files)
    h = {:label => label, :image => "storage_non_vm_files", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'debris_files', :id => @record},
          :title => "Show non-VM files on this #{ui_lookup(:table=>"storages")}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_storage_systems
    num   = @record.storage_systems_size
    label = ui_lookup(:tables => "ontap_storage_system")
    h     = {:label => label, :image => "ontap_storage_system", :value => num}
    if num > 0 && role_allows(:feature => "ontap_storage_system_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => "ontap_storage_systems"}, :title => "Show all #{label}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_storage_volumes
    num   = @record.storage_volumes_size
    label = ui_lookup(:tables => "ontap_storage_volume")
    h     = {:label => label, :image => "ontap_storage_volume", :value => num}
    if num > 0 && role_allows(:feature => "ontap_storage_volume_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => "ontap_storage_volumes"}, :title => "Show all #{label}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_logical_disk
    ld = @record.logical_disk
    label = ui_lookup(:table => "ontap_logical_disk")
    h = {:label => label, :image => "ontap_logical_disk", :value => (ld.blank? ? "None" : ld.evm_display_name.truncate(13))}
    if !ld.blank? && role_allows(:feature => "ontap_logical_disk_show")
      h[:link] = link_to("", {:controller => 'ontap_logical_disk', :action => 'show', :id => ld}, :title => "Show #{label} '#{ld.evm_display_name}'")
    end
    h
  end

  def graphical_file_share
    fs = @record.file_share
    label = ui_lookup(:table => "ontap_file_share")
    h = {:label => label, :image => "ontap_file_share", :value => (fs.blank? ? "None" : fs.evm_display_name.truncate(13))}
    if !fs.blank? && role_allows(:feature => "ontap_file_share_show")
      h[:link] = link_to("", {:controller => 'ontap_file_share', :action => 'show', :id => fs}, :title => "Show #{label} '#{fs.evm_display_name}'")
    end
    h
  end
end
