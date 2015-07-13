module FixAuth
  module AuthConfigModel
    extend ActiveSupport::Concern
    include FixAuth::AuthModel

    module ClassMethods
      attr_accessor :password_fields
      attr_accessor :password_prefix
      # true if we want to output the keys as symbols (default: false - output as string keys)
      attr_accessor :symbol_keys

      def display_record(r)
        puts "  #{r.id}:"
      end

      def display_column(r, column, options)
        puts "    #{column}:"
        traverse_column([], YAML.load(r.send(column)), options)
      end

      def password_field?(key)
        key.to_s.in?(password_fields) || (password_prefix && key.to_s.include?(password_prefix))
      end

      def traverse_column(names, hash, options)
        hash.each_pair do |n, v|
          if password_field?(n)
            puts "      #{names.join(".")}.#{n}: #{highlight_password(v, options)}"
          elsif v.is_a?(Hash)
            traverse_column(names + [n], v, options)
          end
        end
      end

      def recrypt(old_value, options = {})
        hash = Vmdb::ConfigurationEncoder.load(old_value, !symbol_keys) do |k, v, h|
          h[k] = super(v, options) if password_field?(k) && v.present?
        end
        Vmdb::ConfigurationEncoder.dump(hash, nil, !symbol_keys) { |_k, _v, _h| }
      end
    end
  end
end
