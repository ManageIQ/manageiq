module Api
  module Mixins
    module ResourceSettings
      def filter_resource_settings(resource_settings)
        if User.current_user.super_admin_user?
          resource_settings
        else
          slice_settings(resource_settings, exposed_settings)
        end
      end

      private

      def exposed_settings
        ApiConfig.collections[:settings][:categories]
      end

      def slice_settings(settings_hash, keys)
        settings_hash.slice(*Array(keys).collect(&:to_sym))
      end
    end
  end
end
