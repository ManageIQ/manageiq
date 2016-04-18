module ManageIQ::Providers
  class InfraManager < BaseManager
    require_nested :Template
    require_nested :ProvisionWorkflow
    require_nested :Vm

    class << model_name
      define_method(:route_key) { "ems_infras" }
      define_method(:singular_route_key) { "ems_infra" }
    end

    #
    # ems_timeouts is a general purpose proc for obtaining
    # read and open timeouts for any ems type and optional service.
    #
    # :ems
    #   :ems_redhat    (This is the type parameter for these methods)
    #     :open_timeout: 3.minutes
    #     :inventory   (This is the optional service parameter for ems_timeouts)
    #        :read_timeout: 5.minutes
    #     :service
    #        :read_timeout: 1.hour
    #
    cache_with_timeout(:ems_config, 2.minutes) { VMDB::Config.new("vmdb").config[:ems] || {} }

    def self.ems_timeouts(type, service = nil)
      read_timeout = open_timeout = nil
      if ems_config[type]
        if service
          if ems_config[type][service.downcase.to_sym]
            config       = ems_config[type][service.downcase.to_sym]
            read_timeout = config[:read_timeout] if config[:read_timeout]
            open_timeout = config[:open_timeout] if config[:open_timeout]
          end
        end
        read_timeout = ems_config[type][:read_timeout] if read_timeout.nil?
        open_timeout = ems_config[type][:open_timeout] if open_timeout.nil?
      end
      read_timeout = read_timeout.to_i_with_method if read_timeout
      open_timeout = open_timeout.to_i_with_method if open_timeout
      [read_timeout, open_timeout]
    end
  end
end
