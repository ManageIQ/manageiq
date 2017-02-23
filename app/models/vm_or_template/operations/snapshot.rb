module VmOrTemplate::Operations::Snapshot
  extend ActiveSupport::Concern

  included do
    supports :snapshot_create do
      if supports_snapshots?
        if !snapshots.blank? && snapshots.first.get_current_snapshot.nil?
          unsupported_reason_add(:snapshot_create, _("At least one snapshot has to be active to create a new snapshot for this VM"))
        end
        unless supports_control?
          unsupported_reason_add(:snapshot_create, unsupported_reason(:control))
        end
      else
        unsupported_reason_add(:snapshot_create, _("Operation not supported"))
      end
    end

    supports :remove_snapshot do
      if supports_snapshots?
        if snapshots.size <= 0
          unsupported_reason_add(:remove_snapshot, _("No snapshots available for this VM"))
        end
        unless supports_control?
          unsupported_reason_add(:remove_snapshot, unsupported_reason(:control))
        end
      else
        unsupported_reason_add(:remove_snapshot, _("Operation not supported"))
      end
    end

    supports :remove_all_snapshots do
      unless supports_remove_snapshot?
        unsupported_reason_add(:remove_all_snapshots, unsupported_reason(:remove_snapshot))
      end
    end

    supports :remove_snapshot_by_description do
      unless supports_remove_snapshot?
        unsupported_reason_add(:remove_snapshot_by_description, unsupported_reason(:remove_snapshot))
      end
    end

    supports :revert_to_snapshot do
      unless supports_remove_snapshot?
        unsupported_reason_add(:revert_to_snapshot, unsupported_reason(:remove_snapshot))
      end
    end
  end

  def raw_create_snapshot(name, desc = nil, memory)
    run_command_via_parent(:vm_create_snapshot, :name => name, :desc => desc, :memory => memory)
  end

  def create_snapshot(name, desc = nil, memory = false)
    check_policy_prevent(:request_vm_create_snapshot, :raw_create_snapshot, name, desc, memory)
  end

  def raw_remove_snapshot(snapshot_id)
    raise MiqVmError, unsupported_reason(:remove_snapshot) unless supports_remove_snapshot?
    snapshot = snapshots.find_by(:id => snapshot_id)
    raise _("Requested VM snapshot not found, unable to remove snapshot") unless snapshot
    begin
      run_command_via_parent(:vm_remove_snapshot, :snMor => snapshot.uid_ems)
    rescue => err
      if err.to_s.include?('not found')
        raise MiqVmSnapshotError, err.to_s
      else
        raise
      end
    end
  end

  #
  # For some types of VMs, the process for removing
  # evm stapshots is very different from that of
  # removing normal snapshots.
  #
  # Here, we differentiate between the two, so the
  # methods can be overridden by the subclass as needed.
  #

  def remove_snapshot(snapshot_id)
    raw_remove_snapshot(snapshot_id)
  end

  def remove_evm_snapshot(snapshot_id)
    raw_remove_snapshot(snapshot_id)
  end

  def remove_snapshot_queue(snapshot_id, task_id = nil)
    MiqQueue.put_unless_exists(
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => 'remove_snapshot',
      :args        => [snapshot_id],
      :role        => "ems_operations",
      :zone        => my_zone,
      :task_id     => task_id
    )
  end

  def remove_evm_snapshot_queue(snapshot_id, task_id = nil)
    MiqQueue.put_unless_exists(
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => 'remove_evm_snapshot',
      :args        => [snapshot_id],
      :role        => "ems_operations",
      :zone        => my_zone,
      :task_id     => task_id
    )
  end

  def raw_remove_snapshot_by_description(description, refresh = false)
    raise MiqVmError, unsupported_reason(:remove_snapshot_by_description) unless supports_remove_snapshot_by_description?
    run_command_via_parent(:vm_remove_snapshot_by_description, :description => description, :refresh => refresh)
  end

  def remove_snapshot_by_description(description, refresh = false, retry_time = nil)
    if (ext_management_system.kind_of?(ManageIQ::Providers::Vmware::InfraManager) && ManageIQ::Providers::Vmware::InfraManager.use_vim_broker? && MiqVimBrokerWorker.available?) || host.nil? || host.state == "on"
      raw_remove_snapshot_by_description(description, refresh)
    else
      if retry_time.nil?
        raise _("The VM's Host system is unavailable to remove the snapshot. VM id:[%{id}] Snapshot description:[%{description}]") %
                {:id => id, :descrption => description}
      end
      # If the host is off re-queue the action based on the retry_time
      MiqQueue.put(:class_name  => self.class.name,
                   :instance_id => id,
                   :method_name => 'remove_snapshot_by_description',
                   :args        => [description, refresh, retry_time],
                   :deliver_on  => Time.now.utc + retry_time,
                   :role        => "smartstate",
                   :zone        => my_zone)
    end
  end

  def raw_remove_all_snapshots
    raise MiqVmError, unsupported_reason(:remove_all_snapshots) unless supports_remove_all_snapshots?
    run_command_via_parent(:vm_remove_all_snapshots)
  end

  def remove_all_snapshots
    raw_remove_all_snapshots
  end

  def raw_revert_to_snapshot(snapshot_id)
    raise MiqVmError, unsupported_reason(:revert_to_snapshot) unless supports_revert_to_snapshot?
    snapshot = snapshots.find_by(:id => snapshot_id)
    raise _("Requested VM snapshot not found, unable to RevertTo snapshot") unless snapshot
    run_command_via_parent(:vm_revert_to_snapshot, :snMor => snapshot.uid_ems)
  end

  def revert_to_snapshot(snapshot_id)
    raw_revert_to_snapshot(snapshot_id)
  end
end
