module VmOrTemplate::Operations::Snapshot
  def validate_create_snapshot
    return {:available=>false, :message=>"Create Snapshot Operation not supported for #{self.class.model_suffix} VM"} unless self.supports_snapshots?
    msg = validate_vm_control
    return {:available=>msg[0], :message=>msg[1]} unless msg.nil?
    msg = {:available=>true, :message=>nil}
    msg[:message] = 'At least one snapshot has to be active to create a new snapshot for this VM' if !self.snapshots.blank? && self.snapshots.first.get_current_snapshot.nil?
    return msg
  end

  def validate_remove_snapshot
    return {:available=>false, :message=>"Remove Snapshot Operation not supported for #{self.class.model_suffix} VM"} unless self.supports_snapshots?
    msg = validate_vm_control
    return {:available=>msg[0], :message=>msg[1]} unless msg.nil?
    msg = {:available=>true, :message=>nil}
    msg[:message] = 'There are no snapshots available for this VM' if self.snapshots.size <= 0
    return msg
  end

  def validate_remove_all_snapshots
    return self.validate_remove_snapshot
  end

  def validate_remove_snapshot_by_description
    return self.validate_remove_snapshot
  end

  def validate_revert_to_snapshot
    return self.validate_remove_snapshot
  end

  def raw_create_snapshot(name, desc = nil, memory)
    run_command_via_parent(:vm_create_snapshot, :name => name, :desc => desc, :memory => memory)
  end

  def create_snapshot(name, desc = nil, memory = false)
    raw_create_snapshot(name, desc, memory) unless policy_prevented?(:request_vm_create_snapshot)
  end

  def raw_remove_snapshot(snapshot_id)
    raise_is_available_now_error_message(:remove_snapshot)
    snapshot = self.snapshots.find_by_id(snapshot_id)
    raise "Requested VM snapshot not found, unable to remove snapshot" unless snapshot
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

  def remove_snapshot(snapshot_id)
    raw_remove_snapshot(snapshot_id)
  end

  def remove_snapshot_queue(snapshot_id, task_id = nil)
    MiqQueue.put_unless_exists(
      :class_name  => self.class.name,
      :instance_id => self.id,
      :method_name => 'remove_snapshot',
      :args        => [snapshot_id],
      :role        => "ems_operations",
      :zone        => self.my_zone,
      :task_id     => task_id
    )
  end

  def raw_remove_snapshot_by_description(description, refresh = false)
    raise_is_available_now_error_message(:remove_snapshot_by_description)
    run_command_via_parent(:vm_remove_snapshot_by_description, :description => description, :refresh => refresh)
  end

  def remove_snapshot_by_description(description, refresh=false, retry_time=nil)
    if (self.ext_management_system.kind_of?(EmsVmware) && EmsVmware.use_vim_broker? && MiqVimBrokerWorker.available?) || self.host.nil? || self.host.state == "on"
      raw_remove_snapshot_by_description(description, refresh)
    else
      raise "The VM's Host system is unavailable to remove the snapshot.  VM id:[#{self.id}]  Snapshot description:[#{description}]" if retry_time.nil?
      # If the host is off re-queue the action based on the retry_time
      MiqQueue.put(:class_name => self.class.name,
                   :instance_id => self.id,
                   :method_name => 'remove_snapshot_by_description',
                   :args => [description, refresh, retry_time],
                   :deliver_on  => Time.now.utc + retry_time,
                   :role => "smartstate",
                   :zone => self.my_zone)
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
    snapshot = self.snapshots.find_by_id(snapshot_id)
    raise "Requested VM snapshot not found, unable to RevertTo snapshot" unless snapshot
    run_command_via_parent(:vm_revert_to_snapshot, :snMor => snapshot.uid_ems)
  end

  def revert_to_snapshot(snapshot_id)
    raw_revert_to_snapshot(snapshot_id)
  end

  def supports_snapshots?
    # KVM systems do not support snapshots
    return ['VMware', 'Microsoft'].include?(self.vendor)
  end
end
