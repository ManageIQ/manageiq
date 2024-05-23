module Vmdb
  class Settings
    class Validator
      include Vmdb::Logging

      def initialize(config)
        @config = config.to_hash
      end

      def valid?
        validate.first
      end

      def validate
        @errors = {}
        valid = true
        @config.each_key do |k|
          next unless respond_to?(k.to_s, true)

          _log.debug("Validating #{k}")
          ost = OpenStruct.new(@config[k].stringify_keys)
          section_valid, errors = send(k.to_s, ost)
          next if section_valid

          _log.debug("  Invalid: #{errors}")
          errors.each { |key, msg| @errors["#{k}-#{key}"] = msg }
          valid = false
        end
        return valid, @errors
      end

      private

      def webservices(data)
        valid, errors = true, []

        keys = data.each_pair.to_a.transpose.first.to_set

        if keys.include?(:mode) && !%w[invoke disable].include?(data.mode)
          valid = false
          errors << [:mode, "webservices mode, \"#{data.mode}\", invalid. Should be one of: invoke or disable"]
        end

        if keys.include?(:contactwith) && !%w[ipaddress hostname].include?(data.contactwith)
          valid = false
          errors << [:contactwith, "webservices contactwith, \"#{data.contactwith}\", invalid. Should be one of: ipaddress or hostname"]
        end

        if keys.include?(:nameresolution) && ![true, false].include?(data.nameresolution)
          valid = false
          errors << [:nameresolution, "webservices nameresolution, \"#{data.nameresolution}\", invalid. Should be one of: true or false"]
        end

        if keys.include?(:timeout) && !data.timeout.kind_of?(Integer)
          valid = false
          errors << [:timeout, "timeout, \"#{data.timeout}\", invalid. Should be numeric"]
        end

        return valid, errors
      end

      def authentication(data)
        errors = Authenticator.validate_config(data)
        valid = errors.empty?
        return valid, errors
      end

      def log(data)
        valid, errors = true, []

        # validate level
        data.each_pair do |key, value|
          next unless key.to_s.start_with?("level")

          level = value.to_s.upcase.to_sym
          unless Logger::Severity.constants.include?(level)
            valid = false
            errors << [key, "#{key}, \"#{level}\", is invalid. Should be one of: #{Logger::Severity.constants.join(", ")}"]
          end
        end

        return valid, errors
      end

      def session(data)
        valid, errors = true, []

        keys = data.each_pair.to_a.transpose.first.to_set

        if keys.include?(:timeout)
          unless data.timeout.kind_of?(Integer)
            valid = false
            errors << [:timeout, "timeout, \"#{data.timeout}\", invalid. Should be numeric"]
          end

          if data.timeout == 0
            valid = false
            errors << [:timeout, "timeout can't be zero"]
          end
        end

        if keys.include?(:interval)
          unless data.interval.kind_of?(Integer)
            valid, _key, _message = [false, :interval, "interval, \"#{data.interval}\", invalid.  invalid. Should be numeric"]
          end

          if data.interval == 0
            valid = false
            errors << [:interval, "interval can't be zero"]
          end
        end

        return valid, errors
      end

      def server(data)
        valid, errors = true, []

        keys = data.each_pair.to_a.transpose.first.to_set

        if keys.include?(:listening_port)
          unless is_numeric?(data.listening_port) || data.listening_port.blank?
            valid = false
            errors << [:listening_port, "listening_port, \"#{data.listening_port}\", invalid. Should be numeric"]
          end
        end

        if keys.include?(:session_store) && !%w[sql memory cache].include?(data.session_store)
          valid = false
          errors << [:session_store, "session_store, \"#{data.session_store}\", invalid. Should be one of \"sql\", \"memory\", \"cache\""]
        end

        if keys.include?(:zone)
          unless Zone.in_my_region.find_by(:name => data.zone)
            valid = false
            errors << [:zone, "zone, \"#{data.zone}\", invalid. Should be a valid Zone"]
          end
        end

        if keys.include?(:rate_limiting)
          %i[api_login request ui_login].each do |limiting_section|
            next if data.rate_limiting[limiting_section].blank?

            limit  = data.rate_limiting[limiting_section][:limit]
            period = data.rate_limiting[limiting_section][:period]

            unless is_integer?(limit)
              valid = false
              errors << [:rate_limiting, "rate_limiting.#{limiting_section}.limit, \"#{limit}\", invalid. Should be an integer"]
            end

            unless is_integer?(period) || period.number_with_method?
              valid = false
              errors << [:rate_limiting, "rate_limiting.#{limiting_section}.period, \"#{period}\", invalid. Should be an integer"]
            end
          end
        end

        return valid, errors
      end

      def smtp(data)
        valid, errors = true, []

        keys = data.each_pair.to_a.transpose.first.to_set

        if keys.include?(:authentication) && !%w[login plain none].include?(data.authentication)
          valid = false
          errors << [:mode, "authentication, \"#{data.mode}\", invalid. Should be one of: login, plain, or none"]
        end

        if data.authentication == "login" && data.user_name.blank?
          valid = false
          errors << [:user_name, "cannot be blank for 'login' authentication"]
        end

        if keys.include?(:port) && data.port.to_s !~ /^[0-9]*$/
          valid = false
          errors << [:port, "\"#{data.port}\", invalid. Should be numeric"]
        end

        if keys.include?(:from) && data.from !~ /^\A([\w.\-+]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z$/i
          valid = false
          errors << [:from, "\"#{data.from}\", invalid. Should be a valid email address"]
        end

        return valid, errors
      end

      def workers(data)
        valid, errors = true, []
        # worker_settings expects a hash-like structure with nested keys: :config and :workers
        data = {:config => {:workers => data}}
        MiqWorker.descendants.each do |worker_class|
          result, new_errors = validate_worker_request_limit(worker_class, data)
          if result == false
            valid = false
            errors += new_errors
          end

          result, new_errors = validate_worker_count(worker_class, data)
          if result == false
            valid = false
            errors += new_errors
          end
        end

        return valid, errors
      end

      def validate_worker_request_limit(worker_class, data)
        valid = true
        errors = []
        worker_settings = worker_class.fetch_worker_settings_from_options_hash(data[:config])

        # Only validate request/limits if you specify any of them.  Specifying at least one of these four, requires
        # all of them to be enumerated. This gets around tests that want to stub some of the worker_settings.
        worker_settings_keys_with_dependencies = %i[cpu_request_percent cpu_threshold_percent memory_request memory_threshold]
        return valid, errors if (worker_settings.keys & worker_settings_keys_with_dependencies).empty?

        worker_settings_keys_with_dependencies.each do |key|
          if !worker_settings.key?(key)
            errors << [key, "#{worker_class.settings_name} #{key} is missing!"]
            return false, errors
          elsif !worker_settings[key].kind_of?(Numeric)
            errors << [key, "#{worker_class.settings_name} #{key} has non-numeric value: #{worker_settings[key].inspect}"]
            return false, errors
          end
        end

        cpu_request     = worker_settings[:cpu_request_percent]
        cpu_limit       = worker_settings[:cpu_threshold_percent]
        memory_request  = worker_settings[:memory_request]
        memory_limit    = worker_settings[:memory_threshold]

        if cpu_request > cpu_limit
          valid = false
          errors << [:cpu_request_percent, "#{worker_class.settings_name}: cpu_request_percent: #{cpu_request} cannot exceed cpu_threshold_percent: #{cpu_limit}"]
        end

        if memory_request > memory_limit
          valid = false
          errors << [:memory_request, "#{worker_class.settings_name}: memory_request: #{memory_request} cannot exceed memory_threshold: #{memory_limit}"]
        end
        return valid, errors
      end

      def validate_worker_count(worker_class, data)
        valid  = true
        errors = []

        worker_settings = worker_class.fetch_worker_settings_from_options_hash(data[:config])

        count                 = worker_settings[:count]
        maximum_workers_count = worker_class.maximum_workers_count

        if maximum_workers_count.kind_of?(Integer) && count > maximum_workers_count
          valid = false
          errors << [:count, "#{worker_class.settings_name}: count: #{count} exceeds maximum worker count: #{maximum_workers_count}"]
        end
        return valid, errors
      end
    end
  end
end
