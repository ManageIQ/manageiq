module ManageIQ::Providers::Vmware::CloudManager::ManagerEventsMixin
  extend ActiveSupport::Concern

  def event_monitor_options
    @event_monitor_options ||= begin
      opts = {
        :ems          => self,
        :virtual_host => "/",
      }
      amqp = connection_configuration_by_role("amqp")
      if (endpoint = amqp.try(:endpoint))
        opts[:hostname]          = endpoint.hostname
        opts[:port]              = endpoint.port
        opts[:security_protocol] = endpoint.security_protocol
      end

      if (authentication = amqp.try(:authentication))
        opts[:username] = authentication.userid
        opts[:password] = authentication.password
      end
      opts
    end
  end

  def verify_amqp_credentials(_options = {})
    ManageIQ::Providers::Vmware::CloudManager::EventCatcher::Stream.test_amqp_connection(event_monitor_options)
  rescue => err
    raise translate_exception(err)
  end
end
