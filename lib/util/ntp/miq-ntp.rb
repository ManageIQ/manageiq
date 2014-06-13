class MiqNtp
  NTP_CONF = "/etc/ntp.conf"
  SCRIPT = "/var/www/miq/lib/util/ntp/cron_ntpdate"
  DEFAULT_INTERVAL = 15  # run ntpdate every 15 minutes

  class << self
    def sync_settings(ntp_settings)
      return unless Platform::IMPL == :linux && File.exists?(SCRIPT)
      update_ntp_conf(ntp_settings[:server])

      sync_to_ntpd if use_ntpd?
      if use_ntpdate?
        interval = ntp_settings[:interval].nil? ? DEFAULT_INTERVAL : ntp_settings[:interval]
        add_ntpdate_to_cron(interval)
      end
    end
    
    private
    def use_ntpd?
      false
    end

    def sync_to_ntpd
      # restart or start ntpd to pick up the changes
    end

    def use_ntpdate?
      true
    end

    def add_ntpdate_to_cron(interval)
      `#{SCRIPT} #{interval}`
    end
  
    def update_ntp_conf(server)
      server = [server] unless server.is_a?(Array)

      # Read the current config
      if File.exists?(NTP_CONF)
        data = File.read(NTP_CONF)

        # Remove existing lines beginning with "server"
        data.gsub!(/\nserver\s(\S+)/, "")
      else
        data = ""
      end

      # Add lines for each server provided by the user
      server.each {|s| data << "\nserver #{s}" }

      # Write the changes back
      File.open(NTP_CONF, "w") {|f| f.write(data)}
    end
  end
end


