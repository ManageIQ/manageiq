require 'rest-client'
require 'rubygems'
require 'json'
module ManageIQ::Providers
  class Nuage::NetworkManager::VsdClient
    def initialize(server, user, password)
      @server = server
      @user = user
      @password = password
      @rest_call = Rest.new(server, user, password)
      _is_conn, data = @rest_call.login
      if _is_conn
        @enterprise_id = data
        return
      end
      $log.error('VSD Authentication failed')
    end

    def get_domains
      response = @rest_call.get(@server + '/domains')
      if response.code == 200
        if response.body == ''
          $log.warn('No domains present')
          return
        end
        return JSON.parse(response.body)
      end
      $log.error('Error in connection ' + response.code.to_s)
    end

    def get_subnets
      response = @rest_call.get(@server + '/subnets')
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
      response = @rest_call.get(@server + '/vports')
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
      response = @rest_call.get(@server + '/vms')
      if response.code == 200
        if response.body == ''
          $log.warn('No VM present')
          return
        end
        return JSON.parse(response.body)
      end
      $log.error('Error in connection ' + response.code.to_s)
    end

    def install_license(license_str)
      license_dict = {}
      license_dict['license'] = license_str
      response = @rest_call.post(@server + '/licenses', JSON.dump(license_dict))
      if response.code != 201
        if response.body == 'The license already exists'
          $log.error('license install failed')
        end
      end
    end

    def add_csproot_to_cms_group
      response = @rest_call.get(@server + "/enterprises/#{@enterprise_id}/groups")
      groups = JSON.parse(response.body)
      @cms_group_id = nil
      csproot_user_id = nil

      groups.each do |group|
        $log.info('group::' + group)
        if group['name'] == 'CMS Group'
          @cms_group_id = group['ID']
        end
      end

      response = @rest_call.get(@server + "/enterprises/#{@enterprise_id}/users")
      users = JSON.parse(response.body)
      users.each do |user|
        $log.info('user::' + user)
        if user['userName'] == 'csproot'
          csproot_user_id = user['ID']
        end
      end

      response = @rest_call.get(@server + "/enterprises/#{@cms_group_id}/users")
      $log.info(response.body)
      userlist = ['{' + csproot_user_id + '}']
      @rest_call.put(@server + "/groups/#{@cms_group_id}/users", JSON.dump(userlist))
      response = @rest_call.get(@server + "/groups/#{@cms_group_id}/users")
      $log.info(response.body)
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
