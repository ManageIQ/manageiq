class ConfigurationManager < ExtManagementSystem
  has_many :configured_systems,     :dependent => :destroy
  has_many :configuration_profiles, :dependent => :destroy

  def self.hostname_required?
    false
  end

  def total_configuration_profiles
    configuration_profiles.count
  end

  def total_configured_systems
    configured_systems.count
  end
end
