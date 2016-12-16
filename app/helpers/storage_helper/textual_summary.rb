module StorageHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(store_type free_space used_space total_space)
  end

  def textual_group_registered_vms
    %i(uncommitted_space used_uncommitted_space)
  end

  def textual_group_relationships
    %i(hosts managed_vms managed_miq_templates registered_vms unregistered_vms unmanaged_vms)
  end

  def textual_group_storage_relationships
    %i(storage_systems storage_volumes logical_disk file_share)
  end

  def textual_group_smart_management
    %i(tags)
  end

  def textual_group_content
    return nil if @record["total_space"].nil?
    %i(files disk_files snapshot_files vm_ram_files vm_misc_files debris_files)
  end

  #
  # Items
  #

  def textual_store_type
    {:label => _("%{storage} Type") % {:storage => ui_lookup(:table => "storages")}, :value => @record.store_type}
  end

  def textual_free_space
    return nil if @record["free_space"].nil? && @record["total_space"].nil?
    return nil if @record["free_space"].nil?
    {:label => _("Free Space"),
     :value => "#{number_to_human_size(@record["free_space"], :precision => 2)} (#{@record.free_space_percent_of_total}%)"}
  end

  def textual_used_space
    return nil if @record["free_space"].nil? && @record["total_space"].nil?
    {:label => _("Used Space"),
     :value => "#{number_to_human_size(@record.used_space, :precision => 2)} (#{@record.used_space_percent_of_total}%)"}
  end

  def textual_total_space
    return nil if @record["free_space"].nil? && @record["total_space"].nil?
    return nil if @record["total_space"].nil?
    {:label => _("Total Space"), :value => "#{number_to_human_size(@record["total_space"], :precision => 2)} (100%)"}
  end

  def textual_uncommitted_space
    return nil if @record["total_space"].nil?
    space = if @record["uncommitted"].blank?
              _("None")
            else
              number_to_human_size(@record["uncommitted"], :precision => 2)
            end
    {:label => _("Uncommitted Space"), :value => space}
  end

  def textual_used_uncommitted_space
    return nil if @record["total_space"].nil?
    {:label => _("Used + Uncommitted Space"),
     :value => "#{number_to_human_size(@record.v_total_provisioned, :precision => 2)} (#{@record.v_provisioned_percent_of_total}%)"}
  end

  def textual_hosts
    label = title_for_hosts
    num   = @record.number_of(:hosts)
    h     = {:label => label, :icon => "pficon pficon-screen", :value => num}
    if num > 0 && role_allows?(:feature => "host_show_list")
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'hosts')
      h[:title] = _("Show all %{label}") % {:label => label}
    end
    h
  end

  def textual_managed_vms
    label = _("Managed VMs")
    num   = @record.number_of(:all_vms)
    h     = {:label => label, :icon => "pficon pficon-virtual-machine", :value => num}
    if num > 0 && role_allows?(:feature => "vm_show_list")
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'all_vms')
      h[:title] = _("Show all %{label}") % {:label => label}
    end
    h
  end

  def textual_managed_miq_templates
    label = _("Managed %{tables}") % {:tables => ui_lookup(:tables => "miq_template")}
    num   = @record.number_of(:all_miq_templates)
    h     = {:label => label, :icon => "pficon pficon-virtual-machine", :value => num}
    if num > 0 && role_allows?(:feature => "miq_template_show_list")
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'all_miq_templates')
      h[:title] = _("Show all %{label}") % {:label => label}
    end
    h
  end

  def textual_registered_vms
    {:label => _("Managed/Registered VMs"), :icon => "pficon pficon-virtual-machine", :value => @record.total_managed_registered_vms}
  end

  def textual_unregistered_vms
    {:label => _("Managed/Unregistered VMs"), :icon => "pficon pficon-virtual-machine", :value => @record.total_managed_unregistered_vms}
  end

  def textual_unmanaged_vms
    {:label => _("Unmanaged VMs"), :icon => "pficon pficon-virtual-machine", :value => @record.total_unmanaged_vms}
  end

  def textual_storage_systems
    num   = @record.storage_systems_size
    label = ui_lookup(:tables => "ontap_storage_system")
    h     = {:label => label, :icon => "pficon pficon-volume", :value => num}
    if num > 0 && role_allows?(:feature => "ontap_storage_system_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => "ontap_storage_systems")
    end
    h
  end

  def textual_storage_volumes
    num   = @record.storage_volumes_size
    label = ui_lookup(:tables => "ontap_storage_volume")
    h     = {:label => label, :icon => "pficon pficon-volume", :value => num}
    if num > 0 && role_allows?(:feature => "ontap_storage_volume_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => "ontap_storage_volumes")
    end
    h
  end

  def textual_logical_disk
    ld = @record.logical_disk
    label = ui_lookup(:table => "ontap_logical_disk")
    h = {:label => label, :icon => "fa fa-hdd-o", :value => (ld.blank? ? _("None") : ld.evm_display_name)}
    if !ld.blank? && role_allows?(:feature => "ontap_logical_disk_show")
      h[:title] = _("Show this Datastore's %{label}") % {:label => label}
      h[:link]  = url_for(:controller => 'ontap_logical_disk', :action => 'show', :id => ld)
    end
    h
  end

  def textual_file_share
    fs = @record.file_share
    label = ui_lookup(:table => "ontap_file_share")
    h = {:label => label, :icon => "product product-file_share", :value => (fs.blank? ? _("None") : fs.evm_display_name)}
    if !fs.blank? && role_allows?(:feature => "ontap_file_share_show")
      h[:title] = _("Show this Datastore's %{label}") % {:label => label}
      h[:link]  = url_for(:controller => 'ontap_file_share', :action => 'show', :id => fs)
    end
    h
  end

  def textual_files
    num   = @record.number_of(:files)
    h     = {:label => _("All Files"), :icon => "fa fa-file-o", :value => num}
    if num > 0
      h[:title] = _("Show all files installed on this %{table}") % {:table => ui_lookup(:table => "storages")}
      h[:link]  = url_for(:action => 'files', :id => @record)
    end
    h
  end

  def textual_disk_files
    num   = @record.number_of(:disk_files)
    value = num == 0 ? 0 :
                     n_("%{number} (%{percentage} of Used Space, %{amount} file)",
                        "%{number} (%{percentage} of Used Space, %{amount} files)",
                        @record.number_of(:disk_files)) %
                       {:number     => number_to_human_size(@record.v_total_disk_size, :precision => 2),
                        :percentage => @record.v_disk_percent_of_used.to_s + "%",
                        :amount     => @record.number_of(:disk_files)}

    h     = {:label => _("VM Provisioned Disk Files"), :icon => "fa fa-file-o", :value => value}
    if num > 0
      h[:title] = _("Show VM Provisioned Disk Files installed on this %{table}") %
                  {:table => ui_lookup(:table => "storages")}
      h[:link]  = url_for(:action => 'disk_files', :id => @record)
    end
    h
  end

  def textual_snapshot_files
    num   = @record.number_of(:snapshot_files)
    value = num == 0 ? 0 :
                    n_("%{number} (%{percentage} of Used Space, %{amount} file)",
                       "%{number} (%{percentage} of Used Space, %{amount} files)",
                       @record.number_of(:snapshot_files)) %
                    {:number     => number_to_human_size(@record.v_total_snapshot_size, :precision => 2),
                     :percentage => @record.v_snapshot_percent_of_used.to_s + "%",
                     :amount     => @record.number_of(:snapshot_files)}
    h     = {:label => _("VM Snapshot Files"), :icon => "fa fa-file-o", :value => value}
    if num > 0
      h[:title] = _("Show VM Snapshot Files installed on this %{storage}") %
                  {:storage => ui_lookup(:table => "storages")}
      h[:link]  = url_for(:action => 'snapshot_files', :id => @record)
    end
    h
  end

  def textual_vm_ram_files
    num   = @record.number_of(:vm_ram_files)
    value = num == 0 ? 0 :
                    n_("%{number} (%{percentage} of Used Space, %{amount} file)",
                       "%{number} (%{percentage} of Used Space, %{amount} files)",
                       @record.number_of(:vm_ram_files)) %
                    {:number     => number_to_human_size(@record.v_total_memory_size, :precision => 2),
                     :percentage => @record.v_memory_percent_of_used.to_s + "%",
                     :amount     => @record.number_of(:vm_ram_files)}
    h     = {:label => _("VM Memory Files"), :icon => "fa fa-file-o", :value => value}
    if num > 0
      h[:title] = _("Show VM Memory Files installed on this %{storage}") % {:storage => ui_lookup(:table => "storages")}
      h[:link]  = url_for(:action => 'vm_ram_files', :id => @record)
    end
    h
  end

  def textual_vm_misc_files
    num   = @record.number_of(:vm_misc_files)
    value = num == 0 ? 0 :
                    n_("%{number} (%{percentage} of Used Space, %{amount} file)",
                       "%{number} (%{percentage} of Used Space, %{amount} files)",
                       @record.number_of(:vm_misc_files)) %
                    {:number     => number_to_human_size(@record.v_total_vm_misc_size, :precision => 2),
                     :percentage => @record.v_vm_misc_percent_of_used.to_s + "%",
                     :amount     => @record.number_of(:vm_misc_files)}
    h     = {:label => _("Other VM Files"), :icon => "fa fa-file-o", :value => value}
    if num > 0
      h[:title] = _("Show Other VM Files installed on this %{storage}") % {:storage => ui_lookup(:table => "storages")}
      h[:link]  = url_for(:action => 'vm_misc_files', :id => @record)
    end
    h
  end

  def textual_debris_files
    num   = @record.number_of(:debris_files)
    value = num == 0 ? 0 :
                    n_("%{number} (%{percentage} of Used Space, %{amount} file)",
                       "%{number} (%{percentage} of Used Space, %{amount} files)",
                       @record.number_of(:debris_files)) %
                    {:number     => number_to_human_size(@record.v_total_debris_size, :precision => 2),
                     :percentage => @record.v_debris_percent_of_used.to_s + "%",
                     :amount     => @record.number_of(:debris_files)}
    h     = {:label => _("Non-VM Files"), :icon => "fa fa-file-o", :value => value}
    if num > 0
      h[:title] = _("Show Non-VM Files installed on this %{storage}") % {:storage => ui_lookup(:table => "storages")}
      h[:link]  = url_for(:action => 'debris_files', :id => @record)
    end
    h
  end
end
