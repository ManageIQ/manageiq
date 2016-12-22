module EmsCinderHelper::TextualSummary
  include TextualMixins::TextualRefreshStatus
  #
  # Groups
  #

  def textual_group_properties
    %i(provider_region hostname ipaddress type port guid)
  end

  def textual_group_relationships
    %i(parent_ems_cloud cloud_volumes cloud_volume_snapshots cloud_volume_backups)
  end

  def textual_group_status
    textual_authentications(@record.authentication_for_summary) + %i(refresh_status)
  end

  def textual_group_smart_management
    %i(zone tags)
  end

  def textual_group_topology
  end

  #
  # Items
  #
  def textual_provider_region
    return nil if @record.provider_region.nil?
    {:label => _("Region"), :value => @record.description}
  end

  def textual_hostname
    @record.hostname
  end

  def textual_ipaddress
    return nil if @record.ipaddress.blank?
    {:label => _("Discovered IP Address"), :value => @record.ipaddress}
  end

  def textual_type
    @record.emstype_description
  end

  def textual_port
    @record.supports_port? ? {:label => _("API Port"), :value => @record.port} : nil
  end

  def textual_guid
    {:label => _("Management Engine GUID"), :value => @record.guid}
  end

  def textual_parent_ems_cloud
    @record.try(:parent_manager)
  end

  def textual_cloud_volumes
    @record.cloud_volumes
  end

  def textual_cloud_volume_snapshots
    @record.cloud_volume_snapshots
  end

  def textual_cloud_volume_backups
    @record.cloud_volume_backups
  end

  def textual_zone
    {:label => _("Managed by Zone"), :icon => "pficon pficon-zone", :value => @record.zone.try(:name)}
  end
end
