require 'miq-xml'
require 'xmldata_helper'
require 'yaml'

module MiqservicesOps
  WS_TIMEOUT = 60

  def save_vmmetadata(vmId, xmlFile, type, jobid=nil)
    begin
      Timeout::timeout(WS_TIMEOUT) do
        $log.info "MIQ(save_vmmetadata): vm [#{vmId}],  job [#{jobid}] enter"

        # If we get a job id use that to lookup the vm
        unless jobid.blank?
          job = Job.find(:first, :conditions => ["guid = ?", jobid], :select => "target_id")
          vm = VmOrTemplate.find_by_id(job.target_id) if job
        end

        vm = VmOrTemplate.find_by_guid(vmId) if vm.nil?

        if vm
          $log.info "MIQ(save_vmmetadata): vm [#{vmId}] found vm object id [#{vm.id}], job [#{jobid}]"
          MiqQueue.put(:target_id => vm.id, :class_name => "VmOrTemplate", :method_name => "save_metadata", :data => Marshal.dump([xmlFile, type]), :task_id => jobid, :zone => vm.my_zone, :role => "smartstate")
          $log.info "MIQ(save_vmmetadata): vm [#{vmId}] data put on queue, job [#{jobid}]"
        else
          errMsg = "No VM found for id [#{vmId}], metadata will be discarded, job [#{jobid}]"
          errStatus = "error"
          $log.error "MIQ(save_vmmetadata): job [#{jobid}]" + errMsg
          MiqQueue.put(:class_name => "Job", :method_name => "signal_by_taskid", :args => [jobid, :error, errMsg, errStatus], :task_id => jobid, :zone => MiqServer.my_zone, :role => "smartstate")
          return false
        end
      end
    rescue Exception => err
      $log.log_backtrace(err)
      MiqservicesOps.reconnect_to_db
      return false
    end
    true
  end

  def agent_job_state(jobid, state, message=nil)
    $log.info "MIQ(agent_job_state): jobid: [#{jobid}] starting"
    begin
      Timeout::timeout(WS_TIMEOUT) do
        MiqQueue.put(:class_name => "Job", :method_name => "agent_state_update_queue", :args => [jobid, state, message], :task_id => "agent_job_state_#{Time.now.to_i}", :zone => MiqServer.my_zone, :role => "smartstate")
        return true
      end
    rescue Exception => err
      $log.log_backtrace(err)
      MiqservicesOps.reconnect_to_db
      return false
    end
  end

  def task_update(task_id, state, status, message)
    $log.info "MIQ(task_state_update): task_id: [#{task_id}] starting"
    begin
      Timeout::timeout(WS_TIMEOUT) do
        task = MiqTask.find_by_id(task_id)
        unless task.nil?
          task.update_status(state, status, message)
        else
          $log.warn "MIQ(task_update): task_id: [#{task_id}] not found"
        end
        return true
      end
    rescue Exception => err
      $log.log_backtrace(err)
      MiqservicesOps.reconnect_to_db
      return false
    end
  end

  def start_update(vmId)
    begin
      return false if vmId.blank?
      Timeout::timeout(WS_TIMEOUT) do
        vm = VmOrTemplate.find_by_guid(vmId)
        return false if vm.busy
        vm.busy = true
        vm.save!
      end
    rescue Exception => err
      $log.log_backtrace(err)
      MiqservicesOps.reconnect_to_db
      false
    end
    true
  end

  def end_update(vmId)
    begin
      return false if vmId.blank?
      Timeout::timeout(WS_TIMEOUT) do
        vm = VmOrTemplate.find_by_guid(vmId)
        vm.busy = false
        vm.save!
      end
    rescue Exception => err
      $log.log_backtrace(err)
      MiqservicesOps.reconnect_to_db
      false
    end
    true
  end

  def save_hostmetadata(hostId, xmlFile, type)
    begin
      Timeout::timeout(WS_TIMEOUT) do
        $log.info "MIQ(save_hostmetadata): for host [#{hostId}]"
        host = Host.find_by_guid(hostId)
        MiqQueue.put(
          :target_id => host.id,
          :class_name => "Host",
          :method_name => "save_metadata",
          :data => [xmlFile, type],
          :priority => MiqQueue::HIGH_PRIORITY
        )
        $log.info "MIQ(save_hostmetadata): for host [#{hostId}] host queued"
      end
    rescue Exception => err
      $log.log_backtrace(err)
      MiqservicesOps.reconnect_to_db
      return false
    end
    true
  end

  def host_heartbeat(hostId, xmlFile, type)
    ret = {}
    begin
      Timeout::timeout(WS_TIMEOUT) do
        $log.info "MIQ(host_heartbeat): host heartbeat starting for GUID:[#{hostId}]"
        host = Host.find_by_guid(hostId)

        if host && host.miq_proxy
          $log.debug "MIQ(host_heartbeat): HostId id [#{hostId}]"
          ret = host.miq_proxy.heartbeat(xmlFile, type)
        else
          # If the host is not found by id then we need to send back
          # an error message and action details.
          errMsg = "No proxy found for id [#{hostId}]"
          $log.error "MIQ(host_heartbeat): " + errMsg
          ret = {
            :server_error => true,
            :server_message => errMsg,
            :host_action => "stop",
          }
        end
      end
    rescue Exception => err
      # In case of an unhandled error on the server side, tell
      # the host to retry after a heartbeat sleep cycle.
      $log.log_backtrace(err)
      MiqservicesOps.reconnect_to_db
      ret = {
        :server_error => true,
        :server_message => err.to_s,
        :host_action => "retry"
      }
    end

    # Update the return hash with current time and vmdb build number
    ret.merge!({:server_time=>Time.now.utc.iso8601, :server_build=>VMDB::Config.BUILD}) if (ret.class == Hash)

    return YAML.dump(ret)
  end

  def vm_status_update(vmId, vmStatus)
    begin
      Timeout::timeout(WS_TIMEOUT) do
        vm = VmOrTemplate.find_by_guid(vmId)
        return unless vm
        vm.state = vmStatus
        vm.save
      end
    rescue Exception => err
      $log.log_backtrace(err)
      MiqservicesOps.reconnect_to_db
      return false
    end
    true
  end

  def agent_unregister(proxy_guid, message)
    begin
      Timeout::timeout(WS_TIMEOUT) do
        host = Host.find_by_guid(proxy_guid)
        return false if host.nil?

        miq_proxy = host.miq_proxy
        if miq_proxy
          MiqProxy.destroy(miq_proxy.id)
          $log.info("MIQ(agent_unregister): deleting miq_proxy, guid #{proxy_guid}, message [#{message}]")
          return true
        else
          $log.info("MIQ(agent_unregister): could not find miq_proxy, guid #{proxy_guid}, cannot unregister the agent")
          return false
        end
      end
    rescue Exception => err
      $log.log_backtrace(err)
      MiqservicesOps.reconnect_to_db
      return false
    end
  end

  def agent_config(hostId, config)
    ret = nil
    $log.info "MIQ(agent_config): starting agent_config for [#{hostId}]"
    begin
      Timeout::timeout(WS_TIMEOUT) do
        host = Host.find_by_guid(hostId)
        if host && host.miq_proxy
          $log.debug "MIQ(agent_config): Found host id [#{host.id}]"
          agentSettings = YAML.load(MIQEncode.decode(config))
          ret = host.miq_proxy.agent_config(agentSettings)
        else
          # If the host is not found by id then we need to send back
          # an error message and action details.
          errMsg = "No host found for id [#{hostId}]"
          $log.error "MIQ(agent_config): " + errMsg
          ret = {
            :server_error => true,
            :server_message => errMsg,
            :host_action => "reset_hostid",
          }
        end
      end
    rescue Exception => err
      # In case of an unhandled error on the server side, tell
      # the host to retry after a heartbeat sleep cycle.
      $log.log_backtrace(err)
      MiqservicesOps.reconnect_to_db
      ret = {
        :server_error => true,
        :server_message => err.to_s,
        :host_action => "retry"
      }
    end

    return YAML.dump(ret)
  end

  def agent_register(xmlFile)
    ret = false
    begin
      Timeout::timeout(WS_TIMEOUT) do
        $log.info "MIQ(agent_register): Starting"
        ret = Host.self_register(MiqXml.load(xmlFile))
      end
    rescue Exception => err
      $log.log_backtrace(err)
      MiqservicesOps.reconnect_to_db
    end
    return YAML.dump(ret)
  end

  def register_vm(nm, loc, vndr)
    begin
      Timeout::timeout(WS_TIMEOUT) do
        vm = VmOrTemplate.new(:name => nm, :location => loc, :vendor => vndr)
        vm.save!
        return(@vm.id)
      end
    rescue Exception => err
      $log.log_backtrace(err)
      MiqservicesOps.reconnect_to_db
    end
  end

  def test_statemachine(jobId, signal, data=nil)
    begin
      $log.info "MIQ(test_statemachine): job [#{jobId}], signal [#{signal}]"
      job = Job.find_by_guid(jobId)
      $log.info "MIQ(test_statemachine): job [#{jobId}] found job object id [#{job.id}]"
      unless data.nil?
        job.signal(signal.to_sym, data)
        # job.signal_process(signal.to_sym, data)
      else
        job.signal(signal.to_sym)
        # job.signal_process(signal.to_sym)
      end
    rescue => err
      $log.log_backtrace(err)
      return false
    end
    true
  end

  def policy_check_vm(vmId, xmlFile)
    $log.info "MIQ(policy_check_vm): VmId:[#{vmId}]"
    ret, reason = false, "unknown"
    begin
      Timeout::timeout(WS_TIMEOUT) do
        begin
          vm = VmOrTemplate.find_by_guid(vmId)
          # Policy check is so outdated it doesn't even exist in the Vm model anymore.
          # TODO: Re-implement based on new policy routines if still viable.
          #ret, reason = vm.policy_check(xmlFile)
          ret, reason = true, "OK"
        rescue
          ret, reason = false, $!.to_s
        end
      end
    rescue Exception => err
      $log.log_backtrace(err)
      MiqservicesOps.reconnect_to_db
      false
    ensure
      return [ret, reason].inspect
    end

    # If we get here return false
    return [false, reason].inspect
  end

  def start_service(service, userid, time)
    begin
      Timeout::timeout(WS_TIMEOUT) do
        $log.info("MIQ(MiqservicesOps.start_service) Audit: req: <start_service>, user: <#{userid}>, service: <#{service}>, when: <#{time}>")
        svc = Service.find_by_name(service)
        return false if svc == nil

        MiqQueue.put(:target_id => svc.id, :class_name => "Service", :method_name => "msg_handler", :data => "service")

        return true
      end
    rescue Exception => err
      $log.log_backtrace(err)
      MiqservicesOps.reconnect_to_db
      return false
    end
  end

  def save_xmldata(hostId, xmlFile)
    begin
      Timeout::timeout(WS_TIMEOUT) do
        $log.info "MIQ(save_xmldata): request received from host id: #{hostId}"
        doc = MiqXml.decode(xmlFile)
        $log.debug "MIQ(save_xmldata): doc:\n#{doc}"
        doctype = doc.root.name.downcase
        $log.info "MIQ(save_xmldata): recieved document: #{doctype}"
        if XmlData.respond_to?(doctype)
          XmlData.send(doctype, hostId, doc.to_s)
        else
          raise "\"#{doctype}\" is not supported by this web service."
        end
      end
    rescue Exception => err
      $log.log_backtrace(err)
      MiqservicesOps.reconnect_to_db
      return false
    end
    true
  end

  def queue_async_response(queue_parms, data)
    queue_parms = YAML.load(MIQEncode.decode(queue_parms))
    queue_parms.merge!(:args => [BinaryBlob.create(:binary => MIQEncode.decode(data)).id])
    MiqQueue.put(queue_parms)
    return true
  end

  def miq_ping(data)
    $log.info "MIQ(miq_ping): enter"
    t0 = Time.now
    $log.info "MIQ(miq_ping): data: #{data}"
    $log.info "MIQ(miq_ping): exit, elapsed time [#{Time.now - t0}] seconds"
    true
  end

  # def test_ws
  #   $log.info "MIQ(vm_list): enter"
  #   $log.info "MIQ(vm_list): type: #{type}"
  #   t0 = Time.now
  #   result = VmOrTemplate.find(:all).collect {|v| [v.guid, v.name]}
  #   # result = VmOrTemplate.find(:all).collect {|v| {:id => v.guid, :name => v.name}}
  #   result
  # end

  def self.reconnect_to_db
    log_header = "MIQ(MiqservicesOps.reconnect_to_db)"
    begin
      $log.info("#{log_header} Reconnecting to database after error...")
      ActiveRecord::Base.connection.reconnect!
      $log.info("#{log_header} Reconnecting to database after error...Successful")
    rescue Exception => err
      $log.error("#{log_header} Error during reconnect: #{err.message}")
    end
  end
end
