require "spec_helper"

describe "JobProxyDispatcherVmStorage2Proxies" do
  require File.expand_path(File.join(File.dirname(__FILE__), 'job_proxy_dispatcher/job_proxy_dispatcher_helper'))
  include JobProxyDispatcherHelper

  context "two vix disk enabled servers," do
    before(:each) do
      @guid = MiqUUID.new_guid
      MiqServer.stub(:my_guid => @guid)
      @zone = FactoryGirl.create(:zone)
      @server1 = FactoryGirl.create(:miq_server, :zone => @zone, :guid => @guid, :status => "started")
      MiqServer.my_server(true)
      @server2 = FactoryGirl.create(:miq_server, :zone => @zone, :guid => MiqUUID.new_guid, :status => "started")
      MiqServer.any_instance.stub(:is_vix_disk? => true)
    end

    context "hosts with proxy and vmware vms," do
      before(:each) do
        @hosts, @proxies, @storages, @vms = self.build_hosts_proxies_storages_vms
        @vm = @vms.first
      end

      context "the vm having a repository host," do
        before(:each) do
          @repo_host = @hosts.last
          @vm.stub(:myhost => @repo_host)
        end

        context "removing proxy from a host" do
          before(:each) do
            @host = @hosts.first
            @host.miq_proxy = nil
            @host.save
            @repo_host.miq_proxy = nil
            @repo_host.save

            @vm.host = @host
            @vm.vendor = "RedHat"
            @vm.save
            @vm.stub(:miq_server_proxies => [])
          end

          it "Vm#storage2proxies will exclude proxy-less hosts" do
            @vm.storage2proxies.should be_empty
          end
        end

        context "vm's storage having no hosts," do
          before(:each) do
            store = @vm.storage
            store.hosts = []
            store.save
          end
          context "repo host's proxy inactive" do
            before(:each) do
              repo_proxy = @repo_host.miq_proxy
              repo_proxy.last_heartbeat = Time.at(0)
              repo_proxy.save
            end

            it "Vm#storage2active_proxies will exclude all proxies" do
              @vm.storage2active_proxies.should be_empty
            end
          end

          context "'smartproxy' server and roles deactivated" do
            before(:each) do
              # Overwrite so that we set our own assigned roles instead of from config file
              MiqServer.any_instance.stub(:set_assigned_roles).and_return(nil)
              MiqServer.any_instance.stub(:sync_workers).and_return(nil)
              MiqServer.any_instance.stub(:sync_log_level).and_return(nil)
              MiqServer.any_instance.stub(:wait_for_started_workers).and_return(nil)

              server_roles = [FactoryGirl.create(:server_role, :name => "smartproxy", :max_concurrent => 0)]

              MiqServer.my_server(true)
              @server1.deactivate_all_roles
              @server1.role    = 'smartproxy'
              Host.any_instance.stub(:missing_credentials? => false)
            end

            it "will have no roles active" do
              @server1.server_roles.length.should == 1
              @server1.inactive_roles.length.should == 1
              @server1.active_roles.length.should == 0
            end

            it "MiqServer#is_proxy_active? will be false" do
              @server1.is_proxy_active?.should_not be_true
            end

            it "Vm#storage2active_proxies will not be eligible to scan vms" do
              $log.info("XXX @server1.is_proxy_active?: #{@server1.is_proxy_active?}")
              $log.info("XXX @server1.started?: #{@server1.started?}")
              $log.info("XXX @server1.has_active_role?(:SmartProxy): #{@server1.has_active_role?(:SmartProxy)}")
              @vm.storage2active_proxies.should_not include(@server1)
            end
          end

          context "with server proxies active," do
            before(:each) do
              MiqServer.any_instance.stub(:is_proxy_active? => true)
              @vm.stub(:my_zone).and_return(@zone.name)
            end

            context "a vm template and invalid VC authentication" do
              before(:each) do
                EmsVmware.any_instance.stub(:missing_credentials? => true)
                @vm.stub(:template? => true)
                @ems1 = FactoryGirl.create(:ems_vmware, :name => "Ems1")
                @vm.ext_management_system = @ems1
                @vm.save
              end
              it "Vm#storage2active_proxies will return only repo host" do
                @vm.storage2active_proxies.should == [@repo_host]
              end
            end

            context "a vm and invalid host authentication" do
              before(:each) do
                Host.any_instance.stub(:missing_credentials? => true)
                @vm.stub(:template? => false)
              end
              it "Vm#storage2active_proxies will return only repo host" do
                @vm.storage2active_proxies.should == [@repo_host]
              end
            end
          end

        end
      end

    end
  end
end
