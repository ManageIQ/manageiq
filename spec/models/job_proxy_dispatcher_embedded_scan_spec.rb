describe "JobProxyDispatcherEmbeddedScanSpec" do
  describe "dispatch embedded" do
    include Spec::Support::JobProxyDispatcherHelper

    NUM_OF_VMS = 5
    NUM_OF_REPO_VMS = 0
    NUM_OF_HOSTS = 3
    NUM_OF_SERVERS = 3
    NUM_OF_STORAGES = 3

    def assert_at_most_x_scan_jobs_per_y_resource(x_scans, y_resource)
      vms_in_embedded_scanning = Job.where(["dispatch_status = ? AND state != ? AND target_class = ?", "active", "finished", "VmOrTemplate"])
                                    .pluck(:target_id).compact.uniq
      expect(vms_in_embedded_scanning.length).to be > 0

      method = case y_resource
               when :ems then 'ems_id'
               when :host then 'host_id'
               when :miq_server then 'target_id'
               end

      if y_resource == :miq_server
        resource_hsh = vms_in_embedded_scanning.inject({}) do |hsh, target_id|
          hsh[target_id] ||= 0
          hsh[target_id] += 1
          hsh
        end
      else
        vms = VmOrTemplate.where(:id => vms_in_embedded_scanning)
        resource_hsh = vms.inject({}) do |hsh, v|
          hsh[v.send(method)] ||= 0
          hsh[v.send(method)] += 1
          hsh
        end
      end

      expect(resource_hsh.values.detect { |count| count > 0 }).to be_truthy, "Expected at least one #{y_resource} resource with more than 0 scan jobs. resource_hash: #{resource_hsh.inspect}"
      expect(resource_hsh.values.detect { |count| count > x_scans }).to be_nil, "Expected no #{y_resource} resource with more than #{x_scans} scan jobs. resource_hash: #{resource_hsh.inspect}"
    end

    context "With a zone, server, ems, hosts, vmware vms" do
      let(:zone) { FactoryGirl.create(:zone) }
      before do
        server = EvmSpecHelper.local_miq_server(:is_master => true, :name => "test_server_main_server", :zone => zone)
        (NUM_OF_SERVERS - 1).times do |i|
          FactoryGirl.create(:miq_server, :zone => server.zone, :name => "test_server_#{i}")
        end

        # TODO: We should be able to set values so we don't need to stub behavior
        allow_any_instance_of(MiqServer).to receive_messages(:is_vix_disk? => true)
        allow_any_instance_of(MiqServer).to receive_messages(:is_a_proxy? => true)
        allow_any_instance_of(MiqServer).to receive_messages(:has_active_role? => true)
        allow_any_instance_of(ManageIQ::Providers::Vmware::InfraManager).to receive_messages(:authentication_status_ok? => true)
        allow_any_instance_of(Host).to receive_messages(:authentication_status_ok? => true)

        @hosts, @proxies, @storages, @vms, @repo_vms = build_entities(
          :hosts    => NUM_OF_HOSTS,
          :storages => NUM_OF_STORAGES,
          :vms      => NUM_OF_VMS,
          :repo_vms => NUM_OF_REPO_VMS,
          :zone     => zone,
        )
      end

      context "and a scan job for each vm" do
        before do
          allow(MiqVimBrokerWorker).to receive(:available_in_zone?).and_return(true)

          @jobs = @vms.collect(&:raw_scan)
        end

        context "and embedded scans on ems" do
          context "and scans against ems limited to 2 and up to 10 scans per miqserver" do
            it "should dispatch only 2 scan jobs per ems"  do
              allow(ManageIQ::Providers::Vmware::InfraManager::Vm).to receive(:scan_via_ems?).and_return(true)
              JobProxyDispatcher.dispatch
              assert_at_most_x_scan_jobs_per_y_resource(2, :ems)
            end

            it "should signal 2 jobs to start" do
              stub_settings(:coresident_miqproxy => {:concurrent_per_ems => 2},
                            :ems                 => {:ems_amazon => {}})
              JobProxyDispatcher.dispatch
              expect(MiqQueue.count).to eq(2)
            end
          end

          context "and scans against ems limited to 4 and up to 10 scans per miqserver" do
            it "should dispatch only 4 scan jobs per ems"  do
              JobProxyDispatcher.dispatch
              assert_at_most_x_scan_jobs_per_y_resource(4, :ems)
            end
          end

          context "and scans against ems limited to 4 and up to 2 scans per miqserver" do
            it "should dispatch up to 4 per ems and 2 per miqserver"  do
              JobProxyDispatcher.dispatch
              assert_at_most_x_scan_jobs_per_y_resource(4, :ems)
              assert_at_most_x_scan_jobs_per_y_resource(2, :miq_server)
            end
          end
        end

        context "and embedded scans on hosts" do
          before do
            allow(ManageIQ::Providers::Vmware::InfraManager::Vm).to receive(:scan_via_ems?).and_return(false)
          end

          context "and scans against host limited to 2 and up to 10 scans per miqserver" do
            it "should dispatch only 2 scan jobs per host"  do
              JobProxyDispatcher.dispatch
              assert_at_most_x_scan_jobs_per_y_resource(2, :host)
            end
          end

          context "and scans against host limited to 4 and up to 10 scans per miqserver" do
            it "should dispatch only 4 scan jobs per host"  do
              JobProxyDispatcher.dispatch
              assert_at_most_x_scan_jobs_per_y_resource(4, :host)
            end
          end

          context "and scans against host limited to 4 and up to 2 scans per miqserver" do
            it "should dispatch up to 4 per host and 2 per miqserver"  do
              JobProxyDispatcher.dispatch
              assert_at_most_x_scan_jobs_per_y_resource(4, :host)
              assert_at_most_x_scan_jobs_per_y_resource(2, :miq_server)
            end
          end
        end
      end
    end
  end
end
