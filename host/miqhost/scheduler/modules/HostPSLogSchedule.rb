$:.push("#{File.dirname(__FILE__)}/../../../../lib/util/win32")
require "miq-powershell"

class HostPSLogSchedule
  def self.start(host)
    return unless Platform::OS == :win32

    ps_log_dir = MiqPowerShell::Daemon.get_log_dir
    ps_log_filter = File.join(ps_log_dir, "*.log")

    host.scheduler.schedule_every("5s", :tags => ["host", "events"], :first_in => "5s") do
      MiqThreadCtl.quiesceExit

      begin
        Dir.glob(ps_log_filter) do |f|
          if File.file?(f)
            log_msg = File.read(f).chomp

            log_level = case log_msg[0,1].to_s.downcase
            when 'i' then :info
            when 'd' then :debug
            when 'w' then :warn
            when 'f' then :fatal
            else :info
            end

            $log.send(log_level, "PS LOG: #{log_msg}")
            File.delete(f)
          end
        end
      rescue => err
        $log.error "HostPSLogSchedule: [#{err}]\n#{err.backtrace}"
      end
    end
  end
end
