module Vmdb
  class ConfigurationEncoder
    PASSWORD_FIELDS = %w(bind_pwd password amazon_secret)

    def self.validate!(hash)
      load(dump(hash))
    end

    def self.stringify!(h)
      h.each_key { |k| h[k].stringify_keys! }.stringify_keys!
    end

    def self.symbolize!(h)
      h.each_key { |k| h[k].symbolize_keys! }.symbolize_keys!
    end

    def self.load(data, symbolize_keys = true, &block)
      return {} if data.blank?

      if defined?(Rails) && !Rails.env.production?
        require 'erb'
        data = ERB.new(data).result
      end

      hash = YAML.load(data)
      # shouldn't be necessary: fixes issue when data was double encoded
      hash = YAML.load(hash) if hash.kind_of?(String)

      symbolize!(stringify!(hash)) if symbolize_keys

      if block_given?
        walk_nested_hashes(hash, &block)
      else
        decrypt_password_fields!(hash)
      end
    end

    def self.dump(hash, fd = nil, stringify_keys = true, &block)
      hash = hash.deep_clone

      if block_given?
        walk_nested_hashes(hash, &block)
      else
        encrypt_password_fields!(hash)
      end
      stringify!(hash) if stringify_keys
      YAML.dump(hash, fd)
    end

    def self.walk_nested_hashes(hash, &block)
      hash.each do |k, v|
        yield k, v, hash
        walk_nested_hashes(v, &block) if v.kind_of?(Hash)
      end
      hash
    end

    def self.encrypt_password_fields!(hash)
      walk_nested_hashes(hash) do |k, v, h|
        h[k] = MiqPassword.try_encrypt(v) if PASSWORD_FIELDS.include?(k.to_s) && v.present?
      end
    end

    def self.encrypt_password_fields(hash)
      encrypt_password_fields!(hash.deep_clone)
    end

    def self.decrypt_password_fields!(hash)
      walk_nested_hashes(hash) do |k, v, h|
        h[k] = MiqPassword.try_decrypt(v) if PASSWORD_FIELDS.include?(k.to_s) && v.present?
      end
    end

    def self.decrypt_password_fields(hash)
      decrypt_password_fields!(hash.deep_clone)
    end
  end
end
