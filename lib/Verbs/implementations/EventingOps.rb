$:.push("#{File.dirname(__FILE__)}")

require 'miq-xml'
require 'SharedOps'

class EmsEventMonitorOps
  def initialize(ost, klass)
    extend SharedOps
    @ost = ost
    @klass = klass
    @events = []
    @sleep_interval = 60
    @hostId = ost.args[1]
  end

  def self.doEvents(ost, klass)
    inv_class = klass.new
    raise "EmsEventMonitorOps-doEvents: Class:[#{klass}] does not contain require method 'inv_to_h'." unless inv_class.respond_to?(:to_inv_h)
    em = EmsEventMonitorOps.new(ost, klass)
    em. doEvents
  end

  def init
    begin
      emsName = @ost.args[0]
      emsh = getEmsh(@ost, emsName)
      emsh['name'] = emsName
      @ost.emsEnt = emsh

      @inv_class = @klass.new
      @previous_state_file = File.join(@ost.config.dataDir, 'host_ems_state.yaml')
      @previous_state = nil
      #@previous_state = YAML.load_file(@previous_state_file) rescue nil
      #@previous_state = nil unless Hash === @previous_state

      # Load any previously unsent events
      @previous_events_file = File.join(@ost.config.dataDir, 'host_events.yaml')
      @events = YAML.load_file(@previous_events_file) rescue []
      @events = [] unless Array === @events
    rescue
      $log.error "MonitorEmsEvents-init error [#{$!}]"
      $log.debug "MonitorEmsEvents-init #{$!.backtrace.join("\n")}"
    end
  end

	def doEvents
		init

    begin
      while true
        break if MiqThreadCtl.exiting?
        pollEvents
        send_events
        save_events
        sleep_wait()
      end
    rescue => err
      $log.error "EventingOps: #{err.to_s}" if $log
      $log.error err.backtrace.join("\n") if $log
      sleep_wait(60)
      break if MiqThreadCtl.exiting?
      retry
    end
	end # def doEvents

  def pollEvents
    current_state = @inv_class.to_inv_h
    unless @previous_state.nil?
      process_vm_events(@previous_state, current_state)
    end

    # Setup for next polling event
    @previous_state = current_state
    #File.open(@previous_state_file,'w') {|f| YAML.dump(current_state, f)}
  end

  def save_events
    if @events.blank?
      File.delete(@previous_events_file) if File.exist?(@previous_events_file)
    else
      File.open(@previous_events_file,'w') {|f| YAML.dump(@events, f)}
    end
  end

  def sleep_wait(total_time=nil)
    total_time = @sleep_interval if total_time.to_i < @sleep_interval
    1.upto(total_time/5) {break if MiqThreadCtl.exiting?; sleep(5)}
  end

  def getEmsh(ost, emsName)
    raise "Unknown external management system: #{emsName}" if !ost.config.ems || !(emsh = ost.config.ems[emsName])
    emsh
  end

  def diff_object(old_obj, new_obj, root_key, uniq_id)
    delta = {:adds=>[], :deletes=>[], :updates=>[]}
    o,n  = old_obj[root_key], new_obj[root_key]

    o.sort! {|a,b| a[uniq_id] <=> b[uniq_id]}
    n.sort! {|a,b| a[uniq_id] <=> b[uniq_id]}

    o_idx, n_idx = 0, 0
    loop do
      neww, old = n[n_idx], o[o_idx]

      break if neww.nil? && old.nil?

      if neww.nil? || old.nil?
        if neww.nil?
          delta[:deletes] << old
          o_idx += 1
        else
          delta[:adds] << neww
          n_idx += 1
        end
      else
        case neww[uniq_id] <=> old[uniq_id]
        when 0
          if old.inspect != neww.inspect
            delta[:updates] << {:prev=>old, :curr=>neww}
          end
          n_idx += 1; o_idx += 1
        when 1
          delta[:deletes] << old
          o_idx += 1
        when -1
          delta[:adds] << neww
          n_idx += 1
        end
      end
    end
    return delta
  end

  def diff_stats(delta)
    {:adds=>delta[:adds].length, :deletes=>delta[:deletes].length, :updates=>delta[:updates].length}
  end

  def process_vm_events(previous_state, current_state)
    diff = diff_object(previous_state, current_state, :vms, :location)
    #diff_stat = diff_stats(diff)
    #$log.warn "Eventing diff: [#{diff_stat.inspect}]" if $log

    diff[:deletes].each do |v|
      add_vm_event(:VmConnectedEvent, v)
    end

    diff[:adds].each do |v|
      add_vm_event(:VmDisconnectedEvent, v)
    end

    diff[:updates].each do |upd|
      v = diff_hash_shallow(upd[:prev], upd[:curr])
      v[:updates].each_pair {|k,v| add_vm_event(nil, upd[:curr], {k=>v})}
      unless upd[:prev][:hardware].nil?
        h = diff_hash_shallow(upd[:prev][:hardware], upd[:curr][:hardware])
        add_vm_event(:VmReconfiguredEvent, upd[:curr], h[:updates]) unless h[:updates].empty?
      end
    end
  end

  def diff_hash_shallow(data_old, data_new)
    ret = {:adds=>data_new.keys - data_old.keys,
           :deletes=> data_old.keys - data_new.keys,
           :children => [],
           :updates => {}}

    data_new.each do |k,v|
      next if ret[:adds].include?(k) || ret[:deletes].include?(k)
      if v.kind_of?(Hash) || v.kind_of?(Array)
        ret[:children] << k
        next
      end
      ret[:updates][k] = {:prev=>data_old[k], :curr=>v} unless v == data_old[k]
    end

    return ret
  end

  def add_vm_event(event_type, vm, data=nil)
    event = {:vm => {:path => vm[:location], :name=>vm[:name], :uid_ems=>vm[:uid_ems]}, :data => data}

    if event_type.nil?
      if data.has_key?(:power_state)
        new_power_state = data[:power_state][:curr].capitalize
        case new_power_state
        when 'On', 'Off'
          event[:eventType] = "VmPowered#{new_power_state}Event"
        when 'Suspended'
          event[:eventType] = "VmSuspendedEvent"
        end

        event[:fullFormattedMessage] = "VM [#{vm[:name]}] has changed to power state #{new_power_state}"
      else
        # Event not handled
        return
      end
    else
      event[:eventType] = event_type.to_s
      host_name = vm.fetch_path(:host, :name)
      event[:fullFormattedMessage] = case event_type
      when :VmReconfiguredEvent then "Reconfigured [#{vm[:name]}] on #{host_name}"
      when :VmConnectedEvent    then "Virtual Machine [#{vm[:name]}] is connected on #{host_name}"
      when :VmDisconnectedEvent then "Virtual Machine [#{vm[:name]}] is disconnected on #{host_name}"
      end
    end

    add_event(event[:eventType], event)
  end

  def add_event(event_type, event)
    # Build the event hash
    result = {
      :event_type => event_type,
      :is_task => false,
      :source => 'MIQ',

      :message => event[:fullFormattedMessage],
      :timestamp => Time.now.utc,
      :full_data => event
    }

    vm_name = event.fetch_path(:vm, :name)
    result[:vm_name] = vm_name unless vm_name.nil?

    vm_location = event.fetch_path(:vm, :path)
    result[:vm_location] = vm_location unless vm_location.nil?

#    result[:username] = event['userName'] unless event['userName'].blank?
    $log.warn "Events: Adding [#{result[:event_type]}] for [#{result[:vm_name]}]"
    @events << result
  end

  def host_id
    # Handle if the hostId changes without restarting
    return @hostId if $miqHostCfg.blank? || $miqHostCfg.hostId.blank?
    return @hostId = $miqHostCfg.hostId
  end

  def send_events
    return if @events.empty?
    
    @ost.args[0] = self.host_id
    @ost.args[1] = {:type=> :ems_events, :timestamp => Time.now.utc, :host_id => @hostId, :events => @events}
    @ost.args[2] = 'yaml'

    begin
      $log.warn "Sending EMS events.  Count:[#{@events.length}]"
      SaveHostMetadata(@ost)
      @events.clear
    rescue
    end
  end
end
