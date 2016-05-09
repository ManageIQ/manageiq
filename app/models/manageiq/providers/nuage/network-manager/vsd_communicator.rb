require 'rest-client'
require 'rubygems'
require 'json'
class Rest
  def initialize(server, user, password)
    @server=server
    @user=user
    @password=password
    @apiKey=''
    @headers = {'X-Nuage-Organization'=>'csp',"Content-Type"=>"application/json; charset=UTF-8"}
  end

  def login
    @loginUrl = @server+"/me"
    #p "Rest Client loginUrl: { #@loginUrl }"
    RestClient::Request.execute(method: :get, url: @loginUrl,user:@user ,password:@password ,headers:@headers){ |response, request, result, &block|
      case response.code
        when 200
          data = JSON.parse(response.body)
          data1 = data[0]
          #p response.body
          @apiKey = data1["APIKey"]
          return true,data1["enterpriseID"]
        else
          return false,nil
      end
    }

  end

  def server
    return @server
  end

  def appendHeaders(key, value)
    @headers[key]=value
  end

  def get(url)
    if (@apiKey == '')
      login
    end
    #p url
    RestClient::Request.execute(method: :get, url: url,user:@user ,password:@apiKey ,headers:@headers){ |response, request, result, &block|
      #p response.code
      #p response.body
      return response
    }
  end

  def delete(url)
    if(@apiKey == '')
      login
    end
    RestClient::Request.execute(method: :delete, url: url,user:@user ,password:@apiKey ,headers:@headers){ |response, request, result, &block|
      #p response.code
      #p response.body
      return response
    }
  end

  def put(url,data)
    if (@apiKey == '')
      login
    end
    #p url
    #p data
    RestClient::Request.execute(method: :put, data: data, url: url,user:@user ,password:@apiKey ,headers:@headers){ |response, request, result, &block|
      #p response.code
      #p response.body
      return response
    }
  end

  def post(url,data)
    if (@apiKey == '')
      login
    end
    #p url
    #p data
    RestClient::Request.execute(method: :post, data: data, url: url,user:@user ,password:@apiKey ,headers:@headers){ |response, request, result, &block|
      #p response.code
      #p response.body
      return response
    }
  end

end

#aRest=Rest.new(ARGV[0],ARGV[1],ARGV[2]);
#p JSON.parse(aRest.get(ARGV[0]+"/vms"))
class ManageIQ::Providers::Nuage::VsdClient
  def initialize(server, user, password)
    @server=server
    @user=user
    @password=password
    @restCall = Rest.new(server,user,password);
    _is_conn,data = @restCall.login
    if _is_conn
      @enterprise_id = data
      return
    end
    p 'VSD Authentication failed'
  end

  def get_domains
    response = @restCall.get(@server + '/domains')
    if (response.code == 200)
      if (response.body == '')
        p 'No domains present'
        return
      end
      return JSON.parse(response.body)
    end
    p 'Error in connection '+response.code.to_s
  end

  def get_subnets
    response = @restCall.get(@server + '/subnets')
    if (response.code == 200)
      if (response.body == '')
        p 'No subnets present'
        return
      end
      subnets = JSON.parse(response.body)
      results = subnets.collect { |subnet|
          {
           :type                           => self.class.cloud_subnet_type,
           :name                           => subnet['name'],
           :ems_ref                        => subnet['ID'],
           :cidr                           => subnet['address'] + to_cidr(subnet['netmask']),
           :network_protocol               => subnet['IPType'].downcase!,
           :gateway                        => subnet['gateway'],
           :dhcp_enabled                   => false,
           :cloud_tenant                   => nil,
           :dns_nameservers                => nil,
           :ipv6_router_advertisement_mode => nil,
           :ipv6_address_mode              => nil,
           :allocation_pools               => nil,
           :host_routes                    => nil,
           :ip_version                     => 4,
           :subnetpool_id                  => nil,
         }
       }
      return results
    end
    p 'Error in connection '+response.code.to_s
  end

  def to_cidr (netmask)
    '/' + netmask.to_i.to_s(2).count("1").to_s
  end

  def get_vPorts
    response = @restCall.get(@server + '/vports')
    if (response.code == 200)
      if (response.body == '')
        p 'No vports present'
        return
      end
      return JSON.parse(response.body)
    end
    p 'Error in connection '+response.code.to_s
  end

  def get_vms
    response = @restCall.get(@server + '/vms')
    if (response.code == 200)
      if (response.body == '')
        p 'No VM present'
        return
      end
      return JSON.parse(response.body)
    end
    p 'Error in connection '+response.code.to_s
  end

  def install_license(license_str)
    licenseDict = {}
    licenseDict['license']= license_str
    response = @restCall.post(@server + '/licenses', JSON.dump(licenseDict))
    if (response.code != 201)
      if (response.body == 'The license already exists')
        p 'license install failed'
      end
    end
  end

  def add_csproot_to_cms_group
    response = @restCall.get(@server + "/enterprises/#@enterprise_id/groups")
    groups = JSON.parse(response.body)
    cms_group_id = nil
    csproot_user_id = nil

    for group in groups
      p 'group::'+group
      if group['name'] == 'CMS Group'
        cms_group_id = group['ID']
      end
    end

    response = @restCall.get(@server + "/enterprises/#@enterprise_id/users")
    users = JSON.parse(response.body)
    for user in users
      p 'user::'+user
      if user['userName'] == 'csproot'
        csproot_user_id = user['ID']
      end
    end

    response = @restCall.get(@server + "/enterprises/#@cms_group_id/users")
    p response.body
    userlist = ['{'+csproot_user_id+'}']
    response = @restCall.put(@server + "/groups/#@cms_group_id/users",JSON.dump(userlist))
    response = @restCall.get(@server + "/groups/#@cms_group_id/users")
    p response.body
  end

  class << self
    def security_group_type
      'ManageIQ::Providers::Openstack::NetworkManager::SecurityGroup'
    end

    def network_router_type
      "ManageIQ::Providers::Openstack::NetworkManager::NetworkRouter"
    end

    def cloud_network_type
      "ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork"
    end

    def cloud_subnet_type
      "ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet"
    end

    def floating_ip_type
      "ManageIQ::Providers::Openstack::NetworkManager::FloatingIp"
    end

    def network_port_type
      "ManageIQ::Providers::Openstack::NetworkManager::NetworkPort"
    end
  end
end


Vsd = VsdClient.new(ARGV[0],ARGV[1],ARGV[2]);
if (ARGV[3] == 'domains')
  if(ARGV[4] == 'no')
     p Vsd.get_domains
  else
     Vsd.get_domains.each do |domain|
       p domain['name']
     end
  end
end
if (ARGV[3] == 'subnets')
    p Vsd.get_subnets
end
if (ARGV[3] == 'vports')
  if(ARGV[4] == 'no')
     p Vsd.get_vPorts
  else
     Vsd.get_vPorts.each do |vport|
       p vport['name']
     end
  end
end
if (ARGV[3] == 'vms')
  if(ARGV[4] == 'no')
    p Vsd.get_vms
  else
     Vsd.get_vms.each do |vm|
      p vm['name']
    end
  end
end