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
        @config.each_key do|k|
          if respond_to?(k.to_s, true)
            _log.debug("Validating #{k}")
            ost = OpenStruct.new(@config[k].stringify_keys)
            section_valid, errors = send(k.to_s, ost)

            unless section_valid
              _log.debug("  Invalid: #{errors}")
              errors.each do|e|
                key, msg = e
                @errors[[k, key].join("_")] = msg
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

        unless ["invoke", "disable"].include?(data.mode)
          valid = false; errors << [:mode, "webservices mode, \"#{data.mode}\", invalid. Should be one of: invoke or disable"]
        end

        unless ["ipaddress", "hostname"].include?(data.contactwith)
          valid = false; errors << [:contactwith, "webservices contactwith, \"#{data.contactwith}\", invalid. Should be one of: ipaddress or hostname"]
        end

        unless [true, false].include?(data.nameresolution)
          valid = false; errors << [:nameresolution, "webservices nameresolution, \"#{data.nameresolution}\", invalid. Should be one of: true or false"]
        end

        unless data.timeout.kind_of?(Fixnum)
          valid = false; errors << [:timeout, "timeout, \"#{data.timeout}\", invalid. Should be numeric"]
        end

        return valid, errors
      end

      AUTH_TYPES = %w(ldap ldaps httpd amazon database none)

      def authentication(data)
        valid, errors = true, []

        unless AUTH_TYPES.include?(data.mode)
          valid = false
          errors << [:mode, "authentication type, \"#{data.mode}\", invalid. Should be one of: #{AUTH_TYPES.join(", ")}"]
        end

        if data.mode == "ldap"
          if data.ldaphost.blank?
            valid = false; errors << [:ldaphost, "ldaphost can't be blank"]
          end
        elsif data.mode == "amazon"
          if data.amazon_key.blank?
            valid = false; errors << [:amazon_key, "amazon key can't be blank"]
          end

          if data.amazon_secret.blank?
            valid = false; errors << [:amazon_secret, "amazon secret can't be blank"]
          end
        end

        return valid, errors
      end

      def log(data)
        valid, errors = true, []

        # validate level
        data.each_pair do |key, value|
          next unless key.to_s.start_with?("level")

          level = value.to_s.upcase.to_sym
          unless VMDBLogger::Severity.constants.include?(level)
            valid = false; errors << [key, "#{key}, \"#{level}\", is invalid. Should be one of: #{VMDBLogger::Severity.constants.join(", ")}"]
          end
        end

        return valid, errors
      end

      def session(data)
        valid, errors = true, []

        unless data.timeout.kind_of?(Fixnum)
          valid = false; errors << [:timeout, "timeout, \"#{data.timeout}\", invalid. Should be numeric"]
        end

        unless data.interval.kind_of?(Fixnum)
          valid, key, message = [false, :interval, "interval, \"#{data.interval}\", invalid.  invalid. Should be numeric"]
        end

        if data.timeout == 0
          valid = false; errors << [:timeout, "timeout can't be zero"]
        end

        if data.interval == 0
          valid = false; errors << [:interval, "interval can't be zero"]
        end

        return valid, errors
      end

      def server(data)
        valid, errors = true, []

        unless is_numeric?(data.listening_port) || data.listening_port.blank?
          valid = false; errors << [:listening_port, "listening_port, \"#{data.listening_port}\", invalid. Should be numeric"]
        end

        unless ["sql", "memory", "cache"].include?(data.session_store)
          valid = false; errors << [:session_store, "session_store, \"#{data.session_store}\", invalid. Should be one of \"sql\", \"memory\", \"cache\""]
        end

        return valid, errors
      end

      def smtp(data)
        valid, errors = true, []

        unless ["login", "plain", "none"].include?(data.authentication)
          valid = false; errors << [:mode, "authentication, \"#{data.mode}\", invalid. Should be one of: login, plain, or none"]
        end

        if data.user_name.blank? && data.authentication == "login"
          valid = false; errors << [:user_name, "cannot be blank for 'login' authentication"]
        end

        unless data.port.to_s =~ /^[0-9]*$/
          valid = false; errors << [:port, "\"#{data.port}\", invalid. Should be numeric"]
        end

        unless data.from =~ /^\A([\w\.\-\+]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z$/i
          valid = false; errors << [:from, "\"#{data.from}\", invalid. Should be a valid email address"]
        end

        return valid, errors
      end
    end
  end
end
