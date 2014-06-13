module MiqProvision::Vdi

  def connect_to_vdi(vm)
    log_header = "MIQ(#{self.class.name}#connect_to_vdi)"

    if self.get_option(:vdi_enabled)
      farm = VdiFarm.find_by_id(self.get_option(:vdi_farm))
      if farm
        return if farm.has_broker?
        dp = self.vdi_brokerless_desktop_pool(farm)
        if dp
          desktop = VdiDesktop.create_desktop_for_vm(vm, dp)
          self.vdi_brokerless_assign_desktop_user(desktop, dp)
        end
      end
    end
  end

  def vdi_brokerless_desktop_pool(farm)
    if self.get_option(:vdi_desktop_pool_create) == true
      dp_name = self.get_option(:vdi_new_desktop_pool_name)
      dp = farm.vdi_desktop_pools.find_by_name(dp_name)
      dp = farm.create_desktop_pool({:name => dp_name, :assignment_behavior => self.get_option(:vdi_new_desktop_pool_assignment)}) if dp.nil?
    else
      dp = farm.vdi_desktop_pools.find_by_id(self.get_option(:vdi_desktop_pool))
    end
    return dp
  end

  def vdi_brokerless_assign_desktop_user(desktop, dp)
    desktopgroup_users = self.get_option(:vdi_desktop_pool_user_list).to_s.split(',').collect{|user| user.split(' ')}.flatten.uniq
    request_task_idx   = self.get_option(:pass).to_i - 1

    user_name = desktopgroup_users[request_task_idx]
    unless user_name.blank?
      user = VdiUser.find_user(user_name)
      if user
        user.desktop_assignment_add(desktop)
        dp.vdi_users << user
      end
    end
  end

end
