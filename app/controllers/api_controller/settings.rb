class ApiController
  module Settings
    def show_settings
      validate_api_action
      selected_sections = if @req[:c_id]
                            exposed_settings.include?(@req[:c_id]) ? @req[:c_id] : nil
                          else
                            exposed_settings
                          end

      result = Array(selected_sections).each_with_object({}) do |section, hash|
        hash[section] = ::Settings[section].to_hash
      end
      render_resource :settings, result
    end

    private

    def exposed_settings
      @exposed_settings ||= YAML.load_file(Rails.root.join("config/api_settings.yml"))[:settings]
    end
  end
end
