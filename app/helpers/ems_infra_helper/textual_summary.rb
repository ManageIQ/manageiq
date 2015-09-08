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

  #
  # Items
  #

  def textual_hostname
    @ems.hostname
  end

  def textual_ipaddress
    {:label => "Discovered IP Address", :value => @ems.ipaddress}
  end

  def textual_type
    @ems.emstype_description
  end

  def textual_port
    @ems.supports_port? ? {:label => "API Port", :value => @ems.port} : nil
  end

  def textual_cpu_resources
    {:label => "Aggregate #{title_for_host} CPU Resources", :value => mhz_to_human_size(@ems.aggregate_cpu_speed)}
  end

  def textual_memory_resources
    {:label => "Aggregate #{title_for_host} Memory",
     :value => number_to_human_size(@ems.aggregate_memory * 1.megabyte, :precision => 0)}
  end

  def textual_cpus
    {:label => "Aggregate #{title_for_host} CPUs", :value => @ems.aggregate_physical_cpus}
  end

  def textual_cpu_cores
    {:label => "Aggregate #{title_for_host} CPU Cores", :value => @ems.aggregate_logical_cpus}
  end

  def textual_guid
    {:label => "Management Engine GUID", :value => @ems.guid}
  end

  def textual_infrastructure_folders
    return nil if @record.kind_of?(ManageIQ::Providers::Openstack::InfraManager)
    label     = "#{title_for_hosts} & #{title_for_clusters}"
    available = @ems.number_of(:ems_folders) > 0 && @ems.ems_folder_root
    h         = {:label => label, :image => "hosts_and_clusters", :value => available ? "Available" : "N/A"}
    if available
      h[:link]  = url_for(:action => 'show', :id => @ems, :display => 'ems_folders')
      h[:title] = "Show #{label}"
    end
    h
  end

  def textual_folders
    return nil if @record.kind_of?(ManageIQ::Providers::Openstack::InfraManager)
    label     = "VMs & Templates"
    available = @ems.number_of(:ems_folders) > 0 && @ems.ems_folder_root
    h         = {:label => label, :image => "vms_and_templates", :value => available ? "Available" : "N/A"}
    if available
      h[:link]  = url_for(:action => 'show', :id => @ems, :display => 'ems_folders', :vat => true)
      h[:title] = "Show Virtual Machines & Templates"
    end
    h
  end

  def textual_clusters
    label = title_for_clusters
    num   = @ems.number_of(:ems_clusters)
    h     = {:label => label, :image => "cluster", :value => num}
    if num > 0 && role_allows(:feature => "ems_cluster_show_list")
      h[:link] = url_for(:action => 'show', :id => @ems, :display => 'ems_clusters')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_hosts
    label = title_for_hosts
    num   = @ems.number_of(:hosts)
    h     = {:label => label, :image => "host", :value => num}
    if num > 0 && role_allows(:feature => "host_show_list")
      h[:link]  = url_for(:action => 'show', :id => @ems, :display => 'hosts')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_used_tenants
    return nil if !@record.respond_to?(:cloud_tenants) || !@record.cloud_tenants

    textual_link(@record.cloud_tenants,
                 :as   => CloudTenant,
                 :link => url_for(:action => 'show', :id => @record, :display => 'cloud_tenants'))
  end

  def textual_used_availability_zones
    return nil if !@record.respond_to?(:availability_zones) || !@record.availability_zones

    textual_link(@record.availability_zones,
                 :as   => AvailabilityZone,
                 :link => url_for(:action => 'show', :id => @record, :display => 'availability_zones'))
  end

  def textual_datastores
    return nil if @record.kind_of?(ManageIQ::Providers::Openstack::InfraManager)

    textual_link(@record.storages,
                 :as   => Storage,
                 :link => url_for(:action => 'show', :id => @record, :display => 'storages'))
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
    return [{:label => "Default Authentication", :title => "None", :value => "None"}] if authentications.blank?

    authentications.collect do |auth|
      label =
        case auth.authtype
        when "default"; "Default"
        when "metrics"; "C & U Database"
        else;           "<Unknown>"
        end

      {:label => "#{label} Credentials", :value => auth.status || "None", :title => auth.status_details}
    end
  end

  def textual_orchestration_stacks_status
    return nil if !@ems.respond_to?(:orchestration_stacks) || !@ems.orchestration_stacks

    label         = "States of Root Orchestration Stacks"
    stacks_states = @ems.direct_orchestration_stacks.collect { |x| "#{x.name} status: #{x.status}" }.join(", ")

    {:label => label, :value => stacks_states}
  end

  def textual_orchestration_stacks
    return nil if !@ems.respond_to?(:orchestration_stacks)

    @ems.orchestration_stacks
  end

  def textual_refresh_status
    last_refresh_status = @ems.last_refresh_status.titleize
    if @ems.last_refresh_date
      last_refresh_date = time_ago_in_words(@ems.last_refresh_date.in_time_zone(Time.zone)).titleize
      last_refresh_status << " - #{last_refresh_date} Ago"
    end
    {
      :label => "Last Refresh",
      :value => [{:value => last_refresh_status},
                 {:value => @ems.last_refresh_error.try(:truncate, 120)}],
      :title => @ems.last_refresh_error
    }
  end

  def textual_zone
    {:label => "Managed by Zone", :image => "zone", :value => @ems.zone.name}
  end

  def textual_host_default_vnc_port_range
    return nil unless @ems.is_a?(ManageIQ::Providers::Vmware::InfraManager)
    value = @ems.host_default_vnc_port_start.blank? ?
        "" :
        "#{@ems.host_default_vnc_port_start} - #{@ems.host_default_vnc_port_end}"
    {:label => "#{title_for_host} Default VNC Port Range", :value => value}
  end

end
