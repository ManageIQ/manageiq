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
      @enterprises       = {}
      @domains           = {}
      @zones             = {}
    end

    def ems_inv_to_hashes
      log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{@ems.name}] id: [#{@ems.id}]"

      $log.info("#{log_header}...")
      get_enterprises
      #$log.info(@data)
      @data
    end

    private

    def get_enterprises
      enterprises = @vsd_client.get_enterprises
      enterprises.each do |enterprise|
        @enterprises[enterprise['ID']] = enterprise['name']
      end
      get_domains
    end

    def get_domains
      domains = @vsd_client.get_domains
      domains.each do |domain|
        @domains[domain['ID']] = domain['name'], domain['parentID'], @enterprises[domain['parentID']]
      end
      get_zones
    end

    def get_zones
      zones = @vsd_client.get_zones
      zones.each do |zone|
        domain = @domains[zone['parentID']]
        @zones[zone['ID']] = zone['name'], zone['parentID'], domain[0], domain[1], domain[2]
      end
      get_subnets
    end

    def get_subnets
      subnets = @vsd_client.get_subnets
      process_collection(subnets, :cloud_subnets) { |s| parse_subnets(s) }
    end

    def to_cidr(netmask)
      '/' + netmask.split(".").map { |e| e.to_i.to_s(2).rjust(8, "0") }.join.count("1").to_s
    end

    def parse_network_group(network_group)
      uid     = network_group['ID']
      status  = "active"

      new_result = {
        :type    => self.class.network_group_type,
        :name    => uid,
        :ems_ref => uid,
        :status  => status,
      }
      return uid, new_result
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
    end

    def map_extra_attributes(subnet_parent_id)
      zone_id              = subnet_parent_id
      zone                 = @zones[subnet_parent_id]
      {'enterprise_name' => zone[4],
       'enterprise_id'   => zone[3],
       'domain_name'     => zone[2],
       'domain_id'       => zone[1],
       'zone_name'       => zone[0],
       'zone_id'         => zone_id}
    end
    
    def map_extra_attributes(subnet_parent_id)
      zone_id              = subnet_parent_id
      zone_name            = @zones[subnet_parent_id][0]
      domain_id            = @zones[subnet_parent_id][1]
      domain_name          = @zones[subnet_parent_id][2]
      enterprise_id        = @zones[subnet_parent_id][3]
      enterprise_name      = @zones[subnet_parent_id][4]
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
