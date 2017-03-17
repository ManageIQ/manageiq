module Api
  class ZonesController < BaseController
    include Mixins::SettingsMixin

    def fetch_zones_resource_settings(resource)
      filter_settings(resource.resource_settings)
    end
  end
end
