module VmOrTemplate::Operations::Snapshot
  def validate_create_snapshot
    return {:available => false, :message => "Create Snapshot operation not supported for #{self.class.model_suffix} VM"} unless self.supports_snapshots?
    unless supports_control?
      return {:available => false, :message => unsupported_reason(:control)}
    end
    msg = {:available => true, :message => nil}
    msg[:message] = 'At least one snapshot has to be active to create a new snapshot for this VM' if !snapshots.blank? && snapshots.first.get_current_snapshot.nil?
    msg
  end

  def validate_remove_snapshot(task = 'Remove')
    return {:available => false, :message => "#{task} Snapshot operation not supported for #{self.class.model_suffix} VM"} unless self.supports_snapshots?
    return {:available => false, :message => "There are no snapshots available for this VM"} if snapshots.size <= 0
    unless supports_control?
      return {:available => false, :message => unsupported_reason(:control)}
    end
    {:available => true, :message => nil}
  end

  def validate_remove_all_snapshots
    validate_remove_snapshot
  end

  def validate_remove_snapshot_by_description
    validate_remove_snapshot
  end

  def validate_revert_to_snapshot
    validate_remove_snapshot('Revert')
  end

  def raw_create_snapshot(name, desc = nil, memory)
    run_command_via_parent(:vm_create_snapshot, :name => name, :desc => desc, :memory => memory)
  end

  def create_snapshot(name, desc = nil, memory = false)
    check_policy_prevent(:request_vm_create_snapshot, :raw_create_snapshot, name, desc, memory)
  end

  def raw_remove_snapshot(snapshot_id)
    raise_is_available_now_error_message(:remove_snapshot)
    snapshot = snapshots.find_by_id(snapshot_id)
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
    raise_is_available_now_error_message(:remove_snapshot_by_description)
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
    raise_is_available_now_error_message(:remove_all_snapshots)
    run_command_via_parent(:vm_remove_all_snapshots)
  end

  def remove_all_snapshots
    raw_remove_all_snapshots
  end

  def raw_revert_to_snapshot(snapshot_id)
    raise_is_available_now_error_message(:revert_to_snapshot)
    snapshot = snapshots.find_by_id(snapshot_id)
    raise _("Requested VM snapshot not found, unable to RevertTo snapshot") unless snapshot
    run_command_via_parent(:vm_revert_to_snapshot, :snMor => snapshot.uid_ems)
  end

  def revert_to_snapshot(snapshot_id)
    raw_revert_to_snapshot(snapshot_id)
  end
end
