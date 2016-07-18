require 'MiqVim'
require 'http-access2' # Required in case it is not already loaded

module ManageIQ::Providers
  module Vmware
    class InfraManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
      include EmsRefresh::Refreshers::EmsRefresherMixin
      include InfraManager::RefreshParser::Filter

      # Development helper method for setting up the selector specs for VC
      def self.init_console(use_vim_broker = false)
        return @initialized_console unless @initialized_console.nil?
        provider = parent
        provider.instance_variable_set(:@__use_vim_broker, use_vim_broker)
        def provider.use_vim_broker?; @__use_vim_broker; end
        klass = use_vim_broker ? MiqVimBroker : MiqVimInventory
        klass.cacheScope = :cache_scope_ems_refresh
        klass.setSelector(EmsRefresh::VcUpdates::VIM_SELECTOR_SPEC)
        @initialized_console = true
      end

      def collect_inventory_for_targets(ems, targets)
        Benchmark.realtime_block(:get_ems_data) { get_ems_data(ems) }
        Benchmark.realtime_block(:get_vc_data) { get_vc_data(ems) }

        Benchmark.realtime_block(:get_vc_data_ems_customization_specs) { get_vc_data_ems_customization_specs(ems) } if targets.include?(ems)

        # Filter the data, and determine for which hosts we will need to get extended data
        filtered_host_mors = []
        targets_with_data = targets.collect do |target|
          filtered_data, = Benchmark.realtime_block(:filter_vc_data) { filter_vc_data(ems, target) }
          filtered_host_mors += filtered_data[:host].keys
          [target, filtered_data]
        end
        filtered_host_mors.uniq!

        Benchmark.realtime_block(:get_vc_data_host_scsi) { get_vc_data_host_scsi(ems, filtered_host_mors) }

        return targets_with_data
      ensure
        disconnect_from_ems(ems)
      end

      def parse_targeted_inventory(ems, _target, inventory)
        log_header = format_ems_for_logging(ems)
        _log.debug "#{log_header} Parsing VC inventory..."
        hashes, = Benchmark.realtime_block(:parse_vc_data) do
          InfraManager::RefreshParser.ems_inv_to_hashes(inventory)
        end
        _log.debug "#{log_header} Parsing VC inventory...Complete"

        hashes
      end

      def save_inventory(ems, target, hashes)
        Benchmark.realtime_block(:db_save_inventory) do
          # TODO: really wanna kill this @ems_data instance var
          ems.update_attributes(@ems_data) unless @ems_data.nil?
          EmsRefresh.save_ems_inventory(ems, hashes, target)
        end
      end

      def post_refresh(ems, start_time)
        log_header = format_ems_for_logging(ems)
        [VmOrTemplate, Host].each do |klass|
          next unless klass.respond_to?(:post_refresh_ems)
          _log.info "#{log_header} Performing post-refresh operations for #{klass} instances..."
          klass.post_refresh_ems(ems.id, start_time)
          _log.info "#{log_header} Performing post-refresh operations for #{klass} instances...Complete"
        end
      end

      #
      # VC data collection methods
      #

      VC_ACCESSORS = [
        [:dataStoresByMor,              :storage],
        [:storagePodsByMor,             :storage_pod],
        [:pbmProfilesByUid,             :storage_profile],
        [:dvPortgroupsByMor,            :dvportgroup],
        [:dvSwitchesByMor,              :dvswitch],
        [:hostSystemsByMor,             :host],
        [:virtualMachinesByMor,         :vm],
        [:datacentersByMor,             :dc],
        [:foldersByMor,                 :folder],
        [:clusterComputeResourcesByMor, :cluster],
        [:computeResourcesByMor,        :host_res],
        [:resourcePoolsByMor,           :rp],
        [:virtualAppsByMor,             :vapp]
      ]

      def get_vc_data(ems)
        log_header = format_ems_for_logging(ems)

        cleanup_callback = proc { @vc_data = nil }

        retrieve_from_vc(ems, cleanup_callback) do
          @vc_data = Hash.new { |h, k| h[k] = {} }

          VC_ACCESSORS.each do |acc, type|
            _log.info("#{log_header} Retrieving #{type.to_s.titleize} inventory...")
            inv_hash = @vi.send(acc, :"ems_refresh_#{type}")
            EmsRefresh.log_inv_debug_trace(inv_hash, "#{_log.prefix} #{log_header} inv_hash:")

            @vc_data[type] = inv_hash unless inv_hash.blank?
            _log.info("#{log_header} Retrieving #{type.to_s.titleize} inventory...Complete - Count: [#{inv_hash.blank? ? 0 : inv_hash.length}]")
          end
        end

        # Merge Virtual Apps into Resource Pools
        if @vc_data.key?(:vapp)
          @vc_data[:rp] ||= {}
          @vc_data[:rp].merge!(@vc_data.delete(:vapp))
        end

        EmsRefresh.log_inv_debug_trace(@vc_data, "#{_log.prefix} #{log_header} @vc_data:", 2)
      end

      def get_vc_data_ems_customization_specs(ems)
        log_header = format_ems_for_logging(ems)

        cleanup_callback = proc { @vc_data = nil }

        retrieve_from_vc(ems, cleanup_callback) do
          _log.info("#{log_header} Retrieving Customization Spec inventory...")
          begin
            vim_csm = @vi.getVimCustomizationSpecManager
            @vc_data[:customization_specs] = vim_csm.getAllCustomizationSpecs
          rescue RuntimeError => err
            raise unless err.message.include?("not supported on this system")
            _log.info("#{log_header} #{err}")
          ensure
            vim_csm.release if vim_csm rescue nil
          end
          _log.info("#{log_header} Retrieving Customization Spec inventory...Complete - Count: [#{@vc_data[:customization_specs].length}]")

          EmsRefresh.log_inv_debug_trace(@vc_data[:customization_specs], "#{_log.prefix} #{log_header} customization_spec_inv:")
        end
      end

      def get_vc_data_host_scsi(ems, host_mors)
        log_header = format_ems_for_logging(ems)
        return _log.info("#{log_header} Not retrieving Storage Device inventory for hosts...") if host_mors.empty?

        cleanup_callback = proc { @vc_data = nil }

        retrieve_from_vc(ems, cleanup_callback) do
          _log.info("#{log_header} Retrieving Storage Device inventory for [#{host_mors.length}] hosts...")
          host_mors.each do |mor|
            data = @vc_data.fetch_path(:host, mor)
            next if data.nil?

            _log.info("#{log_header} Retrieving Storage Device inventory for Host [#{mor}]...")
            begin
              vim_host = @vi.getVimHostByMor(mor)
              sd = vim_host.storageDevice(:ems_refresh_host_scsi)
              data.store_path('config', 'storageDevice', sd.fetch_path('config', 'storageDevice')) unless sd.nil?
            ensure
              vim_host.release if vim_host rescue nil
            end
            _log.info("#{log_header} Retrieving Storage Device inventory for Host [#{mor}]...Complete")
          end
          _log.info("#{log_header} Retrieving Storage Device inventory for [#{host_mors.length}] hosts...Complete")

          EmsRefresh.log_inv_debug_trace(@vc_data[:host], "#{_log.prefix} #{log_header} host_inv:")
        end
      end

      def get_ems_data(ems)
        log_header = format_ems_for_logging(ems)

        cleanup_callback = proc { @ems_data = nil }

        retrieve_from_vc(ems, cleanup_callback) do
          _log.info("#{log_header} Retrieving EMS information...")
          about = @vi.about
          @ems_data = {:api_version => about['apiVersion'], :uid_ems => about['instanceUuid']}
          _log.info("#{log_header} Retrieving EMS information...Complete")
        end

        EmsRefresh.log_inv_debug_trace(@ems_data, "#{_log.prefix} #{log_header} ext_management_system_inv:")
      end

      MAX_RETRIES = 5
      RETRY_SLEEP_TIME = 30 # seconds

      def retrieve_from_vc(ems, cleanup_callback = nil)
        return unless block_given?

        log_header = format_ems_for_logging(ems)

        retries = 0
        begin
          @vi ||= ems.connect
          yield
        rescue HTTPAccess2::Session::KeepAliveDisconnected => httperr
          # Handle this error by trying again multiple times and sleeping between attempts
          _log.log_backtrace(httperr)

          cleanup_callback.call unless cleanup_callback.nil?

          unless retries >= MAX_RETRIES
            retries += 1

            # disconnect before trying again
            disconnect_from_ems(ems)

            _log.warn("#{log_header} Abnormally disconnected from VC...Retrying in #{RETRY_SLEEP_TIME} seconds")
            sleep RETRY_SLEEP_TIME
            _log.warn("#{log_header} Beginning EMS refresh retry \##{retries}")
            retry
          end

          # after MAX_RETRIES, give up...
          raise "EMS: [#{ems.name}] Exhausted all #{MAX_RETRIES} retries."
        rescue Exception
          cleanup_callback.call unless cleanup_callback.nil?
          raise
        end
      end

      def disconnect_from_ems(ems)
        return if @vi.nil?
        _log.info("Disconnecting from EMS: [#{ems.name}], id: [#{ems.id}]...")
        @vi.disconnect
        @vi = nil
        _log.info("Disconnecting from EMS: [#{ems.name}], id: [#{ems.id}]...Complete")
      end

      VC_ACCESSORS_BY_MOR = {
        :storage     => :dataStoreByMor,
        :network     => :networkByMor,
        :dvportgroup => :dvPortgroupByMor,
        :dvswitch    => :dvSwitchByMor,
        :host        => :hostSystemByMor,
        :vm          => :virtualMachineByMor,
        :dc          => :datacenterByMor,
        :folder      => :folderByMor,
        :cluster     => :clusterComputeResourceByMor,
        :host_res    => :computeResourceByMor,
        :rp          => :resourcePoolByMor,
        :vapp        => :virtualAppByMor
      }

      def get_vc_data_by_mor(ems, type, mor)
        log_header = format_ems_for_logging(ems)

        accessor = VC_ACCESSORS_BY_MOR[type]
        raise ArgumentError, "Invalid type" if accessor.nil?

        mor = [mor] unless mor.kind_of?(Array)

        cleanup_callback = proc { @vc_data = nil }

        retrieve_from_vc(ems, cleanup_callback) do
          @vc_data = Hash.new { |h, k| h[k] = {} } if @vc_data.nil?

          _log.info("#{log_header} Retrieving #{type.to_s.titleize} inventory...")
          inv_hash = mor.each_with_object({}) do |m, h|
            data = @vi.send(accessor, m)
            h[m] = data unless data.nil?
          end
          EmsRefresh.log_inv_debug_trace(inv_hash, "#{_log.prefix} #{log_header} inv_hash:")

          @vc_data[type] = inv_hash unless inv_hash.blank?
          _log.info("#{log_header} Retrieving #{type.to_s.titleize} inventory...Complete - Count: [#{inv_hash.blank? ? 0 : inv_hash.length}]")
        end
      end

      #
      # Inventory refresh for Reconfigure VM Task event
      #

      public

      def self.reconfig_refresh(vm)
        new([vm]).reconfig_refresh
      end

      def reconfig_refresh
        ems_id = @targets_by_ems_id.keys.first
        vm = @targets_by_ems_id[ems_id].first
        ems = vm.ext_management_system

        _log.info "Refreshing target VM for reconfig..."
        _log.info "#{vm.class}: [#{vm.name}], id: [#{vm.id}]"

        dummy, timings = Benchmark.realtime_block(:total_time) do
          Benchmark.realtime_block(:get_vc_data_total) do
            begin
              get_vc_data_by_mor(ems, :vm, vm.ems_ref_obj)
              get_vc_data_by_mor(ems, :host, vm.host.ems_ref_obj)
              get_vc_data_by_mor(ems, :storage, vm.host.storages.collect(&:ems_ref_obj))
            ensure
              disconnect_from_ems(ems)
            end
          end

          _log.debug "Parsing VC inventory..."
          hashes, = Benchmark.realtime_block(:parse_vc_data) do
            InfraManager::RefreshParser.reconfig_inv_to_hashes(@vc_data)
          end
          _log.debug "Parsing VC inventory...Complete"

          Benchmark.realtime_block(:db_save_inventory) do
            EmsRefresh.reconfig_save_vm_inventory(vm, hashes)
          end
        end

        _log.info "Refreshing target VM for reconfig...Complete - Timings: #{timings.inspect}"
      end
    end
  end
end
