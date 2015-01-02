class ConfigurationManagerForeman < ConfigurationManager
  delegate :connection_attrs, :to => :provider
  has_many :configured_systems, :class_name => :ConfiguredSystemForeman
  has_many :configuration_profiles
end
