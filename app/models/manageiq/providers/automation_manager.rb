class ManageIQ::Providers::AutomationManager < ManageIQ::Providers::BaseManager
  require_nested :Authentication
  require_nested :ConfigurationScript
  require_nested :ConfigurationScriptPayload
  require_nested :ConfigurationScriptSource
  require_nested :ConfiguredSystem
  require_nested :InventoryGroup
  require_nested :InventoryRootGroup
  require_nested :OrchestrationStack

  has_many :configured_systems,           :dependent => :destroy, :foreign_key => "manager_id"
  has_many :configuration_profiles,       :dependent => :destroy, :foreign_key => "manager_id"
  has_many :configuration_scripts,        :dependent => :destroy, :foreign_key => "manager_id"
  has_many :authentication_configuration_script_bases, :through => :configuration_scripts
  has_many :credentials,                  :class_name => "ManageIQ::Providers::AutomationManager::Authentication",
           :as => :resource, :dependent => :destroy
  has_many :inventory_groups,             :dependent => :destroy, :foreign_key => "ems_id", :inverse_of => :manager
  has_many :inventory_root_groups,        :dependent => :destroy, :foreign_key => "ems_id", :inverse_of => :manager
  has_many :configuration_script_sources, :dependent => :destroy, :foreign_key => "manager_id"
  has_many :configuration_script_payloads, :through => :configuration_script_sources

  has_many :workflows,          :dependent => :destroy, :foreign_key => :ems_id, :inverse_of => :ext_management_system
  has_many :workflow_instances, :dependent => :destroy, :foreign_key => :ems_id, :inverse_of => :ext_management_system

  delegate :url, :to => :provider

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
    Rbac.filtered(configured_systems).count
  end

  def total_inventory_groups
    Rbac.filtered(inventory_groups).count
  end
end
