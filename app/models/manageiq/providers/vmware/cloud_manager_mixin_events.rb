module ManageIQ::Providers::Vmware::CloudManagerMixinEvents
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

  def event_monitor_available?
    require 'vmware/vmware_vcloud_event_monitor'
    VmwareVcloudEventMonitor.available?(event_monitor_options)
  rescue => e
    _log.error("Exception trying to find Vmware vCloud event monitor for #{name}(#{hostname}). #{e.message}")
    _log.error(e.backtrace.join("\n"))
    false
  end

  def verify_amqp_credentials(_options = {})
    require 'vmware/vmware_vcloud_event_monitor'
    VmwareVcloudEventMonitor.test_amqp_connection(event_monitor_options)
  rescue => err
    miq_exception = translate_exception(err)
    raise unless miq_exception

    _log.error("Error Class=#{err.class.name}, Message=#{err.message}")
    raise miq_exception
  end
end
