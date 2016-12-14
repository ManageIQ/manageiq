module EmsClusterHelper::TextualSummary
  include TextualMixins::TextualGroupTags
  #
  # Groups
  #

  def textual_group_host_totals
    %i(aggregate_cpu_speed aggregate_memory aggregate_physical_cpus aggregate_cpu_total_cores aggregate_disk_capacity block_storage_disk_usage object_storage_disk_usage)
  end

  def textual_group_vm_totals
    %i(aggregate_vm_memory aggregate_vm_cpus)
  end

  def textual_group_relationships
    %i(ems parent_datacenter total_hosts total_direct_vms allvms_size total_miq_templates total_vms rps_size states_size)
  end

  def textual_group_storage_relationships
    %i(ss_size sv_size fs_size se_size)
  end

  def textual_group_configuration
    return nil if @record.ha_enabled.nil? && @record.ha_admit_control.nil? && @record.drs_enabled.nil? &&
                  @record.drs_automation_level.nil? && @record.drs_migration_threshold.nil?
    %i(ha_enabled ha_admit_control drs_enabled drs_automation_level drs_migration_threshold)
  end

  def textual_group_openstack_status
    return nil unless @record.kind_of?(ManageIQ::Providers::Openstack::InfraManager::EmsCluster)
    ret = textual_generate_openstack_status

    ret.blank? ? nil : ret
  end

  #
  # Items
  #

  def textual_generate_openstack_status
    @record.service_group_names.collect do |x|
      running_count = @record.host_ids_with_running_service_group(x.name).count
      failed_count  = @record.host_ids_with_failed_service_group(x.name).count
      all_count     = @record.host_ids_with_service_group(x.name).count

      running = {:title => _("Show list of hosts with running %{name}") % {:name => x.name},
                 :value => _("Running (%{number})") % {:number => running_count},
                 :image => failed_count == 0 && running_count > 0 ? '100/status_complete.png' : nil,
                 :link  => if running_count > 0
                             url_for(:controller              => controller.controller_name,
                                     :action                  => 'show',
                                     :id                      => @record,
                                     :display                 => 'hosts',
                                     :host_service_group_name => x.name,
                                     :status                  => :running)
                           end}

      failed = {:title => _("Show list of hosts with failed %{name}") % {:name => x.name},
                :value => _("Failed (%{number})") % {:number => failed_count},
                :image => failed_count > 0 ? '100/status_error.png' : nil,
                :link  => if failed_count > 0
                            url_for(:controller              => controller.controller_name,
                                    :action                  => 'show',
                                    :id                      => @record,
                                    :display                 => 'hosts',
                                    :host_service_group_name => x.name,
                                    :status                  => :failed)
                          end}

      all = {:title => _("Show list of hosts with %{name}") % {:name => x.name},
             :value => _("All (%{number})") % {:number => all_count},
             :image => '100/host.png',
             :link  => if all_count > 0
                         url_for(:controller              => controller.controller_name,
                                 :action                  => 'show',
                                 :display                 => 'hosts',
                                 :id                      => @record,
                                 :host_service_group_name => x.name,
                                 :status                  => :all)
                       end}

      sub_items = [running, failed, all]

      {:value => x.name, :sub_items => sub_items}
    end
  end

  def textual_aggregate_cpu_speed
    {:label => _("Total CPU Resources"), :value => mhz_to_human_size(@record.aggregate_cpu_speed).to_s}
  end

  def textual_aggregate_memory
    {:label => _("Total Memory"), :value => number_to_human_size(@record.aggregate_memory.megabytes, :precision => 2)}
  end

  def textual_aggregate_physical_cpus
    {:label => _("Total CPUs"), :value => number_with_delimiter(@record.aggregate_physical_cpus)}
  end

  def textual_aggregate_cpu_total_cores
    {:label => _("Total %{title} CPU Cores") % {:title => title_for_host},
     :value => number_with_delimiter(@record.aggregate_cpu_total_cores)}
  end

  def textual_aggregate_vm_memory
    {:label => _("Total Configured Memory"),
     :value => _("%{number} (Virtual to Real Ratio: %{ratio})") %
       {:number => number_to_human_size(@record.aggregate_vm_memory.megabytes, :precision => 2),
        :ratio  => @record.v_ram_vr_ratio.round(2)}}
  end

  def textual_aggregate_vm_cpus
    {:label => _("Total Configured CPUs"),
     :value => _("%{number} (Virtual to Real Ratio: %{ratio})") %
       {:number => number_with_delimiter(@record.aggregate_vm_cpus),
        :ratio  => @record.v_cpu_vr_ratio.round(2)}}
  end

  def textual_ems
    textual_link(@record.ext_management_system)
  end

  def textual_parent_datacenter
    {:label => _("Datacenter"), :image => "100/datacenter.png", :value => @record.v_parent_datacenter || _("None")}
  end

  def textual_total_hosts
    num = @record.total_hosts
    h = {:label => title_for_hosts, :image => "100/host.png", :value => num}
    if num > 0 && role_allows?(:feature => "host_show_list")
      h[:title] = _("Show all %{title}") % {:title => title_for_hosts}
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'show', :id => @record, :display => 'hosts')
    end
    h
  end

  def textual_total_direct_vms
    num = @record.total_direct_vms
    h = {:label => _("Direct VMs"), :image => "100/vm.png", :value => num}
    if num > 0 && role_allows?(:feature => "vm_show_list")
      h[:title] = _("Show VMs in this %{title}, but not in Resource Pools below") % {:title => cluster_title}
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'show', :id => @record, :display => 'vms')
    end
    h
  end

  def textual_allvms_size
    num = @record.total_vms
    h = {:label => _("All VMs"), :image => "100/vm.png", :value => num}
    if num > 0 && role_allows?(:feature => "vm_show_list")
      h[:title] = _("Show all VMs in this %{title}") % {:title => cluster_title}
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'show', :id => @record, :display => 'all_vms')
    end
    h
  end

  def textual_total_miq_templates
    return nil if @record.kind_of?(ManageIQ::Providers::Openstack::InfraManager::EmsCluster)

    num = @record.total_miq_templates
    h = {:label => _("All Templates"), :image => "100/vm.png", :value => num}
    if num > 0 && role_allows?(:feature => "miq_template_show_list")
      h[:title] = _("Show all Templates in this %{title}") % {:title => cluster_title}
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'show', :id => @record, :display => 'miq_templates')
    end
    h
  end

  def textual_total_vms
    num = @record.total_vms
    h = {:label => _("All VMs (Tree View)"), :image => "100/vm.png", :value => num}
    if num > 0 && role_allows?(:feature => "vm_show_list")
      h[:title] = _("Show tree of all VMs by Resource Pool in this %{title}") % {:title => cluster_title}
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'show', :id => @record, :display => 'descendant_vms')
    end
    h
  end

  def textual_rps_size
    return nil if @record.kind_of?(ManageIQ::Providers::Openstack::InfraManager::EmsCluster)

    textual_link(@record.resource_pools,
                 :as   => EmsCluster,
                 :link => url_for(:controller => 'ems_cluster', :action => 'show', :id => @record, :display => 'resource_pools'))
  end

  def textual_states_size
    return nil unless role_allows?(:feature => "ems_cluster_drift")
    num = @record.number_of(:drift_states)
    h = {:label => _("Drift History"), :image => "100/drift.png", :value => (num == 0 ? _("None") : num)}
    if num > 0
      h[:title] = _("Show %{title} drift history") % {:title => cluster_title}
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'drift_history', :id => @record)
    end
    h
  end

  def textual_ss_size
    num = @record.storage_systems.count
    label = ui_lookup(:tables => "ontap_storage_system")
    h = {:label => label, :image => "100/ontap_storage_system.png", :value => num}
    if num > 0 && role_allows?(:feature => "ontap_storage_system_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'show', :id => @record, :display => 'storage_systems')
    end
    h
  end

  def textual_sv_size
    num = @record.storage_systems.count
    label = ui_lookup(:tables => "ontap_storage_volume")
    h = {:label => label, :image => "100/ontap_storage_volume.png", :value => num}
    if num > 0 && role_allows?(:feature => "ontap_storage_system_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'show', :id => @record, :display => 'ontap_storage_volumes')
    end
    h
  end

  def textual_fs_size
    num = @record.file_shares.count
    label = ui_lookup(:tables => "ontap_file_share")
    h = {:label => label, :image => "100/ontap_file_share.png", :value => num}
    if num > 0 && role_allows?(:feature => "ontap_file_share_show_list")
      h[:title] = label
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'show', :id => @record, :display => 'ontap_file_shares')
    end
    h
  end

  def textual_se_size
    num = @record.base_storage_extents.count
    label = ui_lookup(:tables => "cim_base_storage_extent")
    h = {:label => label, :image => "100/cim_base_storage_extent.png", :value => num}
    if num > 0 && role_allows?(:feature => "cim_base_storage_extent_show_list")
      h[:title] = label
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'show', :id => @record, :display => 'storage_extents')
    end
    h
  end

  def textual_ha_enabled
    value = @record.ha_enabled
    return nil if value.nil?
    {:label => _("HA Enabled"), :value => value}
  end

  def textual_ha_admit_control
    value = @record.ha_admit_control
    return nil if value.nil?
    {:label => _("HA Admit Control"), :value => value}
  end

  def textual_drs_enabled
    value = @record.drs_enabled
    return nil if value.nil?
    {:label => _("DRS Enabled"), :value => value}
  end

  def textual_drs_automation_level
    value = @record.drs_automation_level
    return nil if value.nil?
    {:label => _("DRS Automation Level"), :value => value}
  end

  def textual_drs_migration_threshold
    value = @record.drs_migration_threshold
    return nil if value.nil?
    {:label => _("DRS Migration Threshold"), :value => value}
  end

  def textual_aggregate_disk_capacity
    {:value => number_to_human_size(@record.aggregate_disk_capacity.gigabytes, :precision => 2)}
  end

  def textual_block_storage_disk_usage
    return nil unless @record.respond_to?(:block_storage?) && @record.block_storage? && !@record.cloud.nil?
    {:value => number_to_human_size(@record.cloud_block_storage_disk_usage.bytes, :precision => 2)}
  end

  def textual_object_storage_disk_usage
    return nil unless @record.respond_to?(:object_storage?) && @record.object_storage? && !@record.cloud.nil?
    {:value => number_to_human_size(@record.cloud_object_storage_disk_usage.bytes, :precision => 2)}
  end

  def cluster_title
    title_for_cluster_record(@record)
  end
end
