module ContainerGroupHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(name phase message reason creation_timestamp resource_version restart_policy dns_policy ip)
  end

  def textual_group_relationships
    # Order of items should be from parent to child
    %i(ems container_project container_services container_replicator containers container_node lives_on container_images)
  end

  def textual_group_conditions
    labels = [_("Name"), _("Status")]
    h = {:labels => labels}
    h[:values] = @record.container_conditions.collect do |condition|
      [
        condition.name,
        condition.status,
      ]
    end
    h
  end

  def textual_group_smart_management
    items = %w(tags)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  @@key_dictionary = [
    [:empty_dir_medium_type, _('Storage Medium Type')],
    [:gce_pd_name, _('GCE PD Resource')],
    [:git_repository, _('Git Repository')],
    [:git_revision, _('Git Revision')],
    [:nfs_server, _('NFS Server')],
    [:iscsi_target_portal, _('ISCSI Target Portal')],
    [:iscsi_iqn, _('ISCSI Target Qualified Name')],
    [:iscsi_lun, _('ISCSI Target Lun Number')],
    [:glusterfs_endpoint_name, _('Glusterfs Endpoint Name')],
    [:claim_name, _('Persistent Volume Claim Name')],
    [:rbd_ceph_monitors, _('Rados Ceph Monitors')],
    [:rbd_image, _('Rados Image Name')],
    [:rbd_pool, _('Rados Pool Name')],
    [:rbd_rados_user, _('Rados User Name')],
    [:rbd_keyring, _('Rados Keyring')],
    [:common_path, _('Volume Path')],
    [:common_fs_type, _('FS Type')],
    [:common_read_only, _('Read-Only')],
    [:common_volume_id, _('Volume ID')],
    [:common_partition, _('Partition')],
    [:common_secret, _('Secret Name')]
  ]

  def textual_group_volumes
    h = {:labels => [_("Name"), _("Property"), _("Value")], :values => []}
    @record.container_volumes.each do |volume|
      volume_values = @@key_dictionary.collect do |key, name|
        [nil, name, volume[key]] if volume[key].present?
      end.compact
      # Set the volume name only  for the first item in the list
      volume_values[0][0] = volume.name if volume_values.length > 0
      h[:values] += volume_values
    end
    h
  end

  #
  # Items
  #

  def textual_phase
    @record.phase
  end

  def textual_message
    @record.message
  end

  def textual_reason
    @record.reason
  end

  def textual_restart_policy
    @record.restart_policy
  end

  def textual_dns_policy
    {:label => _("DNS Policy"), :value => @record.dns_policy}
  end

  def textual_ip
    {:label => _("IP Address"), :value => @record.ipaddress}
  end

  def textual_lives_on
    lives_on_ems = @record.container_node.try(:lives_on).try(:ext_management_system)
    return nil if lives_on_ems.nil?
    # TODO: handle the case where the node is a bare-metal
    lives_on_entity_name = lives_on_ems.kind_of?(EmsCloud) ? _("Instance") : _("Virtual Machine")
    {
      :label => _("Underlying %{name}") % {:name => lives_on_entity_name},
      :image => "100/vendor-#{lives_on_ems.image_name}.png",
      :value => @record.container_node.lives_on.name.to_s,
      :link  => url_for(
        :action     => 'show',
        :controller => 'vm_or_template',
        :id         => @record.container_node.lives_on.id
      )
    }
  end

  def textual_container_statuses_summary
    %i(waiting running terminated)
  end

  def container_statuses_summary
    @container_statuses_summary ||= @record.container_states_summary
  end

  def textual_waiting
    container_statuses_summary[:waiting] || 0
  end

  def textual_running
    container_statuses_summary[:running] || 0
  end

  def textual_terminated
    container_statuses_summary[:terminated] || 0
  end

  def textual_compliance_history
    super(:title => _("Show Compliance History of this Replicator (Last 10 Checks)"))
  end
end
