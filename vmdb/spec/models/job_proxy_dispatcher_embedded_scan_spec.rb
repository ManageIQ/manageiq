require "spec_helper"

module JobProxyDispatcherEmbeddedScanSpec
  describe "dispatch embedded" do
    require File.expand_path(File.join(File.dirname(__FILE__), 'job_proxy_dispatcher/job_proxy_dispatcher_helper'))
    include JobProxyDispatcherHelper

    NUM_VMS = 5
    NUM_REPO_VMS = 0
    NUM_HOSTS = 3
    NUM_SERVERS = 3
    NUM_COS_PROXIES = 0
    NUM_STORAGES = 3

    def assert_at_most_x_scan_jobs_per_y_resource(x_scans, y_resource)
      vms_in_embedded_scanning = Job.where(["dispatch_status = ? AND state != ? AND agent_class = ? AND target_class = ?", "active", "finished", "MiqServer", "VmOrTemplate"]).select("target_id").collect(&:target_id).compact.uniq
      vms_in_embedded_scanning.length.should > 0

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
        vms = VmOrTemplate.find_all_by_id(vms_in_embedded_scanning)
        resource_hsh = vms.inject({}) do |hsh, v|
          hsh[v.send(method)] ||= 0
          hsh[v.send(method)] += 1
          hsh
        end
      end

      resource_hsh.values.detect {|count| count > 0 }.should be_true, "Expected at least one #{y_resource} resource with more than 0 scan jobs. resource_hash: #{resource_hsh.inspect}"
      resource_hsh.values.detect {|count| count > x_scans}.should be_nil, "Expected no #{y_resource} resource with more than #{x_scans} scan jobs. resource_hash: #{resource_hsh.inspect}"
    end

    context "With a zone, server, ems, hosts, vmware vms" do
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
        EmsVmware.any_instance.stub(:authentication_status_ok? => true)
        Host.any_instance.stub(:authentication_status_ok? => true)
        MiqProxy.any_instance.stub(:state).and_return("on")

        @hosts, @proxies, @storages, @vms, @repo_vms = self.build_hosts_proxies_storages_vms(:hosts => NUM_HOSTS, :proxies => NUM_COS_PROXIES, :storages => NUM_STORAGES, :vms => NUM_VMS, :repo_vms => NUM_REPO_VMS)
      end

      context "and a scan job for each vm" do
        before(:each) do
          MiqVimBrokerWorker.stub(:available_in_zone?).and_return(true)
          #JobProxyDispatcher.stub(:start_job_on_proxy).and_return(nil)

          @jobs = @vms.collect(&:scan)
        end

        context "and embedded scans on ems" do
          before(:each) do
            VmVmware.stub(:scan_via_ems?).and_return(true)
          end

          context "and scans against ems limited to 2 and up to 10 scans per miqserver" do
            before(:each) do
              MiqServer.any_instance.stub(:concurrent_job_max).and_return(10)
              JobProxyDispatcher.stub(:coresident_miqproxy).and_return({:concurrent_per_ems => 2})
            end

            it "should dispatch only 2 scan jobs per ems"  do
              JobProxyDispatcher.dispatch
              self.assert_at_most_x_scan_jobs_per_y_resource(2, :ems)
            end

            it "should signal 2 jobs to start" do
              JobProxyDispatcher.dispatch
              expect(MiqQueue.count).to eq(2)
            end
          end

          context "and scans against ems limited to 4 and up to 10 scans per miqserver" do
            before(:each) do
              MiqServer.any_instance.stub(:concurrent_job_max).and_return(10)
              JobProxyDispatcher.stub(:coresident_miqproxy).and_return({:concurrent_per_ems => 4})
            end

            it "should dispatch only 4 scan jobs per ems"  do
              JobProxyDispatcher.dispatch
              self.assert_at_most_x_scan_jobs_per_y_resource(4, :ems)
            end
          end

          context "and scans against ems limited to 4 and up to 2 scans per miqserver" do
            before(:each) do
              MiqServer.any_instance.stub(:concurrent_job_max).and_return(2)
              JobProxyDispatcher.stub(:coresident_miqproxy).and_return({:concurrent_per_ems => 4})
            end

            it "should dispatch up to 4 per ems and 2 per miqserver"  do
              JobProxyDispatcher.dispatch
              self.assert_at_most_x_scan_jobs_per_y_resource(4, :ems)
              self.assert_at_most_x_scan_jobs_per_y_resource(2, :miq_server)
            end
          end
        end

        context "and embedded scans on hosts" do
          before(:each) do
            VmVmware.stub(:scan_via_ems?).and_return(false)
          end

          context "and scans against host limited to 2 and up to 10 scans per miqserver" do
            before(:each) do
              MiqServer.any_instance.stub(:concurrent_job_max).and_return(10)
              JobProxyDispatcher.stub(:coresident_miqproxy).and_return({:concurrent_per_host => 2})
            end

            it "should dispatch only 2 scan jobs per host"  do
              JobProxyDispatcher.dispatch
              self.assert_at_most_x_scan_jobs_per_y_resource(2, :host)
            end
          end

          context "and scans against host limited to 4 and up to 10 scans per miqserver" do
            before(:each) do
              MiqServer.any_instance.stub(:concurrent_job_max).and_return(10)
              JobProxyDispatcher.stub(:coresident_miqproxy).and_return({:concurrent_per_host => 4})
            end

            it "should dispatch only 4 scan jobs per host"  do
              JobProxyDispatcher.dispatch
              self.assert_at_most_x_scan_jobs_per_y_resource(4, :host)
            end
          end

          context "and scans against host limited to 4 and up to 2 scans per miqserver" do
            before(:each) do
              MiqServer.any_instance.stub(:concurrent_job_max).and_return(2)
              JobProxyDispatcher.stub(:coresident_miqproxy).and_return({:concurrent_per_host => 4})
            end

            it "should dispatch up to 4 per host and 2 per miqserver"  do
              JobProxyDispatcher.dispatch
              self.assert_at_most_x_scan_jobs_per_y_resource(4, :host)
              self.assert_at_most_x_scan_jobs_per_y_resource(2, :miq_server)
            end
          end
        end
      end
    end
  end
end
