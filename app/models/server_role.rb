class ServerRole < ApplicationRecord
  has_many :assigned_server_roles
  has_many :miq_servers, :through => :assigned_server_roles

  validates :name, :presence => true, :uniqueness_when_changed => true

  scope :database_roles, -> { where(:role_scope => 'database').order(:name) }
  scope :region_roles,   -> { where(:role_scope => 'region').order(:name) }
  scope :zone_roles,     -> { where(:role_scope => 'zone').order(:name) }

  def self.seed
    server_roles = all.index_by(&:name)

    server_role_paths = [fixture_path] + Vmdb::Plugins.server_role_paths

    csv_rows = server_role_paths.flat_map do |path|
      CSV.foreach(path, :headers => true, :skip_lines => /^#/).map(&:to_hash)
    end

    csv_rows.each do |action|
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
