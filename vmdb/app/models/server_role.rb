class ServerRole < ActiveRecord::Base
  has_many :assigned_server_roles
  has_many :miq_servers, :through => :assigned_server_roles

  validates_presence_of     :name
  validates_uniqueness_of   :name

  FIXTURE_DIR = File.join(Rails.root, "db/fixtures")

  def self.seed_data
    File.read(File.join(FIXTURE_DIR, "#{self.to_s.pluralize.underscore}.csv"))
  end

  def self.seed
    MiqRegion.my_region.lock do
      data = self.seed_data.split("\n")
      cols = data.shift.split(",")

      data.each do |a|
        next if a =~ /^#.*$/ # skip commented lines

        arr = a.split(",")

        action = {}
        cols.each_index {|i| action[cols[i].to_sym] = arr[i]}

        rec = self.where(:name => (action[:name])).first
        if rec.nil?
          $log.info("MIQ(ServerRole.seed) Creating Server Role [#{action[:name]}]")
          rec = self.create(action)
        else
          rec.attributes = action
          if rec.changed?
            $log.info("MIQ(ServerRole.seed) Updating Server Role [#{action[:name]}]")
            rec.save
          end
        end
      end
    end
    @zone_scoped_roles = @region_scoped_roles = nil
  end

  def self.to_role(server_role)
    # server_role can either be a Role Name (string or symbol) or an instance of a ServerRole
    unless server_role.kind_of?(ServerRole)
      role_name   = server_role.to_s.strip.downcase
      server_role = ServerRole.where(:name => role_name).first
      raise "Role <#{role_name}> not defined in server_roles table" if server_role.nil?
    end

    server_role
  end

  def self.all_names
    self.order(:name).pluck(:name)
  end

  def self.database_scoped_role_names
    self.where(:role_scope => 'database').order(:name).pluck(:name)
  end

  def self.database_scoped_roles
    @database_scoped_roles ||= self.where(:role_scope =>('database').order(:name))
  end

  def self.region_scoped_roles
    @region_scoped_roles ||= self.where(:role_scope => 'region').order(:name)
  end

  def self.zone_scoped_roles
    @zone_scoped_roles ||= self.where(:role_scope => 'zone').order(:name)
  end

  def self.database_role?(role)
    self.database_scoped_roles.any? {|r| r.name == role.to_s}
  end

  def self.regional_role?(role)
    self.region_scoped_roles.any? {|r| r.name == role.to_s}
  end

  def self.zonal_role?(role)
    self.zone_scoped_roles.any? {|r| r.name == role.to_s}
  end

  def database_role?
    self.current_role_scope == "database"
  end

  def regional_role?
    self.current_role_scope == "region"
  end

  def zonal_role?
    self.current_role_scope == "zone"
  end

  def current_role_scope
    self.role_scope
  end

  def master_supported?
    self.max_concurrent == 1
  end

  def unlimited?
    self.max_concurrent == 0
  end

  def self.database_owner
    @database_owner ||= self.find_by_name('database_owner')
  end

end
