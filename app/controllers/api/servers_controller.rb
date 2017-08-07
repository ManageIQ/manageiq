module Api
  class ServersController < BaseController
    include Mixins::SettingsMixin

    def fetch_servers_resource_settings(resource)
      filter_settings(resource.resource_settings)
    end
  end
end
