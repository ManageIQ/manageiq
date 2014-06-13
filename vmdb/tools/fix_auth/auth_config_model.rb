module FixAuth
  module AuthConfigModel
    extend ActiveSupport::Concern

    include FixAuth::AuthModel

    module ClassMethods
      attr_accessor :password_fields

      def display_column(r, column)
        puts "    #{column}:"
        traverse_column([], YAML.load(r.send(column)))
      end

      def traverse_column(names, hash)
        hash.each_pair do |n, v|
          if n.to_s.in?(password_fields)
            puts "      #{names.join(".")}.#{n}: #{v}"
          elsif v.is_a?(Hash)
            traverse_column(names + [n], v)
          end
        end
      end

      def hardcode(old_value, new_value)
        hash = Vmdb::ConfigurationEncoder.load(old_value) do |k, v, h|
          h[k] = new_value if k.to_s.in?(password_fields) && v.present?
        end
        Vmdb::ConfigurationEncoder.dump(hash)
      end

      def recrypt(old_value, options = {})
        hash = Vmdb::ConfigurationEncoder.load(old_value)
        Vmdb::ConfigurationEncoder.dump(hash)
      rescue
        if options[:invalid]
          hardcode(old_value, options[:invalid])
        else
          raise
        end
      end
    end
  end
end
