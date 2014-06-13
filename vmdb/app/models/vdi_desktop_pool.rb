class VdiDesktopPool < ActiveRecord::Base
  belongs_to    :vdi_farm
  has_and_belongs_to_many :ext_management_systems, :association_foreign_key => "ems_id"
  has_many      :vdi_desktops, :dependent => :nullify
  has_and_belongs_to_many :vdi_users
  has_many      :ems_events

  virtual_has_many  :vdi_sessions, :uses => {:vdi_desktops => :vdi_sessions}
  virtual_has_many  :unassigned_vdi_desktops, :uses => :vdi_desktops
  virtual_column    :vendor, :type => :string

  include ReportableMixin
  include ArCountMixin

  # TODO: Remove after UI is updated to support multi-ems per desktop pool
  def ext_management_system
    self.ext_management_systems.first
  end

  def vdi_sessions
    self.vdi_desktops.collect { |d| d.vdi_sessions }.flatten.uniq
  end

  def unassigned_vdi_desktops
    self.vdi_desktops.reject {|d| d.vdi_users.size != 0}
  end

  def vendor
    self.vdi_farm.try(:vendor)
  end

  def has_broker?
    self.vdi_farm.try(:has_broker?)
  end

  def add_user_to_desktop_pool(user)
    if self.vdi_users.include?(user)
      self.vdi_farm.create_tracking_task("VDI: Add User Skipped - User '#{user.name}' already exists on Desktop Pool '#{self.name}'")
    else
      task_description = "VDI: Add user '#{user.name}' to Desktop Pool '#{self.name}'"
      self.vdi_farm.send_ps_task(task_description, :add_user_to_desktop_pool, user.name, user.uid_ems, self.name, self.uid_ems)
    end
  end

  def remove_user_from_desktop_pool(user=nil)
    user ||= self.vdi_users.first
    if self.vdi_users.include?(user)
      task_description = "VDI: Remove user '#{user.name}' from Desktop Pool '#{self.name}'"
      self.vdi_farm.send_ps_task(task_description, :remove_user_from_desktop_pool, user.name, user.uid_ems, self.name, self.uid_ems)
    else
      self.vdi_farm.create_tracking_task("VDI: Remove User Skipped - User '#{user.name}' does not exist on Desktop Pool '#{self.name}'")
    end
  end

  def remove_desktop_pool
    task_description = "VDI: Remove Desktop Pool '#{self.name}'"
    self.vdi_farm.send_ps_task(task_description, :remove_desktop_pool, self.name, self.uid_ems)
  end

  def self.remove_desktop_pools(pools)
    self.where(:id => pools).each {|pool| pool.remove_desktop_pool}
  end

  def self.assign_users(pools, users)
    vdi_users = VdiUser.where(:id => users)
    self.where(:id => pools).each do |pool|
      vdi_users.each do |vdi_user|
        pool.add_user_to_desktop_pool(vdi_user)
      end
    end
  end

  def self.unassign_users(pools, users)
    vdi_users = VdiUser.where(:id => users)
    self.where(:id => pools).each do |pool|
      vdi_users.each do |vdi_user|
        pool.remove_user_from_desktop_pool(vdi_user)
      end
    end
  end

  def self.user_assignable_pools
    VdiDesktopPool.where(:assignment_behavior => ['Pooled', 'AssignOnFirstUse', 'Shared'])
  end

  def self.create_desktop_pool(settings)
    return "Name cannot be blank" if settings[:name].blank?
    return "Farm cannot be blank" if settings[:vdi_farm_id].blank?
    return "Assignment Behavior cannot be blank" if settings[:assignment_behavior].blank?

    dp_name = settings[:name]
    farm = VdiFarm.find_by_id(settings[:vdi_farm_id])
    dp = farm.vdi_desktop_pools.find_by_name(settings[:name])

    return "Management System cannot be blank" if farm.allowed_emses && settings[:ext_management_system_id].blank?
    return "A Desktop Pool with the name '#{settings[:name]}' already exists on the farm '#{farm.name}'" if dp

    if settings[:ext_management_system_id]
      ems = ExtManagementSystem.find_by_id(settings[:ext_management_system_id])
      settings[:ems_hostname] = ems.hostname
      settings[:user_name]    = ems.authentication_userid
      settings[:user_pwd]     = ems.authentication_password_encrypted
    end

    task_description = "VDI: Create Desktop Pool '#{dp_name}'"
    farm.send_ps_task(task_description, :create_desktop_pool, settings)
    nil # no errors
  end

  def modify_desktop_pool(settings)
    return "Name cannot be blank" if settings[:name].blank?

    task_description = "VDI: Modify Desktop Pool '#{self.name}'"
    self.vdi_farm.send_ps_task(task_description, :modify_desktop_pool, self.name, self.uid_ems, settings)
    nil # no errors
  end

  def modify_settings(settings)
    log_header = "MIQ(VdiDesktopPool.modify_settings) VdiDesktopPool: [#{self.name}], id: [#{self.id}]"
    $log.info "#{log_header} Settings: <#{settings.inspect}>"

    # Ensure we do not set name to a blank value
    dp_name = settings.delete(:name)
    self.name = dp_name unless dp_name.blank?

    settings.each do |k,v|
      next if k == :vdi_farm_id
      self.send("#{k}=", v) if self.respond_to?("#{k}=")
    end
    self.save!
  end
end
