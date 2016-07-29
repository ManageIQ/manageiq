module ManageIQ::Providers
  class Nuage::NetworkManager::RefreshParser
    include ManageIQ::Providers::Nuage::RefreshParserCommon::HelperMethods

    def self.ems_inv_to_hashes(ems, options = nil)
      new(ems, options).ems_inv_to_hashes
    end

    def initialize(ems, options = nil)
      @ems               = ems
      @vsd_client        = ems.connect
      @options           = options || {}
      @data              = {}
      @data_index        = {}
    end

    def ems_inv_to_hashes
      log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{@ems.name}] id: [#{@ems.id}]"

      $log.info("#{log_header}...")
      get_subnets

      @data
    end

    private

    def get_subnets
      subnets = @vsd_client.get_subnets
      process_collection(subnets, :cloud_subnets) { |s| parse_subnets(s) }
    end

    def to_cidr(netmask)
      '/' + netmask.to_i.to_s(2).count("1").to_s
    end

    def parse_subnets(subnet)
      uid = subnet['ID']

      new_result = {
        :type             => self.class.cloud_subnet_type,
        :name             => subnet['name'],
        :ems_ref          => uid,
        :cidr             => subnet['address'] + to_cidr(subnet['netmask']),
        :network_protocol => subnet['IPType'].downcase!,
        :gateway          => subnet['gateway'],
        :dhcp_enabled     => false,
        :ip_version       => 4,
      }
      return uid, new_result
    end

    class << self
      def cloud_subnet_type
        "ManageIQ::Providers::Nuage::NetworkManager::CloudSubnet"
      end
    end
  end
end
