require "spec_helper"

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
        NUM_COS_PROXIES = (NUM_HOSTS - 1)
        NUM_STORAGES = 30
      else
        NUM_VMS = 3
        NUM_REPO_VMS = 3
        NUM_HOSTS = 3
        NUM_SERVERS = 3
        NUM_COS_PROXIES = (NUM_HOSTS - 1)
        NUM_STORAGES = 3
      end

      context "With a default zone, server, with hosts with a miq_proxy, vmware vms on storages" do
        before(:each) do
          @guid = MiqUUID.new_guid
          MiqServer.stub(:my_guid => @guid)
          @zone = FactoryGirl.create(:zone)
          @server = FactoryGirl.create(:miq_server, :zone => @zone, :guid => @guid, :name => "test_server_main_server")
          MiqServer.my_server(true)

          (NUM_SERVERS - 1).times do |i|
            FactoryGirl.create(:miq_server, :zone => @zone, :guid => MiqUUID.new_guid, :name => "test_server_#{i}")
          end

          #TODO: We should be able to set values so we don't need to stub behavior
          MiqServer.any_instance.stub(:is_vix_disk? => true)
          MiqServer.any_instance.stub(:is_a_proxy? => true)
          MiqServer.any_instance.stub(:has_active_role? => true)
          EmsVmware.any_instance.stub(:missing_credentials? => false)
          Host.any_instance.stub(:missing_credentials? => false)

          @hosts, @proxies, @storages, @vms, @repo_vms = self.build_hosts_proxies_storages_vms(:hosts => NUM_HOSTS, :proxies => NUM_COS_PROXIES, :storages => NUM_STORAGES, :vms => NUM_VMS, :repo_vms => NUM_REPO_VMS)
        end

        # Don't run these tests if we only want to run dispatch for load testing
        unless DISPATCH_ONLY
          it "should have a zone" do
            @zone.should_not be_nil
          end

          it "should have a server in default zone" do
            @server.should_not be_nil
            @zone.should == @server.zone
          end

          it "should have #{NUM_HOSTS} hosts" do
            NUM_HOSTS.should == @hosts.length
          end

          it "should have #{NUM_COS_PROXIES} active cos based proxies on hosts" do
            NUM_COS_PROXIES.should == @proxies.length
            #miqServers = self.class.miq_servers_for_scan.find_all { |svr| !svr.has_vm_scan_affinity? }
            host_proxies = @hosts.find_all(&:is_a_proxy?).length
            NUM_COS_PROXIES.should == host_proxies

            active_host_proxies = @hosts.find_all(&:is_proxy_active?).length
            NUM_COS_PROXIES.should == active_host_proxies
          end

          it "should have #{NUM_VMS} vms and #{NUM_REPO_VMS} repo vms" do
            NUM_VMS.should == @vms.length
          end

          it "should have #{NUM_REPO_VMS} repo vms" do
            NUM_REPO_VMS.should == @repo_vms.length
          end

          context "with a vm without a storage" do
            before(:each) do
              # Test a vm without a storage (ie, removed from VC but retained in the VMDB)
              MiqVimBrokerWorker.stub(:available_in_zone?).and_return(true)
              @vm = @vms.first
              @vm.storage = nil
              @vm.save
              @vm.scan
            end

            it "should expect queue_signal and dispatch without errors" do
              dispatcher = JobProxyDispatcher.new
              dispatcher.should_receive(:queue_signal)
              lambda {dispatcher.dispatch }.should_not raise_error
            end
          end
        end

        context "with jobs, a default smartproxy for repo scanning" do
          before(:each) do
            MiqVimBrokerWorker.stub(:available?).and_return(true)
            #JobProxyDispatcher.stub(:start_job_on_proxy).and_return(nil)
            #MiqProxy.any_instance.stub(:concurrent_job_max).and_return(1)
            @repo_proxy = @proxies.last
            if @repo_proxy
              @repo_proxy.name = "repo_proxy"
              @repo_proxy.save
              @repo_proxy.host.name = "repo_host"
              @repo_proxy.host.save
              cfg = VMDB::Config.new("vmdb")
              cfg.config.store_path(:repository_scanning, :defaultsmartproxy, @repo_proxy.id)
              VMDB::Config.stub(:new).and_return(cfg)
            end
            @jobs = (@vms + @repo_vms).collect(&:scan)

            MiqProxy.any_instance.stub(:state).and_return("on")
            #TODO: Create real contexts out of this
            #MiqServer.any_instance.stub(:concurrent_job_max).and_return(20)
          end

          # Don't run these tests if we only want to run dispatch for load testing
          unless DISPATCH_ONLY
            if @repo_proxy
              it "should have repository host set" do
                @repo_vms.first.myhost.id.should == @repo_proxy.host_id
              end
            end

            it "should have #{NUM_VMS + NUM_REPO_VMS} jobs" do
              total = NUM_VMS + NUM_REPO_VMS
              @jobs.length.should == total
            end
          end

          it "should run dispatch" do
            lambda {JobProxyDispatcher.dispatch }.should_not raise_error
          end

          it "dispatch should handle a job with a deleted target VM" do
            @job = Job.first
            @job.target_id = 999999
            @job.save!
            lambda {JobProxyDispatcher.dispatch }.should_not raise_error
            @job.reload
            @job.state.should  == "finished"
            @job.status.should == "warn"
          end
        end
      end
    end
  end
