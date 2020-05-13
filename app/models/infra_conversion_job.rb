class InfraConversionJob < Job
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
      :initializing                         => {'initialize' => 'waiting_to_start'},
      :start                                => {'waiting_to_start' => 'started'},
      :start_precopying_disks               => {'started' => 'precopying_disks'},
      :poll_precopying_disks                => {'precopying_disks' => 'precopying_disks'},
      :pause_disks_precopy                  => {'precopying_disks' => 'pausing_disks_precopy'},
      :poll_pause_disks_precopy_complete    => {'pausing_disks_precopy' => 'pausing_disks_precopy'},
      :wait_for_ip_address                  => {
        'started'                => 'waiting_for_ip_address',
        'pausing_disks_precopy'  => 'waiting_for_ip_address',
        'powering_on_vm'         => 'waiting_for_ip_address',
        'waiting_for_ip_address' => 'waiting_for_ip_address'
      },
      :run_migration_playbook               => {'waiting_for_ip_address' => 'running_migration_playbook'},
      :poll_run_migration_playbook_complete => {'running_migration_playbook' => 'running_migration_playbook'},
      :shutdown_vm                          => {'running_migration_playbook' => 'shutting_down_vm' },
      :poll_shutdown_vm_complete            => {'shutting_down_vm' => 'shutting_down_vm'},
      :transform_vm                         => {'shutting_down_vm' => 'transforming_vm'},
      :poll_transform_vm_complete           => {'transforming_vm' => 'transforming_vm'},
      :inventory_refresh                    => {'transforming_vm' => 'waiting_for_inventory_refresh'},
      :poll_inventory_refresh_complete      => {'waiting_for_inventory_refresh' => 'waiting_for_inventory_refresh'},
      :apply_right_sizing                   => {'waiting_for_inventory_refresh' => 'applying_right_sizing'},
      :restore_vm_attributes                => {'applying_right_sizing' => 'restoring_vm_attributes'},
      :power_on_vm                          => {
        'restoring_vm_attributes' => 'powering_on_vm',
        'aborting_virtv2v'        => 'powering_on_vm'
      },
      :poll_power_on_vm_complete            => {'powering_on_vm' => 'powering_on_vm'},
      :mark_vm_migrated                     => {
        'powering_on_vm'             => 'marking_vm_migrated',
        'running_migration_playbook' => 'marking_vm_migrated'
      },
      :poll_automate_state_machine          => {
        'powering_on_vm'      => 'running_in_automate',
        'marking_vm_migrated' => 'running_in_automate',
        'running_in_automate' => 'running_in_automate'
      },
      :finish                               => {'*'                => 'finished'},
      :abort_job                            => {'*'                => 'aborting'},
      :cancel                               => {'*'                => 'canceling'},
      :abort_virtv2v                        => {
        '*'                => 'aborting_virtv2v',
        'aborting_virtv2v' => 'aborting_virtv2v'
      },
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
      :precopying_disks              => {
        :description => 'Precopying disks',
        :max_retries => 36.hours / state_retry_interval
      },
      :pausing_disks_precopy         => {
        :description => 'Pausing disks precopy',
        :max_retries => 36.hours / state_retry_interval
      },
      :waiting_for_ip_address        => {
        :description => 'Waiting for VM IP address',
        :weight      => 2,
        :max_retries => 1.hour / state_retry_interval
      },
      :running_migration_playbook    => {
        :description => "Running #{migration_phase}-migration playbook",
        :weight      => 15,
        :max_retries => 6.hours / state_retry_interval
      },
      :shutting_down_vm              => {
        :description => "Shutting down virtual machine",
        :weight      => 2,
        :max_retries => 15.minutes / state_retry_interval
      },
      :transforming_vm               => {
        :description => "Converting disks",
        :weight      => 60,
        :max_retries => 1.day / state_retry_interval
      },
      :waiting_for_inventory_refresh => {
        :description => "Identify destination VM",
        :weight      => 1,
        :max_retries => 1.hour / state_retry_interval
      },
      :applying_right_sizing         => {
        :description => "Apply Right-Sizing Recommendation",
        :weight      => 1
      },
      :restoring_vm_attributes       => {
        :description => "Restore VM Attributes",
        :weight      => 1
      },
      :powering_on_vm                => {
        :description => "Power on virtual machine",
        :weight      => 2,
        :max_retries => 15.minutes / state_retry_interval
      },
      :marking_vm_migrated           => {
        :description => "Virtual machine successfully migrated",
        :weight      => 1
      },
      :aborting_virtv2v              => {
        :description => "Abort virt-v2v operation",
        :max_retries => 1.minute / state_retry_interval
      },
      :running_in_automate           => {
        :max_retries => 1.hour / state_retry_interval
      }
    }
  end

  # --- Override Job methods to handle cancelation properly  --- #

  def self.current_job_timeout(_timeout_adjustment = 1)
    36.hours
  end

  # ---           Job relationships helper methods           --- #

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
    @destination_vm ||= migration_task.destination
  end

  def destination_vm_ems_ref(uuid)
    send("destination_vm_ems_ref_#{migration_task.destination_ems.emstype}", uuid)
  end

  def destination_vm_ems_ref_rhevm(uuid)
    "/api/vms/#{uuid}"
  end

  def destination_vm_ems_ref_openstack(uuid)
    uuid
  end

  def target_vm
    return @target_vm = source_vm if migration_phase == 'pre' || migration_task.canceling?
    return @target_vm = destination_vm if migration_phase == 'post'
  end

  # ---           State transition helper methods            --- #

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

  def task_progress
    migration_task.options[:progress] || {:current_state => state, :status => "ok", :percent => 0.0, :states => {}}
  end

  def update_migration_task_progress(state_phase, state_progress = nil)
    progress = task_progress
    return if progress[:status] == "error"
    state_hash = send(state_phase, progress[:states][state.to_sym], state_progress)
    progress[:states][state.to_sym] = state_hash
    if state_phase == :on_entry
      progress[:current_state] = state
      progress[:current_description] = state_settings[state.to_sym][:description] if state_settings[state.to_sym][:description].present?
    end
    progress[:percent] = progress[:states].map { |k, v| v[:percent] * (state_settings[k.to_sym][:weight] || 0) / 100.0 }.inject(0) { |sum, x| sum + x }
    migration_task.update_transformation_progress(progress)
    abort_conversion('Migration cancelation requested', 'ok') if migration_task.cancel_requested?
  end

  # Temporary method to allow switching from InfraConversionJob to Automate.
  # In Automate, another method waits for workflow_runner to be 'automate'.
  def handover_to_automate
    if migration_task.canceling?
      migration_task.canceled
      queue_signal(:abort_job)
    end

    migration_task.update_options(:workflow_runner => 'automate')
  end

  def abort_conversion(message, status)
    _log.error("Aborting conversion: #{message}")
    migration_task.canceling
    progress = task_progress
    progress[:current_description] = "Migration failed: #{message}. Cancelling"
    progress[:status] = status
    progress[:states][state.to_sym] = {} if state == 'waiting_to_start'
    migration_task.update_options(:progress => progress)
    queue_signal(:abort_virtv2v)
  end

  def polling_timeout
    return false if state_settings[state.to_sym][:max_retries].nil?

    retries = "retries_#{state}".to_sym
    context[retries] = (context[retries] || 0) + 1
    context[retries] > state_settings[state.to_sym][:max_retries]
  end

  def queue_signal(*args, deliver_on: nil)
    super(*args, :role => "ems_operations", :deliver_on => deliver_on, :server_guid => MiqServer.my_server.guid)
  end

  def prep_message(contents)
    "MiqRequestTask id=#{migration_task.id}, InfraConversionJob id=#{id}. #{contents}"
  end

  # ---              Functional helper methods               --- #

  def apply_right_sizing_cpu(mode)
    destination_vm.set_number_of_cpus(source_vm.send("#{mode}_recommended_vcpus"))
  end

  def apply_right_sizing_memory(mode)
    destination_vm.set_memory(source_vm.send("#{mode}_recommended_mem"))
  end

  # --- Methods that implement the state machine transitions --- #

  # This transition simply allows to officially mark the task as migrating.
  # Temporarily, it also hands over to Automate.
  def start
    migration_task.update!(:state => 'migrate')
    migration_task.update_options(:migration_phase => 'pre')
    migration_task.warm_migration? ? queue_signal(:start_precopying_disks) : queue_signal(:wait_for_ip_address)
  end

  def start_precopying_disks
    update_migration_task_progress(:on_entry)
    migration_task.run_conversion
    queue_signal(:poll_precopying_disks, :deliver_on => Time.now.utc + state_retry_interval)
  rescue => error
    update_migration_task_progress(:on_error)
    abort_conversion(error.message, 'error')
  end

  def poll_precopying_disks
    update_migration_task_progress(:on_entry)
    return abort_conversion('Precopying disks timed out', 'error') if polling_timeout

    migration_task.get_conversion_state

    unless migration_task.miq_request.options[:cutover_datetime].present? && migration_task.miq_request.options[:cutover_datetime] < Time.now.utc
      update_migration_task_progress(:on_retry)
      return queue_signal(:poll_precopying_disks, :deliver_on => Time.now.utc + state_retry_interval)
    end

    update_migration_task_progress(:on_exit)
    queue_signal(:pause_disks_precopy)
  rescue => error
    update_migration_task_progress(:on_error)
    abort_conversion(error.message, 'error')
  end

  def pause_disks_precopy
    update_migration_task_progress(:on_entry)
    migration_task.pause_disks_precopy
    queue_signal(:poll_pause_disks_precopy_complete, :deliver_on => Time.now.utc + state_retry_interval)
  rescue => error
    update_migration_task_progress(:on_error)
    abort_conversion(error.message, 'error')
  end

  def poll_pause_disks_precopy_complete
    update_migration_task_progress(:on_entry)
    return abort_conversion('Pausing disks precopy timed out', 'error') if polling_timeout

    migration_task.get_conversion_state
    unless migration_task.options[:virtv2v_status] == 'paused'
      update_migration_task_progress(:on_retry)
      return queue_signal(:poll_pause_disks_precopy_complete, :deliver_on => Time.now.utc + state_retry_interval)
    end

    update_migration_task_progress(:on_exit)
    queue_signal(:wait_for_ip_address)
  rescue => error
    update_migration_task_progress(:on_error)
    abort_conversion(error.message, 'error')
  end

  def wait_for_ip_address
    update_migration_task_progress(:on_entry)
    return abort_conversion('Waiting for IP address timed out', 'error') if polling_timeout

    # If the target VM is powered off, we won't get an IP address, so no need to wait.
    # We don't block powered off VMs, because the playbook could still be relevant.
    if target_vm.power_state == 'on'
      # If the source VM didn't report IP addresses during pre-flight check, there's no need to wait.
      # We don't block VMs with no IP address, because the playbook could still be relevant.
      unless migration_task.options[:source_vm_ipaddresses].empty?
        # The IP address is used only for pre and post-migration playbooks.
        # If no playbook is expected to run, we don't need to wait for the IP address.
        service_template = migration_task.send("#{migration_phase}_ansible_playbook_service_template")
        if target_vm.ipaddresses.empty? && service_template.present?
          update_migration_task_progress(:on_retry)
          return queue_signal(:wait_for_ip_address)
        end
      end
    end

    update_migration_task_progress(:on_exit)
    queue_signal(:run_migration_playbook)
  rescue => error
    update_migration_task_progress(:on_error)
    abort_conversion(error.message, 'error')
  end

  def run_migration_playbook
    update_migration_task_progress(:on_entry)
    service_template = migration_task.send("#{migration_phase}_ansible_playbook_service_template")
    unless service_template.nil?
      user_id = User.find_by(:userid => migration_task.userid).id
      service_dialog_options = {
        :credential => service_template.config_info[:provision][:credential_id],
        :hosts      => target_vm.ipaddresses.first || service_template.config_info[:provision][:hosts]
      }
      migration_task.update_options("#{migration_phase}_migration_playbook_service_request_id".to_sym => service_template.provision_request(user_id, service_dialog_options).id)
      update_migration_task_progress(:on_exit)
      return queue_signal(:poll_run_migration_playbook_complete, :deliver_on => Time.now.utc + state_retry_interval)
    end

    update_migration_task_progress(:on_exit)
    return queue_signal(:shutdown_vm) if migration_phase == 'pre'

    queue_signal(:mark_vm_migrated)
  rescue => error
    update_migration_task_progress(:on_error)
    return abort_conversion(error.message, 'error') if migration_phase == 'pre'

    queue_signal(:mark_vm_migrated)
  end

  def poll_run_migration_playbook_complete
    update_migration_task_progress(:on_entry)
    return abort_conversion('Running migration playbook timed out', 'error') if polling_timeout

    service_request = ServiceTemplateProvisionRequest.find(migration_task.options["#{migration_phase}_migration_playbook_service_request_id".to_sym])
    playbooks_status = migration_task.get_option(:playbooks) || {}
    playbooks_status[migration_phase] = { :job_state => service_request.request_state }
    migration_task.update_options(:playbooks => playbooks_status)

    if service_request.request_state == 'finished'
      playbooks_status[migration_phase][:job_status] = service_request.status
      playbooks_status[migration_phase][:job_id] = service_request.miq_request_tasks.first.destination.service_resources.first.resource.id
      migration_task.update_options(:playbooks => playbooks_status)
      raise "Ansible playbook has failed (migration_phase=#{migration_phase})" if service_request.status == 'Error' && migration_phase == 'pre'

      update_migration_task_progress(:on_exit)
      return queue_signal(:shutdown_vm) if migration_phase == 'pre'
      return queue_signal(:mark_vm_migrated)
    end

    update_migration_task_progress(:on_retry)
    queue_signal(:poll_run_migration_playbook_complete, :deliver_on => Time.now.utc + state_retry_interval)
  rescue => error
    update_migration_task_progress(:on_error)
    return abort_conversion(error.message, 'error') if migration_phase == 'pre'

    queue_signal(:mark_vm_migrated)
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
    queue_signal(:transform_vm)
  rescue => error
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
  rescue => error
    update_migration_task_progress(:on_error)
    abort_conversion(error.message, 'error')
  end

  def transform_vm
    update_migration_task_progress(:on_entry)
    if migration_task.warm_migration?
      migration_task.cutover
      migration_task.unpause_disks_precopy
    else
      migration_task.run_conversion
    end
    update_migration_task_progress(:on_exit)
    queue_signal(:poll_transform_vm_complete, :deliver_on => Time.now.utc + state_retry_interval)
  rescue => error
    update_migration_task_progress(:on_error)
    abort_conversion(error.message, 'error')
  end

  def poll_transform_vm_complete
    update_migration_task_progress(:on_entry)
    return abort_conversion('Converting disks timed out', 'error') if polling_timeout

    migration_task.get_conversion_state
    case migration_task.options[:virtv2v_status]
    when 'active'
      unless migration_task.warm_migration?
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
      else
        update_migration_task_progress(:on_retry, :message => 'Warm migration in progress')
      end
      queue_signal(:poll_transform_vm_complete, :deliver_on => Time.now.utc + state_retry_interval)
    when 'failed'
      raise migration_task.options[:virtv2v_message]
    when 'succeeded'
      update_migration_task_progress(:on_exit)
      queue_signal(:inventory_refresh)
    end
  rescue => error
    update_migration_task_progress(:on_error)
    abort_conversion(error.message, 'error')
  end

  def inventory_refresh
    update_migration_task_progress(:on_entry)
    if migration_task.options[:destination_vm_uuid].present?
      target = InventoryRefresh::Target.new(
        :association => :vms,
        :manager_ref => {:ems_ref => destination_vm_ems_ref(migration_task.options[:destination_vm_uuid])},
        :manager     => migration_task.destination_ems
      )
      EmsRefresh.queue_refresh(target)
    end
    update_migration_task_progress(:on_exit)
    queue_signal(:poll_inventory_refresh_complete, :deliver_on => Time.now.utc + state_retry_interval)
  rescue
    update_migration_task_progress(:on_error)
    queue_signal(:poll_inventory_refresh_complete)
  end

  # This methods waits for the destination EMS inventory to refresh.
  # It updates the migration_task.destination relationship with the create VM.
  # We don't force the EMS refresh and rather allow 1 hour to get it.
  def poll_inventory_refresh_complete
    update_migration_task_progress(:on_entry)
    return abort_conversion('Identify destination VM timed out', 'error') if polling_timeout

    destination_vm = Vm.find_by(:name => migration_task.source.name, :ems_id => migration_task.destination_ems.id)
    if destination_vm.nil?
      update_migration_task_progress(:on_retry)
      return queue_signal(:poll_inventory_refresh_complete, :deliver_on => Time.now.utc + state_retry_interval)
    end

    migration_task.update!(:destination => destination_vm)
    migration_task.update_options(:migration_phase => 'post')
    update_migration_task_progress(:on_exit)
    queue_signal(:apply_right_sizing)
  rescue => error
    update_migration_task_progress(:on_error)
    abort_conversion(error.message, 'error')
  end

  def apply_right_sizing
    update_migration_task_progress(:on_entry)

    %i[cpu memory].each do |item|
      right_sizing_mode = migration_task.send("#{item}_right_sizing_mode")
      send("apply_right_sizing_#{item}", right_sizing_mode) if right_sizing_mode.present?
    end

    update_migration_task_progress(:on_exit)
    queue_signal(:restore_vm_attributes)
  rescue
    update_migration_task_progress(:on_error)
    queue_signal(:restore_vm_attributes)
  end

  def restore_vm_attributes
    update_migration_task_progress(:on_entry)

    # Transfer service link to destination VM
    if source_vm.service
      destination_vm.add_to_service(source_vm.service)
      source_vm.direct_service.try(:remove_resource, source_vm)
    end

    # Copy tags and custom attributes from source VM
    source_vm.tags.each do |tag|
      next if tag.name =~ /^\/managed\/folder_path_/

      tag_as_array = tag.name.split('/')
      namespace = tag_as_array.shift
      value = tag_as_array.pop
      category = tag_as_array.join('/')
      destination_vm.tag_add("#{category}/#{value}", :ns => namespace)
    end
    source_vm.miq_custom_keys.each { |ca| destination_vm.miq_custom_set(ca, source_vm.miq_custom_get(ca)) }

    # Copy ownership from source VM
    destination_vm.evm_owner = source_vm.evm_owner if source_vm.present?
    destination_vm.miq_group = source_vm.miq_group if source_vm.miq_group.present?

    # Copy retirement settings from source VM
    destination_vm.retires_on = source_vm.retires_on if source_vm.retires_on.present?
    destination_vm.retirement_warn = source_vm.retirement_warn if source_vm.retirement_warn.present?

    # Save destination_vm in VMDB
    destination_vm.save

    update_migration_task_progress(:on_exit)
    queue_signal(:power_on_vm)
  rescue
    update_migration_task_progress(:on_error)
    queue_signal(:power_on_vm)
  end

  def power_on_vm
    update_migration_task_progress(:on_entry)

    if migration_task.options[:source_vm_power_state] == 'on' && target_vm.power_state != 'on'
      target_vm.start
      update_migration_task_progress(:on_exit)
      return queue_signal(:poll_power_on_vm_complete, :deliver_on => Time.now.utc + state_retry_interval)
    end

    update_migration_task_progress(:on_exit)
    return queue_signal(:wait_for_ip_address) if target_vm.power_state == 'on' && !migration_task.canceling?

    if migration_task.canceling?
      migration_task.canceled
      handover_to_automate
      return queue_signal(:poll_automate_state_machine)
    end

    queue_signal(:mark_vm_migrated)
  rescue
    update_migration_task_progress(:on_error)
    migration_task.canceled if migration_task.canceling?
    queue_signal(:poll_automate_state_machine)
  end

  def poll_power_on_vm_complete
    update_migration_task_progress(:on_entry)
    raise 'Powering on VM timed out' if polling_timeout

    if target_vm.power_state == 'on'
      update_migration_task_progress(:on_exit)
      return queue_signal(:wait_for_ip_address) unless migration_task.canceling?

      migration_task.canceled
      handover_to_automate
      return queue_signal(:poll_automate_state_machine)
    end

    update_migration_task_progress(:on_retry)
    queue_signal(:poll_power_on_vm_complete, :deliver_on => Time.now.utc + state_retry_interval)
  rescue
    update_migration_task_progress(:on_error)
    migration_task.canceled if migration_task.canceling?
    handover_to_automate
    queue_signal(:poll_automate_state_machine)
  end

  def mark_vm_migrated
    update_migration_task_progress(:on_entry)
    migration_task.mark_vm_migrated
    handover_to_automate
    queue_signal(:poll_automate_state_machine)
    update_migration_task_progress(:on_exit)
  end

  def abort_virtv2v
    virtv2v_runs = migration_task.options[:virtv2v_started_on].present? && migration_task.options[:virtv2v_finished_on].nil? && migration_task.options[:virtv2v_wrapper].present?
    return queue_signal(:power_on_vm) unless virtv2v_runs

    if polling_timeout
      migration_task.kill_virtv2v('KILL')
      return queue_signal(:power_on_vm)
    end

    migration_task.kill_virtv2v('TERM') if context["retries_#{state}".to_sym] == 1
    queue_signal(:abort_virtv2v, :deliver_on => Time.now.utc + state_retry_interval)
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
