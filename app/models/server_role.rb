class ServerRole < ApplicationRecord
  has_many :assigned_server_roles
  has_many :miq_servers, :through => :assigned_server_roles

  validates_presence_of     :name
  validates_uniqueness_of   :name

  def self.seed
    CSV.foreach(fixture_path, :headers => true, :skip_lines => /^#/).each do |csv_row|
      action = csv_row.to_hash

      rec = find_by(:name => action['name'])
      if rec.nil?
        _log.info("Creating Server Role [#{action['name']}]")
        create(action)
      else
        rec.attributes = action
        if rec.changed?
          _log.info("Updating Server Role [#{action['name']}]")
          rec.save
        end
      end
    end
    @zone_scoped_roles = @region_scoped_roles = nil
  end

  def self.fixture_path
    FIXTURE_DIR.join("#{to_s.pluralize.underscore}.csv")
  end

  def self.to_role(server_role)
    # server_role can either be a Role Name (string or symbol) or an instance of a ServerRole
    unless server_role.kind_of?(ServerRole)
      role_name   = server_role.to_s.strip.downcase
      server_role = ServerRole.find_by(:name => role_name)
      raise _("Role <%{name}> not defined in server_roles table") % {:name => role_name} if server_role.nil?
    end

    server_role
  end

  def self.all_names
    order(:name).pluck(:name)
  end

  def self.database_scoped_role_names
    where(:role_scope => 'database').order(:name).pluck(:name)
  end

  def self.database_scoped_roles
    @database_scoped_roles ||= where(:role_scope => 'database').order(:name).to_a
  end

  def self.region_scoped_roles
    @region_scoped_roles ||= where(:role_scope => 'region').order(:name).to_a
  end

  def self.zone_scoped_roles
    @zone_scoped_roles ||= where(:role_scope => 'zone').order(:name).to_a
  end

  def self.database_role?(role)
    database_scoped_roles.any? { |r| r.name == role.to_s }
  end

  def self.regional_role?(role)
    region_scoped_roles.any? { |r| r.name == role.to_s }
  end

  def self.zonal_role?(role)
    zone_scoped_roles.any? { |r| r.name == role.to_s }
  end

  def database_role?
    current_role_scope == "database"
  end

  def regional_role?
    current_role_scope == "region"
  end

  def zonal_role?
    current_role_scope == "zone"
  end

  def current_role_scope
    role_scope
  end

  def master_supported?
    max_concurrent == 1
  end

  def unlimited?
    max_concurrent == 0
  end

  def self.database_owner
    @database_owner ||= find_by(:name => 'database_owner')
  end
end
