RSpec.describe "JobProxyDispatcherGetEligibleProxiesForJob" do
  include Spec::Support::JobProxyDispatcherHelper

  context "with two servers on same zone, vix disk enabled for all, " do
    before do
      @server1 = EvmSpecHelper.local_miq_server
      @server2 = FactoryBot.create(:miq_server, :zone => @server1.zone)
      allow_any_instance_of(MiqServer).to receive_messages(:is_vix_disk? => true)

      # Support old style class methods or new instance style
      @jpd = JobProxyDispatcher.respond_to?(:get_eligible_proxies_for_job) ? JobProxyDispatcher : JobProxyDispatcher.new
    end

    context "with hosts with a miq_proxy, vmware vms on storages" do
      before do
        @hosts, @proxies, @storages, @vms = build_entities
        @vm = @vms.first
      end

      context "with a vm scan job, " do
        before do
          @job = @vm.raw_scan
          @jpd.instance_of?(JobProxyDispatcher) ? @jpd.instance_variable_set(:@vm, @vm) : @jpd.send(:class_variable_set, :@@vm, @vm)
          @jpd.instance_variable_set(:@vm, @vm)
        end

        context "and the vm attached to the job was not found, so @vm is nil, " do
          before do
            @jpd.instance_of?(JobProxyDispatcher) ? @jpd.instance_variable_set(:@vm, nil) : @jpd.send(:class_variable_set, :@@vm, nil)
          end

          it "should return an empty array" do
            expect(@jpd.get_eligible_proxies_for_job(@job)).to be_empty
          end
        end

        context "vm on unsupported storage type, " do
          before do
            store = @vm.storage
            store.store_type = "VMFS2"
            store.save
          end

          it "should return an empty array" do
            expect(@jpd.get_eligible_proxies_for_job(@job)).to be_empty
          end
        end

        context "with no proxies for job, " do
          before do
            allow_any_instance_of(ManageIQ::Providers::Vmware::InfraManager::Vm).to receive_messages(:proxies4job => {:proxies => [], :message => "blah"})
          end

          it "should return an empty array" do
            expect(@jpd.get_eligible_proxies_for_job(@job)).to be_empty
          end
        end
      end
    end
  end
end
