module Api
  class ZonesController < BaseController
    include Mixins::ResourceSettings

    def fetch_zones_resource_settings(resource)
      filter_resource_settings(resource.resource_settings)
    end
  end
end
