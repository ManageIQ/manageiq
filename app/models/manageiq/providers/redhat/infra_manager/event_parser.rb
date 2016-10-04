module ManageIQ::Providers::Redhat::InfraManager::EventParser
  # Sample RHEVM Event
  #
  # :id: '13060729'
  # :href: /api/events/13060729
  # :cluster:
  #   :id: 40c1c666-e919-11e0-9c6b-005056af0085
  #   :href: /api/clusters/40c1c666-e919-11e0-9c6b-005056af0085
  # :host:
  #   :id: ca389dbc-2054-11e1-9241-005056af0085
  #   :href: /api/hosts/ca389dbc-2054-11e1-9241-005056af0085
  # :template:
  #   :id: 7120b19a-1b39-4bd4-afa8-6393fc4cd3dc
  #   :href: /api/templates/7120b19a-1b39-4bd4-afa8-6393fc4cd3dc
  # :user:
  #   :id: 97aca95a-72d4-4882-bf31-e2832ce3a0ba
  #   :href: /api/users/97aca95a-72d4-4882-bf31-e2832ce3a0ba
  # :vm:
  #   :id: b79de892-655a-455d-b926-4dd620bc1fd4
  #   :href: /api/vms/b79de892-655a-455d-b926-4dd620bc1fd4
  # :description: ! 'VM shutdown initiated by bdunne on VM bd-s (Host: rhelvirt.manageiq.com).'
  # :severity: normal
  # :code: 73
  # :time: 2012-08-17 12:01:25.555000000 -04:00
  # :name: USER_INITIATED_SHUTDOWN_VM

  def self.event_to_hash(event, ems_id = nil)
    log_header = "ems_id: [#{ems_id}] " unless ems_id.nil?

    _log.debug { "#{log_header}event: [#{event.inspect}]" }

    # Connect back to RHEV to get the actual user_name
    ems       = ManageIQ::Providers::Redhat::InfraManager.find_by_id(ems_id)
    user_href = ems_ref_from_object_in_event(event[:user])
    username  = nil
    if ems && user_href
      ems.with_provider_connection do |rhevm|
        username = Ovirt::User.find_by_href(rhevm, user_href).try(:[], :user_name)
      end
    end

    # Build the event hash
    {
      :event_type          => event[:name],
      :source              => 'RHEVM',
      :message             => event[:description],
      :timestamp           => event[:time],
      :username            => username,
      :full_data           => event,
      :ems_id              => ems_id,
      :vm_ems_ref          => ems_ref_from_object_in_event(event[:vm]) || ems_ref_from_object_in_event(event[:template]),
      :host_ems_ref        => ems_ref_from_object_in_event(event[:host]),
      :ems_cluster_ems_ref => ems_ref_from_object_in_event(event[:cluster]),
    }
  end

  def self.ems_ref_from_object_in_event(data)
    return nil unless data.respond_to?(:[])
    ManageIQ::Providers::Redhat::InfraManager.make_ems_ref(data[:href])
  end

  def self.parse_new_target(full_data, message, ems, event_type)
    cluster = full_data[:cluster]
    cluster_ref = ManageIQ::Providers::Redhat::InfraManager.make_ems_ref(cluster[:href])

    cluster_name = ems.with_provider_connection do |rhevm|
      Ovirt::Cluster.find_by_href(rhevm, cluster_ref).try(:[], :name)
    end

    {
      :ems_id         => ems.id,
      :vm             => parse_new_vm(full_data[:vm], message, event_type),
      :cluster        => parse_new_cluster(cluster_ref, cluster[:id], cluster_name),
      :resource_pools => parse_new_rp(cluster[:id], cluster_name),
      :folders        => parse_new_dc(full_data[:data_center])
    }
  end

  def self.parse_new_vm(vm, message, event_type)
    ems_ref = ManageIQ::Providers::Redhat::InfraManager.make_ems_ref(vm[:href])

    ManageIQ::Providers::Redhat::InfraManager::RefreshParser.create_vm_hash(
      ems_ref.include?('/templates/'), ems_ref, vm[:id], parse_target_name(message, event_type))
  end

  def self.parse_target_name(message, event_type)
    if %w(NETWORK_ADD_VM_INTERFACE NETWORK_INTERFACE_PLUGGED_INTO_VM).include?(event_type)
      # sample message: "Network Interface nic1 (VirtIO) was plugged to VM v5. (User: admin@internal)"
      message.split(/\s/)[8][0...-1]
    else
      # sample message: "VM v5 was created by admin@internal."
      message.split(/\s/)[1]
    end
  end

  def self.parse_new_cluster(cluster_ref, cluster_id, cluster_name)
    {
      :ems_ref     => cluster_ref,
      :ems_ref_obj => cluster_ref,
      :uid_ems     => cluster_id,
      :name        => cluster_name
    }
  end

  def self.parse_new_rp(cluster_id, cluster_name)
    {
      :name       => "Default for Cluster #{cluster_name}",
      :uid_ems    => "#{cluster_id}_respool",
      :is_default => true,
    }
  end

  def self.parse_new_dc(dc)
    {:ems_ref => ManageIQ::Providers::Redhat::InfraManager.make_ems_ref(dc[:href])}
  end
end
