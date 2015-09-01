module EmsCloudHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(provider_region hostname ipaddress type port guid)
  end

  def textual_group_relationships
    %i(ems_infra availability_zones cloud_tenants flavors security_groups instances images orchestration_stacks)
  end

  def textual_group_status
    textual_authentications + %i(refresh_status)
  end

  def textual_group_smart_management
    %i(zone tags)
  end

  #
  # Items
  #
  def textual_provider_region
    return nil if @ems.provider_region.nil?
    {:label => "Region", :value => @ems.description }
  end

  def textual_hostname
    @ems.hostname
  end

  def textual_ipaddress
    return nil if @ems.kind_of?(ManageIQ::Providers::Amazon::CloudManager)
    {:label => "Discovered IP Address", :value => @ems.ipaddress}
  end

  def textual_type
    @ems.emstype_description
  end

  def textual_port
    @ems.supports_port? ? {:label => "API Port", :value => @ems.port} : nil
  end

  def textual_guid
    {:label => "Management Engine GUID", :value => @ems.guid}
  end

  def textual_instances
    label = ui_lookup(:tables=>"vm_cloud")
    num   = @ems.number_of(:vms)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link]  = url_for(:action => 'show', :id => @ems, :display => 'instances')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_images
    label = ui_lookup(:tables=>"template_cloud")
    num = @ems.number_of(:miq_templates)
    h = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "miq_template_show_list")
      h[:link]  = url_for(:action => 'show', :id => @ems, :display => 'images')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_ems_infra
    textual_link(@record.try(:provider).try(:infra_ems), :as => EmsInfra)
  end

  def textual_availability_zones
    @record.availability_zones
  end

  def textual_cloud_tenants
    @record.cloud_tenants
  end

  def textual_orchestration_stacks
    @record.orchestration_stacks
  end

  def textual_flavors
    @record.flavors
  end

  def textual_security_groups
    @record.security_groups
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
end
