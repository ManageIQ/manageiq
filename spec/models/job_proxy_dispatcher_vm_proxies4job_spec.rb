require "spec_helper"

describe "JobProxyDispatcherVmProxies4Job" do
  require File.expand_path(File.join(File.dirname(__FILE__), 'job_proxy_dispatcher/job_proxy_dispatcher_helper'))
  include JobProxyDispatcherHelper

  context "with two servers on same zone, vix disk enabled for all, " do
    before(:each) do
      @server1 = EvmSpecHelper.local_miq_server(:is_master => true)
      @server2 = FactoryGirl.create(:miq_server, :zone => @server1.zone)
      MiqServer.any_instance.stub(:is_vix_disk? => true)
    end

    context "with hosts with a miq_proxy, vmware vms on storages" do
      before(:each) do
        @hosts, @proxies, @storages, @vms = build_hosts_proxies_storages_vms
        @vm = @vms.first
      end

      context "with no eligible active proxies, " do
        before(:each) do
          @vm.stub(:storage2active_proxies => [])
        end

        context "with @server1 in list of all eligible proxies before filtering, " do
          before(:each) do
            @vm.stub(:storage2proxies => [@server1])
          end

          it "should return with message asking for VM's host's creds" do
            @vm.proxies4job[:message].should == "Provide credentials for this VM's Host to perform SmartState Analysis"
          end
        end

        context "with first host in list of all eligible proxies before filtering, " do
          before(:each) do
            @vm.stub(:storage2proxies => [@hosts.first])
          end

          it "should return with message 'No active SmartProxies'" do
            @vm.proxies4job[:message].should == "No active SmartProxies found to analyze this VM"
          end
        end
      end

      context "with a single host 'eligible' but not the active Vmware Vm's host" do
        before(:each) do
          @host, @vms_host = @hosts
          @vm.stub(:storage2active_proxies => [@host])
          @vm.stub(:storage2proxies => [@host])
          @vm.host = @vms_host
          @vm.raw_power_state = "poweredOn"
          @vm.save
        end

        it "should return with message Smarstate Analysis is available through registered Host only" do
          @vm.proxies4job[:message].should == 'SmartState Analysis is only available through the registered Host for running VM'
        end

        context "with a server in the all proxy list" do
          before(:each) do
            @vm.stub(:storage2proxies => [@server1])
          end
          it "should return with message to start a smart proxy or provide Vm's hosts creds" do
            @vm.proxies4job[:message].should == "Start a SmartProxy or provide credentials for this VM's Host to perform SmartState Analysis"
          end
        end
      end

      context "with a vm scan job, with no eligible proxies, " do
        before(:each) do
          @job = @vm.scan
          @vm.stub(:storage2proxies => [])
          @vm.stub(:storage2activeproxies => [])
        end

        it "should accept an instance of a job and call log proxies with a job" do
          @vm.should_receive(:log_proxies).with([], [], (instance_of(String)), (instance_of(VmScan)))
          @vm.proxies4job(@job)[:proxies].should be_empty
        end

        it "should accept a job guid and call log proxies with a job" do
          @vm.should_receive(:log_proxies).with([], [], (instance_of(String)), (instance_of(VmScan)))
          @vm.proxies4job(@job.guid)[:proxies].should be_empty
        end

        context "with VmAmazon, " do
          before(:each) do
            @vm.type = "ManageIQ::Providers::Amazon::CloudManager::Vm"
            @vm.save
            @vm = VmOrTemplate.find(@vm.id)
            MiqServer.stub(:my_server => @server1)
          end

          it "should return my_server" do
            @vm.proxies4job[:proxies].should == [@server1]
          end
        end
      end
    end
  end
end
