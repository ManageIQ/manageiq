class ConfigurationServiceForeman < ConfigurationService
  # def raw_connect
  #   Manageiq::Providers::Foreman::Connection.new(connection_attrs)
  # end

  delegate :connection_attrs, :to => :provider
end
