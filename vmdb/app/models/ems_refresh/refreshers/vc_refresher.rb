require 'MiqVim'
require 'http-access2' # Required in case it is not already loaded

module EmsRefresh::Refreshers
  class VcRefresher < BaseRefresher
    include EmsRefresh::Parsers::Vc::Filter

    # Development helper method for setting up the selector specs for VC
    def self.init_console(use_vim_broker = false)
      return @initialized_console unless @initialized_console.nil?
      EmsVmware.instance_variable_set(:@__use_vim_broker, use_vim_broker)
      def EmsVmware.use_vim_broker?; @__use_vim_broker; end
      klass = use_vim_broker ? MiqVimBroker : MiqVimInventory
      klass.cacheScope = :cache_scope_ems_refresh
      klass.setSelector(EmsRefresh::VcUpdates::VIM_SELECTOR_SPEC)
      @initialized_console = true
    end

    def initialize(targets)
      super

      @full_refresh_threshold = options[:full_refresh_threshold] || 10

      # See if any should be escalated to a full refresh
      @targets_by_ems_id.each do |ems_id, list|
        ems = @ems_by_ems_id[ems_id]
        ems_in_list = list.any? { |t| t.kind_of?(ExtManagementSystem) }

        if ems_in_list
          $log.info "MIQ(VcRefresher.initialize) Defaulting to full refresh for EMS: [#{ems.name}], id: [#{ems.id}]." if list.length > 1
          list.clear << ems
        elsif !ems_in_list && list.length >= @full_refresh_threshold
          $log.info "MIQ(VcRefresher.initialize) Escalating to full refresh for EMS: [#{ems.name}], id: [#{ems.id}]."
          list.clear << ems
        end
      end
    end

    def refresh
      $log.info "MIQ(VcRefresher.refresh) Refreshing all targets..."
      outer_time = Time.now

      @targets_by_ems_id.each do |ems_id, targets|
        # Get the ems object
        @ems = @ems_by_ems_id[ems_id]
        log_header = "MIQ(VcRefresher.refresh) EMS: [#{@ems.name}], id: [#{@ems.id}]"

        begin
          $log.info "#{log_header} Refreshing targets for EMS..."
          targets.each { |t| $log.info "#{log_header}   #{t.class}: [#{t.name}], id: [#{t.id}]" }

          dummy, timings = Benchmark.realtime_block(:total_time) { refresh_targets_for_ems(targets) }

          $log.info "#{log_header} Refreshing targets for EMS...Complete - Timings: #{timings.inspect}"
        rescue => e
          $log.log_backtrace(e)
          $log.error("#{log_header} Unable to perform refresh for the following targets:" )
          targets.each { |t| $log.error "#{log_header}   #{t.class}: [#{t.name}], id: [#{t.id}]" }
          @ems.update_attributes(:last_refresh_error => e.to_s, :last_refresh_date => Time.now.utc)
        else
          @ems.update_attributes(:last_refresh_error => nil, :last_refresh_date => Time.now.utc)
        end
      end

      $log.info "MIQ(VcRefresher.refresh) Refreshing all targets...Completed in #{Time.now - outer_time}s"
    end

    private

    def refresh_targets_for_ems(targets)
      targets_with_data, = Benchmark.realtime_block(:get_vc_data_total) { get_and_filter_vc_data(targets) }
      start_time = Time.now
      targets_with_data.each { |t, d| refresh_target(t, d) }
      Benchmark.realtime_block(:post_refresh_ems) { post_refresh_ems(start_time) }
    end

    def get_and_filter_vc_data(targets)
      Benchmark.realtime_block(:get_ems_data) { get_ems_data }
      Benchmark.realtime_block(:get_vc_data) { get_vc_data }

      Benchmark.realtime_block(:get_vc_data_ems_customization_specs) { get_vc_data_ems_customization_specs } if targets.include?(@ems)

      # Filter the data, and determine for which hosts we will need to get extended data
      filtered_host_mors = []
      targets_with_data = targets.collect do |target|
        filtered_data, = Benchmark.realtime_block(:filter_vc_data) { filter_vc_data(target) }
        filtered_host_mors += filtered_data[:host].keys
        [target, filtered_data]
      end
      filtered_host_mors.uniq!

      Benchmark.realtime_block(:get_vc_data_host_scsi) { get_vc_data_host_scsi(filtered_host_mors) }

      return targets_with_data
    ensure
      disconnect_from_ems
    end

    def refresh_target(target, filtered_data)
      log_header = "MIQ(VcRefresher.refresh) EMS: [#{@ems.name}], id: [#{@ems.id}]"
      $log.info "#{log_header} Refreshing target #{target.class} [#{target.name}] id [#{target.id}]..."

      $log.debug "#{log_header} Parsing VC inventory..."
      hashes, = Benchmark.realtime_block(:parse_vc_data) do
        EmsRefresh::Parsers::Vc.ems_inv_to_hashes(filtered_data)
      end
      $log.debug "#{log_header} Parsing VC inventory...Complete"

      Benchmark.realtime_block(:db_save_inventory) do
        @ems.update_attributes(@ems_data) unless @ems_data.nil?
        EmsRefresh.save_ems_inventory(@ems, hashes, target)
      end

      $log.info "#{log_header} Refreshing target #{target.class} [#{target.name}] id [#{target.id}]...Complete"
    end

    def post_refresh_ems(start_time)
      log_header = "MIQ(VcRefresher.refresh) EMS: [#{@ems.name}], id: [#{@ems.id}]"
      [VmOrTemplate, Host].each do |klass|
        next unless klass.respond_to?(:post_refresh_ems)
        $log.info "#{log_header} Performing post-refresh operations for #{klass} instances..."
        klass.post_refresh_ems(@ems.id, start_time)
        $log.info "#{log_header} Performing post-refresh operations for #{klass} instances...Complete"
      end
    end

    #
    # VC data collection methods
    #

    VC_ACCESSORS = [
      [:dataStoresByMor,              :storage],
      [:hostSystemsByMor,             :host],
      [:virtualMachinesByMor,         :vm],
      [:datacentersByMor,             :dc],
      [:foldersByMor,                 :folder],
      [:clusterComputeResourcesByMor, :cluster],
      [:computeResourcesByMor,        :host_res],
      [:resourcePoolsByMor,           :rp],
      [:virtualAppsByMor,             :vapp]
    ]

    def get_vc_data
      log_header = "MIQ(VcRefresher.get_vc_data) EMS: [#{@ems.name}], id: [#{@ems.id}]"

      cleanup_callback = Proc.new { @vc_data = nil }

      retrieve_from_vc(cleanup_callback) do
        @vc_data = Hash.new { |h, k| h[k] = Hash.new }

        VC_ACCESSORS.each do |acc, type|
          $log.info("#{log_header} Retrieving #{type.to_s.titleize} inventory...")
          inv_hash = @vi.send(acc, :"ems_refresh_#{type}")
          EmsRefresh.log_inv_debug_trace(inv_hash, "#{log_header} inv_hash:")

          @vc_data[type] = inv_hash unless inv_hash.blank?
          $log.info("#{log_header} Retrieving #{type.to_s.titleize} inventory...Complete - Count: [#{inv_hash.blank? ? 0 : inv_hash.length}]")
        end
      end

      # Merge Virtual Apps into Resource Pools
      if @vc_data.has_key?(:vapp)
        @vc_data[:rp] ||= {}
        @vc_data[:rp].merge!(@vc_data.delete(:vapp))
      end

      EmsRefresh.log_inv_debug_trace(@vc_data, "#{log_header} @vc_data:", 2)
    end

    def get_vc_data_ems_customization_specs
      log_header = "MIQ(VcRefresher.get_vc_data_ems_customization_specs) EMS: [#{@ems.name}], id: [#{@ems.id}]"

      cleanup_callback = Proc.new { @vc_data = nil }

      retrieve_from_vc(cleanup_callback) do
        $log.info("#{log_header} Retrieving Customization Spec inventory...")
        begin
          vim_csm = @vi.getVimCustomizationSpecManager
          @vc_data[:customization_specs] = vim_csm.getAllCustomizationSpecs
        rescue RuntimeError => err
          raise unless err.message.include?("not supported on this system")
          $log.info("#{log_header} #{err}")
        ensure
          vim_csm.release if vim_csm rescue nil
        end
        $log.info("#{log_header} Retrieving Customization Spec inventory...Complete - Count: [#{@vc_data[:customization_specs].length}]")

        EmsRefresh.log_inv_debug_trace(@vc_data[:customization_specs], "#{log_header} customization_spec_inv:")
      end
    end

    def get_vc_data_host_scsi(host_mors)
      log_header = "MIQ(VcRefresher.get_vc_data_host_scsi) EMS: [#{@ems.name}], id: [#{@ems.id}]"
      return $log.info("#{log_header} Not retrieving Storage Device inventory for hosts...") if host_mors.empty?

      cleanup_callback = Proc.new { @vc_data = nil }

      retrieve_from_vc(cleanup_callback) do
        $log.info("#{log_header} Retrieving Storage Device inventory for [#{host_mors.length}] hosts...")
        host_mors.each do |mor|
          data = @vc_data.fetch_path(:host, mor)
          next if data.nil?

          $log.info("#{log_header} Retrieving Storage Device inventory for Host [#{mor}]...")
          begin
            vim_host = @vi.getVimHostByMor(mor)
            sd = vim_host.storageDevice(:ems_refresh_host_scsi)
            data.store_path('config', 'storageDevice', sd.fetch_path('config', 'storageDevice')) unless sd.nil?
          ensure
            vim_host.release if vim_host rescue nil
          end
          $log.info("#{log_header} Retrieving Storage Device inventory for Host [#{mor}]...Complete")
        end
        $log.info("#{log_header} Retrieving Storage Device inventory for [#{host_mors.length}] hosts...Complete")

        EmsRefresh.log_inv_debug_trace(@vc_data[:host], "#{log_header} host_inv:")
      end
    end

    def get_ems_data
      log_header = "MIQ(VcRefresher.get_ems_data) EMS: [#{@ems.name}], id: [#{@ems.id}]"

      cleanup_callback = Proc.new { @ems_data = nil }

      retrieve_from_vc(cleanup_callback) do
        $log.info("#{log_header} Retrieving EMS information...")
        about = @vi.about
        @ems_data = {:api_version => about['apiVersion'], :uid_ems => about['instanceUuid']}
        $log.info("#{log_header} Retrieving EMS information...Complete")
      end

      EmsRefresh.log_inv_debug_trace(@ems_data, "#{log_header} ext_management_system_inv:")
    end

    MAX_RETRIES = 5
    RETRY_SLEEP_TIME = 30 #seconds

    def retrieve_from_vc(cleanup_callback = nil)
      return unless block_given?

      log_header = "MIQ(VcRefresher.retrieve_from_vc) EMS: [#{@ems.name}], id: [#{@ems.id}]"

      retries = 0
      begin
        @vi ||= @ems.connect
        yield
      rescue HTTPAccess2::Session::KeepAliveDisconnected => httperr
        # Handle this error by trying again multiple times and sleeping between attempts
        $log.log_backtrace(httperr)

        cleanup_callback.call unless cleanup_callback.nil?

        unless retries >= MAX_RETRIES
          retries += 1

          # disconnect before trying again
          disconnect_from_ems

          $log.warn("#{log_header} Abnormally disconnected from VC...Retrying in #{RETRY_SLEEP_TIME} seconds")
          sleep RETRY_SLEEP_TIME
          $log.warn("#{log_header} Beginning EMS refresh retry \##{retries}")
          retry
        end

        # after MAX_RETRIES, give up...
        raise "EMS: [#{@ems.name}] Exhausted all #{MAX_RETRIES} retries."
      rescue Exception
        cleanup_callback.call unless cleanup_callback.nil?
        raise
      end
    end

    def disconnect_from_ems
      return if @vi.nil?
      $log.info("MIQ(VcRefresher.disconnect_from_ems) Disconnecting from EMS: [#{@ems.name}], id: [#{@ems.id}]...")
      @vi.disconnect
      @vi = nil
      $log.info("MIQ(VcRefresher.disconnect_from_ems) Disconnecting from EMS: [#{@ems.name}], id: [#{@ems.id}]...Complete")
    end

    VC_ACCESSORS_BY_MOR = {
      :storage  => :dataStoreByMor,
      :host     => :hostSystemByMor,
      :vm       => :virtualMachineByMor,
      :dc       => :datacenterByMor,
      :folder   => :folderByMor,
      :cluster  => :clusterComputeResourceByMor,
      :host_res => :computeResourceByMor,
      :rp       => :resourcePoolByMor,
      :vapp     => :virtualAppByMor
    }

    def get_vc_data_by_mor(type, mor)
      log_header = "MIQ(VcRefresher.get_vc_data_by_mor) EMS: [#{@ems.name}], id: [#{@ems.id}]"

      accessor = VC_ACCESSORS_BY_MOR[type]
      raise ArgumentError, "Invalid type" if accessor.nil?

      mor = [mor] unless mor.kind_of?(Array)

      cleanup_callback = Proc.new { @vc_data = nil }

      retrieve_from_vc(cleanup_callback) do
        @vc_data = Hash.new { |h, k| h[k] = Hash.new } if @vc_data.nil?

        $log.info("#{log_header} Retrieving #{type.to_s.titleize} inventory...")
        inv_hash = mor.each_with_object({}) do |m, h|
          data = @vi.send(accessor, m)
          h[m] = data unless data.nil?
        end
        EmsRefresh.log_inv_debug_trace(inv_hash, "#{log_header} inv_hash:")

        @vc_data[type] = inv_hash unless inv_hash.blank?
        $log.info("#{log_header} Retrieving #{type.to_s.titleize} inventory...Complete - Count: [#{inv_hash.blank? ? 0 : inv_hash.length}]")
      end
    end

    #
    # Inventory refresh for Reconfigure VM Task event
    #

    public

    def self.reconfig_refresh(vm)
      self.new([vm]).reconfig_refresh
    end

    def reconfig_refresh
      log_header = "MIQ(VcRefresher.reconfig_refresh)"

      ems_id = @targets_by_ems_id.keys.first
      vm = @targets_by_ems_id[ems_id].first
      @ems = vm.ext_management_system

      $log.info "#{log_header} Refreshing target VM for reconfig..."
      $log.info "#{log_header}   #{vm.class}: [#{vm.name}], id: [#{vm.id}]"

      dummy, timings = Benchmark.realtime_block(:total_time) do
        Benchmark.realtime_block(:get_vc_data_total) do
          begin
            get_vc_data_by_mor(:vm, vm.ems_ref_obj)
            get_vc_data_by_mor(:host, vm.host.ems_ref_obj)
            get_vc_data_by_mor(:storage, vm.host.storages.collect(&:ems_ref_obj))
          ensure
            disconnect_from_ems
          end
        end

        $log.debug "#{log_header} Parsing VC inventory..."
        hashes, = Benchmark.realtime_block(:parse_vc_data) do
          EmsRefresh::Parsers::Vc.reconfig_inv_to_hashes(@vc_data)
        end
        $log.debug "#{log_header} Parsing VC inventory...Complete"

        Benchmark.realtime_block(:db_save_inventory) do
          EmsRefresh.reconfig_save_vm_inventory(vm, hashes)
        end
      end

       $log.info "#{log_header} Refreshing target VM for reconfig...Complete - Timings: #{timings.inspect}"
    end
  end
end
