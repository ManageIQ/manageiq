module OpenstackHandle
  class IdentityDelegate < DelegateClass(Fog::Identity::OpenStack)
    SERVICE_NAME = "Identity"

    def initialize(dobj, os_handle)
      super(dobj)
      @os_handle = os_handle
    end

    #
    # Services returned by Fog are always scoped.
    # For non-admin users, we must use an unscoped token to
    # retrieve a list of tenants the user can access.
    #
    def visible_tenants
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
      vtenants = Fog::Identity::OpenStack::Tenants.new
      vtenants.load(body['tenants'])
      vtenants
    end
  end
end
