module VMDB
  class Config
    class Validator
      def initialize(config)
        @config = config.respond_to?(:config) ? config.config : config
      end

      def valid?
        validate.first
      end

      def validate
        @errors = {}
        valid = true
        @config.each_key {|k|
          if respond_to?(k.to_s, true)
            ost = OpenStruct.new(@config[k].stringify_keys)
            section_valid, errors = send(k.to_s, ost)

            if !section_valid
              errors.each {|e|
                key, msg = e
                @errors[[k, key].join("_")] = msg
              }
              valid = false
            end
          end
        }
        return valid, @errors
      end

      private

      def webservices(data)
        valid, errors = true, []

        if !["invoke", "disable"].include?(data.mode)
          valid = false; errors << [:mode, "webservices mode, \"#{data.mode}\", invalid. Should be one of: invoke or disable"]
        end

        if !["ipaddress", "hostname"].include?(data.contactwith)
          valid = false; errors << [:contactwith, "webservices contactwith, \"#{data.contactwith}\", invalid. Should be one of: ipaddress or hostname"]
        end

        if ![true, false].include?(data.nameresolution)
          valid = false; errors << [:nameresolution, "webservices nameresolution, \"#{data.nameresolution}\", invalid. Should be one of: true or false"]
        end

        unless data.timeout.is_a?(Fixnum)
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
          else
            # # XXXX Test connection to ldap host
            # # ldap=Net::LDAP.new( {:host => data.ldaphost, :port => 389} )
            # begin
            #   # ldap.bind
            #   sock = TCPSocket.new(data.ldaphost, 389)
            #   sock.close
            # rescue => err
            #   valid = false; errors << [:ldaphost, "unable to establish an ldap connection to host \"#{data.ldaphost}\", \"#{err}\""]
            # end
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
        data = data.instance_variable_get(:@table) if data.kind_of?(OpenStruct)
        Vmdb::Logging.validate_config(data)
      end

      def session(data)
        valid, errors = true, []

        unless data.timeout.is_a?(Fixnum)
          valid = false; errors << [:timeout, "timeout, \"#{data.timeout}\", invalid. Should be numeric"]
        end

        unless data.interval.is_a?(Fixnum)
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

        unless ["any", "external"].include?(data.log_network_address)
          valid = false; errors << [:log_network_address, "log_network_address, \"#{data.log_network_address}\", invalid. Should be one of \"any\", \"external\""]
        end

        return valid, errors
      end

      def smtp(data)
        valid, errors = true, []

        if !["login", "plain", "none"].include?(data.authentication)
          valid = false; errors << [:mode, "authentication, \"#{data.mode}\", invalid. Should be one of: login, plain, or none"]
        end

        if data.user_name.blank? && data.authentication == "login"
          valid = false; errors << [:user_name, "cannot be blank for 'login' authentication"]
        end

        unless data.port.to_s =~ /^[0-9]*$/
          valid = false; errors << [:port, "\"#{data.port}\", invalid. Should be numeric"]
        end

        unless data.from =~ %r{^\A([\w\.\-\+]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z$}i
          valid = false; errors << [:from, "\"#{data.from}\", invalid. Should be a valid email address"]
        end

        return valid, errors
      end
    end
  end
end
