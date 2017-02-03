module Api
  class SettingsController < BaseController
    def index
      render_resource :settings, ::Settings.to_hash.slice(*Array(exposed_settings).collect(&:to_sym))
    end

    def show
      raise NotFoundError, "Settings category #{@req.c_id} not found" unless exposed_settings.include?(@req.c_id)
      render_resource :settings, ::Settings.to_hash.slice(*Array(@req.c_id).collect(&:to_sym))
    end

    private

    def exposed_settings
      ApiConfig.collections[:settings][:categories]
    end
  end
end
