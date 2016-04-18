module EmsInfraHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(hostname ipaddress type port cpu_resources memory_resources cpus cpu_cores guid host_default_vnc_port_range)
  end

  def textual_group_relationships
    %i(infrastructure_folders folders clusters hosts used_tenants used_availability_zones datastores vms templates orchestration_stacks)
  end

  def textual_group_status
    textual_authentications + %i(refresh_status orchestration_stacks_status)
  end

  def textual_group_smart_management
    %i(zone tags)
  end

  def textual_group_topology
  end

  #
  # Items
  #

  def textual_hostname
    @ems.hostname
  end

  def textual_ipaddress
    {:label => _("Discovered IP Address"), :value => @ems.ipaddress}
  end

  def textual_type
    @ems.emstype_description
  end

  def textual_port
    @ems.supports_port? ? {:label => _("API Port"), :value => @ems.port} : nil
  end

  def textual_cpu_resources
    {:label => _("Aggregate %{title} CPU Resources") % {:title => title_for_host},
     :value => mhz_to_human_size(@ems.aggregate_cpu_speed)}
  end

  def textual_memory_resources
    {:label => _("Aggregate %{title} Memory") % {:title => title_for_host},
     :value => number_to_human_size(@ems.aggregate_memory * 1.megabyte, :precision => 0)}
  end

  def textual_cpus
    {:label => _("Aggregate %{title} CPUs") % {:title => title_for_host}, :value => @ems.aggregate_physical_cpus}
  end

  def textual_cpu_cores
    {:label => _("Aggregate %{title} CPU Cores") % {:title => title_for_host}, :value => @ems.aggregate_cpu_total_cores}
  end

  def textual_guid
    {:label => _("Management Engine GUID"), :value => @ems.guid}
  end

  def textual_infrastructure_folders
    return nil if @record.kind_of?(ManageIQ::Providers::Openstack::InfraManager)
    label     = "#{title_for_hosts} & #{title_for_clusters}"
    available = @ems.number_of(:ems_folders) > 0 && @ems.ems_folder_root
    h         = {:label => label, :image => "hosts_and_clusters", :value => available ? _("Available") : _("N/A")}
    if available
      h[:link]  = ems_infra_path(@ems.id, :display => 'ems_folders')
      h[:title] = _("Show %{label}") % {:label => label}
    end
    h
  end

  def textual_folders
    return nil if @record.kind_of?(ManageIQ::Providers::Openstack::InfraManager)
    label     = _("VMs & Templates")
    available = @ems.number_of(:ems_folders) > 0 && @ems.ems_folder_root
    h         = {:label => label, :image => "vms_and_templates", :value => available ? _("Available") : _("N/A")}
    if available
      h[:link]  = ems_infra_path(@ems.id, :display => 'ems_folders', :vat => true)
      h[:title] = _("Show Virtual Machines & Templates")
    end
    h
  end

  def textual_clusters
    label = title_for_clusters
    num   = @ems.number_of(:ems_clusters)
    h     = {:label => label, :image => "cluster", :value => num}
    if num > 0 && role_allows(:feature => "ems_cluster_show_list")
      h[:link] = ems_infra_path(@ems.id, :display => 'ems_clusters', :vat => true)
      h[:title] = _("Show all %{label}") % {:label => label}
    end
    h
  end

  def textual_hosts
    label = title_for_hosts
    num   = @ems.number_of(:hosts)
    h     = {:label => label, :image => "host", :value => num}
    if num > 0 && role_allows(:feature => "host_show_list")
      h[:link]  = ems_infra_path(@ems.id, :display => 'hosts')
      h[:title] = _("Show all %{label}") % {:label => label}
    end
    h
  end

  def textual_used_tenants
    return nil if !@record.respond_to?(:cloud_tenants) || !@record.cloud_tenants

    textual_link(@record.cloud_tenants,
                 :as   => CloudTenant,
                 :link => ems_infra_path(@record.id, :display => 'cloud_tenants'))
  end

  def textual_used_availability_zones
    return nil if !@record.respond_to?(:availability_zones) || !@record.availability_zones

    textual_link(@record.availability_zones,
                 :as   => AvailabilityZone,
                 :link => ems_infra_path(@record.id, :display => 'availability_zones'))
  end

  def textual_datastores
    return nil if @record.kind_of?(ManageIQ::Providers::Openstack::InfraManager)

    textual_link(@record.storages,
                 :as   => Storage,
                 :link => ems_infra_path(@record.id, :display => 'storages'))
  end

  def textual_vms
    return nil if @record.kind_of?(ManageIQ::Providers::Openstack::InfraManager)

    textual_link(@ems.vms)
  end

  def textual_templates
    @ems.miq_templates
  end

  def textual_authentications
    authentications = @ems.authentication_userid_passwords
    return [{:label => _("Default Authentication"), :title => t = _("None"), :value => t}] if authentications.blank?

    authentications.collect do |auth|
      label =
        case auth.authtype
        when "default" then _("Default")
        when "metrics" then _("C & U Database")
        when "amqp" then    _("AMQP")
        else;               _("<Unknown>")
        end

      {:label => _("%{label} Credentials") % {:label => label},
       :value => auth.status || _("None"),
       :title => auth.status_details}
    end
  end

  def textual_orchestration_stacks_status
    return nil if !@ems.respond_to?(:orchestration_stacks) || !@ems.orchestration_stacks

    label         = _("States of Root Orchestration Stacks")
    stacks_states = @ems.direct_orchestration_stacks.collect { |x| "#{x.name} status: #{x.status}" }.join(", ")

    {:label => label, :value => stacks_states}
  end

  def textual_orchestration_stacks
    return nil unless @ems.respond_to?(:orchestration_stacks)

    @ems.orchestration_stacks
  end

  def textual_refresh_status
    last_refresh_status = @ems.last_refresh_status.titleize
    if @ems.last_refresh_date
      last_refresh_date = time_ago_in_words(@ems.last_refresh_date.in_time_zone(Time.zone)).titleize
      last_refresh_status << " - #{last_refresh_date} Ago"
    end
    {
      :label => _("Last Refresh"),
      :value => [{:value => last_refresh_status},
                 {:value => @ems.last_refresh_error.try(:truncate, 120)}],
      :title => @ems.last_refresh_error
    }
  end

  def textual_zone
    {:label => _("Managed by Zone"), :image => "zone", :value => @ems.zone.name}
  end

  def textual_host_default_vnc_port_range
    return nil unless @ems.kind_of?(ManageIQ::Providers::Vmware::InfraManager)
    value = @ems.host_default_vnc_port_start.blank? ?
        "" :
        "#{@ems.host_default_vnc_port_start} - #{@ems.host_default_vnc_port_end}"
    {:label => _("%{title} Default VNC Port Range") % {:title => title_for_host}, :value => value}
  end
end
