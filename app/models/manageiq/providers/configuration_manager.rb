class ManageIQ::Providers::ConfigurationManager < ::ExtManagementSystem
  has_many :configured_systems,           :dependent => :destroy, :foreign_key => "manager_id"
  has_many :configuration_profiles,       :dependent => :destroy, :foreign_key => "manager_id"
  has_many :configuration_scripts,        :dependent => :destroy, :foreign_key => "manager_id"
  has_many :configuration_script_sources, :dependent => :destroy, :foreign_key => "manager_id"

  virtual_column  :total_configuration_profiles, :type => :integer
  virtual_column  :total_configured_systems, :type => :integer

  def self.hostname_required?
    false
  end

  def total_configuration_profiles
    Rbac.filtered(configuration_profiles, :match_via_descendants => ConfiguredSystem).count
  end

  def total_configured_systems
    Rbac.filtered(configured_systems, :match_via_descendants => ConfiguredSystem).count
  end
end
