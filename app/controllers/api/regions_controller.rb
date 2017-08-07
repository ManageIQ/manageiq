module Api
  class RegionsController < BaseController
    include Mixins::SettingsMixin

    def fetch_regions_resource_settings(resource)
      filter_settings(resource.resource_settings)
    end
  end
end
