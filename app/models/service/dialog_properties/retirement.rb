class Service
  class DialogProperties
    class Retirement
      RETIREMENT_WARN_FIELD_NAMES = %w(warn_on warn_in_days warn_in_hours warn_offset_days warn_offset_hours).freeze

      def initialize(options, user)
        @attributes = {}
        @options = options || {}
        @user = user
      end

      def self.parse(options, user)
        new(options, user).parse
      end

      def parse
        @attributes.tap { parse_options }
      end

      private

      def parse_options
        if @options['dialog_service_retires_on'].present?
          field_name = 'dialog_service_retires_on'
          self.retire_on_date = time_parse(@options[field_name])
        elsif @options['dialog_service_retires_in_hours'].present?
          field_name = 'dialog_service_retires_in_hours'
          retires_in_duration(@options[field_name], :hours)
        elsif @options['dialog_service_retires_in_days'].present?
          field_name = 'dialog_service_retires_in_days'
          retires_in_duration(@options[field_name], :days)
        end
      rescue StandardError
        $log.error("Error parsing dialog retirement property [#{field_name}] with value [#{@options[field_name].inspect}]. Error: #{$!}")
      end

      def retires_in_duration(value, modifier)
        self.retire_on_date = time_now + offset_set(value, modifier)
      end

      def offset_set(value, modifier)
        value.to_i.send(modifier).tap do |offset|
          raise "Offset cannot be a zero or negative value" if offset.zero? || offset.negative?
        end
      end

      def retire_on_date=(value)
        @attributes[:retires_on] = value
        retirement_warning
      end

      def retirement_warning
        warn_value = parse_retirement_warn
        @attributes[:retirement_warn] = warn_value if warn_value
      end

      def parse_retirement_warn
        warn_key, value = retirement_warn_properties

        case warn_key
        when 'warn_on'
          time_parse(value)
        when 'warn_in_days'
          time_now + offset_set(value, :days)
        when 'warn_in_hours'
          time_now + offset_set(value, :hours)
        when 'warn_offset_days'
          @attributes[:retires_on] - offset_set(value, :days)
        when 'warn_offset_hours'
          @attributes[:retires_on] - offset_set(value, :hours)
        end
      end

      def retirement_warn_properties
        warn_name = RETIREMENT_WARN_FIELD_NAMES.detect do |field_name|
          @options["dialog_service_retirement_#{field_name}"].present?
        end

        return warn_name, @options["dialog_service_retirement_#{warn_name}"] if warn_name
      end

      def time_parse(value)
        with_user_timezone do
          Time.zone.parse(value).utc.tap do |time|
            raise "Retirement date cannot be set in the past" if time < time_now
          end
        end
      end

      def time_now
        with_user_timezone { Time.zone.now.utc }
      end

      def with_user_timezone
        user = @user || User.current_user

        user ? user.with_my_timezone { yield } : yield
      end
    end
  end
end
