class ServerRole < ApplicationRecord
  has_many :assigned_server_roles
  has_many :miq_servers, :through => :assigned_server_roles

  validates :name, :presence => true, :uniqueness_when_changed => true

  scope :database_roles, -> { where(:role_scope => 'database').order(:name) }
  scope :region_roles,   -> { where(:role_scope => 'region').order(:name) }
  scope :zone_roles,     -> { where(:role_scope => 'zone').order(:name) }

  def self.seed
    server_roles = all.index_by(&:name)
    CSV.foreach(fixture_path, :headers => true, :skip_lines => /^#/).each do |csv_row|
      action = csv_row.to_hash

      rec = server_roles[action['name']]
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
    return server_role if server_role.kind_of?(ServerRole)
    role_name = server_role.to_s.strip.downcase
    ServerRole.find_by(:name => role_name) || raise(_("Role <%{name}> not defined in server_roles table") % {:name => role_name})
  end

  def self.all_names
    order(:name).pluck(:name)
  end

  def self.region_scoped_roles
    @region_scoped_roles ||= region_roles.to_a
  end

  def self.zone_scoped_roles
    @zone_scoped_roles ||= zone_roles.to_a
  end

  def self.regional_role?(role)
    region_scoped_roles.any? { |r| r.name == role.to_s }
  end

  def self.database_owner
    @database_owner ||= find_by(:name => 'database_owner')
  end

  def regional_role?
    role_scope == "region"
  end

  def master_supported?
    max_concurrent == 1
  end

  def unlimited?
    max_concurrent == 0
  end
end
