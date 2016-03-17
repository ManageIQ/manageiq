module JobProxyDispatcherSpec
  describe "dispatch" do
    require File.expand_path(File.join(File.dirname(__FILE__), 'job_proxy_dispatcher/job_proxy_dispatcher_helper'))
    include JobProxyDispatcherHelper

    DISPATCH_ONLY = false
    if DISPATCH_ONLY
      NUM_VMS = 200
      NUM_REPO_VMS = 200
      NUM_HOSTS = 10
      NUM_SERVERS = 10
      NUM_STORAGES = 30
    else
      NUM_VMS = 3
      NUM_REPO_VMS = 3
      NUM_HOSTS = 3
      NUM_SERVERS = 3
      NUM_STORAGES = 3
    end

    context "With a default zone, server, with hosts with a miq_proxy, vmware vms on storages" do
      before(:each) do
        @server = EvmSpecHelper.local_miq_server(:name => "test_server_main_server")

        (NUM_SERVERS - 1).times do |i|
          FactoryGirl.create(:miq_server, :zone => @server.zone, :name => "test_server_#{i}")
        end

        # TODO: We should be able to set values so we don't need to stub behavior
        allow_any_instance_of(MiqServer).to receive_messages(:is_vix_disk? => true)
        allow_any_instance_of(MiqServer).to receive_messages(:is_a_proxy? => true)
        allow_any_instance_of(MiqServer).to receive_messages(:has_active_role? => true)
        allow_any_instance_of(ManageIQ::Providers::Vmware::InfraManager).to receive_messages(:missing_credentials? => false)
        allow_any_instance_of(Host).to receive_messages(:missing_credentials? => false)

        @hosts, @proxies, @storages, @vms, @repo_vms = build_hosts_proxies_storages_vms(:hosts => NUM_HOSTS, :storages => NUM_STORAGES, :vms => NUM_VMS, :repo_vms => NUM_REPO_VMS)
      end

      # Don't run these tests if we only want to run dispatch for load testing
      unless DISPATCH_ONLY
        it "should have a server in default zone" do
          expect(@server.zone).not_to be_nil
          expect(@server).not_to be_nil
        end

        it "should have #{NUM_HOSTS} hosts" do
          expect(NUM_HOSTS).to eq(@hosts.length)
        end

        it "should have #{NUM_VMS} vms and #{NUM_REPO_VMS} repo vms" do
          expect(NUM_VMS).to eq(@vms.length)
        end

        it "should have #{NUM_REPO_VMS} repo vms" do
          expect(NUM_REPO_VMS).to eq(@repo_vms.length)
        end

        context "with a vm without a storage" do
          before(:each) do
            # Test a vm without a storage (ie, removed from VC but retained in the VMDB)
            allow(MiqVimBrokerWorker).to receive(:available_in_zone?).and_return(true)
            @vm = @vms.first
            @vm.storage = nil
            @vm.save
            @vm.scan
          end

          it "should expect queue_signal and dispatch without errors" do
            dispatcher = JobProxyDispatcher.new
            expect(dispatcher).to receive(:queue_signal)
            expect { dispatcher.dispatch }.not_to raise_error
          end
        end

        context "with a Microsoft vm without a storage" do
          before(:each) do
            # Test a Microsoft vm without a storage
            allow(MiqVimBrokerWorker).to receive(:available_in_zone?).and_return(true)
            @vm = @vms.first
            @vm.storage = nil
            @vm.vendor = "microsoft"
            @vm.save
            @vm.scan
          end

          it "should run dispatch without calling queue_signal" do
            dispatcher = JobProxyDispatcher.new
            expect(dispatcher).not_to receive(:queue_signal)
          end
        end

        context "with a Microsoft vm with a Microsoft storage" do
          before(:each) do
            # Test a Microsoft vm without a storage
            allow(MiqVimBrokerWorker).to receive(:available_in_zone?).and_return(true)
            @vm = @vms.first
            @vm.storage.store_type = "CSVFS"
            @vm.vendor = "microsoft"
            @vm.save
            @vm.scan
          end

          it "should run dispatch without calling queue_signal" do
            dispatcher = JobProxyDispatcher.new
            expect(dispatcher).not_to receive(:queue_signal)
          end
        end

        context "with a Microsoft vm with an invalid storage" do
          before(:each) do
            # Test a Microsoft vm without a storage
            allow(MiqVimBrokerWorker).to receive(:available_in_zone?).and_return(true)
            @vm = @vms.first
            @vm.storage.store_type = "XFS"
            @vm.vendor = "microsoft"
            @vm.save
            @vm.scan
          end

          it "should expect queue_signal and dispatch without errors" do
            dispatcher = JobProxyDispatcher.new
            expect(dispatcher).to receive(:queue_signal)
            expect { dispatcher.dispatch }.not_to raise_error
          end
        end
      end

      context "with jobs, a default smartproxy for repo scanning" do
        before(:each) do
          allow(MiqVimBrokerWorker).to receive(:available?).and_return(true)
          # JobProxyDispatcher.stub(:start_job_on_proxy).and_return(nil)
          # MiqProxy.any_instance.stub(:concurrent_job_max).and_return(1)
          @repo_proxy = @proxies.last
          if @repo_proxy
            @repo_proxy.name = "repo_proxy"
            @repo_proxy.save
            @repo_proxy.host.name = "repo_host"
            @repo_proxy.host.save
            cfg = VMDB::Config.new("vmdb")
            cfg.config.store_path(:repository_scanning, :defaultsmartproxy, @repo_proxy.id)
            allow(VMDB::Config).to receive(:new).and_return(cfg)
          end
          @jobs = (@vms + @repo_vms).collect(&:scan)
        end

        # Don't run these tests if we only want to run dispatch for load testing
        unless DISPATCH_ONLY
          if @repo_proxy
            it "should have repository host set" do
              expect(@repo_vms.first.myhost.id).to eq(@repo_proxy.host_id)
            end
          end

          it "should have #{NUM_VMS + NUM_REPO_VMS} jobs" do
            total = NUM_VMS + NUM_REPO_VMS
            expect(@jobs.length).to eq(total)
          end
        end

        it "should run dispatch" do
          expect { JobProxyDispatcher.dispatch }.not_to raise_error
        end

        it "dispatch should handle a job with a deleted target VM" do
          @job = Job.first
          @job.target_id = 999999
          @job.save!
          expect { JobProxyDispatcher.dispatch }.not_to raise_error
          @job.reload
          expect(@job.state).to eq("finished")
          expect(@job.status).to eq("warn")
        end
      end
    end
  end
end
