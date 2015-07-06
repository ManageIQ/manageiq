require 'MiqVimEventMonitor'
require 'miq-process'

host, user, pass, logfile = ARGV

logfile ||= "./env_probe_event_catcher.log"
File.delete(logfile) if File.exist?(logfile)
$log = VMDBLogger.new(logfile)
$log.level = VMDBLogger.const_get("INFO")

def log(level, msg)
  puts "[#{Time.now.utc}] #{level.to_s.upcase}: #{msg}"
  $log.send(level, msg)
end

def at_exit(msg)
  log :info, msg
  log :info, "Total Events Caught: #{$event_cnt}, Process stats: #{MiqProcess.processInfo.inspect}"
  exit 0
end

["INT", "KILL", "TERM"].each { |s| trap(s) { at_exit("Interrupt signal (#{s}) received.") } if Signal.list.keys.include?(s) }

$event_cnt = 0
log :info, "Starting Event Catcher on #{host}..."
tid = Thread.new do
  begin
    $vim_em = MiqVimEventMonitor.new(host, user, pass, nil, 100)
    $vim_em.monitorEvents do |ea|
      ea.each do |e|
        e1 = eval(e.inspect)
        event_type = e1['eventType']
        next if event_type.nil?

        case event_type
        when "TaskEvent"
          sub_event_type = event.fetch_path('info', 'name')
          display_name   = "#{event_type}]-[#{sub_event_type}"
        when "EventEx"
          sub_event_type = event['eventTypeId']
          display_name   = "#{event_type}]-[#{sub_event_type}"
        else
          sub_event_type = nil
          display_name   = event_type
        end

        log :info, "Caught event [#{display_name}] chainId [#{e1['chainId']}]"
        $event_cnt += 1
      end
    end
  rescue => err
    log "error", err.message
    log "error", err.backtrace.join("\n")
    exit 1
  end
end

log :info, "Starting Event Catcher on #{host}... Complete"
puts "\nHit ^C to quit"
puts

log :info, "Total Events Caught: #{$event_cnt}, Process stats: #{MiqProcess.processInfo.inspect}"

iterations = 5
while 1 do
  sleep 60

  log :info, "Total Events Caught: #{$event_cnt}, Process stats: #{MiqProcess.processInfo.inspect}"
  iterations -= 1
  break if iterations == 0
end

exit 0
