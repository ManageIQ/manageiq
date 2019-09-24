module MiqServer::RoleManagement
  extend ActiveSupport::Concern

  ROLES_NEEDING_APACHE = %w(user_interface web_services remote_console cockpit_ws).freeze

  included do
    has_many :assigned_server_roles, :dependent => :destroy
    has_many :server_roles,   :through => :assigned_server_roles
    has_many :active_roles,   -> { where('assigned_server_roles.active' => true) }, :through => :assigned_server_roles, :source => :server_role
    has_many :inactive_roles, -> { where('assigned_server_roles.active' => false) }, :through => :assigned_server_roles, :source => :server_role

    alias_method :assigned_roles, :server_roles

    before_save    :check_server_roles
  end

  def role_changes
    o = @active_role_names
    n = active_role_names
    adds      = (n - o)
    deletes   = (o - n)
    unchanged = (o & n)

    return adds, deletes, unchanged
  end

  def log_role_changes
    _log.info("Server's roles have changed:")
    adds, deletes, unchanged = role_changes
    _log.info("  Old roles:       #{@active_role_names.inspect}")
    _log.info("  New roles:       #{active_role_names.inspect}")
    _log.info("  Roles removed:   #{deletes.inspect}")
    _log.info("  Roles added:     #{adds.inspect}")
    _log.info("  Roles unchanged: #{unchanged.inspect}")
  end

  def active_roles_changed?
    @active_role_names != active_role_names
  end

  def sync_active_roles
    @active_role_names = active_role_names
  end

  def apache_needed?
    # TODO: We need to splat the Array into multiple arguments for now
    # https://github.com/ManageIQ/more_core_extensions/pull/18
    active_role_names.include_any?(*ROLES_NEEDING_APACHE)
  end

  def set_active_role_flags
    self.has_active_userinterface  = self.has_active_role?("user_interface")
    self.has_active_remote_console = self.has_active_role?("remote_console")
    self.has_active_webservices    = self.has_active_role?("web_services")
    self.has_active_cockpit_ws     = self.has_active_role?("cockpit_ws")
    save
  end

  def sync_assigned_roles
    self.role = ::Settings.server.role
  end

  def ensure_default_roles
    MiqServer.my_server.add_settings_for_resource(:server => {:role => ENV["MIQ_SERVER_DEFAULT_ROLES"]}) if role.blank? && ENV["MIQ_SERVER_DEFAULT_ROLES"].present?
    sync_assigned_roles
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

    ids = roles == ["*"] ? server_roles.pluck(:id) : ServerRole.where(:name => roles).pluck(:id)
    assigned_server_roles.where(:server_role_id => ids).each do |a|
      next if a.server_role == ServerRole.database_owner
      next if a.active == active
      active ? a.activate : a.deactivate
    end
  end

  def set_database_owner_role(active)
    dbowner    = ServerRole.database_owner
    assigned   = assigned_server_roles.find_by(:server_role_id => dbowner.id)
    assigned ||= assigned_server_roles.create(:server_role => dbowner, :priority => AssignedServerRole::DEFAULT_PRIORITY, :active => active)

    active ? assigned.activate : assigned.deactivate
  end

  def is_master_for_role?(server_role)
    server_role = ServerRole.to_role(server_role)
    assigned    = assigned_server_roles.find_by(:server_role_id => server_role.id)
    return false if assigned.nil?
    assigned.priority == 1
  end

  def set_master_for_role(server_role)
    server_role = ServerRole.to_role(server_role)
    if server_role.master_supported?
      zone.miq_servers.reject { |s| s.id == id }.each do |server|
        assigned = server.assigned_server_roles.find_by(:server_role_id =>  server_role.id)
        next if assigned.nil?
        server.assign_role(server_role, 2)  if assigned.priority == 1
      end
    end
    assign_role(server_role, 1)
  end

  def remove_master_for_role(server_role)
    assign_role(ServerRole.to_role(server_role), 2)
  end

  def check_server_roles
    assigned_server_roles.each { |asr| asr.deactivate if asr.server_role.role_scope == 'zone' } if self.zone_id_changed?
  end

  def server_role_names
    server_roles.pluck(:name).sort
  end
  alias_method :my_roles,            :server_role_names
  alias_method :assigned_role_names, :server_role_names

  def server_role_names=(roles)
    zone.lock do
      if roles.blank?
        server_roles.delete_all
      else
        desired = (roles == "*" ? ServerRole.all_names : roles.map { |role| role.strip.downcase }.sort)
        current = server_role_names

        # MiqServer#server_role_names may include database scoped roles, which are managed elsewhere,
        # so ignore them when determining added and removed roles.
        current -= ServerRole.database_roles.pluck(:name)

        # TODO: Change this to use replace method under Rails 2.x
        removes = ServerRole.where(:name => (current - desired))
        server_roles.delete(removes) unless removes.empty?

        adds    = ServerRole.where(:name => (desired - current))
        adds.each do |r|
          assign_role(r)
          deactivate_roles(r.name)
        end unless adds.empty?
      end
    end

    roles
  end

  def role
    server_role_names.join(',')
  end
  alias_method :my_role,       :role
  alias_method :assigned_role, :role

  def role=(val)
    self.server_role_names = val == "*" ? val : val.split(",")
    role
  end

  def assign_role(server_role, priority = nil)
    server_role          = ServerRole.to_role(server_role)
    assigned_server_role = assigned_server_roles.find_or_create_by(:server_role_id => server_role.id)
    if assigned_server_role.priority.nil? || (priority.kind_of?(Numeric) && assigned_server_role.priority != priority)
      priority ||= AssignedServerRole::DEFAULT_PRIORITY
      assigned_server_role.update(:priority => priority)
    end
    reload
    assigned_server_role
  end

  def inactive_role_names
    inactive_roles.pluck(:name).sort
  end

  def active_role_names
    active_roles.pluck(:name).sort
  end

  def active_role
    active_role_names.join(",")
  end

  def licensed_roles
    ServerRole.all.to_a # TODO: The UI calls delete_if on this method, so it needs to be an Array
  end

  def licensed_role_names
    licensed_roles.collect(&:name).sort
  end

  def licensed_role
    licensed_role_names.join(",")
  end

  def has_assigned_role?(role)
    assigned_role_names.include?(role.to_s.strip.downcase)
  end
  alias_method :has_role?, :has_assigned_role?

  def has_active_role?(role)
    active_role_names.include?(role.to_s.strip.downcase)
  end

  def synchronize_active_roles(servers, roles_to_sync)
    current = Hash.new { |h, k| h[k] = {:active => [], :inactive => []} }
    servers.each do |s|
      s.assigned_server_roles.each do |a|
        next unless roles_to_sync.include?(a.server_role)
        # Priority 1 has more weight than Priority 2
        priority = a.priority || AssignedServerRole::DEFAULT_PRIORITY
        current[a.server_role.name][:active] << [s, priority] if     a.active?
        current[a.server_role.name][:inactive] << [s, priority] unless a.active?
      end
    end

    assigned_roles = servers.collect(&:assigned_roles).flatten.uniq.compact
    assigned_roles.each do |r|
      next unless roles_to_sync.include?(r)
      role_name = r.name
      if r.unlimited?
        current[role_name][:inactive].each { |s, _p| s.activate_roles(role_name) }
      else
        active   = current[role_name][:active].sort_by(&:last).reverse
        inactive = current[role_name][:inactive].sort_by(&:last)
        delta    = r.max_concurrent - active.length
        if delta < 0
          delta.abs.times do
            if active.length > 0
              s, p = active.shift
              s.deactivate_roles(role_name)
              inactive << [s, p]
            end
          end
          inactive = inactive.sort_by(&:last) # Sort again, since we may have added to array
        elsif delta > 0
          delta.times do
            if inactive.length > 0
              s, p = inactive.shift
              s.activate_roles(role_name)
              active << [s, p]
            end
          end
          active = active.sort_by(&:last).reverse # Sort again, since we may have added to array
        end

        active.each do |s, p|
          if (inactive.length > 0) && (p > inactive.first.last)
            s2, p2 = inactive.shift
            _log.info("Migrating Role <#{role_name}> Active on Server <#{s.name}> with Priority <#{p}> to Server <#{s2.name}> with Priority <#{p2}>")
            s.deactivate_roles(role_name)
            s2.activate_roles(role_name)
            active << [s2, p2]
          end
        end

      end
    end
  end

  def monitor_server_roles_timeout
    ::Settings.server.monitor_server_roles_timeout.to_i_with_method
  end

  def monitor_server_roles
    MiqRegion.my_region.lock(:exclusive, monitor_server_roles_timeout) do |region|
      region.zones.each do |zone|
        synchronize_active_roles(zone.active_miq_servers.includes([:active_roles, :inactive_roles]), ServerRole.zone_scoped_roles)
      end
      synchronize_active_roles(region.active_miq_servers.includes([:active_roles, :inactive_roles]), ServerRole.region_scoped_roles)
    end
  end
end
