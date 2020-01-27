class JobProxyDispatcher
  include Vmdb::Logging

  def self.dispatch
    new.dispatch
  end

  def initialize
    @vm = nil
    @all_busy_by_host_id_storage_id = {}
    @active_vm_scans_by_zone = nil
    @active_container_scans_by_zone_and_ems = nil
    @zone = nil
  end

  def dispatch
    _dummy, t = Benchmark.realtime_block(:total_time) do
      Benchmark.realtime_block(:v2v_dispatching) { dispatch_v2v_migrations }
      Benchmark.realtime_block(:v2v_limits) { apply_v2v_limits }
      Benchmark.realtime_block(:container_dispatching) { dispatch_container_scan_jobs }
      jobs_to_dispatch, = Benchmark.realtime_block(:pending_vm_jobs) { pending_jobs }
      Benchmark.current_realtime[:vm_jobs_to_dispatch_count] = jobs_to_dispatch.length

      # Skip work if there are no jobs to dispatch
      if jobs_to_dispatch.length > 0
        Benchmark.realtime_block(:active_vm_scans) { active_vm_scans_by_zone }
        Benchmark.realtime_block(:busy_proxies) { busy_proxies }
        Benchmark.realtime_block(:busy_resources_for_embedded_scanning) { busy_resources_for_embedded_scanning }

        vms_for_jobs = jobs_to_dispatch.collect(&:target_id)
        @vms_for_dispatch_jobs, = Benchmark.realtime_block(:vm_find) do
          VmOrTemplate.where(:id => vms_for_jobs)
          .includes(:ext_management_system => :zone, :storage => :hosts)
          .order(:id)
        end
        zone = Zone.find_by(:name => @zone)
        concurrent_vm_scans_limit = zone.settings.blank? ? 0 : zone.settings[:concurrent_vm_scans].to_i

        jobs_to_dispatch.each do |job|
          if concurrent_vm_scans_limit > 0 && active_vm_scans_by_zone[@zone] >= concurrent_vm_scans_limit
            _log.warn("SKIPPING remaining Vm Or Template jobs in dispatch since there are [%d] active scans in the zone [%s]" %
                      [active_vm_scans_by_zone[@zone], @zone])
            break
          end
          @vm = @vms_for_dispatch_jobs.detect { |v| v.id == job.target_id }
          if @vm.nil? # Handle job for VM that was deleted
            _log.warn("VM with id: [#{job.target_id}] no longer exists, aborting job [#{job.guid}]")
            job.signal(:abort, "VM with id: [#{job.target_id}] no longer exists, job aborted.", "warn")
            next
          end

          proxy = nil
          if @all_busy_by_host_id_storage_id["#{@vm.host_id}_#{@vm.storage_id}"]
            _log.debug("Skipping job id [#{job.id}] guid [#{job.guid}] for vm: [#{@vm.id}] in this dispatch since a prior job with the same host [#{@vm.host_id}] and storage [#{@vm.storage_id}] determined that all resources are busy.")
            next
          end

          begin
            eligible_proxies, = Benchmark.realtime_block(:get_eligible_proxies_for_job) { get_eligible_proxies_for_job(job) }
            proxy = eligible_proxies.detect do |p|
              Benchmark.current_realtime[:busy_proxy_count] += 1
              busy, = Benchmark.realtime_block(:busy_proxy) { self.busy_proxy?(p, job) }
              !busy
            end
          rescue => err
            _log.warn("#{err}, attempting to dispatch job [#{job.guid}], aborting job")
            job.signal(:abort, "Error [#{err}], attempting to dispatch, aborting job [#{job.guid}].", "error")
          end

          if proxy
            # Skip this embedded scan if the host/vc we'd need has already exceeded the limit
            next if embedded_resource_limit_exceeded?(job)
            _log.info("STARTING job: [#{job.guid}] on proxy: [#{proxy.name}]")
            Benchmark.current_realtime[:start_job_on_proxy_count] += 1
            Benchmark.realtime_block(:start_job_on_proxy) { start_job_on_proxy(job, proxy) }
          elsif @vm.host_id && @vm.storage_id && !@vm.template?
            _log.debug("Skipping job id [#{job.id}] guid [#{job.guid}] for vm: [#{@vm.id}] in this dispatch since no proxies/servers are available. Caching result for Vm's host [#{@vm.host_id}] and storage [#{@vm.storage_id}].")
            @all_busy_by_host_id_storage_id["#{@vm.host_id}_#{@vm.storage_id}"] = true
          end
        end
      end
    end
    _log.info("Complete - Timings: #{t.inspect}")
  end

  def container_image_scan_class
    ManageIQ::Providers::Kubernetes::ContainerManager::Scanning::Job
  end

  def dispatch_v2v_migrations
    InfraConversionThrottler.start_conversions
  end

  def apply_v2v_limits
    InfraConversionThrottler.apply_limits
  end

  def dispatch_container_scan_jobs
    jobs_by_ems, = Benchmark.realtime_block(:pending_container_jobs) { pending_container_jobs }
    Benchmark.current_realtime[:container_jobs_to_dispatch_count] = jobs_by_ems.values.reduce(0) { |m, o| m + o.length }
    jobs_by_ems.each do |ems_id, jobs|
      dispatch_to_ems(ems_id, jobs, Settings.container_scanning.concurrent_per_ems.to_i)
    end
  end

  def dispatch_to_ems(ems_id, jobs, concurrent_ems_limit)
    jobs.each do |job|
      active_ems_scans = active_container_scans_by_zone_and_ems[@zone][ems_id]
      if concurrent_ems_limit > 0 && active_ems_scans >= concurrent_ems_limit
        _log.warn(
          "SKIPPING remaining Container Image scan jobs for Provider [%s] in dispatch since there are [%d] active scans in zone [%s]" %
            [
              ems_id,
              active_ems_scans,
              @zone
            ]
        )
        break
      end
      do_dispatch(job, ems_id)
    end
  end

  def do_dispatch(job, ems_id)
    _log.info("Signaling start for container image scan job [#{job.id}]")
    job.update(:dispatch_status => "active", :started_on => Time.now.utc)
    @active_container_scans_by_zone_and_ems[@zone][ems_id] += 1
    MiqQueue.put_unless_exists(
      :args        => [:start],
      :class_name  => "Job",
      :instance_id => job.id,
      :method_name => "signal",
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => "smartstate",
      :task_id     => job.guid,
      :zone        => job.zone
    )
  end

  def queue_signal(job, options)
    Benchmark.current_realtime[:queue_signal_count] += 1
    Benchmark.realtime_block(:queue_signal) do
      return if options.blank?
      default_opts = {
        :class_name  => "Job",
        :method_name => "signal",
        :instance_id => job.id,
        :task_id     => job.guid,
        :priority    => MiqQueue::HIGH_PRIORITY,
        :role        => "smartstate"
      }

      default_opts[:zone] = job.zone if job.zone
      options = default_opts.merge(options)
      # special case signal(:abort) - so we can easily pull off the queue
      if (sig = options[:args].first) == :abort
        options[:args].shift # remove :abort from args
        options[:method_name] = "signal_abort"
      end
      MiqQueue.put_unless_exists(options) do |msg|
        _log.warn("Previous Job signal [#{sig}] for Job: [#{job.guid}] is still running, skipping...") unless msg.nil?
      end
    end
  end

  def start_job_on_proxy(job, proxy)
    assign_proxy_to_job(proxy, job)
    _log.info("Job #{job.attributes_log}")
    job_options = {:args => ["start"], :zone => MiqServer.my_zone, :server_guid => proxy.guid, :role => "smartproxy"}
    @active_vm_scans_by_zone[MiqServer.my_zone] += 1
    queue_signal(job, job_options)
  end

  def assign_proxy_to_job(proxy, job)
    job.miq_server_id   = proxy.id
    job.started_on      = Time.now.utc
    job.dispatch_status = "active"
    job.save

    # Increment the counts for busy proxies and busy hosts for embedded
    busy_proxies["MiqServer_#{job.miq_server_id}"] ||= 0
    busy_proxies["MiqServer_#{job.miq_server_id}"] += 1

    # Track the host/vc resource for embedded scans so we can limit the resource impact
    if (key = embedded_scan_resource(@vm))
      busy_resources_for_embedded_scanning[key] ||= 0
      busy_resources_for_embedded_scanning[key] += 1
    end
  end

  def self.waiting?
    Job.where(:state => "waiting_to_start").or(Job.where(:type => "InfraConversionJob").where.not(:state => ["finished", "waiting_to_start"]))
  end

  def pending_jobs(job_class = VmScan)
    @zone = MiqServer.my_zone
    job_class.order(:id)
             .where(:state           => "waiting_to_start")
             .where(:dispatch_status => "pending")
             .where("zone is null or zone = ?", @zone)
             .where("sync_key is NULL or
                sync_key not in (
                  select sync_key from jobs where
                    dispatch_status = 'active' and
                    state != 'finished' and
                    (zone is null or zone = ?) and
                    sync_key is not NULL)", @zone)
  end

  def pending_container_jobs
    pending_jobs(container_image_scan_class).each_with_object(Hash.new { |h, k| h[k] = [] }) do |job, h|
      h[job.options[:ems_id]] << job
    end
  end

  def busy_proxy?(proxy, _job)
    active_job_count = busy_proxies["#{proxy.class}_#{proxy.id}"]

    # If active is false there is nothing else to check
    return false if active_job_count.nil? || active_job_count == 0

    # If the agent only supports 1 concurrent instance we do not have to perform the count lookup
    concurrent_job_max, = Benchmark.realtime_block(:busy_proxy__concurrent_job_max) { concurrent_job_max_by_proxy(proxy) }
    return true if concurrent_job_max <= 1

    # Return if the active job count meets or exceeds the max allowed concurrent jobs for the agent
    if active_job_count >= concurrent_job_max
      return true
    end

    false
  end

  def concurrent_job_max_by_proxy(proxy)
    @max_concurrent_job_hash ||= {}
    key = "#{proxy.class.name}_#{proxy.id}"
    return @max_concurrent_job_hash[key] if @max_concurrent_job_hash.key?(key) && !@max_concurrent_job_hash[key].nil?
    @max_concurrent_job_hash[key] = proxy.concurrent_job_max
  end

  def busy_proxies
    @busy_proxies_hash ||= begin
      Job.where(:dispatch_status => "active")
      .where("state != ?", "finished")
      .select([:miq_server_id])
      .each_with_object({}) do |j, busy_hsh|
        busy_hsh["MiqServer_#{j.miq_server_id}"] ||= 0
        busy_hsh["MiqServer_#{j.miq_server_id}"] += 1
      end
    end
  end

  def active_scans_by_zone(job_class, count = true)
    actives = Hash.new(0)
    jobs = job_class.where(:zone => @zone, :dispatch_status => "active")
              .where.not(:state => "finished")
    actives[@zone] = count ? jobs.count : jobs
    actives
  end

  def active_vm_scans_by_zone
    @active_vm_scans_by_zone ||= active_scans_by_zone(VmScan)
  end

  def active_container_scans_by_zone_and_ems
    @active_container_scans_by_zone_and_ems ||= begin
      memo = Hash.new do |h, k|
        h[k] = Hash.new(0)
      end
      active_scans_by_zone(container_image_scan_class, false)[@zone].each do |job|
        memo[@zone][job.options[:ems_id]] += 1
      end
      memo
    end
  end

  def busy_resources_for_embedded_scanning
    return @busy_resources_for_embedded_scanning_hash unless @busy_resources_for_embedded_scanning_hash.nil?

    _log.debug("Initializing busy_resources_for_embedding_scanning hash")
    @busy_resources_for_embedded_scanning_hash ||= {}

    vms_in_embedded_scanning =
      Job.where(:dispatch_status => "active")
      .where(:target_class     => "VmOrTemplate")
      .where("state != ?", "finished")
      .pluck(:target_id).compact.uniq
    return @busy_resources_for_embedded_scanning_hash if vms_in_embedded_scanning.blank?

    embedded_scans_by_resource = Hash.new { |h, k| h[k] = 0 }
    VmOrTemplate.where(:id => vms_in_embedded_scanning).each do |v|
      key = embedded_scan_resource(v)
      embedded_scans_by_resource[key] += 1 if key
    end

    @busy_resources_for_embedded_scanning_hash = embedded_scans_by_resource
  end

  def embedded_scan_resource(vm)
    if vm.scan_via_ems?
      "ExtManagementSystem_#{vm.ems_id}" unless vm.ems_id.nil?
    else
      "Host_#{vm.host_id}" unless vm.host_id.nil?
    end
  end

  def embedded_resource_limit_exceeded?(job)
    return false unless job.target_class == "VmOrTemplate"

    if @vm.nil?
      job.signal(:abort, "Unable to find vm [#{job.target_id}], aborting job [#{job.guid}].", "error")
      return
    end

    if @vm.scan_via_ems?
      count_allowed = ::Settings.coresident_miqproxy.concurrent_per_ems.to_i
    else
      return false if @vm.host_id.nil?  # e.g. EC2 images do not have hosts
      count_allowed = ::Settings.coresident_miqproxy.concurrent_per_host.to_i
    end

    return false if busy_resources_for_embedded_scanning.blank?

    begin
      count_allowed = 1 if count_allowed.zero?
      target_resource = embedded_scan_resource(@vm)
      count = busy_resources_for_embedded_scanning[target_resource]
      if count && count >= count_allowed
        return true
      end
    rescue
    end

    false
  end

  def get_eligible_proxies_for_job(job)
    Benchmark.current_realtime[:get_eligible_proxies_for_job_count] += 1

    if @vm.nil?
      msg = "Unable to find vm [#{job.target_id}], aborting job [#{job.guid}]."
      queue_signal(job, {:args => [:abort, msg, "error"]})
      return []
    end

    if @vm.requires_storage_for_scan?
      if @vm.storage.nil?
        msg = "Vm [#{@vm.path}] is not located on a storage, aborting job [#{job.guid}]."
        queue_signal(job, {:args => [:abort, msg, "error"]})
        return []
      else
        unless %w(VSAN VMFS NAS NFS NFS41 ISCSI DIR FCP CSVFS NTFS GLUSTERFS).include?(@vm.storage.store_type)
          msg = "Vm storage type [#{@vm.storage.store_type}] unsupported [#{job.target_id}], aborting job [#{job.guid}]."
          queue_signal(job, {:args => [:abort, msg, "error"]})
          return []
        end
      end
    end

    vm_proxies, = Benchmark.realtime_block(:get_eligible_proxies_for_job__proxies4job) { @vm.proxies4job(job) }
    if vm_proxies[:proxies].empty?
      msg = "No eligible proxies for VM :[#{@vm.path}] - [#{vm_proxies[:message]}], aborting job [#{job.guid}]."
      queue_signal(job, {:args => [:abort, msg, "error"]})
      return []
    end

    vm_proxies[:proxies]
  end
end # class JobProxyDispatcher
