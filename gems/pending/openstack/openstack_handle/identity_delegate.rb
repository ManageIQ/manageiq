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
      # Huge inconsistency in Keystone v3, we actually need to provide domain_id both in token and query param, but only
      # for keystone. This rule is defined in policy.json
      projects.all(:domain_id => @os_handle.domain_id)
    end

    #
    # Services returned by Fog keystone v2 are always scoped.
    # For non-admin users, we must use an unscoped token to
    # retrieve a list of tenants the user can access.
    #
    def visible_tenants_v2
      response = Handle.try_connection(@os_handle.security_protocol) do |scheme, connection_options|
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
  end
end
