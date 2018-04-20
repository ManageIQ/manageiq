module ManageIQ::Providers
  class PhysicalInfraManager < BaseManager
    include SupportsFeatureMixin

    virtual_total :total_physical_racks,      :physical_racks
    virtual_total :total_physical_switches,   :physical_switches
    virtual_total :total_physical_servers,    :physical_servers
    virtual_column :total_hosts,              :type => :integer
    virtual_column :total_vms,                :type => :integer

    class << model_name
      define_method(:route_key) { "ems_physical_infras" }
      define_method(:singular_route_key) { "ems_physical_infra" }
    end

    def self.ems_type
      @ems_type ||= "physical_infra_manager".freeze
    end

    def self.description
      @description ||= "PhysicalInfraManager".freeze
    end

    def validate_authentication_status
      {:available => true, :message => nil}
    end

    def count_physical_servers_with_host
      physical_servers.inject(0) { |t, physical_server| physical_server.host.nil? ? t : t + 1 }
    end

    alias total_hosts count_physical_servers_with_host

    def count_vms
      physical_servers.inject(0) { |t, physical_server| physical_server.host.nil? ? t : t + physical_server.host.vms.size }
    end

    alias total_vms count_vms

    supports :console do
      unless console_supported?
        unsupported_reason_add(:console, N_("Console not supported"))
      end
    end

    def console_supported?
      false
    end

    def console_url
      raise MiqException::Error, _("Console not supported")
    end
  end
end
