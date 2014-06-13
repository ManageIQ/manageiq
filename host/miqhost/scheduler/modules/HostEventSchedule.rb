$:.push("#{File.dirname(__FILE__)}/../../../../lib/VdiCitrix")
$:.push("#{File.dirname(__FILE__)}/../../../../lib/VdiVmware")
require "VdiCitrixInventory"
require "VdiVmwareInventory"

class HostEventSchedule
  def self.start(host)
    event_dir = File.join(host.cfg.dataDir, "event")
    event_filter = File.join(event_dir, "*.*")
    Dir.mkdir(event_dir, 0755) if !File.directory?(event_dir)

    # On startup try to remove and old data files that might be left around
    MiqPowerShell.clear_orphaned_data_files if Platform::OS == :win32

    eventing = host.cfg.eventing || {}
    if eventing[:enabled] == false
      $log.info "HostEventSchedule: VDI Eventing has been disabled."
      return
    end

    process = nil
    [VdiCitrixInventory, VdiVmwareInventory].each do |vdi_klass|
      vdi_enabled = vdi_klass.is_available?
      $log.info "HostEventSchedule: #{vdi_klass} enabled <#{vdi_enabled}>"
      if vdi_enabled == true
        pid = vdi_klass.start_event_watcher(event_dir, eventing[:frequency])
        process = host.register_external_process("vdi_watcher", pid, vdi_klass)
      end
    end
    return if process.blank?

    # Setup the task schedule (default internal is 10 min, but the task will reschedule itself on the first pass.
    host.scheduler.schedule_every("5s", :tags => ["host", "events"], :first_in => "5s") do
      MiqThreadCtl.quiesceExit

      begin
        # Only send data if the heartbeat is active
        if host.heartbeat_alive?
          events, event_files = [], []
          Dir.glob(event_filter) do |f|
            if File.file?(f)
              events << {:filename => f, :format => File.extname(f)[1..-1], :data => File.read(f)}
              event_files << f
            end
          end

          unless events.empty?
            $log.info "HostEventSchedule: Sending <#{events.length}> event(s) to the server"
            host_id = host.cfg.hostId
            data = YAML.dump({:type=> :ems_events, :timestamp => Time.now.utc, :host_id => host_id, :events => events}).miqEncode
            host.runSyncTask(["savehostmetadata", host_id, data, 'b64,zlib,yaml'])
            event_files.each {|f| File.delete(f)}
          end
        end
      rescue => err
        $log.error "HostEventSchedule: [#{err}]\n#{err.backtrace}"
      end
    end
  end
end
