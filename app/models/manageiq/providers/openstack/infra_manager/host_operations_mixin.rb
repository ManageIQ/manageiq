module ManageIQ::Providers::Openstack::InfraManager::HostOperationsMixin
  include Vmdb::Logging

  def ironic_set_power_state_queue(userid = "system",
                                   power_state = "power off",
                                   power_state_text_verb = "Stopping",
                                   power_state_text = "stop",
                                   feature = :host_stop)
    log_target = "#{self.class.name} name: [#{name}], id: [#{id}]"

    task = MiqTask.create(:name => "#{power_state_text_verb} Ironic node '#{name}'", :userid => userid)

    _log.info("#{power_state_text_verb} Ironic node #{log_target}")
    begin
      MiqEvent.raise_evm_job_event(self, :type => power_state_text, :prefix => "request")
    rescue => err
      _log.warn("Error raising request #{power_state_text} for #{log_target}: #{err.message}")
      return
    end

    _log.info("Queuing #{power_state_text} for #{log_target}")
    timeout = (VMDB::Config.new("vmdb").config.fetch_path(feature, :queue_timeout) || 20.minutes).to_i_with_method
    cb = {:class_name  => task.class.name,
          :instance_id => task.id,
          :method_name => :queue_callback_on_exceptions,
          :args        => ['Finished']}
    MiqQueue.put(
      :class_name   => self.class.name,
      :instance_id  => id,
      :args         => [task.id, power_state, power_state_text_verb, power_state_text],
      :method_name  => "ironic_set_power_state",
      :miq_callback => cb,
      :msg_timeout  => timeout,
      :zone         => my_zone
    )
  end

  def ironic_set_power_state(taskid = nil,
                             power_state = "power off",
                             power_state_text_verb = "Stopping",
                             power_state_text = "stop")
    unless taskid.nil?
      task = MiqTask.find_by_id(taskid)
      task.state_active if task
    end

    log_target = "#{self.class.name} name: [#{name}], id: [#{id}]"

    _log.info("#{power_state_text_verb} #{log_target}...")

    task.update_status("Active", "Ok", power_state_text.capitalize) if task

    status = "Fail"
    task_status = "Ok"
    _dummy, t = Benchmark.realtime_block(:total_time) do
      begin
        connection = ext_management_system.openstack_handle.detect_baremetal_service
        response = connection.set_node_power_state(name, power_state)

        if response.status == 202
          status = "Success"
          EmsRefresh.queue_refresh(ext_management_system)
        end
      rescue => err
        task_status = "Error"
        status = err
      end

      begin
        MiqEvent.raise_evm_job_event(self, :type => power_state_text, :suffix => "complete")
      rescue => err
        _log.warn("Error raising complete #{power_state_text} event for #{log_target}: #{err.message}")
      end
    end

    task.update_status("Finished", task_status, "#{power_state_text.capitalize} Complete with #{status}") if task
    _log.info("#{power_state_text_verb} #{log_target}...Complete - Timings: #{t.inspect}")
  end
end
