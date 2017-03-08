module Api
  class RegionsController < BaseController
    include Mixins::ResourceSettings

    def fetch_regions_resource_settings(resource)
      filter_resource_settings(resource.resource_settings)
    end
  end
end
