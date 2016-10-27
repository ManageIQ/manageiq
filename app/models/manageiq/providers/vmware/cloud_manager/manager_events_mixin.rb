module ManageIQ::Providers::Vmware::CloudManager::ManagerEventsMixin
  extend ActiveSupport::Concern

  def event_monitor_options
    @event_monitor_options ||= begin
      opts = {
        :ems          => self,
        :virtual_host => "/",
      }
      if (amqp = connection_configuration_by_role("amqp"))
        if (endpoint = amqp.try(:endpoint))
          opts[:hostname]          = endpoint.hostname
          opts[:port]              = endpoint.port
          opts[:security_protocol] = endpoint.security_protocol
        end

        if (authentication = amqp.try(:authentication))
          opts[:username] = authentication.userid
          opts[:password] = authentication.password
        end
      end
      opts
    end
  end

  def verify_amqp_credentials(_options = {})
    ManageIQ::Providers::Vmware::CloudManager::EventCatcher::Stream.test_amqp_connection(event_monitor_options)
  end
end
