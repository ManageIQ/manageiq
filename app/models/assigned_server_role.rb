class AssignedServerRole < ApplicationRecord
  belongs_to :miq_server
  belongs_to :server_role

  default_value_for :active, false

  delegate :master_supported?, :name, :to => :server_role

  HIGH_PRIORITY        = 1
  MEDIUM_PRIORITY      = 2
  LOW_PRIORITY         = 3
  DEFAULT_PRIORITY     = MEDIUM_PRIORITY
  AVAILABLE_PRIORITIES = [HIGH_PRIORITY,  MEDIUM_PRIORITY, LOW_PRIORITY]
  validates :priority, :inclusion => {:in => AVAILABLE_PRIORITIES}, :allow_nil => true

  def reset
    update(:priority => DEFAULT_PRIORITY, :active => false)
  end

  def is_master?
    miq_server.is_master_for_role?(server_role)
  end

  def inactive?
    !self.active?
  end

  def set_master
    miq_server.set_master_for_role(server_role)
    reload
  end

  def remove_master
    miq_server.remove_master_for_role(server_role)
    reload
  end

  def set_priority(val)
    # Only allow 1 Primary in the RoleScope
    if val == HIGH_PRIORITY && server_role.master_supported?
      if ['zone', 'region'].include?(server_role.role_scope)
        method = "find_other_servers_in_#{server_role.role_scope}"
        other_servers = miq_server.send(method)
        other_servers.each do |server|
          assigned = server.assigned_server_roles.find_by(:server_role_id => server_role_id)
          next if assigned.nil?
          assigned.update_attribute(:priority, DEFAULT_PRIORITY)  if assigned.priority == HIGH_PRIORITY
        end
      end
    end

    update_attribute(:priority, val)
  end

  def activate_in_region(override = false)
    return unless server_role.role_scope == 'region'

    if override || self.inactive?
      MiqRegion.my_region.lock do
        if server_role.master_supported?
          servers = MiqRegion.my_region.active_miq_servers
          self.class.where(:server_role_id => server_role.id).each do |asr|
            asr.deactivate if servers.include?(asr.miq_server)
          end
        end

        activate(override)
      end
    end
  end

  def deactivate_in_region(override = false)
    return unless server_role.role_scope == 'region'

    if override || self.active?
      MiqRegion.my_region.lock do
        deactivate(override)
      end
    end
  end

  def activate_in_zone(override = false)
    return unless server_role.role_scope == 'zone'

    if override || self.inactive?
      miq_server.zone.lock do |_zone|
        if server_role.master_supported?
          servers = miq_server.zone.active_miq_servers
          self.class.where(:server_role_id => server_role.id).each do |asr|
            asr.deactivate if servers.include?(asr.miq_server)
          end
        end

        activate(override)
      end
    end
  end

  def deactivate_in_zone(override = false)
    return unless server_role.role_scope == 'zone'

    if override || self.active?
      miq_server.zone.lock do |_zone|
        deactivate(override)
      end
    end
  end

  def activate_in_role_scope
    case server_role.role_scope
    when 'zone'   then activate_in_zone
    when 'region' then activate_in_region
    end
  end

  def deactivate_in_role_scope
    case server_role.role_scope
    when 'zone'   then deactivate_in_zone
    when 'region' then deactivate_in_region
    end
  end

  def activate(override = false)
    if override || self.inactive?
      _log.info("Activating Role <#{server_role.name}> on Server <#{miq_server.name}>")
      update(:active => true)
    end
  end

  def deactivate(override = false)
    if override || self.active?
      _log.info("Deactivating Role <#{server_role.name}> on Server <#{miq_server.name}>")
      update(:active => false)
    end
  end
end
