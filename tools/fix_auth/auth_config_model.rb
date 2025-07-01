module FixAuth
  module AuthConfigModel
    extend ActiveSupport::Concern
    include FixAuth::AuthModel

    module ClassMethods
      attr_accessor :password_fields
      attr_accessor :password_prefix
      # true if we want to output the keys as symbols (default: false - output as string keys)
      attr_accessor :symbol_keys

      DEFAULT_PERMITTED_CLASSES = [
        ActiveSupport::Duration,
        ActiveSupport::HashWithIndifferentAccess,
        ActiveSupport::TimeWithZone,
        ActiveSupport::TimeZone,
        Date,
        DateTime,
        Object,
        Range,
        Regexp,
        Symbol,
        Time
      ].freeze

      def display_record(r)
        puts "  #{r.id}:"
      end

      def display_column(r, column, options)
        puts "    #{column}:"

        hash = r.send(column).kind_of?(Hash) ? r.send(column) : YAML.safe_load(r.send(column), :aliases => true, :permitted_classes => DEFAULT_PERMITTED_CLASSES)
        traverse_column([], hash, options)
      end

      def password_field?(key)
        key.to_s.in?(password_fields) || (password_prefix && key.to_s.include?(password_prefix))
      end

      def traverse_column(names, hash, options)
        hash.each_pair do |n, v|
          if password_field?(n)
            puts "      #{names.join(".")}.#{n}: #{highlight_password(v, options)}"
          elsif v.kind_of?(Hash)
            traverse_column(names + [n], v, options)
          end
        end
      end

      def recrypt(old_value, options = {})
        hash = old_value.kind_of?(Hash) ? old_value : YAML.safe_load(old_value, :aliases => true, :permitted_classes => DEFAULT_PERMITTED_CLASSES)

        Vmdb::SettingsWalker.walk(hash) do |key, value, _path, owning|
          owning[key] = super(value, options) if password_field?(key) && value.present?
        end

        symbol_keys ? hash.deep_symbolize_keys! : hash.deep_stringify_keys!
        old_value.kind_of?(Hash) ? hash : hash.to_yaml
      rescue ArgumentError # undefined class/module
        unless options[:allow_failures]
          STDERR.puts "potentially bad yaml:"
          STDERR.puts old_value
        end
        raise
      end
    end
  end
end
