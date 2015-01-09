class ConfigurationManagerForeman < ConfigurationManager
  delegate :connection_attrs, :to => :provider
end
