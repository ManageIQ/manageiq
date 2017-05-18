module ManageIQ::Providers
  class Nuage::NetworkManager::RefreshParser
    include ManageIQ::Providers::Nuage::RefreshParserCommon::HelperMethods
    include Vmdb::Logging

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

      _log.info("#{log_header}...")
      get_enterprises
      get_policy_groups
      _log.info(@data)
      @data
    end

    private

    def get_enterprises
      enterprises = @vsd_client.get_enterprises
      enterprises.each do |enterprise|
        @enterprises[enterprise['ID']] = enterprise['name']
      end
      process_collection(enterprises, :network_groups) { |n| parse_network_group(n) }
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
      @data[:network_groups].each do |net|
        # filtering out subnets based on the enterprise they are mapped to
        net[:cloud_subnets] = @vsd_client.get_subnets.collect { |s| parse_subnet(s) }.select { |filter| filter[:extra_attributes]['enterprise_name'] == net[:name] }

        # Lets store also subnets into indexed data, so we can reference them elsewhere
        net[:cloud_subnets].each do |x|
          @data_index.store_path(:cloud_subnets, x[:ems_ref], x)
        end
      end
    end

    def get_policy_groups
      policy_group = @vsd_client.get_policy_groups
      process_collection(policy_group, :security_groups) { |pg| parse_policy_group(pg) }
    end

    def to_cidr(netmask)
      '/' + netmask.to_s.split(".").map { |e| e.to_i.to_s(2).rjust(8, "0") }.join.count("1").to_s
    end

    def parse_network_group(network_group)
      uid     = network_group['ID']
      status  = "active"

      new_result = {
        :type    => self.class.network_group_type,
        :name    => network_group['name'],
        :ems_ref => uid,
        :status  => status,
      }
      return uid, new_result
    end

    def parse_subnet(subnet)
      uid = subnet['ID']

      {
        :type             => self.class.cloud_subnet_type,
        :name             => subnet['name'],
        :ems_ref          => uid,
        :cidr             => subnet['address'].to_s + to_cidr(subnet['netmask']),
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

    def parse_policy_group(pg)
      uid = pg['ID']
      _log.info(@domains[pg['parentID']][2])
      new_result = {
        :type          => self.class.security_group_type,
        :ems_ref       => uid,
        :name          => pg['name'],
        :network_group => NetworkGroup.find_by(:name => (@domains[pg['parentID']][2]).to_s)
      }
      return uid, new_result
    end

    class << self
      def cloud_subnet_type
        "ManageIQ::Providers::Nuage::NetworkManager::CloudSubnet"
      end

      def network_group_type
        "ManageIQ::Providers::Nuage::NetworkManager::NetworkGroup"
      end

      def security_group_type
        'ManageIQ::Providers::Nuage::NetworkManager::SecurityGroup'
      end
    end
  end
end
