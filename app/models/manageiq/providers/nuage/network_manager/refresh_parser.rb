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
      @enterprises       = Hash.new
      @domains           = Hash.new
      @zones             = Hash.new
    end

    def ems_inv_to_hashes
      log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{@ems.name}] id: [#{@ems.id}]"

      $log.info("#{log_header}...")
      get_enterprises
      $log.info(@data)
      @data
    end

    private

    def get_enterprises
      enterprises = @vsd_client.get_enterprises
      p enterprises
      enterprises.each { |enterprise| 
        @enterprises[enterprise['ID']] = enterprise['name']
     }
     get_domains
    end
    
    def get_domains
      domains = @vsd_client.get_domains
      domains.each { |domain| 
        @domains[domain['ID']] = domain['name'], domain['parentID'], @enterprises[domain['parentID']]
     }
      get_zones
    end

    def get_zones
      zones = @vsd_client.get_zones
      zones.each { |zone| 
        domain = @domains[zone['parentID']]
        @zones[zone['ID']] = zone['name'], zone['parentID'], domain[0], domain[1], domain[2]
     }
      get_subnets
    end

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
        :extra_attributes => map_extra_attributes(subnet['parentID'])
      }
      return uid, new_result
    end
    
    def map_extra_attributes(subnet_parent_id)
      zone_id              = subnet_parent_id
      zone                 = @zones[subnet_parent_id]
      zone_name            = zone[0]
      domain_id            = zone[1]
      domain_name          = zone[2]
      enterprise_id        = zone[3]
      enterprise_name      = zone[4]
      return {'enterprise_name' => enterprise_name, 'enterprise_id' => enterprise_id, 
        'domain_name' => domain_name, 'domain_id' => domain_id, 'zone_name' => zone_name, 'zone_id' => zone_id}
    end
   
    class << self
      def cloud_subnet_type
        "ManageIQ::Providers::Nuage::NetworkManager::CloudSubnet"
      end
    end
  end
end
