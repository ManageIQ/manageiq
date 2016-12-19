module OntapFileShareHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(name element_name caption zone_name operational_status_str instance_id sharing_directory? last_update_status_str)
  end

  def textual_group_relationships
    %i(logical_disk storage_system local_file_system base_storage_extents)
  end

  def textual_group_infrastructure_relationships
    %i(vms hosts datastores)
  end

  def textual_group_smart_management
    %i(tags)
  end

  #
  # Items
  #

  def textual_name
    {:label => _("Name"), :value => @record.evm_display_name}
  end

  def textual_element_name
    {:label => _("Element Name"), :value => @record.element_name}
  end

  def textual_caption
    {:label => _("Caption"), :value => @record.caption}
  end

  def textual_zone_name
    {:label => _("Zone Name"), :value => @record.zone_name}
  end

  def textual_operational_status_str
    {:label => _("Operational Status"), :value => @record.operational_status_str}
  end

  def textual_instance_id
    {:label => _("Instance ID"), :value => @record.instance_id}
  end

  def textual_sharing_directory?
    {:label => _("Sharing Directory"), :value => @record.sharing_directory?}
  end

  def textual_last_update_status_str
    {:label => _("Last Update Status"), :value => @record.last_update_status_str}
  end

  def textual_storage_system
    label = ui_lookup(:table => "ontap_storage_system")
    ss    = @record.storage_system
    h     = {:label => label, :icon => "pficon pficon-volume", :value => (ss.blank? ? _("None") : ss.evm_display_name)}
    if !ss.blank? && role_allows?(:feature => "ontap_storage_system_show")
      h[:title] = _("Show %{label} '%{name}'") % {:label => label, :name => ss.evm_display_name}
      h[:link]  = url_for(:controller => 'ontap_storage_system', :action => 'show', :id => ss.id)
    end
    h
  end

  def textual_local_file_system
    label = ui_lookup(:table => "snia_local_file_system")
    lfs   = @record.file_system
    h     = {:label => label,
             :icon  => "product product-file_share",
             :value => (lfs.blank? ? _("None") : lfs.evm_display_name)}
    if !lfs.blank? && role_allows?(:feature => "snia_local_file_system_show")
      h[:title] = _("Show %{label} '%{name}'") % {:label => label, :name => lfs.evm_display_name}
      # h[:link]  = url_for(:controller => 'snia_local_file_system', :action => 'show', :id => lfs.id)
      h[:link]  = url_for(:action => 'snia_local_file_systems', :id => @record, :show => lfs.id, :db => controller.controller_name)
    end
    h
  end

  def textual_logical_disk
    label = ui_lookup(:table => "ontap_logical_disk")
    ld    = @record.logical_disk
    h     = {:label => label, :icon => "fa fa-hdd-o", :value => (ld.blank? ? _("None") : ld.evm_display_name)}
    if !ld.blank? && role_allows?(:feature => "ontap_logical_disk_show")
      h[:title] = _("Show %{label} '%{name}'") % {:label => label, :name => ld.evm_display_name}
      h[:link]  = url_for(:controller => 'ontap_logical_disk', :action => 'show', :id => ld.id)
    end
    h
  end

  def textual_base_storage_extents
    label = ui_lookup(:tables => "cim_base_storage_extent")
    num   = @record.base_storage_extents_size
    h     = {:label => label, :icon => "pficon pficon-volume", :value => num}
    if num > 0 && role_allows?(:feature => "cim_base_storage_extent_show")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:link]  = url_for(:action => 'cim_base_storage_extents', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_hosts
    label = title_for_hosts
    num   = @record.hosts_size
    h     = {:label => label, :icon => "pficon pficon-screen", :value => num}
    if num > 0 && role_allows?(:feature => "host_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'hosts')
    end
    h
  end

  def textual_datastores
    textual_link(@record.storages,
                 :as   => Storage,
                 :link => url_for(:action => 'show', :id => @record, :display => 'storages'))
  end

  def textual_vms
    textual_link(@record.vms,
                 :as   => Vm,
                 :link => url_for(:action => 'show', :id => @record, :display => 'vms'))
  end
end
