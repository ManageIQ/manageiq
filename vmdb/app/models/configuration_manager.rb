class ConfigurationManager < ExtManagementSystem
  has_many :configured_systems,     :dependent => :destroy
  has_many :configuration_profiles, :dependent => :destroy

  def self.hostname_required?
    false
  end
end
