describe "JobProxyDispatcherVmMiqServerProxies" do
  include Spec::Support::JobProxyDispatcherHelper

  context "with two servers on same zone, vix disk enabled for all, " do
    let(:zone) { FactoryGirl.create(:zone) }
    before do
      @server1 = EvmSpecHelper.local_miq_server(:zone => zone)
      @server2 = FactoryGirl.create(:miq_server, :zone => zone)
      allow_any_instance_of(MiqServer).to receive_messages(:is_vix_disk? => true)
    end

    context "with hosts with a miq_proxy, vmware vms on storages" do
      before do
        @hosts, @proxies, @storages, @vms = build_entities(:zone => zone)
        @vm = @vms.first
      end

      context "with a started server, vix disk enabled, in same zone as a vmware vm with a host, " do
        before do
        end

        it "should return both servers" do
          res = @vm.miq_server_proxies
          expect(res.length).to eq(2)
          expect(res.include?(@server1)).to be_truthy
          expect(res.include?(@server2)).to be_truthy
        end
      end

      context "with main server stopped, " do
        before do
          @server1.status = "stopped"
          @server1.save
        end
        it "should return second server" do
          expect(@vm.miq_server_proxies).to eq([@server2])
        end
      end

      context "with no vix disk enabled servers, " do
        before do
          allow_any_instance_of(MiqServer).to receive_messages(:is_vix_disk? => false)
        end
        it "should return no servers" do
          expect(@vm.miq_server_proxies).to be_empty
        end
      end

      context "with only a server in a different zone than the vm, " do
        before do
          @vms_zone = FactoryGirl.create(:zone, :description => "Zone 1", :name => "zone1")
          @server2.zone = @vms_zone
          @server2.save
          allow(@vm).to receive_messages(:my_zone => @vms_zone.name)
        end
        it "should return only server2, in same zone" do
          expect(@vm.miq_server_proxies).to eq([@server2])
        end
      end

      context "with repository vm(a vm without a host), " do
        before do
          @vm.host = nil
          @vm.save
        end
        it "should return no servers" do
          expect(@vm.miq_server_proxies).to be_empty
        end
      end

      context "with a vm without a storage, " do
        before do
          @vm.storage = nil
          @vm.save
        end
        it "should return no servers" do
          expect(@vm.miq_server_proxies).to be_empty
        end
      end

      context "with the vm's host with vm scan affinity, " do
        before do
          host = @vm.host
          host.vm_scan_affinity = [@server2]
        end
        it "should return only servers in the host's affinity list" do
          expect(@vm.miq_server_proxies).to eq([@server2])
        end
      end

      context "with vm's host does not have scan affinity and main server has vm scan affinity for a different host, " do
        before do
          host = @hosts.find { |h| h != @vm.host }
          @server1.vm_scan_host_affinity = [host]
        end

        it "should return only second server (without any scan affinity)" do
          expect(@vm.miq_server_proxies).to eq([@server2])
        end
      end
    end
  end
end
