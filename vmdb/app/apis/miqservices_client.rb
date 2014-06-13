class MiqservicesClient < EvmWebservicesClient
  # Get an internal or external driver depending on the config.vmdb mode
  def self.get_driver(config)
    if config.vmdb
      MiqservicesClientInternal.new
    else
      MiqservicesClient.new("#{config.vmdbHost}:#{config.vmdbPort}", config.webservices[:consumer_protocol])
    end
  end
end
