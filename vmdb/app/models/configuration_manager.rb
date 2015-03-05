class ConfigurationManager < ExtManagementSystem
  has_many :configured_systems,     :dependent => :destroy
  has_many :configuration_profiles, :dependent => :destroy

  def hostname_ipaddress_required?
    false
  end
end

# Preload any subclasses of this class, so that they will be part of the
#   conditions that are generated on queries against this class.
VMDB::Util.eager_load_subclasses('ConfigurationManager')
