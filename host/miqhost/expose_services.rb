$:.push("#{File.dirname(__FILE__)}/../../lib/Verbs")
$:.push("#{File.dirname(__FILE__)}/../../lib/util")
$:.push("#{File.dirname(__FILE__)}/../../lib/util/win32")
$:.push("#{File.dirname(__FILE__)}/scheduler")
$:.push("#{File.dirname(__FILE__)}/..")

require 'MiqVerbs'
require 'ostruct'
require 'process_queue'
require 'miq-xml'
require 'miq-encode'
require 'heartbeat'
require 'EmsEventMonitor'
require 'UpdateAgent'
require 'MiqThreadCtl'
require 'rufus/scheduler'
require 'HostScheduler'
require 'uuidtools'
require 'miq-process'
require 'miq-powershell-daemon'

module Manageiq
  class ExposeServices
    attr_reader :scheduler, :stats, :cfg

    def initialize(cfg)
      @cfg = cfg
      @shutdown_initiated = false
      @longTask  = Manageiq::ProcessQueue.new(cfg, "long",  {:timeout=>1800, :persist=>true})   # Use this for long async tasks
      @shortTask = Manageiq::ProcessQueue.new(cfg, "short", {:timeout=>300})  # Use this for short async tasks
      @scheduler = Rufus::Scheduler.start_new(:scheduler_precision => 1.0) # Use a 1 second precision
      @stats = {
        :start_time => Time.now,
        :heartbeat => {:alive => false, :total => 0, :failed => 0, :consecutive_failed => 0}
      }
      @downloading_agent = Mutex.new
      
      # log version and configuration settings
      $log.addPostRollEvent(:miqhost_settings, true) {log_parameters()}
      $log.info "** Use Ctrl-C to shutdown server"

      # Launch Startup task and event loops
      @scheduler.start
      startup_tasks
    end


    def log_parameters
      # log version and configuration settings
      $log.summary "Version: #{@cfg.host_version.join(".")}"
      $log.summary "miqhost settings:"
      YAML.dump(@cfg).each_line {|e| $log.summary e.chomp}
      $log.summary "---"
    end
    
    def startup_tasks
      # Start heartbeat loop
      extend Heartbeat
      heartbeat_loop

      # Monitor events, as configured
      extend EmsEventMonitor
      monitorEmsEvents
      
      # Initialize scheduled tasks
      HostScheduler.startScheduledTasks(self)

      # Cleanup old temp directories if they are left around
      Manageiq::AgentMgmt.cleanup_temp_files()
    end


    def miqCreateBlackBox(vmName, eventData)
      @longTask.add(["createblackbox", vmName, "\"#{eventData}\""])
      return true
    end
	
    def miqValidateBlackBox(vmName, eventData)
      @longTask.add(["validateblackbox", vmName, "\"#{eventData}\""])
      return true
    end

    def miqDeleteBlackBox(vmName, eventData)
      @longTask.add(["deleteblackbox", vmName, "\"#{eventData}\""])
      return true
    end

    def miqRecordBlackBoxEvent(vmName, eventData)
      @longTask.add(["recordblackboxevent", vmName, "\"#{eventData}\""])
      return true
    end

    def vmMetadataCategories()
      "vmconfig,accounts,software,services,system"
    end
  
    # SyncMetadata - get data out of the blackbox and send to the server
    def miqSyncMetadata(vmName, type=nil, from_time=nil, taskid=nil, options=nil)
      type = self.vmMetadataCategories() if type.nil?
      @longTask.add(["syncmetadata", "--category=\"#{type}\"", "--from_time=\"#{from_time}\"", "--taskid=\"#{taskid}\"", vmName, "\"#{options}\""])
      return true
    end

    # ScanMetadata - get data from the vm disk files and store in the blackbox
    def miqScanMetadata(vmName, type=nil, taskid=nil, options=nil)
      type = self.vmMetadataCategories() if type.nil?
      @longTask.add(["scanmetadata", "--category=\"#{type}\"", "--taskid=\"#{taskid}\"", vmName, "\"#{options}\""])
      return true
    end

    #getheartbeat
    def miqGetHeartBeat(vmName)
      getRValue(runSyncTask(["getheartbeat", vmName]))
    end

    #getversion
    def miqGetVersion
      runSyncTask(["getversion"])
    end

#getvmattributes
#getvmproductinf

    #getvms
    def miqGetVMs(opts=nil)
      Thread.new {
        ret = runSyncTask(["getvms", opts])
        begin
          vm_list = eval(ret) rescue []
          $log.info "GetVMs: VM count = [#{vm_list.length}]"
          $log.debug "miqGetVMs: returned from getvms, ret = #{ret}"
          xml = MiqXml.createDoc("<host_getvms/>")
          xml.root.add_attribute("vmlist", ret)
          $log.debug "miqGetVMs: adding savehostmetadata task"
          hostId = getHostId()
        rescue => err
          $log.error "GetVMs ERROR: [#{err.to_s}]"
          $log.debug "GetVMs ERROR: [#{err.backtrace.join("\n")}]"
        end
        @shortTask.add(["savehostmetadata", hostId, xml])
      }
      true
    end

    def miqScanRepository(scanPath, scanId, opts=nil)
      Thread.new {
        begin
          hostId = getHostId()
          ret = runSyncTask(["scanrepository", scanPath, scanId, opts])
          xml = MiqXml.createDoc("<host_getvms/>")
          xml.root.add_attribute("vmlist", ret)
          @shortTask.add(["savehostmetadata", hostId, xml])
        rescue => err
          $log.error "ScanRepository ERROR: [#{err.to_s}]"
        end
      }
      true
    end

    #getvmstate
    def miqGetVMState(opts)
      getRValue(runSyncTask(["getvmstate", opts]))
    end

#hassnapshot
#help

    #makesmart
    def miqMakeSmart(vmName, queue=@shortTask)
      begin
        queue.add(["makesmart", vmName])
      rescue => e
        $log.error "#{print_hex_pid(nil)} miqMakeSmart Error: [#{e.to_s}]"
      end
    end

#readblackbox

    #registerid
    def miqRegisterId(vmName, id, params={})
      $log.debug "miqRegisterId: vmName = #{vmName}, id = #{id}"
      Thread.new do
        begin
          # Register the id in the blackbox, send vmconfig to db and send current vm state.
          params = {"registeredOnHost"=>false}.merge(params)
          #params["guid"] = UUID.parse(id)
          #raise "Invalid guid for VM.  Guid:[#{id}]" unless params["guid"].valid?
          params["guid"] = id
              
          @longTask.add(["registerid", vmName, "--id=#{params["guid"]}"])
          @longTask.add(["getvmconfig", vmName])
          sendVMState(vmName, params["guid"], @longTask) if params["registeredOnHost"]
          miqMakeSmart(vmName, @longTask) if params["makeSmart"]
        rescue => err
          $log.error "Parsing registered ID for VM:[#{vmName}]"
        end
      end
      return true
    end

    #registervm
    def miqRegisterVM(vmName)
      runSyncTask(["registervm", vmName])
    end

    #resetvm
    def miqResetVM(vmName, vm_guid=nil)
      Thread.new do
        run_action(vmName, vm_guid) {|n| getRValue(runSyncTask(["resetvm", n, vm_guid]))}
      end
      return "reset() = 1"
    end

    #savevmmetadata
    def miqSavevmMetadata(vmName)
      runSyncTask(["savevmmetadata", vmName])
    end

    #startvm
    def miqStartVM(vmName, vm_guid=nil)
      Thread.new do
        run_action(vmName, vm_guid) {|n| getRValue(runSyncTask(["startvm", n, vm_guid]))}
      end
      return "start() = 1"
    end

    #stopvm
    def miqStopVM(vmName, vm_guid=nil, type=3)
      Thread.new do
        begin
          getRValue(runSyncTask(["stopvm", vmName, type]))
        ensure
          sendVMState(vmName, vm_guid)
        end
      end
      return "stop() = 1"
    end

    def miqPing(data)
      $log.info "*** miqPing called received"
      return true
    end

    #suspendvm
    def miqSuspendVM(vmName, vm_guid=nil)
      Thread.new do
        run_action(vmName, vm_guid) {|n| getRValue(runSyncTask(["suspendvm", n]))}
      end
      return "suspend() = 1"
    end

    def miqPauseVM(vmName, vm_guid=nil)
      Thread.new do
        run_action(vmName, vm_guid) {|n| getRValue(runSyncTask(["pausevm", n]))}
      end
      return "pause() = 1"
    end

    def miqShutdownGuest(vmName, vm_guid=nil)
      Thread.new do
        run_action(vmName, vm_guid) {|n| getRValue(runSyncTask(["shutdownguest", n]))}
      end
      return "shutdown_guest() = 1"
    end

    def miqStandbyGuest(vmName, vm_guid=nil)
      Thread.new do
        run_action(vmName, vm_guid) {|n| getRValue(runSyncTask(["standbyguest", n]))}
      end
      return "standby_guest() = 1"
    end

    def miqRebootGuest(vmName, vm_guid=nil)
      Thread.new do
        run_action(vmName, vm_guid) {|n| getRValue(runSyncTask(["rebootguest", n]))}
      end
      return "reboot_guest() = 1"
    end

    #version
    def miqVersion
      runSyncTask(["version"])
    end

    def miqCreateSnapshot(vm_name, name, desc, memory, quiesce, vm_guid=nil)
      Thread.new do
        begin
          cmd = ["createsnapshot", "--name=\"#{name}\"", "--description=\"#{desc}\""]
          cmd << '--memory' if memory==true
          cmd << '--quiesce' if quiesce==true
          cmd << vm_name
          runSyncTask(cmd)
        rescue
          $log.error "miqCreateSnapshot ERROR: [#{$!.to_s}]"
        end
      end
      true
    end

    def miqRemoveSnapshot(vmName, sn_uid, vm_guid=nil)
      Thread.new do
        begin
          runSyncTask(["removesnapshot", vmName, sn_uid])
        rescue
          $log.error "miqRemoveSnapshot ERROR: [#{$!.to_s}]"
        end
      end
      true
    end

    def miqRemoveAllSnapshots(vmName, vm_guid=nil)
      Thread.new do
        begin
          runSyncTask(["removeallsnapshots", vmName])
        rescue
          $log.error "miqRemoveAllSnapshots ERROR: [#{$!.to_s}]"
        end
      end
      true
    end

    def miqRevertToSnapshot(vmName, sn_uid, vm_guid=nil)
      Thread.new do
        begin
          runSyncTask(["reverttosnapshot", vmName, sn_uid])
        rescue
          $log.error "miqRevertToSnapshot ERROR: [#{$!.to_s}]"
        end
      end
      true
    end

    def miqRemoveSnapshotByDescription(vmName, sn_uid, vm_guid=nil)
      Thread.new do
        begin
          runSyncTask(["removesnapshotbydescription", vmName, sn_uid])
        rescue
          $log.error "miqRemoveSnapshotByDescription ERROR: [#{$!.to_s}]"
        end
      end
      true
    end
#writeblackbox

    def version
      return host_version.join(".")
    end

    def miqGetHostConfig(hostId=nil)
      Thread.new {
        hostId = getHostId(hostId)
        ret = runSyncTask(["gethostconfig"])
        @shortTask.add(["savehostmetadata", hostId, ret])
      }
      return true
    end

    def miqSendVMState(vmName=nil)
      Thread.new {
        begin
          if vmName.nil?
    				ret = runSyncTask(["getvms", "-f"])
            # Convert the return value into an Array of Hashes
            vmList = eval(ret)
            $log.summary "Sending current VM state to server for [#{vmList.length}] registered VMs"
            vmList.each {|vm| sendVMState(vm[:location])}
          else
            sendVMState(vmName)
          end
        rescue Timeout::Error, StandardError => e
          $log.error "miqSendState Command Error: [#{e.to_s}]"
          $log.debug e.backtrace.join("\n")
        end
      }
      return true
    end

    def miqReplicateHost(installSettings)
      Thread.new do
        # We can be called while the download is still in progress, so wait.
        @downloading_agent.synchronize do
          begin
            # Run the code to replicate the host
            installSettings = eval(installSettings)
            #$log.info "Replicating host to #{installSettings.inspect}"
            pc = PlatformConfig.new(@cfg)
            pc.remoteInstall(installSettings)
          rescue Timeout::Error, StandardError => e
            $log.error "miqReplicateHost Command Error: [#{e.to_s}]"
          end
        end
      end
      return true
    end

    def runSyncTask(command, options={}, &blk)
      syncTask = Manageiq::ProcessQueue.new(@cfg, "sync", options)
      ret = syncTask.parseCommand(command, &blk)
    end

    # Check if the hostId is blank or this the local config file needs to be updated
    def getHostId(hostId=nil)
      cfg_hostId = @cfg.hostId rescue nil

      # Nothing has changed, return this value
      hostId = cfg_hostId if hostId.nil?
      return hostId if hostId == cfg_hostId

      # The hostId is different
      unless hostId.nil?
        begin
          @cfg.hostId = hostId
          updateHostConfig()
        rescue => err
        end
      end

      return hostId
    end

    def updateHostConfig()
      $log.info "Saving config file [#{@cfg.cfgFile}]"
      MiqHostConfig.writeConfig(@cfg)
    end

    def miqGetEmsInventory(emsName=nil)
      Thread.new do
        hostId = getHostId()
        ret = runSyncTask(["getemsinventory", emsName])
        @shortTask.add(["savehostmetadata", hostId, ret.miqEncode, 'b64,zlib,yaml'])
        #@shortTask.add(["saveemsinventory", hostId, ret])
      end
      return true
    end

    def miqWakeupHeartbeat()
      @hbWakeup = true
    end

    def miqGetAgent(agentURI, props)
      Thread.new do
        @downloading_agent.synchronize do
          begin
            props = eval(props)
            agentURI = "#{@cfg.webservices[:consumer_protocol]}://#{@cfg.vmdbHost}:#{@cfg.vmdbPort}#{agentURI}"
            taskid = props[:taskid]
            pc = PlatformConfig.new(@cfg)
            startTime = Time.now
            $log.info "Running Command: [GetAgent Build #{props[:build]}]"
            Manageiq::AgentMgmt.downloadAgent(agentURI, pc.files[:miqBinDir], @cfg.miqhost_keep, props)
            $log.info "Command [GetAgent] completed successfully in [#{Time.now-startTime}] seconds."
          rescue => err
            $log.error "Command [GetAgent] failed after [#{Time.now-startTime}] seconds."
            $log.error err.to_s
            $log.debug err.backtrace
            miqTaskUpdate(taskid, "Finished", "Error", "Download error:[#{err}]") if taskid
          end
        end
      end
      return true
    end

    def miqChangeAgentConfig(newConfig)
      unless newConfig.is_a?(Hash)
        newConfig = YAML.load(newConfig) rescue eval(newConfig)
      end

      if newConfig.is_a?(Hash)
        Thread.new do
          begin
            $log.info "ChangeConfig received [#{newConfig.class}] [#{newConfig.inspect}]"
            process_settings(newConfig)
            # FB 5438 - restart called on nil object
            if $miqHostServer.nil?
              $log.error "ChangeAgentConfig: Unable to initiate server restart due to nil server handle."
            else
              $miqHostServer.restart()
            end
          rescue => err
            $log.error "ChangeAgentConfig [#{err}]"
            $log.debug "ChangeAgentConfig [#{err.backtrace}]"
          end
        end
      else
        $log.warn "Invalid parm: ChangeConfig [#{newConfig.class}] [#{newConfig}]"
      end
      return true
    end

    def miqActivateAgent(agentURI, props)
      Thread.new do
        # We can be called while the download is still in progress, so wait.
        @downloading_agent.synchronize do
          begin
            props = eval(props)
            pc = PlatformConfig.new(@cfg)

            # Check if the requested agent is available before we activate
            begin
              taskid = props[:taskid]
              Manageiq::AgentMgmt.agent_exist_error_message(pc.files[:miqBinDir], props)
              miqTaskUpdate(taskid, "Active", "Ok", "Restarting to activate version [#{props[:version]}]") if taskid
            rescue => err
              miqTaskUpdate(taskid, "Finished", "Error", "Version [#{props[:build]}] does not exist in local cache.  Message:[#{err}]") if taskid
              raise "Host version [#{props[:build]}] does not exist in cache.  Message:[#{err}]"
            end

            $miqHostServer.shutdown() do |pc|
              $log.debug "miqActivateAgent: calling PlatformConfig.agent_activate"
              pc.agent_activate(props)
              $log.debug "miqActivateAgent: returned from PlatformConfig.agent_activate"
            end
          rescue => err
            $log.error "ActivateAgent [#{err}]"
            $log.debug "ActivateAgent [#{err.backtrace}]"
            miqTaskUpdate(taskid, "Finished", "Error", "Activation error:[#{err}]") if taskid
          end
        end
      end
      return true
    end

    def miqTaskUpdate(task_id, state, status, message)
        runSyncTask(["taskupdate", task_id, state, status, message]) rescue nil
    end

    def miqGetAgentLogs(agentURI, props)
      Thread.new {
        begin
          props = eval(props)
          agentURI = "#{@cfg.webservices[:consumer_protocol]}://#{@cfg.vmdbHost}:#{@cfg.vmdbPort}#{agentURI}"

          startTime = Time.now
                
          # Dump current stats so they show in the agent log
          logStats()

          $log.info "Running Command: [GetAgentLogs collect=#{props[:collect]}]"
          ret = Manageiq::AgentMgmt.logUpload(getHostId, agentURI, @cfg.miqLogs, props)
          if ret == true
            $log.info "Command [GetAgentLogs] completed successfully in [#{Time.now-startTime}] seconds."
          else
            $log.warn "Command [GetAgentLogs] failed after [#{Time.now-startTime}] seconds."
          end
        rescue => err
          $log.error err.to_s
          $log.debug err.backtrace
        end
      }
      return true
    end

    def miqPolicyCheckVm(vmName)
      runSyncTask(["policycheckvm", vmName])
    end

    def logStats
      $log.summary "Stats - Uptime: #{(Time.now-@stats[:start_time]).to_i} seconds - Memory usage: #{MiqProcess.processInfo[:memory_usage]}"
      $log.summary "HOST STATS heartbeat  : #{@stats[:heartbeat].inspect}"
      #        $log.summary "Total tasks process (all queues): #{Manageiq::ProcessQueue.total}"
      logQueueStats(@longTask, "long")
      logQueueStats(@shortTask, "short")
    end

    def logQueueStats(queue, name)
      $log.summary "HOST STATS #{name} queue : #{queue.stats.inspect}  Current Task: #{queue.current_task_string()}"
      $log.summary "HOST STATS #{name} queue : Process info: #{MiqProcess.processInfo(queue.processing_pid()).inspect}" unless queue.processing_pid().nil?
    end

    def miqClearQueueItems(options)
      options = YAML.load(options)
      if options.is_a?(Hash)
        Thread.new do
          begin
            $log.debug "ClearQueueItems request received [#{options.inspect}]"
            [@longTask, @shortTask].each {|q| q.clear_queue_items(options)}
          rescue => err
            $log.error "miqClearQueueItems [#{err}]"
            $log.debug "miqClearQueueItems [#{err.backtrace}]"
          end
        end
      else
        $log.warn "Invalid parm: miqRemoveQueueTask [#{options.class}] [#{options}]"
      end
      return true
    end

    def miqPowershellCommand(ps_script, return_type='object')
      result = {:error => false}
      begin
        $log.debug "PowershellCommand script\n#{ps_script}\nReturn type:[#{return_type}]"
        cmd_ret = (return_type == 'object') ? 'xml' : return_type
        result[:ps_object] = runSyncTask(["powershellcommand", ps_script, cmd_ret]) do |task_ret|
          result.merge!(:ps_logging => task_ret.ps_log_messages)
        end
        result[:ps_object] = MiqPowerShell.ps_xml_to_hash(result[:ps_object]) if return_type == 'object'
      rescue
        $log.error "miqPowershellCommand ERROR - #{$!}"
        $log.debug "#{$!.backtrace.join("\n")}"
        result.merge!(:error => true, :error_class=>$!.class.to_s, :message=>$!.to_s)
      end
      return YAML.dump(result)
    end

    def miqPowershellCommandAsync(ps_script, return_type='object', options = '')
      Thread.new do
        begin
          options = YAML.load(MIQEncode.decode(options))
          queue_parms = YAML.dump(options[:queue_parms]).miqEncode
          result = miqPowershellCommand(ps_script, return_type)
          runSyncTask(["queueasyncresponse", queue_parms, result.miqEncode])
        rescue
          $log.error "miqPowershellCommandAsync ERROR - #{$!}"
          $log.debug "#{$!.backtrace.join("\n")}"
        end        
      end
      return true
    end

    def miqShutdown(options)
      options = YAML.load(options)
      if options.is_a?(Hash)
        Thread.new do
          begin
            $log.info "Shutdown request received [#{options.inspect}]"
            if options[:restart] == true
              $miqHostServer.restart()
            else
              $miqHostServer.shutdown()
            end
          rescue => err
            $log.error "miqShutdown [#{err}]"
            $log.debug "miqShutdown [#{err.backtrace}]"
          end
        end
      else
        $log.warn "Invalid parm: miqShutdown [#{options.class}] [#{options}]"
      end
      return true
    end

    def host_shutdown(restart)
      log_header = "host_shutdown:"
      begin
        unless @shutdown_initiated
          $log.info "#{log_header} initiated... restart=[#{restart}]"
          @shutdown_initiated = true

          $log.debug "#{log_header} calling MiqThreadCtl.exitHold"
          MiqThreadCtl.exitHold
          $log.debug "#{log_header} returned from MiqThreadCtl.exitHold"

          # If heartbeats are alive, try sending a "shutdown" heartbeat to the server
          if heartbeat_alive?
            $log.debug "#{log_header} sending exit heartbeat"
            MiqThreadCtl << Thread.new {send_heartbeat(getHostId(nil), {:timeout=>10})}
          else
            $log.debug "#{log_header} skipping exit heartbeat since last heartbeat failed."
          end

          # At this point if there are external processes running in the queues, stop the processes.
          shutdown_worker_queues()
          stop_external_processes()

          pc = PlatformConfig.new(@cfg)
          if restart
            $log.debug "miqChangeAgentConfig: calling PlatformConfig.restart_daemon"
            pc.restart_daemon
            $log.debug "miqChangeAgentConfig: returned from PlatformConfig.restart_daemon"
          end

          # Run block passed in after the threads have stopped.
          yield(pc) if block_given?
            
          $log.debug "#{log_header} calling PlatformConfig.stopping"
          pc.stopping
          $log.debug "#{log_header} returned from PlatformConfig.stopping"

          $log.debug "#{log_header} quiescing threads"
          MiqThreadCtl.quiesceWait
          $log.debug "#{log_header} threads quiesced"
        end
      rescue StandardError, Psych::SyntaxError => err
        # TODO: Remove the Psych::SyntaxError once we're on a ruby where
        # this error inherits from StandardError instead of SyntaxError.
        # It has been fixed but not yet released, see: https://github.com/tenderlove/psych/issues/23
        $log.error "#{log_header} [#{err}]"
        $log.debug "#{log_header} [#{err.backtrace}]"
      ensure
        $log.debug "#{log_header} calling MiqThreadCtl.exitRelease"
        MiqThreadCtl.exitRelease
        $log.debug "#{log_header} returned from MiqThreadCtl.exitRelease"
          
        $log.info "#{log_header} completed."
      end
    end

    def register_external_process(name, pid, klass=nil)
      @cfg.external_processes ||= []
      @cfg.external_processes << ph = {:name=>name, :pid=>pid, :class_name=>klass.name.to_s}
      updateHostConfig()
      return ph
    end

    def stop_external_processes()
      @cfg.external_processes ||= []
      @cfg.external_processes.delete_if do |pinfo|
        begin
          process = MiqProcess.processInfo(pinfo[:pid])
          if process.length > 1
            if pinfo[:class].blank?
              Process.kill(9, pinfo[:pid])
            else
              Object.const_get(pinfo[:class_name]).stop_process(pinfo)
            end
          end
        rescue => err
          $log.error "#{err}\n#{err.backtrace.join("\n")}"
        end
        true
      end
      updateHostConfig()
    end

    private
    def getRValue(value)
      value =~ /=/
      return value unless $'
      $'.strip.downcase
    end

    def run_action (vmName, vm_uuid=nil, x=nil)
      begin
        yield vmName
      rescue  => e
        errMsg = e
      ensure
        sendVMState(vmName, vm_uuid)
      end
      raise e unless e.nil?
    end

    def sendVMState(vmName, vm_uuid, queue=@shortTask)
      begin
        vmState = miqGetVMState(vmName)
        queue.add(["sendvmstate", vmName, vmState, vm_uuid])
      rescue Timeout::Error, StandardError => e
        $log.error "#{print_hex_pid(nil)} sendVMState Command Error: [#{e.to_s}]"
      end
    end

    def process_settings(ns)
      $log.info "New Settings [#{ns.inspect}]"
      config = OpenStruct.new(@cfg.marshal_dump.merge(ns))

      # Apply heartbeat_frequency and log level settings immediately
      if @cfg.heartbeat_frequency != config.heartbeat_frequency
        $log.debug "heartbeat frequency changed to [#{config.heartbeat_frequency}] from [#{@cfg.heartbeat_frequency}]"
        @cfg.heartbeat_frequency = config.heartbeat_frequency
      end
      if @cfg.log[:level].downcase != config.log[:level].downcase
        $log.debug "Log Level changed to [#{config.log[:level]}] from [#{@cfg.log[:level]}]"
        $log.level = eval('Log4r::' + config.log[:level].upcase)
      end

      MiqHostConfig.writeConfig(@cfg = config)
    end

    def print_hex_pid(pid)
      return sprintf("pid:[%04X]", pid) unless pid.nil?
      ""
    end

    def shutdown_worker_queues()
        [@longTask, @shortTask].each {|q| q.shutdown}
    end

  end # end class

end # end module
