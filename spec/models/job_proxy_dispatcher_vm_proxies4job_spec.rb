RSpec.describe "JobProxyDispatcherVmProxies4Job" do
  include Spec::Support::JobProxyDispatcherHelper

  context "with two servers on same zone, vix disk enabled for all, " do
    before do
      @server1 = EvmSpecHelper.local_miq_server(:is_master => true)
      @server2 = FactoryBot.create(:miq_server, :zone => @server1.zone)
      allow_any_instance_of(MiqServer).to receive_messages(:is_vix_disk? => true)
    end

    context "with hosts with a miq_proxy, vmware vms on storages" do
      before do
        _hosts, _proxies, _storages, @vms = build_entities
        @vm = @vms.first
      end

      context "with available active proxy" do
        before do
          allow(@vm).to receive_messages(:storage2proxies => [@server1])
          allow(@vm).to receive_messages(:storage2active_proxies => [@server1])
        end

        it "should return with message informing that Smart State Analysis will be performed on this VM" do
          expect(@vm.proxies4job[:message]).to eq("Perform SmartState Analysis on this VM")
        end
      end

      context "with no eligible active proxies, " do
        before do
          allow(@vm).to receive_messages(:storage2active_proxies => [])
        end

        context "with @server1 in list of all eligible proxies before filtering, " do
          before do
            allow(@vm).to receive_messages(:storage2proxies => [@server1])
          end

          it "should return with message asking for VM's host's credentials" do
            expect(@vm.proxies4job[:message]).to eq("Provide credentials for this VM's Host to perform SmartState Analysis")
          end
        end

        context "with empty list of all eligible proxies before filtering, " do
          before do
            allow(@vm).to receive_messages(:storage2proxies => [])
          end

          it "should return with message 'No active SmartProxies'" do
            expect(@vm.proxies4job[:message]).to eq("No active SmartProxies found to analyze this VM")
          end
        end
      end

      context "with a vm scan job, with no eligible proxies, " do
        before do
          @job = @vm.raw_scan
          allow(@vm).to receive_messages(:storage2proxies => [])
        end

        it "should call 'log_all_proxies'" do
          expect(@vm).to receive(:log_all_proxies).with([], instance_of(String))
          expect(@vm.proxies4job(@job)[:proxies]).to be_empty
        end

        context "with VmAmazon, " do
          before do
            @vm.type = "ManageIQ::Providers::Amazon::CloudManager::Vm"
            @vm.save
            @vm = VmOrTemplate.find(@vm.id)
            allow(MiqServer).to receive_messages(:my_server => @server1)
          end

          it "should return my_server" do
            expect(@vm.proxies4job[:proxies]).to eq([@server1])
          end
        end
      end
    end
  end
end
