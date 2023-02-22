module Vmdb
  module SettingsWalker
    PASSWORD_FIELDS = %w[
      password
      _pwd
      _protected
      _secret
      _token
      auth_key
      ssh_key_data
      ssh_key_unlock
      verify
    ].freeze

    PASSWORD_MASK = "********".freeze

    module ClassMethods
      # Walks the settings and yields each value along the way
      #
      # @param settings [Config::Options, Hash] The settings to walk.
      # @param path [Array] Not to be passed by the caller as it's used
      #   for the recursion to keep track of the depth.
      # @yieldparam key [String] The current key.
      # @yieldparam value [String] The current value.
      # @yieldparam key_path [Array<String>] The key path from the top of the
      #   settings to the current key.  Includes the current key.  If walking an
      #   Array, this will include the index in the Array.
      # @yieldparam owner [Config::Options, Hash] The settings object
      #   that owns the current key
      def walk(settings, path = [], &block)
        settings.each do |key, value|
          key_path = path.dup << key

          yield key, value, key_path, settings
          next if key == settings || value == settings

          case value
          when settings.class
            walk(value, key_path, &block)
          when Array
            value.each_with_index do |v, i|
              walk(v, key_path.dup << i, &block) if v.kind_of?(settings.class) && v != settings
            end
          end
        end
        settings
      end

      # Walks the settings and yields only each password value along the way
      #
      # @param settings (see .walk)
      def walk_passwords(settings)
        walk(settings) do |key, value, _path, owner|
          yield(key, value, owner) if PASSWORD_FIELDS.any? { |p| key.to_s.include?(p.to_s) } && !(value.is_a?(settings.class) || value.is_a?(Array))
        end
      end

      # Walks the settings and masks out passwords it finds
      #
      # @param settings (see .walk)
      def mask_passwords!(settings, mask = PASSWORD_MASK)
        walk_passwords(settings) { |k, v, h| h[k] = mask if v.present? }
      end

      # Filter out any password attributes from the settings
      #
      # @param settings (see .walk)
      def filter_passwords!(settings)
        walk_passwords(settings) { |k, _v, h| h.respond_to?(:delete_field) ? h.delete_field(k) : h.delete(k) }
      end

      # Walks the settings and decrypts passwords it finds
      #
      # @param settings (see .walk)
      def decrypt_passwords!(settings)
        walk_passwords(settings) { |k, v, h| h[k] = ManageIQ::Password.try_decrypt(v) if v.present? }
      end

      # Walks the settings and encrypts passwords it finds
      #
      # @param settings (see .walk)
      def encrypt_passwords!(settings)
        walk_passwords(settings) { |k, v, h| h[k] = ManageIQ::Password.try_encrypt(v) if v.present? }
      end
    end

    extend ClassMethods
  end
end
