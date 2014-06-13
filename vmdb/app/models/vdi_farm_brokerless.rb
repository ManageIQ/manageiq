class VdiFarmBrokerless < VdiFarm

  def create_desktop_pool(options)
    settings = {
      :name        => options[:name],
      :description => options[:description],
      :vendor      => 'brokerless',
      :enabled     => true,
      :uid_ems     => MiqUUID.new_guid,
      :assignment_behavior => 'PreAssigned'
    }
    self.vdi_desktop_pools.create(settings)
  end

  def remove_desktop_pool(name, uid_ems)
    self.vdi_desktop_pools.find_by_uid_ems(uid_ems).destroy
  end

  def modify_desktop_pool(name, uid_ems, options)
    # TODO
    self.vdi_desktop_pools.find_by_uid_ems(uid_ems).modify_settings(options)
  end

  def active_proxy
    self
  end

  def self.refresh_all_vdi_farms_timer
    nil
  end

  def self.refresh_ems(farm_ids, reload = false)
    nil
  end

  def refresh_ems
    nil
  end

  def allowed_assignment_behaviors
    {"PreAssigned"      => "Pre-assigned"}
  end

  def send_ps_task_from_queue(taskid, task_name, *args)
    begin
      task = MiqTask.find_by_id(taskid) unless taskid.nil?
      task.state_active
      task.update_message("Running command")
      # TODO: Add method logic for desktop/desktop pools here
      self.send(task_name, *args)
      task.update_status(MiqTask::STATE_FINISHED, MiqTask::STATUS_OK, "Command Complete")
    rescue => err
      task.update_status(MiqTask::STATE_FINISHED, MiqTask::STATUS_ERROR, err.to_s)
      $log.log_backtrace(err)
    end
  end

  def remove_user_from_desktop_pool(user_name, user_uid_ems, desktop_pool_name, desktop_pool_uid_ems)
    dp   = self.vdi_desktop_pools.find_by_uid_ems(desktop_pool_uid_ems)
    user = VdiUser.find_by_uid_ems(user_uid_ems)

    dp.vdi_users.delete(user)
    dp.vdi_desktops.each {|d| d.vdi_users.delete(user)}
  end

  def add_user_to_desktop_pool(user_name, user_uid_ems, desktop_pool_name, desktop_pool_uid_ems, assign_user_to_desktop = true)
    dp   = self.vdi_desktop_pools.find_by_uid_ems(desktop_pool_uid_ems)
    user = VdiUser.find_by_uid_ems(user_uid_ems)

    if assign_user_to_desktop
      unassigned_desktop = dp.unassigned_vdi_desktops.first
      if unassigned_desktop.nil?
        raise "No free desktops available in this pool"
      else
        dp.vdi_users << user
        unassigned_desktop.vdi_users << user
      end
    else
      dp.vdi_users << user
    end
  end

  def remove_user_from_desktop(user_name, user_uid_ems, desktop_pool_name, desktop_pool_uid_ems, desktop_name, desktop_vm_uid_ems)
    desktop = VdiDesktop.find_by_vm_uid_ems(desktop_vm_uid_ems)
    user    = VdiUser.find_by_uid_ems(user_uid_ems)
    user.desktop_assignment_delete(desktop)
  end

  def add_user_to_desktop_and_pool(user_name, user_uid_ems, desktop_pool_name, desktop_pool_uid_ems, desktop_name, desktop_vm_uid_ems)
    add_user_to_desktop_pool(user_name, user_uid_ems, desktop_pool_name, desktop_pool_uid_ems, false)
    desktop = VdiDesktop.find_by_vm_uid_ems(desktop_vm_uid_ems)
    user = VdiUser.find_by_uid_ems(user_uid_ems)
    user.desktop_assignment_add(desktop)
  end

end
