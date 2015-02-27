class ConfigurationManagerForeman < ConfigurationManager
  delegate :raw_connect, :connection_attrs, :name, :to => :provider

  def self.ems_type
    "foreman_configuration".freeze
  end

  def with_provider_connection(options = {})
    raise "no block given" unless block_given?
    log_header = "MIQ(#{self.class.name}.with_provider_connection)"
    $log.info("#{log_header} Connecting through #{self.class.name}: [#{name}]")
    yield raw_connect(options)
  end
end
