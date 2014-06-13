class AssignedServerRole < ActiveRecord::Base
  belongs_to :miq_server
  belongs_to :server_role

  before_save :massage_active_field

  HIGH_PRIORITY        = 1
  MEDIUM_PRIORITY      = 2
  LOW_PRIORITY         = 3
  DEFAULT_PRIORITY     = MEDIUM_PRIORITY
  AVAILABLE_PRIORITIES = [ HIGH_PRIORITY,  MEDIUM_PRIORITY, LOW_PRIORITY ]
  validates_inclusion_of :priority, :in => AVAILABLE_PRIORITIES, :allow_nil => true

  def massage_active_field
    self.active = false if self.active.nil?
  end

  def name
    self.server_role.name
  end

  def reset
    self.update_attributes(:priority => DEFAULT_PRIORITY, :active => false)
  end

  def master_supported?
    self.server_role.master_supported?
  end

  def database_owner?
    self.server_role == ServerRole.database_owner
  end

  def is_master?
    self.miq_server.is_master_for_role?(self.server_role)
  end

  def inactive?
    !self.active?
  end

  def set_master
    self.miq_server.set_master_for_role(self.server_role)
    self.reload
  end

  def remove_master
    self.miq_server.remove_master_for_role(self.server_role)
    self.reload
  end

  def set_priority(val)
    # Only allow 1 Primary in the RoleScope
    if val == HIGH_PRIORITY && self.server_role.master_supported?
      if ['zone', 'region'].include?(self.server_role.role_scope)
        method = "find_other_servers_in_#{self.server_role.role_scope}"
        other_servers = self.miq_server.send(method)
        other_servers.each do |server|
          assigned = server.assigned_server_roles.find_by_server_role_id(self.server_role_id)
          next if assigned.nil?
          assigned.update_attribute(:priority, DEFAULT_PRIORITY)  if assigned.priority == HIGH_PRIORITY
        end
      end
    end

    self.update_attribute(:priority, val)
  end

  def activate_in_region(override = false)
    return unless self.server_role.role_scope == 'region'

    if override || self.inactive?
      MiqRegion.my_region.lock do
        if self.server_role.master_supported?
          servers = MiqRegion.my_region.active_miq_servers
          self.class.find(:all, :conditions => { :server_role_id => self.server_role.id } ).each do |asr|
            asr.deactivate if servers.include?(asr.miq_server)
          end
        end

        self.activate(override)
      end
    end
  end

  def deactivate_in_region(override = false)
    return unless self.server_role.role_scope == 'region'

    if override || self.active?
      MiqRegion.my_region.lock do
        self.deactivate(override)
      end
    end
  end

  def activate_in_zone(override = false)
    return unless self.server_role.role_scope == 'zone'

    if override || self.inactive?
      self.miq_server.zone.lock do |zone|
        if self.server_role.master_supported?
          servers = self.miq_server.zone.active_miq_servers
          self.class.find(:all, :conditions => { :server_role_id => self.server_role.id } ).each do |asr|
            asr.deactivate if servers.include?(asr.miq_server)
          end
        end

        self.activate(override)
      end
    end
  end

  def deactivate_in_zone(override = false)
    return unless self.server_role.role_scope == 'zone'

    if override || self.active?
      self.miq_server.zone.lock do |zone|
        self.deactivate(override)
      end
    end
  end

  def activate_in_role_scope
    case self.server_role.role_scope
    when 'zone'   then self.activate_in_zone
    when 'region' then self.activate_in_region
    end
  end

  def deactivate_in_role_scope
    case self.server_role.role_scope
    when 'zone'   then self.deactivate_in_zone
    when 'region' then self.deactivate_in_region
    end
  end

  def activate(override = false)
    if override || self.inactive?
      $log.info("MIQ(AssignedServerRole.activate) Activating Role <#{self.server_role.name}> on Server <#{self.miq_server.name}>")
      self.update_attributes(:active => true)
    end
  end

  def deactivate(override = false)
    if override || self.active?
      $log.info("MIQ(AssignedServerRole.deactivate) Deactivating Role <#{self.server_role.name}> on Server <#{self.miq_server.name}>")
      self.update_attributes(:active => false)
    end
  end

end
