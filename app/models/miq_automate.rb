class MiqAutomate
  def self.async_datastore_reset
    task = MiqTask.create(:name => "Automate Datastore Reset")

    if MiqServer.active_miq_servers.detect { |s| s.has_active_role?("automate") }.nil?
      task.update_status("Finished", "Error", "No Server has Automate Role enabled")
    else
      MiqQueue.submit_job(
        :service     => "automate",
        :class_name  => to_s,
        :method_name => "_async_datastore_reset",
        :args        => [task.id],
        :priority    => MiqQueue::HIGH_PRIORITY,
        :msg_timeout => 3600,
      )
      task.update_status("Queued", "Ok", "Task has been queued")
    end

    task.id
  end

  def self._async_datastore_reset(taskid)
    task = MiqTask.find_by(:id => taskid)
    task.update_status("Active",   "Ok", "Resetting Automate Datastore") if task
    MiqAeDatastore.reset_to_defaults
    task.update_status("Finished", "Ok", "Resetting Automate Datastore complete") if task
  end
end
