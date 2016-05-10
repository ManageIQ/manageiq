require 'rubygems'
require 'json'
module ManageIQ::Providers
  class Nuage::NetworkManager::DummyVsdClient
    def initialize(server, user, password)
      @server = server
      @user = user
      @password = password
      _is_conn = true
      data = ""
      File.open("app/models/manageiq/providers/nuage/network_manager/vsd_login.txt" ).each do |line|
       data = data.to_s + line.to_s
      end
      if _is_conn
        @enterprise_id = data
        return
      end
      $log.error('VSD Authentication failed')
    end

    def get_enterprises
      response = ""
      File.open("app/models/manageiq/providers/nuage/network_manager/vsd_enterprises.txt" ).each do |line|
       response = response + line.to_s
      end
      return JSON.parse(response)
    end
   
    def get_domains
      response = "" 
      File.open("app/models/manageiq/providers/nuage/network_manager/vsd_domains.txt" ).each do |line|
       response = response + line.to_s
      end
      return JSON.parse(response)
    end

    def get_zones
      response = ""
      File.open("app/models/manageiq/providers/nuage/network_manager/vsd_zones.txt" ).each do |line|
       response = response + line.to_s
      end
      return JSON.parse(response)
    end
    
    def get_subnets
      response = ""
      File.open("app/models/manageiq/providers/nuage/network_manager/vsd_subnets.txt" ).each do |line|
       response = response + line.to_s
      end
       return JSON.parse(response)
    end

    def get_vports
      response = ""
      File.open("app/models/manageiq/providers/nuage/network_manager/vsd_vports.txt" ).each do |line|
       response = response + line.to_s
      end
      return JSON.parse(response)
    end

    def get_vms
      response = ""
      File.open("app/models/manageiq/providers/nuage/network_manager/vsd_vms.txt" ).each do |line|
       response = response + line.to_s
      end
      return JSON.parse(response)
    end


    class << self
      def security_group_type
        'ManageIQ::Providers::Nuage::NetworkManager::SecurityGroup'
      end

      def network_router_type
        "ManageIQ::Providers::Nuage::NetworkManager::NetworkRouter"
      end

      def cloud_network_type
        "ManageIQ::Providers::Nuage::NetworkManager::CloudNetwork"
      end

      def cloud_subnet_type
        "ManageIQ::Providers::Nuage::NetworkManager::CloudSubnet"
      end

      def floating_ip_type
        "ManageIQ::Providers::Nuage::NetworkManager::FloatingIp"
      end

      def network_port_type
        "ManageIQ::Providers::Nuage::NetworkManager::NetworkPort"
      end
    end
  end
end


