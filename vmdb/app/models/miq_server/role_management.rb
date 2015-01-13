module MiqServer::RoleManagement
  extend ActiveSupport::Concern

  included do
    has_many :assigned_server_roles, :dependent => :destroy
    has_many :server_roles,   :through => :assigned_server_roles
    has_many :active_roles,   :through => :assigned_server_roles, :source => :server_role, :conditions => ['assigned_server_roles.active = ?', true]
    has_many :inactive_roles, :through => :assigned_server_roles, :source => :server_role, :conditions => ['assigned_server_roles.active = ?', false]

    alias assigned_roles server_roles

    before_save    :check_server_roles
  end

  def log_role_changes
    log_prefix = "MIQ(MiqServer.log_role_changes)"

    $log.info("#{log_prefix} Server's roles have changed:")
    o = @active_role_names
    n = self.active_role_names
    adds      = (n - o)
    deletes   = (o - n)
    unchanged = (o & n)
    $log.info("#{log_prefix}   Old roles:       #{o.inspect}")
    $log.info("#{log_prefix}   New roles:       #{n.inspect}")
    $log.info("#{log_prefix}   Roles removed:   #{deletes.inspect}")
    $log.info("#{log_prefix}   Roles added:     #{adds.inspect}")
    $log.info("#{log_prefix}   Roles unchanged: #{unchanged.inspect}")
  end

  def active_roles_changed?
    @active_role_names != self.active_role_names
  end

  def sync_active_roles
    @active_role_names = self.active_role_names
  end

  def set_active_role_flags
    self.has_active_userinterface = self.has_active_role?("user_interface")
    self.has_active_webservices   = self.has_active_role?("web_services")
    self.save
  end

  def set_assigned_roles
    self.role = VMDB::Config.new("vmdb").config[:server][:role]
  end


  def deactivate_all_roles
    deactivate_roles("*")
  end

  def activate_roles(*roles)
    set_role_activation(true, *roles)
  end

  def activate_all_roles
    activate_roles("*")
  end

  def deactivate_roles(*roles)
    set_role_activation(false, *roles)
  end

  def set_role_activation(active, *roles)
    roles = roles.first if roles.length == 1 && roles[0].kind_of?(Array)
    return if roles.empty?

    roles = (roles.length == 1 && roles[0] == "*") ? self.server_roles : ServerRole.where(:name => roles)
    ids   = roles.collect { |r| r.id }
    self.assigned_server_roles.where(:server_role_id => (ids)).each do |a|
      next if a.database_owner?
      next if a.active == active
      active ? a.activate : a.deactivate
    end
  end

  def set_database_owner_role(active)
    dbowner    = ServerRole.database_owner
    assigned   = self.assigned_server_roles.where(:server_role_id => dbowner.id).first
    assigned ||= self.assigned_server_roles.create(:server_role => dbowner, :priority => AssignedServerRole::DEFAULT_PRIORITY, :active => active)

    active ? assigned.activate : assigned.deactivate
  end

  def is_master_for_role?(server_role)
    server_role = ServerRole.to_role(server_role)
    assigned    = self.assigned_server_roles.where(:server_role_id => server_role.id).first
    returned false if assigned.nil?
    assigned.priority == 1
  end

  def set_master_for_role(server_role)
    server_role = ServerRole.to_role(server_role)
    if server_role.master_supported?
      self.zone.miq_servers.delete_if { |s| s.id == self.id }.each do |server|
        assigned = server.assigned_server_roles.where(:server_role_id =>  server_role.id).first
        next if assigned.nil?
        server.assign_role(server_role, 2)  if assigned.priority == 1
      end
    end
    self.assign_role(server_role, 1)
  end

  def remove_master_for_role(server_role)
    self.assign_role(ServerRole.to_role(server_role), 2)
  end

  def check_server_roles
    self.assigned_server_roles.each { |asr| asr.deactivate if asr.server_role.role_scope == 'zone' } if self.zone_id_changed?
  end

  def server_role_names
    self.server_roles.collect { |r| r.name }.sort
  end
  alias my_roles            server_role_names
  alias assigned_role_names server_role_names

  def role
    self.server_role_names.join(',')
  end
  alias my_role       role
  alias assigned_role role

  def role=(val)
    self.zone.lock do
      val = val.to_s.strip.downcase
      if val.blank?
        self.server_roles.delete(ServerRole.all)
      else
        desired = (val == "*" ? ServerRole.all_names : val.split(",").collect { |v| v.strip.downcase }.sort)
        current = self.server_role_names

        # MiqServer#server_role_names may include database scoped roles, which are managed elsewhere,
        # so ignore them when determining added and removed roles.
        current -= ServerRole.database_scoped_role_names

        #TODO: Change this to use replace method under Rails 2.x
        removes = ServerRole.where(:name => (current - desired))
        self.server_roles.delete(removes) unless removes.empty?

        adds    = ServerRole.where(:name => (desired - current))
        adds.each { |r|
          self.assign_role(r)
          self.deactivate_roles(r.name)
        } unless adds.empty?
      end
    end

    self.role
  end

  def assign_role(server_role, priority = nil)
    server_role          = ServerRole.to_role(server_role)
    assigned_server_role = self.assigned_server_roles.find_or_create_by_server_role_id(server_role.id)
    if assigned_server_role.priority.nil? || (priority.kind_of?(Numeric) && assigned_server_role.priority != priority)
      priority ||= AssignedServerRole::DEFAULT_PRIORITY
      assigned_server_role.update_attributes(:priority => priority)
    end
    self.reload
    assigned_server_role
  end

  def inactive_role_names
    self.inactive_roles.collect { |r| r.name }.sort
  end

  def active_role_names
    self.active_roles.collect { |r| r.name }.sort
  end

  def active_role
    self.active_role_names.join(",")
  end

  def licensed_roles
    roles = ServerRole.all.to_a
    unless VMDB::Config.new("vmdb").config[:product][:storage]
      roles.delete_if {|r| r.name.starts_with?('storage_')}
      roles.delete_if {|r| r.name == 'vmdb_storage_bridge'}
    end
    roles
  end

  def licensed_role_names
    self.licensed_roles.collect { |r| r.name }.sort
  end

  def licensed_role
    self.licensed_role_names.join(",")
  end

  def has_assigned_role?(role)
    self.assigned_role_names.include?(role.to_s.strip.downcase)
  end
  alias has_role? has_assigned_role?

  def has_active_role?(role)
    self.active_role_names.include?(role.to_s.strip.downcase)
  end

  def synchronize_active_roles(servers, roles_to_sync)
    current = Hash.new { |h, k| h[k] = {:active => [], :inactive => []} }
    servers.each do |s|
      s.assigned_server_roles.each { |a|
        next unless roles_to_sync.include?(a.server_role)
        # Priority 1 has more weight than Priority 2
        priority = a.priority || AssignedServerRole::DEFAULT_PRIORITY
        current[a.server_role.name][:active]   << [s, priority] if     a.active?
        current[a.server_role.name][:inactive] << [s, priority] unless a.active?
      }
    end

    assigned_roles = servers.collect { |s| s.assigned_roles }.flatten.uniq.compact
    assigned_roles.each do |r|
      next unless roles_to_sync.include?(r)
      role_name = r.name
      if r.unlimited?
        current[role_name][:inactive].each { |s, p| s.activate_roles(role_name) }
      else
        active   = current[role_name][:active].sort   { |a,b| b.last <=> a.last }
        inactive = current[role_name][:inactive].sort { |a,b| a.last <=> b.last }
        delta    = r.max_concurrent - active.length
        if delta < 0
          delta.abs.times do
            if active.length > 0
              s, p = active.shift
              s.deactivate_roles(role_name)
              inactive << [s, p]
            end
          end
          inactive = inactive.sort { |a,b| a.last <=> b.last } # Sort again, since we may have added to array
        elsif delta > 0
          delta.times do
            if inactive.length > 0
              s, p = inactive.shift
              s.activate_roles(role_name)
              active << [s, p]
            end
          end
          active = active.sort { |a,b| b.last <=> a.last } # Sort again, since we may have added to array
        end

        active.each do |s, p|
          if (inactive.length > 0) && (p > inactive.first.last)
            s2, p2 = inactive.shift
            $log.info("#{log_prefix} Migrating Role <#{role_name}> Active on Server <#{s.name}> with Priority <#{p}> to Server <#{s2.name}> with Priority <#{p2}>")
            s.deactivate_roles(role_name)
            s2.activate_roles(role_name)
            active << [s2, p2]
          end
        end

      end
    end
  end

  def monitor_server_roles
    MiqRegion.my_region.lock do |region|
      region.zones.each do |zone|
        synchronize_active_roles(zone.active_miq_servers(:include => [:active_roles, :inactive_roles]), ServerRole.zone_scoped_roles)
      end
      synchronize_active_roles(region.active_miq_servers(:include => [:active_roles, :inactive_roles]), ServerRole.region_scoped_roles)
    end
  end

end
