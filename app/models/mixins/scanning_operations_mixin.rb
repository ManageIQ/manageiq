require 'xmldata_helper'
require 'yaml'

module ScanningOperationsMixin
  include Vmdb::Logging
  WS_TIMEOUT = 60

  def save_metadata_op(xmlFile, type, jobid = nil)
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
        vm = VmOrTemplate.find_by(:guid => vmId)
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
        vm = VmOrTemplate.find_by(:guid => vmId)
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

  def status_update_op(vmId, vmStatus)
    begin
      Timeout.timeout(WS_TIMEOUT) do
        vm = VmOrTemplate.find_by(:guid => vmId)
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

  # TODO: Use this method above, remove ScanningOperations' version
  def self.reconnect_to_db
    _log.info("Reconnecting to database after error...")
    ActiveRecord::Base.connection.reconnect!
    _log.info("Reconnecting to database after error...Successful")
  rescue Exception => err
    _log.error("Error during reconnect: #{err.message}")
  end
end
