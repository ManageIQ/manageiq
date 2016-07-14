module ManageIQ::Providers::Redhat::InfraManager::Vm::Operations::Snapshot
  def raw_create_snapshot(name, desc = nil, memory)
    desc ||= name
    with_snapshots_service(uid_ems) do |snapshots_service|
      snapshots_service.add({name: name, description: desc, persist_memorystate: memory})
    end
  end

  def raw_remove_snapshot(snapshot_id)
    snapshot = snapshots.find_by_id(snapshot_id)
    raise _("Requested VM snapshot not found, unable to remove snapshot") unless snapshot
    with_snapshots_service(uid_ems) do |snapshots_service|
      snapshots_service.snapshot_service(snapshot.uid_ems).remove
    end
  end

  def raw_revert_to_snapshot(snapshot_id)
    snapshot = snapshots.find_by_id(snapshot_id)
    raise _("Requested VM snapshot not found, unable to RevertTo snapshot") unless snapshot
    with_snapshots_service(uid_ems) do |snapshots_service|
      snapshots_service.snapshot_service(snapshot.uid_ems).restore
    end
  end

  def raw_remove_all_snapshots
    with_snapshots_service(uid_ems) do |snapshots_service|
      snapshots_service.list.each do |snapshot|
        snapshot.remove
      end
    end
  end

  def supports_snapshots?
    true
  end

  private

  def with_snapshots_service(vm_uid_ems, options = {})
    version = options[:version] || 4
    connection = ext_management_system.connect(:version => version)
    service = connection.system_service.vms_service.vm_service(vm_uid_ems).
        snapshots_service
    yield service
  ensure
    connection.close
  end
end
