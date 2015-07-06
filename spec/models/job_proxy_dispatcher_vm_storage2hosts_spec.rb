require "spec_helper"

describe "JobProxyDispatcherVmStorage2Hosts" do
  require File.expand_path(File.join(File.dirname(__FILE__), 'job_proxy_dispatcher/job_proxy_dispatcher_helper'))
  include JobProxyDispatcherHelper
  context "with two servers on same zone, vix disk enabled for all, " do
    before(:each) do
      @guid = MiqUUID.new_guid
      MiqServer.stub(:my_guid => @guid)
      @zone = FactoryGirl.create(:zone)
      @server1 = FactoryGirl.create(:miq_server, :zone => @zone, :guid => @guid, :status => "started")
      MiqServer.my_server(true)
      @server2 = FactoryGirl.create(:miq_server, :zone => @zone, :guid => MiqUUID.new_guid, :status => "started")
      MiqServer.any_instance.stub(:is_vix_disk? => true)
    end

    context "with hosts with a miq_proxy, vmware vms on storages" do
      before(:each) do
        @hosts, @proxies, @storages, @vms = self.build_hosts_proxies_storages_vms
        @vm = @vms.first
      end

      context "with vm's repository host as the last host, " do
        before(:each) do
          @repo_host = @hosts.last
          @vm.stub(:myhost => @repo_host)
        end

        context "with a host-less vm and it's storage having hosts, " do
          before(:each) do
            vm_storage = @vm.storage
            vm_storage.hosts | [@hosts.first]
            vm_storage.save
          end
          it "should return storage's hosts" do
            @vm.storage2hosts.should == @vm.storage.hosts
          end
        end

        context "with host-less vm and it's storage without hosts, " do
          before(:each) do
            vm_storage = @vm.storage
            vm_storage.hosts = []
            vm_storage.save
          end

          it "should return repo host" do
            @vm.storage2hosts.should == [@repo_host]
          end
        end

        context "with a non KVM vm tied to a host and it's storage having hosts, " do
          before(:each) do
            @vm.host = @hosts.first
            @vm.save
            vm_storage = @vm.storage
            vm_storage.hosts | [@hosts.first]
            vm_storage.save
          end

          it "should return storage's hosts" do
            @vm.storage2hosts.should == @vm.storage.hosts
          end
        end

        context "with a non KVM vm tied to a host and it's storage without hosts, " do
          before(:each) do
            @vm.host = @hosts.first
            @vm.save
            vm_storage = @vm.storage
            vm_storage.hosts = []
            vm_storage.save
          end

          it "should return repo host" do
            @vm.storage2hosts.should == [@repo_host]
          end
        end

        context "with a vmware vm on a non-vmware host which is also the only host on the vm's storage, " do
          before(:each) do
            @host = @hosts.first
            @host.vmm_vendor = "microsoft"
            @host.save
            @vm.host = @host
            vm_storage = @vm.storage
            vm_storage.hosts = [@host]
            vm_storage.save
            @vm.save
          end

          it "should exlude non-vmware hosts" do
            @vm.storage2hosts.should be_empty
          end
        end
      end
    end
  end
end
