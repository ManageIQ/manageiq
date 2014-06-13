$:.push("#{File.dirname(__FILE__)}/../../lib/util")

require 'ostruct'
require 'process_queue'
require 'miq-xml'
require 'platform'
require 'MiqThreadCtl'
require 'yaml'
require 'MiqSockUtil'

module Heartbeat
	def heartbeat_loop()
		ht = MiqThreadCtl << Thread.new do
			set_heartbeat_interval()
			# Use this flag to break the heartbeat sleep loop at any given time.
			@hbWakeup = false
			begin
        check_vmdb_settings()
				starting()
				running()
			rescue => err
				$log.fatal "heartbeat_loop [#{err}]"
				$log.debug "heartbeat_loop [#{err.backtrace}]"
			end
		end

		# Increate the priority for the heartbeat thread.
		ht[-1].priority = ht[-1].priority + 10
	end
	
	def send_heartbeat(hostId=nil, options={})
    options = {:timeout=>60}.merge(options)
    
    @hostname ||= MiqSockUtil.getFullyQualifiedDomainName
    set_heartbeat_interval()
    # Pass Agent time to server during heartbeat
    xml = MiqXml.createDoc("<host_heartbeat/>")
    hostNode = xml.root.add_element("host", {"id"=>hostId, "agent_time"=>Time.now.utc.iso8601, "hostname"=>@hostname})
    hostNode.add_attributes({"exiting"=>MiqThreadCtl.exiting?, "tasks"=>YAML.dump(@longTask.contents)})
            
    begin
      @stats[:heartbeat][:total] += 1
      ret = runSyncTask(["hostheartbeat", hostId, xml], options)
      @stats[:heartbeat][:alive] = true
      @stats[:heartbeat][:last_successful_time] = Time.now.utc
      @stats[:heartbeat][:consecutive_failed] = 0
    rescue StandardError => err
      @stats[:heartbeat][:failed] += 1
      @stats[:heartbeat][:consecutive_failed] += 1
      @stats[:heartbeat][:alive] = false
      @stats[:heartbeat][:last_failure_time] = Time.now.utc
      ret = nil
    end
        
    unless ret.nil?
      $log.debug "heartbeat - returned: [#{ret.inspect}]"
      data = YAML.load(ret)
      if data.is_a?(Hash)
        process_server_heartbeat(data)
        # Now check if the heartbeat sent any tasks to process
        if data[:tasks].is_a?(Array)
          data[:tasks].each {|t|
            set_heartbeat_interval(1)
            run_task(OpenStruct.new(YAML.load(t)))
          }
        end
      end
    end
	end

  def process_server_heartbeat(serverData)
        
    begin
      svrTime = Time.parse(serverData[:server_time])
      svrTime = "Server Time:[#{serverData[:server_time].to_s}],  Offset from client:[#{(Time.now-svrTime).to_i}] seconds"
    rescue
      svrTime = ""
    end
        
    # Check if the server is returning an error
    if serverData[:server_error] && serverData[:server_error] == true
      $log.warn "A Server error occurred during the heartbeat.  Message: [#{serverData[:server_message]}].  Host Action:[#{serverData[:host_action]}]"
      process_host_action(serverData[:host_action])
      #if serverData[:host_action] == "retry"
      #end
    else
      # Log the return message and time of the server
      # We also calculate the time difference between the client and server
      # and round it to the nearest second.
      $log.info "heartbeat - returned message: [#{serverData[:server_message]}], #{svrTime}, Server build:[#{serverData[:server_build]}]"
            
      # Log a message if we detect that the server build number has changed.
      unless serverData[:server_build].nil?
        if serverData[:server_build].to_s.strip != @cfg.server_build.to_s.strip
          $log.warn("Server build changed.  Current:[#{serverData[:server_build]}]  Previous:[#{@cfg.server_build}]") #if @cfg.server_build
          @cfg.server_build = serverData[:server_build]
          updateHostConfig()
        end
      end
    end
  end
	
	def register
		begin
			xml = MiqXml.load(runSyncTask(["gethostconfig"]))
			buildHostXML(0).each_element {|e| xml.root << e }
			ret = YAML.load(runSyncTask(["agentregister", xml]))
		
			$log.debug "register - returned: [#{ret.inspect}] [#{ret.class}]"
			if ret.is_a?(Hash)
				$log.info "miqhost registered with id [#{ret[:hostId]}]"
				hostId = getHostId(ret[:hostId])
				set_heartbeat_interval(1)
			else
				$log.warn "miqhost returned [#{ret}] [#{ret.class}] from registration call"
				set_heartbeat_interval()
			end
		rescue => err
			$log.warn "register [#{err.to_s}]"
		end
	end

  def heartbeat_alive?
    @stats[:heartbeat][:alive]
  end
  
  def heartbeat_freq()
    return 60 if @cfg.heartbeat_frequency <= 0
    @cfg.heartbeat_frequency
  end
  
  def set_heartbeat_interval(value=nil)
    # If we get passed a nil, set it to the configured heartbeat freq.
    value = self.heartbeat_freq if value.nil?
    @sleepTime = value <= 0 ? 60 : value
  end
	
	def run_task(ost)
		method_name = "miq" + ost.method_name
		method_parms = format_parms(ost)
		#$log.debug "running heartbeat task :[#{method_name}] with parms: [#{method_parms}]" #{ost.marshal_dump.inspect}"
		self.send(method_name, *method_parms)
		sleep(1)
	end
	
	def format_parms(ost)
		method_parms = []
		case ost.method_name
		when "GetHostConfig"
			method_parms << ost.hostId
		when "GetVMs"
			method_parms << "-f" if ost.fmt==true
		when "RegisterId"
			method_parms << ost.args << ost.vmId
		when "DeleteBlackBox"
			method_parms << ost.args unless ost.args[0].nil?
			method_parms << "-a" if ost.deleteall
		when "SyncMetadata", "ExtractMetadata"
			method_parms << ost.args
			method_parms << ost.category
			method_parms << ost.from_time
		when "ScanMetadata", "FleeceMetadata"
			method_parms << ost.args
			method_parms << ost.category unless ost.category.nil?
		when "ScanRepository"
			method_parms << ost.path << ost.repository_id
			method_parms << "-f" if ost.fmt==true
		when "GetAgent"
			method_parms << ost.url << ost.metadata
		when "ActivateAgent"
			method_parms << ost.url << ost.metadata			
		when "ChangeAgentConfig"
			method_parms << ost.config
		when "RecordBlackBoxEvent"
			method_parms << ost.args[0] << ost.args[1]
		else
			method_parms << ost.args
		end

		# For all methods if we are being passed a taskid, append it.
		method_parms << ost.taskid unless ost.taskid.nil?
		return method_parms
	end
	
	def heartbeat_sleep
		$log.info "heartbeat sleeping for [#{@sleepTime}] seconds" #unless @sleepTime.zero?
		elapsed_seconds = 0
		@hbWakeup = false
		loop do
      MiqThreadCtl.quiesceExit
			break if elapsed_seconds >= @sleepTime
			break if @hbWakeup
			sleep(5)
			elapsed_seconds += 5
		end
		@hbWakeup = false
	end
	
	def buildHostXML(hostId)
		# On the first heartbeat send the host version to the server
		MiqXml.createDoc("<host_heartbeat><host id=\"#{hostId}\" version=\"#{@cfg.host_version.join(".")}\" platform=\"#{Platform::IMPL}\" architecture=\"#{Platform::ARCH}\"/></host_heartbeat>")
	end
	
	def starting
    # Check that the main thread has initialized the server handle.  If not give
    # that thread some time to complete.
    1.upto(10) {|i| break unless $miqHostServer.nil?; Thread.pass(); sleep(1)}

    # We will break out of this loop when we have the first
    # successful heartbeat exchange with the server.
    loop do
      # Make sure we have a hostId to send to the server.
      loop do
        # If we do not
        begin
          break if getHostId(nil)
          # Contact vmdb for an id
          register
          heartbeat_sleep()
        rescue => err
          heartbeat_sleep()
        end
      end

      begin
        if getHostId(nil)
          agentSettings = YAML.dump(@cfg.marshal_dump)
          setEncode = MIQEncode.encode(agentSettings)
          agentRet = runSyncTask(["agentconfig", getHostId(nil), setEncode], {:timeout=>60}) rescue nil

          if agentRet.nil?
            $log.debug "AgentConfig returned nil.  Retrying..."
            heartbeat_sleep()
          else
            ret = YAML.load(agentRet)
            $log.debug "AgentConfig returned [#{ret.inspect}]"
            # Apply new settings
            if ret.is_a?(Hash)
              # Check if the server is returning an error
              if ret[:server_error] && ret[:server_error] == true
                $log.error "A server error was detected.  Message: [#{ret[:server_message]}].  Host Action:[#{ret[:host_action]}]"
                if ret[:host_action]
                  process_host_action(ret[:host_action])
                else
                  heartbeat_sleep()
                end
              else
                miqChangeAgentConfig(ret)
                sleep 2
                # We can successfully break out of the startup loop
                break
              end
            else
              break
            end
          end
        end
      rescue => err
        $log.error "heartbeat_start [#{err}]"
        $log.debug "heartbeat_start [#{err.backtrace}]"
      end
    end
	end

  def process_host_action(action)
    case action
    when "reset_hostid"
      $log.warn  "The hostId value will be cleared from the host to reset with the server."
      @cfg.hostId = nil
    when "shutdown", "stop"
      $miqHostServer.shutdown()
    when "restart"
      $miqHostServer.restart()
    when "uninstall"
      $miqHostServer.shutdown() {|pc| pc.uninstall()}
    when "retry"
      # Just skip
    else
      $log.warn "Unprocessed host action [#{action}]"
    end
  end
  
	def running
		loop do
			begin
				# Look for new tasks to run
        if MiqThreadCtl.exiting?
          # Log that the heartbeat was skipped because of a shutdown
          $log.warn "Heartbeat skipped due to pending shutdown."
        else
          send_heartbeat(getHostId(nil))
        end
				heartbeat_sleep
      rescue StandardError => err
				$log.error "heartbeat error [#{err}]"
				$log.debug "heartbeat error [#{err.backtrace}]"
				heartbeat_sleep
			end
		end
	end

  def check_vmdb_settings()
    remaining_sleep_time = sleep_time = 10
    # Check if we have valid ip/port settings.  Wait if we do not
		loop do
      MiqThreadCtl.quiesceExit
      break if !@cfg.vmdbHost.blank? && @cfg.vmdbHost.downcase[0..2] != "xxx"
      remaining_sleep_time -= sleep_time
      if remaining_sleep_time.zero?
        $log.warn "vmdbHost is not set [#{@cfg.vmdbHost}]."
        remaining_sleep_time = 10 * 6 * 60
      else
        sleep(sleep_time)
      end
		end
  end
end
