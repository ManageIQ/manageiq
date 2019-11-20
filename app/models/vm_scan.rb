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
      :initializing       => {'initialize'       => 'waiting_to_start'},
      :snapshot_delete    => {'scanning'         => 'snapshot_delete'},
      :broker_unavailable => {'snapshot_create'  => 'wait_for_broker'},
      :scan_retry         => {'scanning'         => 'scanning'},
      :abort_retry        => {'scanning'         => 'scanning'},
      :abort_job          => {'*'                => 'aborting'},
      :cancel             => {'*'                => 'canceling'},
      :finish             => {'*'                => 'finished'},
      :error              => {'*'                => '*'},
      :start              => {'waiting_to_start' => 'wait_for_policy'},
      :start_snapshot     => {'wait_for_policy'  => 'snapshot_create',
                              'wait_for_broker'  => 'snapshot_create'},
      :snapshot_complete  => {'snapshot_create' => 'scanning',
                              'snapshot_delete' => 'synchronizing'},
      :data               => {'snapshot_create' => 'scanning',
                              'scanning'        => 'scanning',
                              'snapshot_delete' => 'snapshot_delete',
                              'synchronizing'   => 'synchronizing',
                              'finished'        => 'finished'}
    }
  end

  def call_check_policy
    _log.info("Enter")

    begin
      vm = VmOrTemplate.find(target_id)

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
      :args        => [:start_snapshot],
      :zone        => from_zone,
      :role        => "smartstate"
    )
  end

  def call_snapshot_create
    _log.info("Enter")

    begin
      vm = VmOrTemplate.find(target_id)
      context[:snapshot_mor] = nil

      options[:snapshot] = :skipped
      options[:use_existing_snapshot] = false

      # TODO: should this logic be moved to a VM subclass implementation?
      #       or, make type-specific Job classes.
      if vm.kind_of?(ManageIQ::Providers::Openstack::CloudManager::Vm) ||
         vm.kind_of?(ManageIQ::Providers::Microsoft::InfraManager::Vm)
        return unless create_snapshot(vm)
      elsif vm.kind_of?(ManageIQ::Providers::Azure::CloudManager::Vm) && vm.require_snapshot_for_scan?
        return unless create_snapshot(vm)
      elsif vm.require_snapshot_for_scan?
        proxy = MiqServer.find(miq_server_id)

        # Check if the broker is available
        if MiqServer.use_broker_for_embedded_proxy? && !MiqVimBrokerWorker.available?
          _log.warn("VimBroker is not available")
          signal(:broker_unavailable)
          return
        end

        if proxy && proxy.forceVmScan
          options[:snapshot] = :smartProxy
          _log.info("Skipping snapshot creation, it will be performed by the SmartProxy")
          context[:snapshot_mor] = options[:snapshot_description] = snapshotDescription("(embedded)")
          log_start_user_event_message(vm)
        else
          set_status("Creating VM snapshot")

          return unless create_snapshot(vm)
        end
      else
        log_start_user_event_message(vm)
      end
      signal(:snapshot_complete)
    rescue => err
      _log.log_backtrace(err)
      signal(:abort, err.message, "error")
      return
    rescue Timeout::Error
      msg = case options[:snapshot]
            when :smartProxy, :skipped then "Request to log snapshot user event with EMS timed out."
            else "Request to create snapshot timed out"
            end
      _log.error(msg)
      signal(:abort, msg, "error")
    end
  end

  def wait_for_vim_broker
    _log.info("Enter")
    i = 0
    loop do
      set_status("Waiting for VimBroker to become available (#{i += 1})")
      sleep(60)
      _log.info("Checking VimBroker connection status.  Count=[#{i}]")
      break if MiqVimBrokerWorker.available?
    end

    signal(:start_snapshot)
  end

  def call_scan
    _log.info("Enter")

    begin
      host = MiqServer.find(miq_server_id)
      vm = VmOrTemplate.find(target_id)
      # Send down metadata to allow the host to make decisions.
      scan_args = create_scan_args(vm)
      options[:ems_list] = ems_list = scan_args["ems"]
      options[:categories] = vm.scan_profile_categories(scan_args["vmScanProfiles"])

      # If the host supports VixDisk Lib then we need to validate that the host has the required credentials set.
      if vm.vendor == 'vmware'
        scan_ci_type = ems_list['connect_to']
        if host.is_vix_disk? && ems_list[scan_ci_type] && (ems_list[scan_ci_type][:username].nil? || ems_list[scan_ci_type][:password].nil?)
          context[:snapshot_mor] = nil unless options[:snapshot] == :created
          raise _("no credentials defined for %{type} %{name}") % {:type => scan_ci_type,
                                                                   :name => ems_list[scan_ci_type][:hostname]}
        end
      end
      if ems_list[scan_ci_type]
        _log.info("[#{host.name}] communicates with [#{scan_ci_type}:#{ems_list[scan_ci_type][:hostname]}"\
                  "(#{ems_list[scan_ci_type][:address]})] to scan vm [#{vm.name}]")
      end
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

  def config_snapshot
    snapshot = {"use_existing" => options[:use_existing_snapshot],
                "description"  => options[:snapshot_description]}
    snapshot['create_free_percent'] = ::Settings.snapshots.create_free_percent
    snapshot['remove_free_percent'] = ::Settings.snapshots.remove_free_percent
    snapshot['name'] = context[:snapshot_mor]
    snapshot
  end

  def config_ems_list(vm)
    ems_list = vm.ems_host_list
    ems_list['connect_to'] = vm.scan_via_ems? ? 'ems' : 'host'

    # Disable connecting to EMS for COS SmartProxy.  Embedded Proxy will
    # enable this if needed in the scan_sync_vm method in server_smart_proxy.rb.
    ems_list['connect'] = false if vm.vendor == 'redhat'
    ems_list
  end

  def create_scan_args(vm)
    scan_args = {"ems" => config_ems_list(vm), "snapshot" => config_snapshot}

    # Check if Policy returned scan profiles to use, otherwise use the default profile if available.
    scan_args["vmScanProfiles"] = options[:scan_profiles] || vm.scan_profile_list
    scan_args['snapshot']['forceFleeceDefault'] = false if vm.scan_via_ems? && vm.template?
    scan_args['permissions'] = {'group' => 36} if vm.vendor == 'redhat'
    scan_args
  end

  def call_snapshot_delete
    _log.info("Enter")

    # TODO: remove snapshot here if Vm was running
    vm = VmOrTemplate.find(target_id)
    if context[:snapshot_mor]
      mor = context[:snapshot_mor]
      context[:snapshot_mor] = nil

      if options[:snapshot] == :smartProxy
        set_status("Snapshot delete was performed by the SmartProxy")
      else
        set_status("Deleting VM snapshot: reference: [#{mor}]")
      end

      if vm.ext_management_system
        _log.info("Deleting snapshot: reference: [#{mor}]")
        begin
          # TODO: should this logic be moved to a VM subclass implementation?
          #       or, make type-specific Job classes.
          if vm.kind_of?(ManageIQ::Providers::Openstack::CloudManager::Vm)
            vm.ext_management_system.vm_delete_evm_snapshot(vm, mor)
          elsif vm.kind_of?(ManageIQ::Providers::Microsoft::InfraManager::Vm) ||
                (vm.kind_of?(ManageIQ::Providers::Azure::CloudManager::Vm) && vm.require_snapshot_for_scan?)
            vm.ext_management_system.vm_delete_evm_snapshot(vm, :snMor => mor)
          else
            delete_snapshot(mor, vm)
          end
        rescue => err
          _log.error(err.to_s)
          return
        rescue Timeout::Error
          msg = "Request to delete snapshot timed out"
          _log.error(msg)
        end

        unless options[:snapshot] == :smartProxy
          _log.info("Deleted snapshot: reference: [#{mor}]")
          set_status("Snapshot deleted: reference: [#{mor}]")
        end
      else
        _log.error("Deleting snapshot: reference: [#{mor}], No Providers available to delete snapshot")
        set_status("No Providers available to delete snapshot, skipping", "error")
      end
    else
      set_status("Snapshot was not taken, delete not required") if options[:snapshot] == :skipped
      log_end_user_event_message(vm)
    end

    signal(:snapshot_complete)
  end

  def call_synchronize
    _log.info("Enter")

    begin
      host = MiqServer.find(miq_server_id)
      vm = VmOrTemplate.find(target_id)
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
    dispatch_finish # let the dispatcher know that it is ok to start the next job since we are no longer holding then snapshot.
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
            vm = VmOrTemplate.find_by(:id => target_id)

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
          vm = VmOrTemplate.find(options[:target_id])
          result = vm.save_scan_history(s.attributes.to_h(false).merge("taskid" => doc.root.attributes["taskid"])) if s.attributes
          if result.status_code == 16 # fatal error on proxy
            signal(:abort_retry, result.message, "error", false)
          else
            signal(:snapshot_delete)
          end
        else
          _log.info("no action taken")
        end
      end
    end
    # got data to process
  end

  def delete_snapshot(mor, vm = nil)
    vm ||= VmOrTemplate.find(target_id)
    if mor
      begin
        if vm.ext_management_system
          if options[:snapshot] == :smartProxy
            log_end_user_event_message(vm)
            delete_snapshot_by_description(mor, vm)
          else
            user_event = end_user_event_message(vm)
            if vm.kind_of?(ManageIQ::Providers::Openstack::CloudManager::Vm)
              vm.ext_management_system.vm_delete_evm_snapshot(vm, mor)
            elsif vm.kind_of?(ManageIQ::Providers::Microsoft::InfraManager::Vm) ||
                  (vm.kind_of?(ManageIQ::Providers::Azure::CloudManager::Vm) && vm.require_snapshot_for_scan?)
              vm.ext_management_system.vm_delete_evm_snapshot(vm, :snMor => mor)
            else
              vm.ext_management_system.vm_remove_snapshot(vm, :snMor => mor, :user_event => user_event)
            end
          end
        else
          raise _("No Providers available to delete snapshot")
        end
      rescue => err
        _log.error(err.message)
        _log.log_backtrace(err, :debug)
      end
    else
      log_end_user_event_message(vm)
    end
  end

  def delete_snapshot_by_description(mor, vm)
    if mor
      ems_type = 'host'
      options[:ems_list] = vm.ems_host_list
      miqVimHost = options[:ems_list][ems_type]

      miqVim = nil
      # Make sure we were given a host to connect to and have a non-nil encrypted password
      if miqVimHost && !miqVimHost[:password].nil?
        server = miqVimHost[:hostname] || miqVimHost[:ipaddress]
        begin
          password_decrypt = ManageIQ::Password.decrypt(miqVimHost[:password])
          if MiqServer.use_broker_for_embedded_proxy?(ems_type)
            $vim_broker_client ||= MiqVimBroker.new(:client, MiqVimBrokerWorker.drb_port)
            miqVim = $vim_broker_client.getMiqVim(server, miqVimHost[:username], password_decrypt)
          else
            require 'VMwareWebService/MiqVim'
            miqVim = MiqVim.new(server, miqVimHost[:username], password_decrypt)
          end

          vimVm = miqVim.getVimVm(vm.path)
          vimVm.removeSnapshotByDescription(mor, true) unless vimVm.nil?
        ensure
          vimVm.release if vimVm rescue nil
          miqVim.disconnect unless miqVim.nil?
        end
      end
    end
  end

  def user_event_message(vm, verb)
    "EVM SmartState Analysis #{verb} for VM [#{vm.name}]"
  end

  def start_user_event_message(vm)
    user_event_message(vm, "Initiated")
  end

  def end_user_event_message(vm)
    user_event_message(vm, "completed")
  end

  def log_start_user_event_message(vm)
    log_user_event(start_user_event_message(vm), vm)
  end

  def log_end_user_event_message(vm)
    unless options[:end_message_sent]
      log_user_event(end_user_event_message(vm), vm)
      options[:end_message_sent] = true
    end
  end

  def snapshotDescription(type = nil)
    Snapshot.evm_snapshot_description(jobid, type)
  end

  def process_cancel(*args)
    options = args.first || {}

    _log.info("job canceling, #{options[:message]}")

    begin
      delete_snapshot(context[:snapshot_mor])
    rescue => err
      _log.log_backtrace(err)
    end

    super
  end

  # Logic to determine if we should abort the job or retry the scan depending on the error
  def call_abort_retry(*args)
    message, _status, skip_retry = args
    if message.to_s.include?("Could not find VM: [") && options[:scan_count].to_i.zero?
      # We may need to skip calling the retry if this method is called twice.
      return if skip_retry == true
      options[:scan_count] = options[:scan_count].to_i + 1
      vm = VmOrTemplate.find(target_id)
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
      vm = VmOrTemplate.find_by(:id => target_id)
      unless context[:snapshot_mor].nil?
        mor = context[:snapshot_mor]
        context[:snapshot_mor] = nil
        set_status("Deleting snapshot before aborting job")
        delete_snapshot(mor, vm)
      end
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
  def snapshot_complete
    if state == 'scanning'
      scanning
      call_scan
    else
      call_synchronize
    end
  end

  def data(*args)
    process_data(*args)
    if state == 'scanning'
      scanning
    elsif state == 'synchronizing'
      synchronizing
      # state == 'snapshot_delete'
      # do nothing?
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
  alias_method :start_snapshot,     :call_snapshot_create
  alias_method :snapshot_delete,    :call_snapshot_delete
  alias_method :broker_unavailable, :wait_for_vim_broker
  alias_method :abort_job,          :process_abort
  alias_method :cancel,             :process_cancel
  alias_method :finish,             :process_finished
  alias_method :error,              :process_error

  private

  def create_snapshot(vm)
    if vm.ext_management_system
      sn_description = snapshotDescription
      _log.info("Creating snapshot, description: [#{sn_description}]")
      user_event = start_user_event_message(vm)
      options[:snapshot] = :server
      begin
        # TODO: should this be a vm method?
        sn = vm.ext_management_system.vm_create_evm_snapshot(vm, :desc => sn_description, :user_event => user_event).to_s
      rescue Exception => err
        msg = "Failed to create evm snapshot with EMS. Error: [#{err.class.name}]: [#{err}]"
        _log.error(msg)
        err.kind_of?(MiqException::MiqVimBrokerUnavailable) ? signal(:broker_unavailable) : signal(:abort, msg, "error")
        return false
      end
      context[:snapshot_mor] = sn
      _log.info("Created snapshot, description: [#{sn_description}], reference: [#{context[:snapshot_mor]}]")
      set_status("Snapshot created: reference: [#{context[:snapshot_mor]}]")
      options[:snapshot] = :created
      options[:use_existing_snapshot] = true
      return true
    else
      signal(:abort, "No Providers available to create snapshot, skipping", "error")
      return false
    end
  end

  def log_user_event(user_event, vm)
    begin
      vm.log_user_event(user_event)
    rescue => err
      _log.warn("Failed to log user event with EMS.  Error: [#{err.class.name}]: #{err} Event message [#{user_event}]")
    end
  end

end
