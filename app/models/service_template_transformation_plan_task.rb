class ServiceTemplateTransformationPlanTask < ServiceTemplateProvisionTask
  belongs_to :conversion_host
  delegate :source_transport_method, :to => :conversion_host

  def self.base_model
    ServiceTemplateTransformationPlanTask
  end

  def self.get_description(req_obj)
    source_name = req_obj.source.name
    req_obj.kind_of?(ServiceTemplateTransformationPlanRequest) ? source_name : "Transforming VM [#{source_name}]"
  end

  def after_request_task_create
    update!(:description => get_description)
  end

  def resource_action
    miq_request.source.resource_actions.detect { |ra| ra.action == 'Provision' }
  end

  def transformation_destination(source_obj)
    miq_request.transformation_mapping.destination(source_obj)
  end

  def pre_ansible_playbook_service_template
    ServiceTemplate.find_by(:id => vm_resource.options["pre_ansible_playbook_service_template_id"])
  end

  def post_ansible_playbook_service_template
    ServiceTemplate.find_by(:id => vm_resource.options["post_ansible_playbook_service_template_id"])
  end

  def cpu_right_sizing_mode
    vm_resource.options["cpu_right_sizing_mode"]
  end

  def memory_right_sizing_mode
    vm_resource.options["memory_right_sizing_mode"]
  end

  def warm_migration?
    vm_resource.options["warm_migration"]
  end

  def update_transformation_progress(progress)
    update_options(:progress => (options[:progress] || {}).merge(progress))
  end

  def task_finished
    # update the status of vm transformation status in the plan
    vm_resource.update!(:status => status == 'Ok' ? ServiceResource::STATUS_COMPLETED : ServiceResource::STATUS_FAILED)
  end

  def mark_vm_migrated
    source.tag_with("migrated", :ns => "/managed", :cat => "transformation_status")
  end

  def task_active
    vm_resource.update!(:status => ServiceResource::STATUS_ACTIVE)
  end

  # This method returns true if all mappings are ok. It also preload
  #  virtv2v_disks and network_mappings in task options
  def preflight_check
    raise 'OSP destination and source power_state is off' if destination_ems.emstype == 'openstack' && source.power_state == 'off'
    update_options(
      :source_vm_power_state => source.power_state, # This will determine power_state of destination_vm
      :source_vm_ipaddresses => source.ipaddresses  # This will determine if we need to wait for ip addresses to appear
    )
    destination_cluster
    preflight_check_vm_exists_in_destination
    virtv2v_disks
    network_mappings

    host = source.host
    raise "No credentials configured for '#{host.name}'" if host.missing_credentials?
    raise "Invalid authentication for '#{host.name}': #{host.default_authentication.status_details}" unless host.authentication_status_ok?

    { :status => 'Ok', :message => 'Preflight check is successful' }
  rescue StandardError => error
    { :status => 'Error', :message => error.message }
  end

  def preflight_check_vm_exists_in_destination
    send("preflight_check_vm_exists_in_destination_#{destination_ems.emstype}")
  end

  def preflight_check_vm_exists_in_destination_rhevm
    unless destination_ems.vms_and_templates.where(:name => source.name, :ems_cluster => destination_cluster).count.zero?
      raise "A VM named '#{source.name}' already exist in destination cluster"
    end
  end

  def preflight_check_vm_exists_in_destination_openstack
    unless destination_ems.vms_and_templates.where(:name => source.name, :cloud_tenant => destination_cluster).count.zero?
      raise "A VM named '#{source.name}' already exist in destination cloud tenant"
    end
  end

  def source_cluster
    source.ems_cluster
  end

  def destination_cluster
    dst_cluster = transformation_destination(source_cluster)
    raise "[#{source.name}] Cluster #{source_cluster} has no mapping." if dst_cluster.nil?
    dst_cluster
  end

  def source_ems
    source.ext_management_system
  end

  def destination_ems
    destination_cluster.ext_management_system
  end

  def transformation_type
    "#{source_ems.emstype}2#{destination_ems.emstype}"
  end

  def virtv2v_disks
    return options[:virtv2v_disks] if options[:virtv2v_disks].present?
    update_options(:virtv2v_disks => calculate_virtv2v_disks)
    options[:virtv2v_disks]
  end

  def network_mappings
    return options[:network_mappings] if options[:network_mappings].present?
    update_options(:network_mappings => calculate_network_mappings)
    options[:network_mappings]
  end

  def destination_network_ref(network)
    send("destination_network_ref_#{destination_ems.emstype}", network)
  end

  def destination_network_ref_rhevm(network)
    network.name
  end

  def destination_network_ref_openstack(network)
    network.ems_ref
  end

  def destination_flavor
    Flavor.find_by(:id => vm_resource.options["osp_flavor_id"])
  end

  def destination_security_group
    SecurityGroup.find_by(:id => vm_resource.options["osp_security_group_id"])
  end

  def valid_transformation_log_types
    %w(v2v wrapper)
  end

  def transformation_log(log_type = 'v2v')
    if conversion_host.nil?
      msg = "Conversion host was not found. Download of transformation log aborted."
      _log.error(msg)
      raise MiqException::Error, msg
    end

    logfile = options.fetch_path(:virtv2v_wrapper, "#{log_type}_log")
    if logfile.blank?
      msg = "The location of #{log_type} log was not set. Download of #{log_type} log aborted."
      _log.error(msg)
      raise MiqException::Error, msg
    end

    conversion_host.get_conversion_log(logfile)
  end

  # Intend to be called by UI to display transformation log. The log is stored in MiqTask#task_results
  # Since the task_results may contain a large block of data, it is desired to remove the task upon receiving the data
  def transformation_log_queue(userid = nil, log_type = 'v2v')
    raise "Transformation log type '#{log_type}' not supported" unless valid_transformation_log_types.include?(log_type)
    userid ||= User.current_userid || 'system'
    if conversion_host.nil?
      msg = "Conversion host was not found. Cannot queue the download of #{log_type} log."
      return create_error_status_task(userid, msg).id
    end

    _log.info("Queuing the download of #{log_type} log for #{description} with ID [#{id}]")
    task_options = {:userid => userid, :action => 'transformation_log'}
    queue_options = {:class_name  => self.class.name,
                     :method_name => 'transformation_log',
                     :instance_id => id,
                     :args        => [log_type],
                     :zone        => conversion_host.resource.my_zone}
    MiqTask.generic_action_with_callback(task_options, queue_options)
  end

  def infra_conversion_job
    Job.find(options[:infra_conversion_job_id])
  end

  def cancel
    update!(:cancelation_status => MiqRequestTask::CANCEL_STATUS_REQUESTED)
  end

  def canceling
    update!(:cancelation_status => MiqRequestTask::CANCEL_STATUS_PROCESSING)
  end

  def canceled
    update!(:cancelation_status => MiqRequestTask::CANCEL_STATUS_FINISHED)
  end

  def conversion_options
    source_cluster = source.ems_cluster
    source_storage = source.hardware.disks.select { |d| d.device_type == 'disk' }.first.storage
    destination_cluster = transformation_destination(source_cluster)
    destination_storage = transformation_destination(source_storage)

    results = {
      :source_disks     => virtv2v_disks.map { |disk| disk[:path] },
      :network_mappings => network_mappings
    }

    results.merge!(send("conversion_options_source_provider_#{source_ems.emstype}_#{source_transport_method}", source_storage))
    results.merge!(send("conversion_options_destination_provider_#{destination_ems.emstype}", destination_cluster, destination_storage))
  end

  def update_options(opts)
    save if changed?
    with_lock do
      # Automate is updating this options hash (various keys) as well, using with_lock.
      options.merge!(opts)
      update!(:options => options)
    end
    options
  end

  def run_conversion
    start_timestamp = Time.now.utc.strftime('%Y-%m-%d %H:%M:%S')
    updates = {}
    conversion_host.run_conversion(id, conversion_options)
    updates[:virtv2v_wrapper] = {
      "state_file"      => "/var/lib/uci/#{id}/state.json",
      "throttling_file" => "/var/lib/uci/#{id}/limits.json",
      "cutover_file"    => "/var/lib/uci/#{id}/cutover",
      "v2v_log"         => "/var/log/uci/#{id}/virt-v2v.log",
      "wrapper_log"     => "/var/log/uci/#{id}/virt-v2v-wrapper.log"
    }
    updates[:virtv2v_started_on] = start_timestamp
    updates[:virtv2v_status] = 'active'
    _log.info("InfraConversionJob run_conversion to update_options: #{updates}")
    update_options(updates)
  end

  def get_conversion_state
    updates = {}
    virtv2v_state = conversion_host.get_conversion_state(id)
    updated_disks = virtv2v_disks
    updates[:virtv2v_pid] = virtv2v_state['pid'] if virtv2v_state['pid'].present?
    updates[:virtv2v_message] = virtv2v_state['last_message']['message'] if virtv2v_state['last_message'].present?
    if virtv2v_state['finished'].nil?
      updates[:virtv2v_status] = 'active'
      updated_disks.each do |disk|
        matching_disks = virtv2v_state['disks'].select { |d| d['path'] == disk[:path] }
        raise "No disk matches '#{disk[:path]}'. Aborting." if matching_disks.length.zero?
        raise "More than one disk matches '#{disk[:path]}'. Aborting." if matching_disks.length > 1
        disk[:percent] = matching_disks.first['progress']
      end
    else
      updates[:virtv2v_finished_on] = Time.now.utc.strftime('%Y-%m-%d %H:%M:%S')
      if virtv2v_state['failed']
        updates[:virtv2v_status] = 'failed'
      elsif !canceling?
        updates[:virtv2v_status] = 'succeeded'
        updates[:destination_vm_uuid] = virtv2v_state['vm_id']
        updated_disks.each { |d| d[:percent] = 100 }
      end
    end
    updates[:virtv2v_disks] = updated_disks
    update_options(:get_conversion_state_failures => 0)
  rescue
    failures = options[:get_conversion_state_failures] || 0
    update_options(:get_conversion_state_failures => failures + 1)
    raise "Failed to get conversion state 5 times in a row" if options[:get_conversion_state_failures] > 5
  ensure
    _log.info("InfraConversionJob get_conversion_state to update_options: #{updates}")
    update_options(updates)
  end

  def cutover
    unless conversion_host.create_cutover_file(id)
      raise _("Couldn't create cutover file for #{source.name} on #{conversion_host.name}")
    end
  end

  def kill_virtv2v(signal = 'TERM')
    get_conversion_state

    unless virtv2v_running?
      _log.info("virt-v2v is not running, so there is nothing to do.")
      return false
    end

    _log.info("Killing conversion pod for task '#{id}'.")
    conversion_host.kill_virtv2v(id, signal)
  rescue => err
    _log.error("Couldn't kill conversion pod for task '#{id}': #{err.message}")
    update_options(:virtv2v_finished_on => Time.now.utc.strftime('%Y-%m-%d %H:%M:%S'))
    false
  end

  def virtv2v_running?
    options[:virtv2v_started_on].present? && options[:virtv2v_finished_on].blank? && options[:virtv2v_wrapper].present?
  end

  private

  def vm_resource
    miq_request.vm_resources.find_by(:resource => source)
  end

  def create_error_status_task(userid, msg)
    MiqTask.create(
      :name    => "Download transformation log with ID: #{id}",
      :userid  => userid,
      :state   => MiqTask::STATE_FINISHED,
      :status  => MiqTask::STATUS_ERROR,
      :message => msg
    )
  end

  def calculate_virtv2v_disks
    source.hardware.disks.select { |d| d.device_type == 'disk' }.collect do |disk|
      source_storage = disk.storage
      destination_storage = transformation_destination(disk.storage)
      raise "[#{source.name}] Disk #{disk.device_name} [#{source_storage.name}] has no mapping." if destination_storage.nil?
      {
        :path    => disk.filename,
        :size    => disk.size,
        :percent => 0,
        :weight  => disk.size.to_f / source.allocated_disk_storage.to_f * 100
      }
    end
  end

  def calculate_network_mappings
    source.hardware.nics.select { |n| n.device_type == 'ethernet' }.collect do |nic|
      source_network = nic.lan
      destination_network = transformation_destination(source_network)
      raise "[#{source.name}] NIC #{nic.device_name} [#{source_network.name}] has no mapping." if destination_network.nil?
      {
        :source      => source_network.name,
        :destination => destination_network_ref(destination_network),
        :mac_address => nic.address,
        :ip_address  => nic.network.try(:ipaddress)
      }.compact
    end
  end

  def conversion_options_source_provider_vmwarews_vddk(_storage)
    {
      :vm_name              => source.name,
      :vm_uuid              => source.uid_ems,
      :conversion_host_uuid => conversion_host.resource.ems_ref,
      :transport_method     => 'vddk',
      :vmware_fingerprint   => source.host.thumbprint_sha1,
      :vmware_uri           => URI::Generic.build(
        :scheme   => 'esx',
        :userinfo => CGI.escape(source.host.authentication_userid),
        :host     => source.host.miq_custom_get('TransformationIPAddress') || source.host.ipaddress,
        :path     => '/',
        :query    => { :no_verify => 1 }.to_query
      ).to_s,
      :vmware_password      => source.host.authentication_password,
      :two_phase            => true,
      :warm                 => warm_migration?,
      :daemonize            => false
    }
  end

  def conversion_options_source_provider_vmwarews_ssh(storage)
    {
      :vm_name              => URI::Generic.build(
        :scheme   => 'ssh',
        :userinfo => 'root',
        :host     => source.host.miq_custom_get('TransformationIPAddress') || source.host.ipaddress,
        :path     => "/vmfs/volumes/#{Addressable::URI.escape(storage.name)}/#{Addressable::URI.escape(source.location)}"
      ).to_s,
      :vm_uuid              => source.uid_ems,
      :conversion_host_uuid => conversion_host.resource.ems_ref,
      :transport_method     => 'ssh',
      :daemonize            => false
    }
  end

  def conversion_options_destination_provider_rhevm(cluster, storage)
    {
      :rhv_url             => URI::Generic.build(:scheme => 'https', :host => destination_ems.hostname, :path => '/ovirt-engine/api').to_s,
      :rhv_cluster         => cluster.name,
      :rhv_storage         => storage.name,
      :rhv_password        => destination_ems.authentication_password,
      :install_drivers     => true,
      :insecure_connection => true
    }
  end

  def conversion_options_destination_provider_openstack(cluster, storage)
    {
      :osp_environment            => {
        :os_auth_url             => URI::Generic.build(
          :scheme => destination_ems.security_protocol == 'non-ssl' ? 'http' : 'https',
          :host   => destination_ems.hostname,
          :port   => destination_ems.port,
          :path   => '/' + destination_ems.api_version
        ).to_s,
        :os_identity_api_version => '3',
        :os_user_domain_name     => destination_ems.uid_ems,
        :os_username             => destination_ems.authentication_userid,
        :os_password             => destination_ems.authentication_password,
        :os_project_name         => conversion_host.resource.cloud_tenant.name
      },
      :osp_server_id              => conversion_host.ems_ref,
      :osp_destination_project_id => cluster.ems_ref,
      :osp_volume_type_id         => storage.ems_ref,
      :osp_flavor_id              => destination_flavor.ems_ref,
      :osp_security_groups_ids    => [destination_security_group.ems_ref]
    }
  end

  def valid_states
    super << 'migrate'
  end
end
