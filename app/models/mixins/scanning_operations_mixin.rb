require 'yaml'

module ScanningOperationsMixin
  include Vmdb::Logging
  WS_TIMEOUT = 60

  def save_metadata_op(xmlFile, type, jobid = nil)
    begin
      Timeout.timeout(WS_TIMEOUT) do # TODO: do we need this timeout?
        _log.info("target [#{guid}],  job [#{jobid}] enter")
        _log.info("target [#{guid}] found target object id [#{id}], job [#{jobid}]")
        MiqQueue.submit_job(
          :service     => "smartstate",
          :affinity    => ext_management_system,
          :target_id   => id,
          :class_name  => self.class.base_class.name,
          :method_name => "save_metadata",
          :data        => Marshal.dump([xmlFile, type]),
          :task_id     => jobid,
        )
        _log.info("target [#{guid}] data put on queue, job [#{jobid}]")
      end
    rescue Exception => err
      _log.log_backtrace(err)
      ScanningOperations.reconnect_to_db
      return false
    end
    true
  end

  def task_update_op(task_id, state, status, message)
    _log.info("task_id: [#{task_id}] starting")
    begin
      Timeout.timeout(WS_TIMEOUT) do
        task = MiqTask.find_by(:id => task_id)
        if !task.nil?
          task.update_status(state, status, message)
        else
          _log.warn("task_id: [#{task_id}] not found")
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
