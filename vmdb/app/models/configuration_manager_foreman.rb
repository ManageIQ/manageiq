class ConfigurationManagerForeman < ConfigurationManager
  # def raw_connect
  #   Manageiq::Providers::Foreman::Connection.new(connection_attrs)
  # end

  delegate :connection_attrs, :to => :provider
  has_many :configured_systems, :class_name => :ConfiguredSystemForemans
  has_many :configuration_profiles
end
