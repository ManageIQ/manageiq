module Vmdb
  class ConfigurationEncoder
    PASSWORD_FIELDS = %w{bind_pwd password amazon_secret}

    def self.validate!(hash)
      load(dump(hash))
    end

    def self.stringify!(h)
      h.each_key { |k| h[k].stringify_keys! }.stringify_keys!
    end

    # TODO: Stringify, why does MiqDbConfig have to call stringify directly?
    def self.stringify(h)
      stringify!(h.deep_clone)
    end

    def self.symbolize!(h)
      h.each_key { |k| h[k].symbolize_keys! }.symbolize_keys!
    end

    class YamlLoader < Psych::Visitors::ToRuby
      NUMBER_WITH_METHOD_REGEX = /^([0-9\.,]+)\.([a-z]+)$/

      def visit_Psych_Nodes_Scalar(node)
        if node.value =~ NUMBER_WITH_METHOD_REGEX
          if $2 == 'percent'
            super
          else
            n = $1.include?('.') ? $1.to_f : $1.to_i
            n.send($2)
          end
        else
          super
        end
      end
    end

    def self.load(data, symbolize_keys = true, &block)
      return {} if data.blank?

      if defined?(Rails) && !Rails.env.production?
        require 'erb'
        data = ERB.new(data).result
      end

      require 'psych'
      tree = Psych.parse(data)
      hash = YamlLoader.create.accept(tree)
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
      hash.keys.each do |k|
        v = hash[k]
        yield k, v, hash
        walk_nested_hashes(v, &block) if v.kind_of?(Hash)
      end
      hash
    end

    def self.encrypt_password_fields!(hash)
      walk_nested_hashes(hash) do |k, v, h|
        h[k] = MiqPassword.try_encrypt(v) if k.to_s.in?(PASSWORD_FIELDS) && v.present?
      end
    end

    def self.encrypt_password_fields(hash)
      encrypt_password_fields!(hash.deep_clone)
    end

    def self.decrypt_password_fields!(hash)
      walk_nested_hashes(hash) do |k, v, h|
        h[k] = MiqPassword.try_decrypt(v) if k.to_s.in?(PASSWORD_FIELDS) && v.present?
      end
    end

    def self.decrypt_password_fields(hash)
      decrypt_password_fields!(hash.deep_clone)
    end
  end
end
