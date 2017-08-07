module Api
  class SettingsController < BaseController
    include Mixins::SettingsMixin

    def index
      render_resource :settings, filter_settings(settings_hash)
    end

    def show
      settings_value = entry_value(filter_settings(settings_hash), @req.c_suffix)

      raise NotFoundError, "Settings entry #{@req.c_suffix} not found" if settings_value.nil?
      render_resource :settings, settings_entry_to_hash(@req.c_suffix, settings_value)
    end

    private

    def settings_hash
      @settings_hash ||= Settings.to_hash.deep_stringify_keys
    end
  end
end
