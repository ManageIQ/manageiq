require 'xmldata_helper'
require 'yaml'

module ScanningOperationsMixin
  include Vmdb::Logging
  WS_TIMEOUT = 60

  def save_metadata_op(xmlFile, type, jobid=nil)
    begin
      Timeout.timeout(WS_TIMEOUT) do # TODO: do we need this timeout?
        _log.info "target [#{guid}],  job [#{jobid}] enter"
        _log.info "target [#{guid}] found target object id [#{id}], job [#{jobid}]"
        MiqQueue.put(
          :target_id   => id,
          :class_name  => self.class.base_class.name,
          :method_name => "save_metadata",
          :data        => Marshal.dump([xmlFile, type]),
          :task_id     => jobid,
          :zone        => my_zone,
          :role        => "smartstate"
        )
        _log.info "target [#{guid}] data put on queue, job [#{jobid}]"
      end
    rescue Exception => err
      _log.log_backtrace(err)
      ScanningOperations.reconnect_to_db
      return false
    end
    true
  end

  def agent_job_state_op(jobid, state, message = nil)
    _log.info "jobid: [#{jobid}] starting"
    begin
      Timeout.timeout(WS_TIMEOUT) do
        MiqQueue.put(
          :class_name  => "Job",
          :method_name => "agent_state_update_queue",
          :args        => [jobid, state, message],
          :task_id     => "agent_job_state_#{Time.now.to_i}",
          :zone        => MiqServer.my_zone,
          :role        => "smartstate"
        )
        return true
      end
    rescue Exception => err
      _log.log_backtrace(err)
      ScanningOperations.reconnect_to_db
      return false
    end
  end

  def task_update_op(task_id, state, status, message)
    _log.info "task_id: [#{task_id}] starting"
    begin
      Timeout.timeout(WS_TIMEOUT) do
        task = MiqTask.find_by_id(task_id)
        if !task.nil?
          task.update_status(state, status, message)
        else
          _log.warn "task_id: [#{task_id}] not found"
        end
        return true
      end
    rescue Exception => err
      _log.log_backtrace(err)
      ScanningOperations.reconnect_to_db
      return false
    end
  end

  def start_update_op(vmId)
    begin
      return false if vmId.blank?
      Timeout.timeout(WS_TIMEOUT) do
        vm = VmOrTemplate.find_by_guid(vmId)
        return false if vm.busy
        vm.busy = true
        vm.save!
      end
    rescue Exception => err
      _log.log_backtrace(err)
      ScanningOperations.reconnect_to_db
      false
    end
    true
  end

  def end_update_op(vmId)
    begin
      return false if vmId.blank?
      Timeout.timeout(WS_TIMEOUT) do
        vm = VmOrTemplate.find_by_guid(vmId)
        vm.busy = false
        vm.save!
      end
    rescue Exception => err
      _log.log_backtrace(err)
      ScanningOperations.reconnect_to_db
      false
    end
    true
  end

  # TODO: still needed?
  def save_hostmetadata(hostId, xmlFile, type)
    begin
      Timeout.timeout(WS_TIMEOUT) do
        _log.info "for host [#{hostId}]"
        host = Host.find_by_guid(hostId)
        MiqQueue.put(
          :target_id   => host.id,
          :class_name  => "Host",
          :method_name => "save_metadata",
          :data        => [xmlFile, type],
          :priority    => MiqQueue::HIGH_PRIORITY
        )
        _log.info "for host [#{hostId}] host queued"
      end
    rescue Exception => err
      _log.log_backtrace(err)
      ScanningOperations.reconnect_to_db
      return false
    end
    true
  end

  def status_update_op(vmId, vmStatus)
    begin
      Timeout.timeout(WS_TIMEOUT) do
        vm = VmOrTemplate.find_by_guid(vmId)
        return unless vm
        vm.state = vmStatus
        vm.save
      end
    rescue Exception => err
      _log.log_backtrace(err)
      ScanningOperations.reconnect_to_db
      return false
    end
    true
  end

  def register_vm(nm, loc, vndr)
    Timeout.timeout(WS_TIMEOUT) do
      vm = VmOrTemplate.new(:name => nm, :location => loc, :vendor => vndr)
      vm.save!
      return(@vm.id)
    end
  rescue Exception => err
    _log.log_backtrace(err)
    ScanningOperations.reconnect_to_db
  end

  def test_statemachine(jobId, signal, data=nil)
    begin
      _log.info "job [#{jobId}], signal [#{signal}]"
      job = Job.find_by_guid(jobId)
      _log.info "job [#{jobId}] found job object id [#{job.id}]"
      if !data.nil?
        job.signal(signal.to_sym, data)
        # job.signal_process(signal.to_sym, data)
      else
        job.signal(signal.to_sym)
        # job.signal_process(signal.to_sym)
      end
    rescue => err
      _log.log_backtrace(err)
      return false
    end
    true
  end

  def policy_check_vm(vmId, xmlFile)
    _log.info "VmId:[#{vmId}]"
    ret, reason = false, "unknown"
    begin
      Timeout.timeout(WS_TIMEOUT) do
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
      _log.log_backtrace(err)
      ScanningOperations.reconnect_to_db
      false
    ensure
      return [ret, reason].inspect
    end

    # If we get here return false
    return [false, reason].inspect
  end

  def start_service(service, userid, time)
    begin
      Timeout.timeout(WS_TIMEOUT) do
        _log.info("Audit: req: <start_service>, user: <#{userid}>, service: <#{service}>, when: <#{time}>")
        svc = Service.find_by_name(service)
        return false if svc.nil?

        MiqQueue.put(:target_id => svc.id, :class_name => "Service", :method_name => "msg_handler", :data => "service")

        return true
      end
    rescue Exception => err
      _log.log_backtrace(err)
      ScanningOperations.reconnect_to_db
      return false
    end
  end

  def save_xmldata(hostId, xmlFile)
    begin
      Timeout.timeout(WS_TIMEOUT) do
        _log.info "request received from host id: #{hostId}"
        doc = MiqXml.decode(xmlFile)
        _log.debug "doc:\n#{doc}"
        doctype = doc.root.name.downcase
        _log.info "recieved document: #{doctype}"
        if XmlData.respond_to?(doctype)
          XmlData.send(doctype, hostId, doc.to_s)
        else
          raise "\"#{doctype}\" is not supported by this web service."
        end
      end
    rescue Exception => err
      _log.log_backtrace(err)
      ScanningOperations.reconnect_to_db
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
    _log.info "enter"
    t0 = Time.now
    _log.info "data: #{data}"
    _log.info "exit, elapsed time [#{Time.now - t0}] seconds"
    true
  end

  def self.reconnect_to_db
    _log.info("Reconnecting to database after error...")
    ActiveRecord::Base.connection.reconnect!
    _log.info("Reconnecting to database after error...Successful")
  rescue Exception => err
    _log.error("Error during reconnect: #{err.message}")
  end
end
