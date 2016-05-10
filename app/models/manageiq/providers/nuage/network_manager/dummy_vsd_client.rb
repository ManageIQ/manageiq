require 'rubygems'
require 'json'
module ManageIQ::Providers
  class Nuage::NetworkManager::DummyVsdClient
    def initialize(server, user, password)
      @server = server
      @user = user
      @password = password
      _is_conn = true
      File.open("vsd_login.txt" ).each do |line|
       data += line
      end
      if _is_conn
        @enterprise_id = data
        return
      end
      $log.error('VSD Authentication failed')
    end

    def get_enterprises
      File.open("vsd_enterprises.txt" ).each do |line|
       response += line
      end
      if response.code == 200
        if response.body == ''
          $log.warn('No enterprises present')
          return
        end
        return JSON.parse(response.body)
      end
      $log.error('Error in connection ' + response.code.to_s)
    end
   
    def get_domains 
      File.open("vsd_domains.txt" ).each do |line|
       response += line
      end
      if response.code == 200
        if response.body == ''
          $log.warn('No domains present')
          return
        end
        return JSON.parse(response.body)
      end
      $log.error('Error in connection ' + response.code.to_s)
    end

    def get_zones
      File.open("vsd_zones.txt" ).each do |line|
       response += line
      end
      if response.code == 200
        if response.body == ''
          $log.warn('No zones present')
          return
        end
        return JSON.parse(response.body)
      end
      $log.error('Error in connection ' + response.code.to_s)
    end
    
    def get_subnets
      File.open("vsd_subnets.txt" ).each do |line|
       response += line
      end
      if response.code == 200
        if response.body == ''
          $log.warn('No subnets present')
          return
        end
        subnets = JSON.parse(response.body)
        return subnets
      end
      $log.error('Error in connection ' + response.code.to_s)
    end

    def get_vports
      File.open("vsd_vports.txt" ).each do |line|
       response += line
      end
      if response.code == 200
        if response.body == ''
          $log.warn('No vports present')
          return
        end
        return JSON.parse(response.body)
      end
      $log.error('Error in connection ' + response.code.to_s)
    end

    def get_vms
      File.open("vsd_vms.txt" ).each do |line|
       response += line
      end
      if response.code == 200
        if response.body == ''
          $log.warn('No VM present')
          return
        end
        return JSON.parse(response.body)
      end
      $log.error('Error in connection ' + response.code.to_s)
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


