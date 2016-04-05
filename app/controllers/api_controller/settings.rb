class ApiController
  module Settings
    def show_settings
      validate_api_action
      category = @req[:c_id]
      selected_sections =
        if category
          raise NotFound, "Settings category #{category} not found" unless exposed_settings.include?(category)
          category
        else
          exposed_settings
        end

      render_resource :settings, ::Settings.to_hash.slice(*Array(selected_sections).collect(&:to_sym))
    end

    private

    def exposed_settings
      @exposed_settings ||= YAML.load_file(Rails.root.join("config/api_settings.yml"))[:settings]
    end
  end
end
