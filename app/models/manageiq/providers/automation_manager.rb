class ManageIQ::Providers::AutomationManager < ::ExtManagementSystem
  require_nested :InventoryGroup
  require_nested :InventoryRootGroup

  has_many :configured_systems,           :dependent => :destroy, :foreign_key => "manager_id"
  has_many :configuration_profiles,       :dependent => :destroy, :foreign_key => "manager_id"
  has_many :configuration_scripts,        :dependent => :destroy, :foreign_key => "manager_id"
  has_many :credentials,                  :class_name => "ManageIQ::Providers::AutomationManager::Authentication",
           :as => :resource, :dependent => :destroy
  has_many :inventory_groups,             :dependent => :destroy, :foreign_key => "ems_id", :inverse_of => :manager
  has_many :inventory_root_groups,        :dependent => :destroy, :foreign_key => "ems_id", :inverse_of => :manager
  has_many :configuration_script_sources, :dependent => :destroy, :foreign_key => "manager_id"
  has_many :configuration_script_payloads, :through => :configuration_script_sources

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
