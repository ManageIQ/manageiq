class MiqAutomate
  def self.async_datastore_reset
    task = MiqTask.create(:name => "Automate Datastore Reset")

    if MiqServer.find_all_started_servers.detect { |s| s.has_active_role?("automate") }.nil?
      task.update_status("Finished", "Error", "No Server has Automate Role enabled")
    else
      MiqQueue.put(
        :class_name  => self.to_s,
        :method_name => "_async_datastore_reset",
        :args        => [task.id],
        :priority    => MiqQueue::HIGH_PRIORITY,
        :msg_timeout => 3600,
        :role        => "automate"
      )
      task.update_status("Queued", "Ok", "Task has been queued")
    end

    return task.id
  end

  def self._async_datastore_reset(taskid)
    task = MiqTask.find_by_id(taskid)
    task.update_status("Active",   "Ok", "Resetting Automate Datastore") if task
    MiqAeDatastore.reset_to_defaults
    task.update_status("Finished", "Ok", "Resetting Automate Datastore complete") if task
  end

end
