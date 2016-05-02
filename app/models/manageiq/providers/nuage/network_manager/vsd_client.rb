require 'rest-client'
require 'rubygems'
require 'json'
module ManageIQ::Providers
  class Nuage::NetworkManager::VsdClient
    include Vmdb::Logging
    def initialize(server, user, password)
      @server = server
      @user = user
      @password = password
      @rest_call = Rest.new(server, user, password)
      connected, data = @rest_call.login
      if connected
        @enterprise_id = data
        return
      end
      _log.error('VSD Authentication failed')
    end

    def get_enterprises
      response = @rest_call.get(@server + '/enterprises')
      if response.code == 200
        if response.body == ''
          _log.warn('No enterprises present')
          return
        end
        return JSON.parse(response.body)
      end
      _log.error('Error in connection for server ' + @server.to_s + ' ' + response.code.to_s)
    end

    def get_domains
      response = @rest_call.get(@server + '/domains')
      if response.code == 200
        if response.body == ''
          _log.warn('No domains present')
          return
        end
        return JSON.parse(response.body)
      end
      _log.error('Error in connection ' + response.code.to_s)
    end

    def get_zones
      response = @rest_call.get(@server + '/zones')
      if response.code == 200
        if response.body == ''
          _log.warn('No zones present')
          return
        end
        return JSON.parse(response.body)
      end
      _log.error('Error in connection ' + response.code.to_s)
    end

    def get_subnets
      response = @rest_call.get(@server + '/subnets')
      if response.code == 200
        if response.body == ''
          _log.warn('No subnets present')
          return
        end
        subnets = JSON.parse(response.body)
        return subnets
      end
      _log.error('Error in connection ' + response.code.to_s)
    end

    def get_vports
      response = @rest_call.get(@server + '/vports')
      if response.code == 200
        if response.body == ''
          _log.warn('No vports present')
          return
        end
        return JSON.parse(response.body)
      end
      _log.error('Error in connection ' + response.code.to_s)
    end

    def get_vms
      response = @rest_call.get(@server + '/vms')
      if response.code == 200
        if response.body == ''
          _log.warn('No VM present')
          return
        end
        return JSON.parse(response.body)
      end
      _log.error('Error in connection ' + response.code.to_s)
    end

    def install_license(license_str)
      license_dict = {}
      license_dict['license'] = license_str
      response = @rest_call.post(@server + '/licenses', JSON.dump(license_dict))
      if response.code != 201
        if response.body == 'The license already exists'
          _log.error('license install failed')
        end
      end
    end

    def add_csproot_to_cms_group
      response = @rest_call.get(@server + "/enterprises/#{@enterprise_id}/groups")
      groups = JSON.parse(response.body)
      @cms_group_id = nil

      @cms_group_id = groups.detect { ['name'] == 'CMS Group' }.try(:[], 'ID')
      _log.info("groups::#{groups}")

      response = @rest_call.get(@server + "/enterprises/#{@enterprise_id}/users")
      users = JSON.parse(response.body)
      csproot_user_id = users.detect { ['userName'] == 'csproot' }.try(:[], 'ID')
      _log.info("user::#{users}")

      response = @rest_call.get(@server + "/enterprises/#{@cms_group_id}/users")
      _log.info(response.body)
      userlist = ["{#{csproot_user_id}}"]
      @rest_call.put(@server + "/groups/#{@cms_group_id}/users", JSON.dump(userlist))
      response = @rest_call.get(@server + "/groups/#{@cms_group_id}/users")
      _log.info(response.body)
    end
  end
end
