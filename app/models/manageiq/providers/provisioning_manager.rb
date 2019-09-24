class ManageIQ::Providers::ProvisioningManager < ManageIQ::Providers::BaseManager
  has_many :operating_system_flavors, :dependent => :destroy
  has_many :customization_scripts,          :foreign_key => :manager_id, :dependent => :destroy
  has_many :customization_script_ptables,   :foreign_key => :manager_id
  has_many :customization_script_media,     :foreign_key => :manager_id
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
