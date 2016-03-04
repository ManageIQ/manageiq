describe "JobProxyDispatcherVmStorage2Proxies" do
  require File.expand_path(File.join(File.dirname(__FILE__), 'job_proxy_dispatcher/job_proxy_dispatcher_helper'))
  include JobProxyDispatcherHelper

  context "two vix disk enabled servers," do
    before(:each) do
      @server1 = EvmSpecHelper.local_miq_server(:is_master => true)
      @server2 = FactoryGirl.create(:miq_server, :zone => @server1.zone)
      allow_any_instance_of(MiqServer).to receive_messages(:is_vix_disk? => true)
    end

    context "hosts with proxy and vmware vms," do
      before(:each) do
        @hosts, @proxies, @storages, @vms = build_hosts_proxies_storages_vms
        @vm = @vms.first
      end

      context "the vm having a repository host," do
        before(:each) do
          @repo_host = @hosts.last
          allow(@vm).to receive_messages(:myhost => @repo_host)
        end

        context "removing proxy from a host" do
          before(:each) do
            @host = @hosts.first
            @host.save
            @repo_host.save

            @vm.host = @host
            @vm.vendor = "redhat"
            @vm.save
            allow(@vm).to receive_messages(:miq_server_proxies => [])
          end

          it "Vm#storage2proxies will exclude proxy-less hosts" do
            expect(@vm.storage2proxies).to be_empty
          end
        end

        context "vm's storage having no hosts," do
          before(:each) do
            store = @vm.storage
            store.hosts = []
            store.save
          end
          context "repo host's proxy inactive" do
            it "Vm#storage2active_proxies will exclude all proxies" do
              expect(@vm.storage2active_proxies).to be_empty
            end
          end

          context "'smartproxy' server and roles deactivated" do
            before(:each) do
              # Overwrite so that we set our own assigned roles instead of from config file
              allow_any_instance_of(MiqServer).to receive(:set_assigned_roles).and_return(nil)
              allow_any_instance_of(MiqServer).to receive(:sync_workers).and_return(nil)
              allow_any_instance_of(MiqServer).to receive(:sync_log_level).and_return(nil)
              allow_any_instance_of(MiqServer).to receive(:wait_for_started_workers).and_return(nil)

              server_roles = [FactoryGirl.create(:server_role, :name => "smartproxy", :max_concurrent => 0)]

              @server1.deactivate_all_roles
              @server1.role    = 'smartproxy'
              allow_any_instance_of(Host).to receive_messages(:missing_credentials? => false)
            end

            it "will have no roles active" do
              expect(@server1.server_roles.length).to eq(1)
              expect(@server1.inactive_roles.length).to eq(1)
              expect(@server1.active_roles.length).to eq(0)
            end

            it "MiqServer#is_proxy_active? will be false" do
              expect(@server1.is_proxy_active?).not_to be_truthy
            end

            it "Vm#storage2active_proxies will not be eligible to scan vms" do
              $log.info("XXX @server1.is_proxy_active?: #{@server1.is_proxy_active?}")
              $log.info("XXX @server1.started?: #{@server1.started?}")
              $log.info("XXX @server1.has_active_role?(:SmartProxy): #{@server1.has_active_role?(:SmartProxy)}")
              expect(@vm.storage2active_proxies).not_to include(@server1)
            end
          end

          context "with server proxies active," do
            before(:each) do
              allow_any_instance_of(MiqServer).to receive_messages(:is_proxy_active? => true)
              allow(@vm).to receive(:my_zone).and_return(@server1.zone.name)
            end

            context "a vm template and invalid VC authentication" do
              before(:each) do
                allow_any_instance_of(ManageIQ::Providers::Vmware::InfraManager).to receive_messages(:missing_credentials? => true)
                allow(@vm).to receive_messages(:template? => true)
                @ems1 = FactoryGirl.create(:ems_vmware, :name => "Ems1")
                @vm.ext_management_system = @ems1
                @vm.save
              end
              it "Vm#storage2active_proxies will return an empty list" do
                expect(@vm.storage2active_proxies).to be_empty
              end
            end

            context "a vm and invalid host authentication" do
              before(:each) do
                allow_any_instance_of(Host).to receive_messages(:missing_credentials? => true)
                allow(@vm).to receive_messages(:template? => false)
              end
              it "Vm#storage2active_proxies will return an empty list" do
                expect(@vm.storage2active_proxies).to be_empty
              end
            end
          end
        end
      end
    end
  end
end
