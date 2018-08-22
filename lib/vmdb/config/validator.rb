module VMDB
  class Config
    class Validator
      include Vmdb::Logging

      def initialize(config)
        @config =
          if config.kind_of?(::Config::Options)
            config.to_hash
          elsif config.respond_to?(:config)
            config.config
          else
            config
          end
      end

      def valid?
        validate.first
      end

      def validate
        @errors = {}
        valid = true
        @config.each_key do |k|
          if respond_to?(k.to_s, true)
            _log.debug("Validating #{k}")
            ost = OpenStruct.new(@config[k].stringify_keys)
            section_valid, errors = send(k.to_s, ost)

            unless section_valid
              _log.debug("  Invalid: #{errors}")
              errors.each do |e|
                key, msg = e
                @errors[[k, key].join("-")] = msg
              end
              valid = false
            end
          end
        end
        return valid, @errors
      end

      private

      def webservices(data)
        valid, errors = true, []

        keys = data.each_pair.to_a.transpose.first.to_set

        if keys.include?(:mode) && !["invoke", "disable"].include?(data.mode)
          valid = false
          errors << [:mode, "webservices mode, \"#{data.mode}\", invalid. Should be one of: invoke or disable"]
        end

        if keys.include?(:contactwith) && !["ipaddress", "hostname"].include?(data.contactwith)
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
          unless VMDBLogger::Severity.constants.include?(level)
            valid = false
            errors << [key, "#{key}, \"#{level}\", is invalid. Should be one of: #{VMDBLogger::Severity.constants.join(", ")}"]
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

        if keys.include?(:session_store) && !["sql", "memory", "cache"].include?(data.session_store)
          valid = false
          errors << [:session_store, "session_store, \"#{data.session_store}\", invalid. Should be one of \"sql\", \"memory\", \"cache\""]
        end

        if keys.include?(:zone)
          unless Zone.in_my_region.find_by(:name => data.zone)
            valid = false
            errors << [:zone, "zone, \"#{data.zone}\", invalid. Should be a vaild Zone"]
          end
        end

        return valid, errors
      end

      def smtp(data)
        valid, errors = true, []

        keys = data.each_pair.to_a.transpose.first.to_set

        if keys.include?(:authentication) && !["login", "plain", "none"].include?(data.authentication)
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

        if keys.include?(:from) && data.from !~ /^\A([\w\.\-\+]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z$/i
          valid = false
          errors << [:from, "\"#{data.from}\", invalid. Should be a valid email address"]
        end

        return valid, errors
      end
    end
  end
end
