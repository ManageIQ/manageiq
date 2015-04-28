class ConfigurationManager < ExtManagementSystem
  has_many :configuration_profiles, :dependent => :destroy
  has_many :configured_systems,     :dependent => :destroy
  has_many :configuration_tags,     :dependent => :destroy, :foreign_key => :manager_id
  has_many :configuration_architectures,                    :foreign_key => :manager_id
  has_many :configuration_compute_profiles,                 :foreign_key => :manager_id
  has_many :configuration_domains,                          :foreign_key => :manager_id
  has_many :configuration_environments,                     :foreign_key => :manager_id
  has_many :configuration_realms,                           :foreign_key => :manager_id

  def self.hostname_required?
    false
  end
end
