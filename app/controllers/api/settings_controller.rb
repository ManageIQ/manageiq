module Api
  class SettingsController < BaseController
    def index
      render_resource :settings, whitelist_settings(settings_hash)
    end

    def show
      settings_value = entry_value(whitelist_settings(settings_hash), @req.c_suffix)

      raise NotFoundError, "Settings entry #{@req.c_suffix} not found" if settings_value.nil?
      render_resource :settings, settings_entry_to_hash(@req.c_suffix, settings_value)
    end

    private

    def whitelist_settings(settings)
      result_hash = {}
      ApiConfig.collections[:settings][:categories].each do |category_path|
        result_hash.deep_merge!(settings_entry_to_hash(category_path, entry_value(settings, category_path)))
      end
      result_hash
    end

    def settings_hash
      @settings_hash ||= Settings.to_hash.deep_stringify_keys
    end

    def entry_value(settings, path)
      settings.fetch_path(path.split('/'))
    end

    def settings_entry_to_hash(path, value)
      path_elements = path.split("/")
      result_hash = {path_elements.last => value}
      path_elements[0..-2].reverse.each { |entry| result_hash = { entry => result_hash } } if path_elements.length > 1
      result_hash
    end
  end
end
