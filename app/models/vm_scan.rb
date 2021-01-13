class VmScan < Job
  #
  # TODO: until we get location/offset read capability for OpenStack
  # image data, OpenStack fleecing is prone to timeout (based on image size).
  # We adjust the queue timeout in server_smart_proxy.rb, but that's not enough,
  # we also need to adjust the job timeout here.
  #
  DEFAULT_TIMEOUT = defined?(RSpec) ? 300 : 3000

  def self.current_job_timeout(timeout_adjustment = 1)
    timeout_adjustment = 1 if defined?(RSpec)
    DEFAULT_TIMEOUT * timeout_adjustment
  end

  def load_transitions
    self.state ||= 'initialize'
    {
      :initializing       => {'initialize'                => 'waiting_to_start'},
      :start              => {'waiting_to_start'          => 'checking_policy'},
      :before_scan        => {'checking_policy'           => 'before_scan'},
      :start_scan         => {'before_scan'               => 'scanning'},
      :after_scan         => {'scanning'                  => 'after_scan'},
      :synchronize        => {'after_scan'                => 'synchronizing'},
      :finish             => {'synchronizing'             => 'finished',
                              'aborting'                  => 'finished'},
      :data               => {'scanning'                  => 'scanning',
                              'synchronizing'             => 'synchronizing',
                              'finished'                  => 'finished'},
      :scan_retry         => {'scanning'                  => 'scanning'},
      :abort_retry        => {'scanning'                  => 'scanning'},
      :abort_job          => {'*'                         => 'aborting'},
      :cancel             => {'*'                         => 'canceling'},
      :error              => {'*'                         => '*'},
    }
  end

  def vm
    @vm ||= VmOrTemplate.find(target_id)
  end

  def call_check_policy
    _log.info("Enter")

    begin
      q_options = {
        :miq_callback => {
          :class_name  => self.class.to_s,
          :instance_id => id,
          :method_name => :check_policy_complete,
          :args        => [MiqServer.my_zone] # Store the zone where the scan job was initiated.
        }
      }
      inputs = {:vm => vm, :host => vm.host}
      MiqEvent.raise_evm_job_event(vm, {:type => "scan", :suffix => "start"}, inputs, q_options)
    rescue => err
      _log.log_backtrace(err)
      signal(:abort, err.message, "error")
    end
  end

  def check_policy_complete(from_zone, status, message, result)
    unless status == 'ok'
      _log.error("Status = #{status}, message = #{message}")
      signal(:abort, message, "error")
      return
    end

    if result.kind_of?(MiqAeEngine::MiqAeWorkspaceRuntime)
      event = result.get_obj_from_path("/")['event_stream']
      data  = event.attributes["full_data"]
      prof_policies = data.fetch_path(:policy, :actions, :assign_scan_profile) if data
      if prof_policies
        scan_profiles = []
        prof_policies.each { |p| scan_profiles += p[:result] unless p[:result].nil? }
        options[:scan_profiles] = scan_profiles unless scan_profiles.blank?
        save
      end
    end

    MiqQueue.put(
      :class_name  => self.class.to_s,
      :instance_id => id,
      :method_name => "signal",
      :args        => [:before_scan],
      :zone        => from_zone,
      :role        => "smartstate"
    )
  end

  def before_scan
    _log.info("Enter")
    log_start_user_event_message
    signal(:start_scan)
  end

  def start_scan
    scanning
    call_scan
  end

  def call_scan
    _log.info("Enter")

    begin
      host = MiqServer.find(miq_server_id)
      # Send down metadata to allow the host to make decisions.
      scan_args = create_scan_args
      options[:ems_list] = scan_args["ems"]
      options[:categories] = vm.scan_profile_categories(scan_args["vmScanProfiles"])

      vm.scan_metadata(options[:categories], "taskid" => jobid, "host" => host, "args" => [YAML.dump(scan_args)])
    rescue Timeout::Error
      message = "timed out attempting to scan, aborting"
      _log.error(message)
      signal(:abort, message, "error")
      return
    rescue => message
      _log.log_backtrace(message)
      signal(:abort, message.message, "error")
    end

    set_status("Scanning for metadata from VM")
  end

  def config_ems_list
    ems_list = vm.ems_host_list
    ems_list['connect_to'] = vm.scan_via_ems? ? 'ems' : 'host'
    ems_list
  end

  def create_scan_args
    scan_args = { 'ems' => config_ems_list }

    # Check if Policy returned scan profiles to use, otherwise use the default profile if available.
    scan_args["vmScanProfiles"] = options[:scan_profiles] || vm.scan_profile_list
    scan_args
  end

  def after_scan
    signal(:synchronize)
  end

  def call_synchronize
    _log.info("Enter")

    begin
      host = MiqServer.find(miq_server_id)
      scan_args = create_scan_args
      options[:categories] = vm.scan_profile_categories(scan_args["vmScanProfiles"])
      vm.sync_metadata(options[:categories],
                       "taskid" => jobid,
                       "host"   => host
                      )
    rescue Timeout::Error
      message = "timed out attempting to synchronize, aborting"
      _log.error(message)
      signal(:abort, message, "error")
      return
    rescue => message
      _log.error(message.to_s)
      signal(:abort, message.message, "error")
      return
    end

    set_status("Synchronizing metadata from VM")
    dispatch_finish # let the dispatcher know that it is ok to start the next job
  end

  def synchronizing
    _log.info(".")
  end

  def scanning
    _log.info(".") if context[:scan_attempted]
    context[:scan_attempted] = true
  end

  def process_data(*args)
    _log.info("starting...")

    data = args.first
    set_status("Processing VM data")

    doc = MiqXml.load(data)
    _log.info("Document=#{doc.root.name.downcase}")

    if doc.root.name.downcase == "summary"
      doc.root.each_element do |s|
        case s.name.downcase
        when "syncmetadata"
          request_docs = []
          all_docs = []
          s.each_element do |e|
            _log.info("Summary XML [#{e}]")
            request_docs << e.attributes['original_filename'] if e.attributes['items_total'] && e.attributes['items_total'].to_i.zero?
            all_docs << e.attributes['original_filename']
          end
          if request_docs.empty? || (request_docs.length != all_docs.length)
            _log.info("sending :finish")

            # Collect any VIM data here
            # TODO: Make this a separate state?
            if vm.respond_to?(:refresh_on_scan)
              begin
                vm.refresh_on_scan
              rescue => err
                _log.error("refreshing data from VIM: #{err.message}")
                _log.log_backtrace(err)
              end

              vm.reload
            end

            # Generate the vm state from the model upon completion
            begin
              vm.save_drift_state unless vm.nil?
            rescue => err
              _log.error("saving VM drift state: #{err.message}")
              _log.log_backtrace(err)
            end
            signal(:finish, "Process completed successfully", "ok")

            begin
              raise _("Unable to find Vm") if vm.nil?
              inputs = {:vm => vm, :host => vm.host}
              MiqEvent.raise_evm_job_event(vm, {:type => "scan", :suffix => "complete"}, inputs)
            rescue => err
              _log.warn("#{err.message}, unable to raise policy event: [vm_scan_complete]")
            end
          else
            message = "scan operation yielded no data. aborting"
            _log.error(message)
            signal(:abort, message, "error")
          end
        when "scanmetadata"
          _log.info("sending :synchronize")
          result = vm.save_scan_history(s.attributes.to_h(false).merge("taskid" => doc.root.attributes["taskid"])) if s.attributes
          if result.status_code == 16 # fatal error on proxy
            signal(:abort_retry, result.message, "error", false)
          else
            signal(:after_scan)
          end
        else
          _log.info("no action taken")
        end
      end
    end
    # got data to process
  end

  def user_event_message(verb)
    "EVM SmartState Analysis #{verb} for VM [#{vm.name}]"
  end

  def start_user_event_message
    user_event_message("initiated")
  end

  def end_user_event_message
    user_event_message("completed")
  end

  def log_start_user_event_message
    log_user_event(start_user_event_message)
  end

  def log_end_user_event_message
    unless options[:end_message_sent]
      log_user_event(end_user_event_message)
      options[:end_message_sent] = true
    end
  end

  def process_cancel(*args)
    options = args.first || {}
    _log.info("job canceling, #{options[:message]}")
    super
  end

  # Logic to determine if we should abort the job or retry the scan depending on the error
  def call_abort_retry(*args)
    message, _status, skip_retry = args
    if message.to_s.include?("Could not find VM: [") && options[:scan_count].to_i.zero?
      # We may need to skip calling the retry if this method is called twice.
      return if skip_retry == true
      options[:scan_count] = options[:scan_count].to_i + 1
      EmsRefresh.refresh(vm)
      vm.reload
      _log.info("Retrying VM scan for [#{vm.name}] due to error [#{message}]")
      signal(:scan_retry)
    else
      signal(:abort, *args[0, 2])
    end
  end

  def process_abort(*args)
    begin
      if vm
        inputs = {:vm => vm, :host => vm.host}
        MiqEvent.raise_evm_job_event(vm, {:type => "scan", :suffix => "abort"}, inputs)
      end
    rescue => err
      _log.log_backtrace(err)
    end

    super
  end

  # Signals
  def data(*args)
    process_data(*args)
    if state == 'scanning'
      scanning
    elsif state == 'synchronizing'
      synchronizing
    end
  end

  def scan_retry
    scanning
    call_scan
  end

  def abort_retry(*args)
    scanning
    call_abort_retry(*args)
  end

  # All other signals
  alias_method :initializing,       :dispatch_start
  alias_method :start,              :call_check_policy
  alias_method :synchronize,        :call_synchronize
  alias_method :abort_job,          :process_abort
  alias_method :cancel,             :process_cancel
  alias_method :finish,             :process_finished
  alias_method :error,              :process_error

  private

  def log_user_event(user_event)
    begin
      vm.log_user_event(user_event)
    rescue => err
      _log.warn("Failed to log user event with EMS.  Error: [#{err.class.name}]: #{err} Event message [#{user_event}]")
    end
  end

end
