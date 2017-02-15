module Api
  class SettingsController < BaseController
    def index
      render_resource :settings, slice_settings(exposed_settings)
    end

    def show
      raise NotFoundError, "Settings category #{@req.c_id} not found" unless exposed_settings.include?(@req.c_id)
      render_resource :settings, slice_settings(@req.c_id)
    end

    private

    def exposed_settings
      ApiConfig.collections[:settings][:categories]
    end

    def slice_settings(keys)
      ::Settings.to_hash.slice(*Array(keys).collect(&:to_sym))
    end
  end
end
