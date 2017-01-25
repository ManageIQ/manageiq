class ManageIQ::Providers::ConfigurationManager < ::ExtManagementSystem
  require_nested :InventoryGroup
  require_nested :InventoryRootGroup

  has_many :configured_systems,           :dependent => :destroy, :foreign_key => "manager_id"
  has_many :configuration_profiles,       :dependent => :destroy, :foreign_key => "manager_id"
  has_many :configuration_scripts,        :dependent => :destroy, :foreign_key => "manager_id"
  has_many :inventory_groups,             :dependent => :destroy, :foreign_key => "ems_id", :inverse_of => :manager
  has_many :configuration_script_sources, :dependent => :destroy, :foreign_key => "manager_id"

  virtual_column  :total_configuration_profiles, :type => :integer
  virtual_column  :total_configured_systems, :type => :integer
  virtual_column  :url, :type => :string

  def self.hostname_required?
    false
  end

  def total_configuration_profiles
    Rbac.filtered(configuration_profiles, :match_via_descendants => ConfiguredSystem).count
  end

  def total_configured_systems
    Rbac.filtered(configured_systems, :match_via_descendants => ConfiguredSystem).count
  end

  delegate :url, to: :provider
end
