module OpenstackHandle
  class IdentityDelegate < DelegateClass(Fog::Identity::OpenStack)
    include OpenstackHandle::HandledList
    include Vmdb::Logging

    SERVICE_NAME = "Identity"

    attr_reader :name

    def initialize(dobj, os_handle, name)
      super(dobj)
      @os_handle = os_handle
      @name      = name
    end

    def visible_tenants
      if respond_to?(:projects)
        # Check if keystone v3 method projects is available, if not fall back to v2
        visible_tenants_v3
      else
        visible_tenants_v2
      end
    end

    def visible_tenants_v3
      handled_list(:projects)
    end

    #
    # Services returned by Fog keystone v2 are always scoped.
    # For non-admin users, we must use an unscoped token to
    # retrieve a list of tenants the user can access.
    #
    def visible_tenants_v2
      response = Handle.try_connection do |scheme, connection_options|
        url = Handle.url(@os_handle.address, @os_handle.port, scheme, "/v2.0/tenants")
        connection = Fog::Core::Connection.new(url, false, connection_options)
        response = connection.request(
          :expects => [200, 204],
          :headers => {'Content-Type' => 'application/json',
                       'Accept'       => 'application/json',
                       'X-Auth-Token' => unscoped_token},
          :method  => 'GET'
        )
      end
      body = Fog::JSON.decode(response.body)
      vtenants = Fog::Identity::OpenStack::V2::Tenants.new
      vtenants.load(body['tenants'])
      vtenants
    end

    def multi_tenancy_class
      # For keystone, we are not scoping to project, Seems like keystone v2 tenants is ignoring pagination
      OpenstackHandle::MultiTenancy::None
    end

    def pagination_class
      # Keystone v3 is using page number pagination
      OpenstackHandle::Pagination::PageNumber
    end
  end
end
