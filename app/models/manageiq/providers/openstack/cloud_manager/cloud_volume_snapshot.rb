class ManageIQ::Providers::Openstack::CloudManager::CloudVolumeSnapshot < ::CloudVolumeSnapshot
  include SupportsFeatureMixin

  supports :create
  supports :update
  supports :delete

  def provider_object(connection)
    connection.snapshots.get(ems_ref)
  end

  def with_provider_object
    super(connection_options)
  end

  def self.create_snapshot_queue(userid, cloud_volume, options = {})
    ext_management_system = cloud_volume.try(:ext_management_system)
    task_opts = {
      :action => "creating volume snapshot in #{ext_management_system.inspect}\
      for #{cloud_volume.inspect} with #{options.inspect}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => cloud_volume.class,
      :instance_id => cloud_volume.id,
      :method_name => 'create_snapshot',
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => my_zone(ext_management_system),
      :args        => [options]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.create_snapshot(cloud_volume, options = {})
    raise ArgumentError, _("cloud_volume cannot be nil") if cloud_volume.nil?
    ext_management_system = cloud_volume.try(:ext_management_system)
    raise ArgumentError, _("ext_management_system cannot be nil") if ext_management_system.nil?

    cloud_tenant = cloud_volume.cloud_tenant
    snapshot = nil
    options[:volume_id] = cloud_volume.ems_ref
    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      snapshot = service.snapshots.create(options)
    end

    create(
      :name                  => snapshot.name,
      :description           => snapshot.description,
      :ems_ref               => snapshot.id,
      :status                => snapshot.status,
      :cloud_volume          => cloud_volume,
      :cloud_tenant          => cloud_tenant,
      :ext_management_system => ext_management_system,
    )
  rescue => e
    _log.error "snapshot=[#{options[:name]}], error: #{e}"
    raise MiqException::MiqVolumeSnapshotCreateError, e.to_s, e.backtrace
  end

  def update_snapshot_queue(userid = "system", options = {})
    task_opts = {
      :action => "updating volume snapshot #{inspect} in #{ext_management_system.inspect} with #{options.inspect}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => 'update_snapshot',
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => my_zone,
      :args        => [options]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def update_snapshot(options = {})
    with_provider_object do |snapshot|
      if snapshot
        snapshot.update(options)
      else
        raise MiqException::MiqVolumeSnapshotUpdateError("snapshot does not exist")
      end
    end
  rescue => e
    _log.error "snapshot=[#{name}], error: #{e}"
    raise MiqException::MiqVolumeSnapshotUpdateError, e.to_s, e.backtrace
  end

  def delete_snapshot_queue(userid = "system", _options = {})
    task_opts = {
      :action => "deleting volume snapshot #{inspect} in #{ext_management_system.inspect}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => 'delete_snapshot',
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => my_zone,
      :args        => []
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def delete_snapshot(_options = {})
    with_provider_object do |snapshot|
      if snapshot
        snapshot.destroy
      else
        _log.warn "snapshot=[#{name}] already deleted"
      end
    end
  rescue => e
    _log.error "snapshot=[#{name}], error: #{e}"
    raise MiqException::MiqVolumeSnapshotDeleteError, e.to_s, e.backtrace
  end

  private

  def self.connection_options(cloud_tenant = nil)
    connection_options = { :service => 'Volume' }
    connection_options[:tenant_name] = cloud_tenant.name if cloud_tenant
    connection_options
  end

  def connection_options
    self.class.connection_options(cloud_tenant)
  end
end
