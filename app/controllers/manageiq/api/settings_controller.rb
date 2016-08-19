module ManageIQ
  module API
    class SettingsController < BaseController
      def show
        validate_api_action
        category = @req.c_id
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
        ManageIQ::API::Settings.collections[:settings][:categories]
      end
    end
  end
end
