module Vmdb
  class Settings
    module Walker
      PASSWORD_FIELDS = %i(bind_pwd password amazon_secret ssh_key_data ssh_key_unlock become_password vault_password security_token).to_set.freeze

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
      def self.walk(settings, path = [], &block)
        settings.each do |key, value|
          key_path = path.dup << key

          yield key, value, key_path, settings

          case value
          when settings.class
            walk(value, key_path, &block)
          when Array
            value.each_with_index do |v, i|
              walk(v, key_path.dup << i, &block) if v.kind_of?(settings.class)
            end
          end
        end
        settings
      end

      # Walks the settings and yields only each password value along the way
      #
      # @param settings (see .walk)
      def self.walk_passwords(settings)
        walk(settings) do |key, value, _path, owner|
          yield(key, value, owner) if value.present? && PASSWORD_FIELDS.include?(key.to_sym)
        end
      end

      # Walks the settings and masks out passwords it finds
      #
      # @param settings (see .walk)
      def self.mask_passwords!(settings)
        walk_passwords(settings) { |k, _v, h| h[k] = "********" }
      end

      # Walks the settings and decrypts passwords it finds
      #
      # @param settings (see .walk)
      def self.decrypt_passwords!(settings)
        walk_passwords(settings) { |k, v, h| h[k] = MiqPassword.try_decrypt(v) }
      end

      # Walks the settings and encrypts passwords it finds
      #
      # @param settings (see .walk)
      def self.encrypt_passwords!(settings)
        walk_passwords(settings) { |k, v, h| h[k] = MiqPassword.try_encrypt(v) }
      end
    end
  end
end
