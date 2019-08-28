class InfraConversionJob < Job
  def self.create_job(options)
    super(name, options)
  end

  #
  # State-transition diagram:
  #                              :poll_conversion                         :poll_post_stage
  #    *                          /-------------\                        /---------------\
  #    | :initialize              |             |                        |               |
  #    v               :start     v             |                        v               |
  # waiting_to_start --------> running ------------------------------> post_conversion --/
  #     |                         |                :start_post_stage       |
  #     | :abort_job              | :abort_job                             |
  #     \------------------------>|                                        | :finish
  #                               v                                        |
  #                             aborting --------------------------------->|
  #                                                    :finish             v
  #                                                                    finished
  #
  # TODO: Update this diagram after we've settled on the updated state transitions.

  alias_method :initializing, :dispatch_start
  alias_method :finish,       :process_finished
  alias_method :abort_job,    :process_abort
  alias_method :cancel,       :process_cancel
  alias_method :error,        :process_error

  def load_transitions
    self.state ||= 'initialize'

    {
      :initializing                         => {'initialize'         => 'waiting_to_start'},
      :start                                => {'waiting_to_start'   => 'started'},
      :remove_snapshots                     => {'started'            => 'removing_snapshots'},
      :poll_remove_snapshots_complete       => {'removing_snapshots' => 'removing_snapshots'},
      :wait_for_ip_address                  => {
        'removing_snapshots'     => 'waiting_for_ip_address',
        'waiting_for_ip_address' => 'waiting_for_ip_address'
      },
      :run_migration_playbook               => {'waiting_for_ip_address' => 'running_migration_playbook'},
      :poll_run_migration_playbook_complete => {'running_migration_playbook' => 'running_migration_playbook'},
      :shutdown_vm                          => {'running_migration_playbook' => 'shutting_down_vm' },
      :poll_shutdown_vm_complete            => {'shutting_down_vm' => 'shutting_down_vm'},
      :transform_vm                         => {'shutting_down_vm' => 'transforming_vm'},
      :poll_transform_vm_complete           => {'transforming_vm' => 'transforming_vm'},
      :poll_automate_state_machine          => {
        'transforming_vm'     => 'running_in_automate',
        'running_in_automate' => 'running_in_automate'
      },
      :finish                               => {'*'                => 'finished'},
      :abort_job                            => {'*'                => 'aborting'},
      :cancel                               => {'*'                => 'canceling'},
      :error                                => {'*'                => '*'}
    }
  end

  # Example state:
  #   :state_name => {
  #     :description => 'State description',
  #     :weight      => 30,
  #     :max_retries => 960
  #   }
  def state_settings
    @state_settings ||= {
      :removing_snapshots         => {
        :description => 'Remove snapshosts',
        :weight      => 5,
        :max_retries => 4.hours / state_retry_interval
      },
      :waiting_for_ip_address     => {
        :description => 'Waiting for VM IP address',
        :weight      => 1,
        :max_retries => 1.hour / state_retry_interval
      },
      :running_migration_playbook => {
        :description => "Running #{migration_phase}-migration playbook",
        :weight      => 10,
        :max_retries => 6.hours / state_retry_interval
      },
      :shutting_down_vm           => {
        :description => "Shutting down virtual machine",
        :weight      => 1,
        :max_retries => 15.minutes / state_retry_interval
      },
      :transforming_vm            => {
        :description => "Converting disks",
        :weight      => 60,
        :max_retries => 1.day / state_retry_interval
      },
      :running_in_automate        => {
        :max_retries => 36.hours / state_retry_interval
      }
    }
  end

  def state_retry_interval
    @state_retry_interval ||= Settings.transformation.job.retry_interval || 15.seconds
  end

  def migration_task
    @migration_task ||= target_entity
    # valid states: %w(migrate pending finished active queued)
  end

  def migration_phase
    migration_task.options[:migration_phase]
  end

  def source_vm
    @source_vm ||= migration_task.source
  end

  def destination_vm
    return nil if migration_task.options[:destination_vm_id].nil?

    @destination_vm ||= Vm.find(migration_task.options[:destination_vm_id]).tap do |vm|
      raise "No Vm in VMDB with id #{migration_task.options[:destination_vm_id]}" if vm.nil?
    end
  end

  def target_vm
    return @target_vm = source_vm if migration_phase == 'pre'
    return @target_vm = destination_vm if migration_phase == 'post'
  end

  def on_entry(state_hash, _)
    state_hash || {
      :state       => 'active',
      :status      => 'Ok',
      :description => state_settings[state.to_sym][:description],
      :started_on  => Time.now.utc,
      :percent     => 0.0
    }.compact
  end

  def on_retry(state_hash, state_progress = nil)
    if state_progress.nil?
      state_hash[:percent] = context["retries_#{state}".to_sym].to_f / state_settings[state.to_sym][:max_retries].to_f * 100.0
    else
      state_hash.merge!(state_progress)
    end
    state_hash[:updated_on] = Time.now.utc
    state_hash
  end

  def on_exit(state_hash, _)
    state_hash[:state] = 'finished'
    state_hash[:percent] = 100.0
    state_hash[:updated_on] = Time.now.utc
    state_hash
  end

  def on_error(state_hash, _)
    state_hash[:state] = 'finished'
    state_hash[:status] = 'Error'
    state_hash[:updated_on] = Time.now.utc
    state_hash
  end

  def update_migration_task_progress(state_phase, state_progress = nil)
    progress = migration_task.options[:progress] || { :current_state => state, :percent => 0.0, :states => {} }
    state_hash = send(state_phase, progress[:states][state.to_sym], state_progress)
    progress[:states][state.to_sym] = state_hash
    progress[:current_description] = state_settings[state.to_sym][:description] if state_phase == :on_entry && state_settings[state.to_sym][:description].present?
    progress[:percent] += state_hash[:percent] * state_settings[state.to_sym][:weight] / 100.0 if state_settings[state.to_sym][:weight].present?
    migration_task.update_transformation_progress(progress)
  end

  # Temporary method to allow switching from InfraConversionJob to Automate.
  # In Automate, another method waits for workflow_runner to be 'automate'.
  def handover_to_automate
    migration_task.update_options(:workflow_runner => 'automate')
  end

  def abort_conversion(message, status)
    migration_task.cancel
    queue_signal(:abort_job, message, status)
  end

  def polling_timeout
    return false if state_settings[state.to_sym][:max_retries].nil?

    retries = "retries_#{state}".to_sym
    context[retries] = (context[retries] || 0) + 1
    context[retries] > state_settings[state.to_sym][:max_retries]
  end

  def queue_signal(*args, deliver_on: nil)
    MiqQueue.put(
      :class_name  => self.class.name,
      :method_name => "signal",
      :instance_id => id,
      :role        => "ems_operations",
      :zone        => zone,
      :task_id     => guid,
      :args        => args,
      :deliver_on  => deliver_on
    )
  end

  def prep_message(contents)
    "MiqRequestTask id=#{migration_task.id}, InfraConversionJob id=#{id}. #{contents}"
  end

  def order_ansible_playbook_service
    service_template = migration_task.send("#{migration_phase}_ansible_playbook_service_template")
    return if service_template.nil?

    service_dialog_options = {
      :credentials => service_template.config_info[:provision][:credential_id],
      :hosts       => target_vm.ipaddresses.first || service_template.config_info[:provision][:hosts]
    }
    service_template.provision_request(migration_task.userid.to_i, service_dialog_options)
  end

  # --- Methods that implement the state machine transitions --- #

  # This transition simply allows to officially mark the task as migrating.
  # Temporarily, it also hands over to Automate.
  def start
    migration_task.update!(:state => 'migrate')
    migration_task.update_options(:migration_phase => 'pre')
    queue_signal(:remove_snapshots)
  end

  def remove_snapshots
    update_migration_task_progress(:on_entry)
    if migration_task.source.supports_remove_all_snapshots?
      context[:async_task_id_removing_snapshots] = migration_task.source.remove_all_snapshots_queue(migration_task.userid.to_i)
      update_migration_task_progress(:on_exit)
      return queue_signal(:poll_remove_snapshots_complete, :deliver_on => Time.now.utc + state_retry_interval)
    end

    update_migration_task_progress(:on_exit)
    queue_signal(:wait_for_ip_address)
  rescue StandardError => error
    update_migration_task_progress(:on_error)
    abort_conversion(error.message, 'error')
  end

  def poll_remove_snapshots_complete
    update_migration_task_progress(:on_entry)
    raise 'Removing snapshots timed out' if polling_timeout

    async_task = MiqTask.find(context[:async_task_id_removing_snapshots])

    if async_task.state == MiqTask::STATE_FINISHED
      raise async_task.message unless async_task.status == MiqTask::STATUS_OK

      update_migration_task_progress(:on_exit)
      return queue_signal(:wait_for_ip_address)
    end

    update_migration_task_progress(:on_retry)
    queue_signal(:poll_remove_snapshots_complete, :deliver_on => Time.now.utc + state_retry_interval)
  rescue StandardError => error
    update_migration_task_progress(:on_error)
    abort_conversion(error.message, 'error')
  end

  def wait_for_ip_address
    update_migration_task_progress(:on_entry)
    return abort_conversion('Waiting for IP address timed out', 'error') if polling_timeout

    # If the target VM is powered off, we won't get an IP address, so no need to wait.
    # We don't block powered off VMs, because the playbook could still be relevant.
    if target_vm.power_state == 'on'
      if target_vm.ipaddresses.empty?
        update_migration_task_progress(:on_retry)
        return queue_signal(:wait_for_ip_address)
      end
    end

    update_migration_task_progress(:on_exit)
    queue_signal(:run_migration_playbook)
  rescue StandardError => error
    update_migration_task_progress(:on_error)
    abort_conversion(error.message, 'error')
  end

  def run_migration_playbook
    update_migration_task_progress(:on_entry)
    service_template = migration_task.send("#{migration_phase}_ansible_playbook_service_template")
    unless service_template.nil?
      service_dialog_options = {
        :credentials => service_template.config_info[:provision][:credential_id],
        :hosts       => target_vm.ipaddresses.first || service_template.config_info[:provision][:hosts]
      }
      context["#{migration_phase}_migration_playbook_service_request_id".to_sym] = service_template.provision_request(migration_task.userid.to_i, service_dialog_options).id
      update_migration_task_progress(:on_exit)
      return queue_signal(:poll_run_migration_playbook_complete, :deliver_on => Time.now.utc + state_retry_interval)
    end

    update_migration_task_progress(:on_exit)
    queue_signal(:shutdown_vm)
  rescue StandardError => error
    update_migration_task_progress(:on_error)
    abort_conversion(error.message, 'error')
  end

  def poll_run_migration_playbook_complete
    update_migration_task_progress(:on_entry)
    return abort_conversion('Running migration playbook timed out', 'error') if polling_timeout

    service_request = ServiceTemplateProvisionRequest.find(context["#{migration_phase}_migration_playbook_service_request_id".to_sym])
    playbooks_status = migration_task.get_option(:playbooks) || {}
    playbooks_status[migration_phase] = { :job_state => service_request.request_state }
    migration_task.update_options(:playbooks => playbooks_status)

    if service_request.request_state == 'finished'
      playbooks_status[migration_phase][:job_status] = service_request.status
      playbooks_status[migration_phase][:job_id] = service_request.miq_request_tasks.first.destination.service_resources.first.resource.id
      migration_task.update_options(:playbooks => playbooks_status)
      raise "Ansible playbook has failed (migration_phase=#{migration_phase})" if service_request.status == 'Error' && migration_phase == 'pre'

      update_migration_task_progress(:on_exit)
      return queue_signal(:shutdown_vm)
    end

    update_migration_task_progress(:on_retry)
    queue_signal(:poll_run_migration_playbook_complete, :deliver_on => Time.now.utc + state_retry_interval)
  rescue StandardError => error
    update_migration_task_progress(:on_error)
    abort_conversion(error.message, 'error')
  end

  def shutdown_vm
    update_migration_task_progress(:on_entry)
    unless target_vm.power_state == 'off'
      if target_vm.supports_shutdown_guest?
        target_vm.shutdown_guest
      else
        target_vm.stop
      end
      update_migration_task_progress(:on_exit)
      return queue_signal(:poll_shutdown_vm_complete, :deliver_on => Time.now.utc + state_retry_interval)
    end

    update_migration_task_progress(:on_exit)
    handover_to_automate
    queue_signal(:transform_vm)
  rescue StandardError => error
    update_migration_task_progress(:on_error)
    abort_conversion(error.message, 'error')
  end

  def poll_shutdown_vm_complete
    update_migration_task_progress(:on_entry)
    return abort_conversion('Shutting down VM timed out', 'error') if polling_timeout

    if target_vm.power_state == 'off'
      update_migration_task_progress(:on_exit)
      return queue_signal(:transform_vm)
    end

    update_migration_task_progress(:on_retry)
    queue_signal(:poll_shutdown_vm_complete, :deliver_on => Time.now.utc + state_retry_interval)
  rescue StandardError => error
    update_migration_task_progress(:on_error)
    abort_conversion(error.message, 'error')
  end

  def transform_vm
    update_migration_task_progress(:on_entry)
    migration_task.run_conversion
    update_migration_task_progress(:on_exit)
    queue_signal(:poll_transform_vm_complete, :deliver_on => Time.now.utc + state_retry_interval)
  rescue StandardError => error
    update_migration_task_progress(:on_error)
    abort_conversion(error.message, 'error')
  end

  def poll_transform_vm_complete
    update_migration_task_progress(:on_entry)
    return abort_conversion('Converting disks timed out', 'error') if polling_timeout

    migration_task.get_conversion_state
    case migration_task.options[:virtv2v_status]
    when 'active'
      virtv2v_disks = migration_task.options[:virtv2v_disks]
      converted_disks = virtv2v_disks.reject { |disk| disk[:percent].zero? }
      if converted_disks.empty?
        message = 'Disk transformation is initializing.'
        percent = 1
      else
        percent = 0
        converted_disks.each { |disk| percent += (disk[:percent].to_f * disk[:weight].to_f / 100.0) }
        message = "Converting disk #{converted_disks.length} / #{virtv2v_disks.length} [#{percent.round(2)}%]."
      end
      update_migration_task_progress(:on_retry, :message => message, :percent => percent)
      queue_signal(:poll_transform_vm_complete, :deliver_on => Time.now.utc + state_retry_interval)
    when 'failed'
      raise migration_task.options[:virtv2v_message]
    when 'succeeded'
      update_migration_task_progress(:on_exit)
      handover_to_automate
      queue_signal(:poll_automate_state_machine)
    end
  rescue StandardError => error
    update_migration_task_progress(:on_error)
    abort_conversion(error.message, 'error')
  end

  def poll_automate_state_machine
    return abort_conversion('Polling Automate state machine timed out', 'error') if polling_timeout

    message = "Migration Task vm=#{migration_task.source.name}, state=#{migration_task.state}, status=#{migration_task.status}"
    _log.info(prep_message(message))
    update(:message => message)
    if migration_task.state == 'finished'
      self.status = migration_task.status
      queue_signal(:finish)
    else
      queue_signal(:poll_automate_state_machine, :deliver_on => Time.now.utc + state_retry_interval)
    end
  end
end
