require_relative "miq_defaults"

module Workers
  class Heartbeat
    def self.file_check(heartbeat_file = Workers::MiqDefaults.heartbeat_file)
      if File.exist?(heartbeat_file)
        current_time = Time.now.utc
        contents     = File.read(heartbeat_file)
        mtime        = File.mtime(heartbeat_file).utc
        timeout      = if contents.empty?
                         (mtime + Workers::MiqDefaults.heartbeat_timeout).utc
                       else
                         Time.parse(contents).utc
                       end

        current_time < timeout
      else
        false
      end
    end
  end
end
