module VmOrTemplate::Operations::Snapshot
  extend ActiveSupport::Concern

  included do
    supports :snapshot_create do
      unsupported_reason(:snapshots) || unsupported_reason(:control)
    end

    supports :remove_snapshot do
      unsupported_reason(:snapshots) || unsupported_reason(:control) ||
        (_("No snapshots available for this VM") if snapshots.size <= 0)
    end

    supports(:remove_all_snapshots)           { unsupported_reason(:remove_snapshot) }
    supports(:remove_snapshot_by_description) { unsupported_reason(:remove_snapshot) }
    supports(:revert_to_snapshot)             { unsupported_reason(:remove_snapshot) }
    supports_not :snapshots
  end

  def raw_create_snapshot(_name, _desc = nil, _memory)
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def create_snapshot_queue(name, desc = nil, memory)
    run_command_via_queue("raw_create_snapshot", :args => [name, desc, memory])
  end

  def create_snapshot(name, desc = nil, memory = false)
    check_policy_prevent(:request_vm_create_snapshot, :create_snapshot_queue, name, desc, memory)
  end

  def raw_remove_snapshot(_snapshot_id)
    raise NotImplementedError, _("must be implemented in a subclass")
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

  # Remove a snapshot as a queued operation and return the queue object. The
  # queue name and the queue zone are derived from the EMS. The snapshot id
  # is mandatory, while a task id is optional.
  #
  def remove_snapshot_queue(snapshot_id, task_id = nil)
    MiqQueue.put_unless_exists(
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => 'remove_snapshot',
      :args        => [snapshot_id],
      :role        => 'ems_operations',
      :queue_name  => queue_name_for_ems_operations,
      :zone        => my_zone,
      :task_id     => task_id
    )
  end

  # Remove a evm snapshot as a queued operation and return the queue object. The
  # queue name and the queue zone are derived from the EMS. The snapshot id
  # is mandatory, while a task id is optional.
  #
  def remove_evm_snapshot_queue(snapshot_id, task_id = nil)
    MiqQueue.put_unless_exists(
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => 'remove_evm_snapshot',
      :args        => [snapshot_id],
      :role        => 'ems_operations',
      :queue_name  => queue_name_for_ems_operations,
      :zone        => my_zone,
      :task_id     => task_id
    )
  end

  def raw_remove_snapshot_by_description(_description, _refresh = false)
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def remove_snapshot_by_description(description, refresh = false, _retry_time = nil)
    raw_remove_snapshot_by_description(description, refresh)
  end

  def raw_remove_all_snapshots
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def remove_all_snapshots
    raw_remove_all_snapshots
  end

  # Remove all snapshots as a queued task and return the task id. The queue
  # name and the queue zone are derived from the EMS. The userid is mandatory.
  #
  def remove_all_snapshots_queue(userid)
    task_opts = {
      :name   => "Removing all snapshots for #{name}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'remove_all_snapshots',
      :instance_id => id,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :args        => []
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def raw_revert_to_snapshot(_snapshot_id)
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def revert_to_snapshot(snapshot_id)
    raw_revert_to_snapshot(snapshot_id)
  end
end
