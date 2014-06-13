module StorageHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w{store_type free_space used_space total_space}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_registered_vms
    items = %w{uncommitted_space used_uncommitted_space}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w{hosts managed_vms managed_miq_templates registered_vms unregistered_vms unmanaged_vms}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_storage_relationships
    items = %w{storage_systems storage_volumes logical_disk file_share}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_smart_management
    items = %w{tags}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_content
    return nil if @record["total_space"].nil?
    items = %w{files disk_files snapshot_files vm_ram_files vm_misc_files debris_files}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_store_type
    {:label => "#{ui_lookup(:table=>"storages")} Type", :value => @record.store_type}
  end

  def textual_free_space
    return nil if @record["free_space"].nil? && @record["total_space"].nil?
    return nil if @record["free_space"].nil?
    {:label => "Free Space", :value => "#{number_to_human_size(@record["free_space"],:precision=>2)} (#{@record.free_space_percent_of_total}%)"}
  end

  def textual_used_space
    return nil if @record["free_space"].nil? && @record["total_space"].nil?
    {:label => "Used Space", :value => "#{number_to_human_size(@record.used_space,:precision=>2)} (#{@record.used_space_percent_of_total}%)"}
  end

  def textual_total_space
    return nil if @record["free_space"].nil? && @record["total_space"].nil?
    return nil if @record["total_space"].nil?
    {:label => "Total Space", :value => "#{number_to_human_size(@record["total_space"],:precision=>2)} (100%)"}
  end

  def textual_uncommitted_space
    return nil if @record["total_space"].nil?
    space = @record["uncommitted"].blank? || @record["uncommitted"] == "" ? "None" : number_to_human_size(@record["uncommitted"],:precision=>2)
    {:label => "Uncommitted Space", :value => space}
  end

  def textual_used_uncommitted_space
    return nil if @record["total_space"].nil?
    {:label => "Used + Uncommitted Space", :value => "#{number_to_human_size(@record.v_total_provisioned,:precision=>2)} (#{@record.v_provisioned_percent_of_total}%)"}
  end

  def textual_hosts
    label = "Hosts"
    num   = @record.number_of(:hosts)
    h     = {:label => label, :image => "host", :value => num}
    if num > 0 && role_allows(:feature => "host_show_list")
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'hosts')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_managed_vms
    label = "Managed VMs"
    num   = @record.number_of(:all_vms)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'all_vms')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_managed_miq_templates
    label = "Managed #{ui_lookup(:tables=>"miq_template")}"
    num   = @record.number_of(:all_miq_templates)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "miq_template_show_list")
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'all_miq_templates')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_registered_vms
    {:label => "Managed/Registered VMs", :image=>"vm", :value => @record.total_managed_registered_vms}
  end

  def textual_unregistered_vms
    {:label => "Managed/Unregistered VMs", :image=>"vm", :value => @record.total_managed_unregistered_vms}
  end

  def textual_unmanaged_vms
    {:label => "Unmanaged VMs", :image=>"vm", :value => @record.total_unmanaged_vms}
  end

  def textual_storage_systems
    num   = @record.storage_systems_size
    label = ui_lookup(:tables => "ontap_storage_system")
    h     = {:label => label, :image => "ontap_storage_system", :value => num}
    if num > 0 && role_allows(:feature => "ontap_storage_system_show_list")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => "ontap_storage_systems")
    end
    h
  end

  def textual_storage_volumes
    num   = @record.storage_volumes_size
    label = ui_lookup(:tables => "ontap_storage_volume")
    h     = {:label => label, :image => "ontap_storage_volume", :value => num}
    if num > 0 && role_allows(:feature => "ontap_storage_volume_show_list")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => "ontap_storage_volumes")
    end
    h
  end

  def textual_logical_disk
    ld = @record.logical_disk
    label = ui_lookup(:table => "ontap_logical_disk")
    h = {:label => label, :image => "ontap_logical_disk", :value => (ld.blank? ? "None" : ld.evm_display_name)}
    if !ld.blank? && role_allows(:feature => "ontap_logical_disk_show")
      h[:title] = "Show this Datastore's #{label}"
      h[:link]  = url_for(:controller => 'ontap_logical_disk', :action => 'show', :id => ld)
    end
    h
  end

  def textual_file_share
    fs = @record.file_share
    label = ui_lookup(:table => "ontap_file_share")
    h = {:label => label, :image => "ontap_file_share", :value => (fs.blank? ? "None" : fs.evm_display_name)}
    if !fs.blank? && role_allows(:feature => "ontap_file_share_show")
      h[:title] = "Show this Datastore's #{label}"
      h[:link]  = url_for(:controller => 'ontap_file_share', :action => 'show', :id => fs)
    end
    h
  end

  def textual_files
    label = "All Files"
    num   = @record.number_of(:files)
    h     = {:label => label, :image => "storage_files", :value => num}
    if num > 0
      h[:title] = "Show all files installed on this #{ui_lookup(:table=>"storages")}"
      h[:link]  = url_for(:action => 'files', :id => @record)
    end
    h
  end

  def textual_disk_files
    label = "VM Provisioned Disk Files"
    num   = @record.number_of(:disk_files)
    value = num == 0 ? 0 :
                    "#{number_to_human_size(@record.v_total_disk_size,:precision=>2)} (#{@record.v_disk_percent_of_used}% of Used Space, #{pluralize(@record.number_of(:disk_files),'files')})"
    h     = {:label => label, :image => "storage_disk_files", :value => value}
    if num > 0
      h[:title] = "Show VM Provisioned Disk Files installed on this #{ui_lookup(:table=>"storages")}"
      h[:link]  = url_for(:action => 'disk_files', :id => @record)
    end
    h
  end

  def textual_snapshot_files
    label = "VM Snapshot Files"
    num   = @record.number_of(:snapshot_files)
    value = num == 0 ? 0 :
                    "#{number_to_human_size(@record.v_total_snapshot_size,:precision=>2)} (#{@record.v_snapshot_percent_of_used}% of Used Space, #{pluralize(@record.number_of(:snapshot_files),'files')})"
    h     = {:label => label, :image => "storage_snapshot_files", :value => value}
    if num > 0
      h[:title] = "Show VM Snapshot Files installed on this #{ui_lookup(:table=>"storages")}"
      h[:link]  = url_for(:action => 'snapshot_files', :id => @record)
    end
    h
  end

  def textual_vm_ram_files
    label = "VM Memory Files"
    num   = @record.number_of(:vm_ram_files)
    value = num == 0 ? 0 :
                    "#{number_to_human_size(@record.v_total_memory_size,:precision=>2)} (#{@record.v_memory_percent_of_used}% of Used Space, #{pluralize(@record.number_of(:vm_ram_files),'files')})"
    h     = {:label => label, :image => "storage_memory_files", :value => value}
    if num > 0
      h[:title] = "Show VM Memory Files installed on this #{ui_lookup(:table=>"storages")}"
      h[:link]  = url_for(:action => 'vm_ram_files', :id => @record)
    end
    h
  end

  def textual_vm_misc_files
    label = "Other VM Files"
    num   = @record.number_of(:vm_misc_files)
    value = num == 0 ? 0 :
                    "#{number_to_human_size(@record.v_total_vm_misc_size,:precision=>2)} (#{@record.v_vm_misc_percent_of_used}% of Used Space, #{pluralize(@record.number_of(:vm_misc_files),'files')})"
    h     = {:label => label, :image => "storage_other_vm_files", :value => value}
    if num > 0
      h[:title] = "Show Other VM Files installed on this #{ui_lookup(:table=>"storages")}"
      h[:link]  = url_for(:action => 'vm_misc_files', :id => @record)
    end
    h
  end

  def textual_debris_files
    label = "Non-VM Files"
    num   = @record.number_of(:debris_files)
    value = num == 0 ? 0 :
                    "#{number_to_human_size(@record.v_total_debris_size,:precision=>2)} (#{@record.v_debris_percent_of_used}% of Used Space, #{pluralize(@record.number_of(:debris_files),'files')})"
    h     = {:label => label, :image => "storage_non_vm_files", :value => value}
    if num > 0
      h[:title] = "Show Non-VM Files installed on this #{ui_lookup(:table=>"storages")}"
      h[:link]  = url_for(:action => 'debris_files', :id => @record)
    end
    h
  end

  def textual_tags
    label = "#{session[:customer_name]} Tags"
    h     = {:label => label}
    tags  = session[:assigned_filters]
    if tags.empty?
      h[:image] = "smarttag"
      h[:value] = "No #{label} have been assigned"
    else
      h[:value] = tags.sort_by { |category, assigned| category.downcase }.collect { |category, assigned| {:image => "smarttag", :label => category, :value => assigned } }
    end
    h
  end

end
