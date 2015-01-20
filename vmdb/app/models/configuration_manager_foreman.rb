class ConfigurationManagerForeman < ConfigurationManager
  delegate :connection_attrs, :name, :to => :provider

  def self.ems_type
    "foreman_configuration".freeze
  end
end
