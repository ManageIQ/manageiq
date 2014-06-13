require "spec_helper"

describe "JobProxyDispatcherVmMiqServerProxies" do
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

      context "with a started server, vix disk enabled, in same zone as a vmware vm with a host, " do
        before(:each) do
        end

        it "should return both servers" do
          res = @vm.miq_server_proxies
          res.length.should == 2
          res.include?(@server1).should be_true
          res.include?(@server2).should be_true
        end
      end

      context "with main server stopped, " do
        before(:each) do
          @server1.status = "stopped"
          @server1.save
        end
        it "should return second server" do
          @vm.miq_server_proxies.should == [@server2]
        end
      end

      context "with no vix disk enabled servers, " do
        before(:each) do
          MiqServer.any_instance.stub(:is_vix_disk? => false)
        end
        it "should return no servers" do
          @vm.miq_server_proxies.should be_empty
        end
      end

      context "with only a server in a different zone than the vm, " do
        before(:each) do
          @vms_zone = FactoryGirl.create(:zone, :description => "Zone 1", :name => "zone1")
          @server2.zone = @vms_zone
          @server2.save
          @vm.stub(:my_zone => @vms_zone.name)
        end
        it "should return only server2, in same zone" do
          @vm.miq_server_proxies.should == [@server2]
        end
      end

      context "with a non-vmware vm, " do
        before(:each) do
          @vm.vendor = "Microsoft"
          @vm.save
        end
        it "should return no servers" do
          @vm.miq_server_proxies.should be_empty
        end
      end

      context "with repository vm(a vm without a host), " do
        before(:each) do
          @vm.host = nil
          @vm.save
        end
        it "should return no servers" do
          @vm.miq_server_proxies.should be_empty
        end
      end

      context "with a vm without a storage, " do
        before(:each) do
          @vm.storage = nil
          @vm.save
        end
        it "should return no servers" do
          @vm.miq_server_proxies.should be_empty
        end
      end

      context "with the vm's host with vm scan affinity, " do
        before(:each) do
          host = @vm.host
          host.vm_scan_affinity = [@server2]
        end
        it "should return only servers in the host's affinity list" do
          @vm.miq_server_proxies.should == [@server2]
        end
      end

      context "with vm's host does not have scan affinity and main server has vm scan affinity for a different host, " do
        before(:each) do
          host = @hosts.find {|h| h != @vm.host}
          @server1.vm_scan_host_affinity = [host]
        end

        it "should return only second server (without any scan affinity)" do
          @vm.miq_server_proxies.should == [@server2]
        end
      end
    end
  end
end
