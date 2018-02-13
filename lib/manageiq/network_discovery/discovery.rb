require 'net/ping'

module ManageIQ
  module NetworkDiscovery
    module IPMI
      autoload :Discovery, 'manageiq/network_discovery/ipmi/discovery'
    end

    module Discovery
      PROVIDERS_BY_TYPE = {
        :ipmi            => "ManageIQ::NetworkDiscovery::IPMI::Discovery",
        :msvirtualserver => "ManageIQ::Providers::Microsoft::Discovery",
        :mswin           => "ManageIQ::Providers::Microsoft::Discovery",
        :scvmm           => "ManageIQ::Providers::Microsoft::Discovery",
        :openstack_infra => "ManageIQ::Providers::Openstack::Discovery",
        :rhevm           => "ManageIQ::Providers::Redhat::Discovery",
        :esx             => "ManageIQ::Providers::Vmware::Discovery",
        :virtualcenter   => "ManageIQ::Providers::Vmware::Discovery",
        :vmwareserver    => "ManageIQ::Providers::Vmware::Discovery"
      }.freeze

      def self.scan_host(ost)
        ost.os = []
        ost.hypervisor = []

        # If the ping flag is set we try to ping the box first
        # and skip scanning if the ping fails.
        ping = true
        begin
          ping = Net::Ping::External.new(ost.ipaddr).ping if ost.ping
        rescue Timeout::Error
          ping = false
        end

        if ping
          # Trigger probes
          ost.discover_types.each do |type|
            next unless PROVIDERS_BY_TYPE.include?(type)
            klass = Object.const_get(PROVIDERS_BY_TYPE[type])
            $log&.info("#{klass}: probing ip = #{ost.ipaddr}")
            klass.probe(ost)
            $log&.info("#{klass}: probe of ip = #{ost.ipaddr} complete")
          end
        end
      end
    end
  end
end
