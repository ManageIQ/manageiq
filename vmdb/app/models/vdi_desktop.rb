class VdiDesktop < ActiveRecord::Base
  belongs_to        :vdi_desktop_pool
  has_and_belongs_to_many :vdi_users
  belongs_to        :vm_or_template
  belongs_to        :vm_vdi, :foreign_key => "vm_or_template_id", :class_name => 'Vm'
  has_many          :vdi_sessions, :dependent => :destroy
  has_many          :ems_events

  virtual_has_one   :vdi_farm, :uses => { :vdi_desktop_pool => :vdi_farm }

  virtual_column    :ipaddresses, :type => :string_set, :uses => {:vm_or_template => :ipaddresses}
  virtual_column    :hostnames,   :type => :string_set, :uses => {:vm_or_template => :hostnames}

  include ReportableMixin
  include ArCountMixin

  def vdi_farm
    dp = self.vdi_desktop_pool
    dp.nil? ? nil : dp.vdi_farm
  end

  # TODO: Remove after UI is updated to support multi-user per desktop
  def vdi_user
    self.vdi_users.first
  end

  # This method is called from both inventory and eventing
  def self.find_vm_for_uid_ems(inv)
    vm_uid_ems = inv[:vm_uid_ems].to_s

    # Try to find the ems_id in the inventory data
    ems_ids = [inv.fetch_path(:vdi_desktop_pool, :ems_id)].compact
    # If that's blank try to lookup the desktop pool by name to get the ems_id
    if ems_ids.blank?
      session_data = inv.fetch_path(:session, :Props) || inv.fetch_path(:session, :MS)
      unless session_data.nil?
        desktop_pool_uid = session_data[:desktop_pool_name]
        unless desktop_pool_uid.nil?
          dp = VdiDesktopPool.find_by_uid_ems(desktop_pool_uid)
          ems_ids = dp.ext_management_systems.collect {|e| e.id} unless dp.nil?
        end
      end
    end

    sql, args = "", []
    unless ems_ids.blank?
      sql = 'ems_id IN (?) AND '
      args << ems_ids
    end

    if vm_uid_ems =~ /VirtualMachine-(vm-\d*)/
      # VMware View - Look for VM ems_ref
      sql  += "ems_ref = ?"
      args << $1
    else
      # Citrix VDI - Look for VM guid from
      sql  += "uid_ems = ?"
      args << vm_uid_ems
    end

    Vm.find(:first, :conditions=>[sql, *args], :select=>"id,vdi")
  end

  def allowed_vdi_users
    VdiUser.all
  end

  def supports_user_assignment_error_message
    dp = self.vdi_desktop_pool
    return "Desktop is not part of a Desktop pool" if dp.nil?
    return "Unsupported function for VMware VDI" if self.vdi_farm.kind_of?(VdiFarmVmware)
    return "Function not support for Desktop Pool type of '#{dp.assignment_behavior}'" if ['Shared', 'Pooled'].include?(dp.assignment_behavior)
    false
  end

  def manage_users(requested_ids)
    current_ids = self.vdi_users.collect(&:id)

    # Users to remove
    (current_ids - requested_ids).each do |u_id|
      user = VdiUser.find_by_id(u_id)
      remove_user_from_desktop(user)
    end

    # Users to add
    (requested_ids - current_ids).each do |u_id|
      user = VdiUser.find_by_id(u_id)
      add_user_to_desktop_and_pool(user)
    end
  end

  def add_user_to_desktop_and_pool(user)
    pool = self.vdi_desktop_pool
    task_description = "VDI: Add user '#{user.name}' to Desktop '#{self.name}'"
    self.vdi_farm.send_ps_task(task_description, :add_user_to_desktop_and_pool, user.name, user.uid_ems, pool.name, pool.uid_ems, self.name, self.vm_uid_ems)
  end

  def remove_user_from_desktop(user)
    pool = self.vdi_desktop_pool
    task_description = "VDI: Remove user '#{user.name}' from Desktop '#{self.name}'"
    self.vdi_farm.send_ps_task(task_description, :remove_user_from_desktop, user.name, user.uid_ems, pool.name, pool.uid_ems, self.name, self.vm_uid_ems)
  end

  def power_state
    state = self.read_attribute(:power_state)
    return state unless state.blank?
    self.vm_vdi.try(:power_state)
  end

  def connection_state
    state = self.read_attribute(:connection_state)
    return state unless state.blank?
    # Sorting connection states from the session object pushes 'connected' to the top of the list
    # incase a VDI Desktop has multiple sessions
    self.vdi_sessions.collect {|s| s.state}.sort.first
  end

  def self.create_desktop_for_vm(vm, dp=nil)
    raise MiqException::Error, "Template VM cannot be used as a VDI Desktop source" if vm.template?
    raise MiqException::Error, "Orphaned VM cannot be used as a VDI Desktop source" if vm.orphaned?
    raise MiqException::Error, "Archived VM cannot be used as a VDI Desktop source" if vm.archived?
    nh = {:name => vm.name, :vm_uid_ems => vm.uid_ems, :vm_or_template_id => vm.id}
    dp ? dp.vdi_desktops.create(nh) : VdiDesktop.create(nh)
    vm.update_attribute(:vdi, true)
  end

  def self.queue_mark_as_non_vdi(ids)
    VmVdi.queue_task(:mark_as_non_vdi, "Remove VDI Desktops for #{ids.length} Desktops(s)", ids)
  end

  def remove_desktop_for_vm
    dp = self.vdi_desktop_pool
    raise MiqException::Error, "Removing the VDI Desktop from the '#{dp.vendor}' Desktop Pool type is unsupported" if dp && dp.has_broker?
    vm = self.vm_or_template
    vm.update_attribute(:vdi, false) unless vm.nil?
    self.destroy
  end

  def ipaddresses
    self.vm_or_template.nil? ? [] : self.vm_or_template.ipaddresses
  end

  def hostnames
    self.vm_or_template.nil? ? [] : self.vm_or_template.hostnames
  end

end
