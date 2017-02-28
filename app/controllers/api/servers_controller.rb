module Api
  class ServersController < BaseController
    include Mixins::ResourceSettings

    def fetch_servers_resource_settings(resource)
      filter_resource_settings(resource.resource_settings)
    end
  end
end
