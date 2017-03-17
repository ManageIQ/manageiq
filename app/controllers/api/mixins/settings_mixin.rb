module Api
  module Mixins
    module SettingsMixin
      def filter_settings(settings)
        if User.current_user.super_admin_user?
          settings
        else
          whitelist_settings(settings.deep_stringify_keys)
        end
      end

      def entry_value(settings, path)
        settings.fetch_path(path.split('/'))
      end

      def settings_entry_to_hash(path, value)
        {}.tap { |h| h.store_path(path.split("/"), value) }
      end

      private

      def whitelist_settings(settings)
        result_hash = {}
        ApiConfig.collections[:settings][:categories].each do |category_path|
          result_hash.deep_merge!(settings_entry_to_hash(category_path, entry_value(settings, category_path)))
        end
        result_hash
      end
    end
  end
end
