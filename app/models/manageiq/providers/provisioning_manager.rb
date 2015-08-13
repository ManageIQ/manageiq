class ManageIQ::Providers::ProvisioningManager < ::ExtManagementSystem
  has_many :operating_system_flavors, :dependent => :destroy
  has_many :customization_scripts,    :dependent => :destroy
  has_many :customization_script_ptables
  has_many :customization_script_media
  has_many :configuration_tags,             :foreign_key => :manager_id, :dependent => :destroy
  has_many :configuration_architectures,    :foreign_key => :manager_id
  has_many :configuration_compute_profiles, :foreign_key => :manager_id
  has_many :configuration_domains,          :foreign_key => :manager_id
  has_many :configuration_environments,     :foreign_key => :manager_id
  has_many :configuration_realms,           :foreign_key => :manager_id

  def self.hostname_required?
    false
  end
end
