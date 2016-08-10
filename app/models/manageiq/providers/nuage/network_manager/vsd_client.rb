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
  end
end
